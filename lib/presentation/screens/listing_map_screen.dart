import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/category_model.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/presentation/common_methods/common_methods.dart';

/* --------------------------------------------------------
   LISTING MAP SCREEN
-------------------------------------------------------- */

class ListingMapScreen extends StatefulWidget {
  const ListingMapScreen({super.key});

  @override
  State<ListingMapScreen> createState() => _ListingMapScreenState();
}

class _ListingMapScreenState extends State<ListingMapScreen> {
  Set<Marker> _markers = {};
  Listing? _selectedListing;
  GoogleMapController? _mapController;

  List<Listing> _allListings = [];
  String _selectedCategory = 'All Categories';

  List<Category> _categories = [];

  bool _categoriesLoading = true;

  /// Cache marker icons by image URL
  final Map<String, BitmapDescriptor> _markerCache = {};

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _listenListings();
  }

  Future<void> _fetchCategories() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('categories').get();

      final fetched =
          snapshot.docs.map((d) => Category.fromJson(d.data())).toList()..sort(
            (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
          );

      if (mounted) {
        setState(() {
          _categories = fetched;
          _categoriesLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Failed to fetch categories: $e');
      setState(() => _categoriesLoading = false);
    }
  }

  void _listenListings() {
    FirebaseFirestore.instance.collection('listings').snapshots().listen((
      snapshot,
    ) async {
      _allListings =
          snapshot.docs.map((d) => Listing.fromJson(d.data())).toList();

      await _applyCategoryFilter();
    });
  }

  Future<Set<Marker>> _buildMarkers(List<Listing> listings) async {
    final markers = <Marker>{};

    for (final listing in listings) {
      markers.add(
        Marker(
          markerId: MarkerId(listing.listingId),
          position: LatLng(listing.geo.lat, listing.geo.lng),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          onTap: () async {
            setState(() {
              _selectedListing = listing;
            });
            await _animateToListing(listing);
          },
        ),
      );
    }

    // Load custom markers in background
    _loadCustomMarkers(listings);

    return markers;
  }

  Future<void> _loadCustomMarkers(List<Listing> listings) async {
    for (final listing in listings) {
      if (listing.images.isEmpty) continue;

      final icon = await _getCustomMarker(listing.images.first.thumbUrl);

      final marker = Marker(
        markerId: MarkerId(listing.listingId),
        position: LatLng(listing.geo.lat, listing.geo.lng),
        icon: icon,
        onTap: () async {
          setState(() {
            _selectedListing = listing;
          });
          await _animateToListing(listing);
        },
      );

      if (!mounted) return;

      setState(() {
        _markers.removeWhere((m) => m.markerId.value == listing.listingId);
        _markers.add(marker);
      });
    }
  }

  Future<void> _applyCategoryFilter() async {
    final filtered =
        _selectedCategory == 'All Categories'
            ? _allListings
            : _allListings
                .where((l) => l.category == _selectedCategory)
                .toList();

    final markers = await _buildMarkers(filtered);

    if (mounted) {
      setState(() => _markers = markers);
    }
  }

  Future<void> _animateToListing(Listing listing) async {
    if (_mapController == null) return;

    await _mapController!.animateCamera(
      duration: Duration(milliseconds: 920),
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(listing.geo.lat, listing.geo.lng),

          zoom: 13,
        ),
      ),
    );
  }

  /* --------------------------------------------------------
     CUSTOM MARKER (RED PIN + CIRCULAR IMAGE)
  -------------------------------------------------------- */

  Future<BitmapDescriptor> _getCustomMarker(String imageUrl) async {
    if (_markerCache.containsKey(imageUrl)) {
      return _markerCache[imageUrl]!;
    }

    final Uint8List imageBytes =
        (await http.get(Uri.parse(imageUrl))).bodyBytes;

    final codec = await ui.instantiateImageCodec(
      imageBytes,
      targetWidth: 72,
      targetHeight: 72,
    );
    final frame = await codec.getNextFrame();
    final ui.Image image = frame.image;

    const int size = 200;
    const double imageRadius = 60;
    const double borderWidth = 7;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..isAntiAlias = true;

    /// Transparent background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
      Paint()..color = Colors.transparent,
    );

    /// Red pin body
    paint.color = AppColors.THEME_COLOR;
    final path =
        Path()
          ..moveTo(size / 2, size.toDouble())
          ..quadraticBezierTo(10, size / 2, size / 2, size / 2)
          ..quadraticBezierTo(size - 10, size / 2, size / 2, size.toDouble());
    canvas.drawPath(path, paint);

    /// White circular border
    paint.color = Colors.white;
    canvas.drawCircle(
      Offset(size / 2, size / 2 - 12),
      imageRadius + borderWidth,
      paint,
    );

    /// Clip circular image
    final clipPath =
        Path()..addOval(
          Rect.fromCircle(
            center: Offset(size / 2, size / 2 - 12),
            radius: imageRadius,
          ),
        );

    canvas.save();
    canvas.clipPath(clipPath);

    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      Rect.fromCircle(
        center: Offset(size / 2, size / 2 - 12),
        radius: imageRadius,
      ),
      Paint(),
    );

    canvas.restore();

    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    final descriptor = BitmapDescriptor.bytes(byteData!.buffer.asUint8List());

    _markerCache[imageUrl] = descriptor;
    return descriptor;
  }

  /* --------------------------------------------------------
     UI
  -------------------------------------------------------- */

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(
              target: LatLng(22.5744, 88.3629),
              zoom: 9,
            ),
            markers: _markers,
            onMapCreated: (controller) {
              _mapController = controller;
            },
            onTap: (_) => setState(() => _selectedListing = null),
          ),

          if (_selectedListing != null)
            Positioned(
              bottom: 25,
              left: 16,
              right: 16,
              child: ListingPreviewCard(listing: _selectedListing!),
            ),

          // Positioned(
          //   top: 12,
          //   left: 16,
          //   right: 16,
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child:
                  _categoriesLoading
                      ? const SizedBox(
                        height: 48,
                        child: Center(child: CircularProgressIndicator()),
                      )
                      : _CategorySelector(
                        categories: _categories,
                        selected: _selectedCategory,
                        onChanged: (value) async {
                          if (value == _selectedCategory) return;
                          setState(() => _selectedCategory = value);
                          await _applyCategoryFilter();
                        },
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

/* --------------------------------------------------------
   PREVIEW CARD
-------------------------------------------------------- */

class _CategorySelector extends StatelessWidget {
  final List<Category> categories;
  final String selected;
  final ValueChanged<String> onChanged;

  const _CategorySelector({
    required this.categories,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.96),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.teal.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 22,
            spreadRadius: 1,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      // elevation: 6,
      // borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selected,
            isExpanded: true,
            // icon: const Icon(Icons.filter_list),
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.teal.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.tune_rounded,
                size: 20,
                color: Colors.black,
              ),
            ),
            items: [
              const DropdownMenuItem(
                value: 'All Categories',
                child: Text(
                  'All Categories',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              ...categories.map(
                (c) => DropdownMenuItem(
                  value: c.name,
                  child: Row(
                    children: [
                      if (c.imageUrl.isNotEmpty)
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CachedNetworkImage(
                            imageUrl: c.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            // show your shimmer while loading
                            // placeholder: Shimmer.fromColors(
                            //   baseColor: AppColors.GREY_SHADE_300,
                            //   highlightColor: AppColors.GREY_SHADE_100,
                            //   child: Container(color: AppColors.GREY_SHADE_300),
                            // ),
                            // errorWidget: const Icon(Icons.broken_image),
                          ),
                        ),

                      if (c.imageUrl.isNotEmpty) const SizedBox(width: 15),
                      Text(
                        c.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            onChanged: (v) {
              if (v != null) onChanged(v);
            },
          ),
        ),
      ),
    );
  }
}

class ListingPreviewCard extends StatelessWidget {
  final Listing listing;

  const ListingPreviewCard({super.key, required this.listing});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        CommonMethods.navigateToListingDetailScreen(context, listing, []);
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.WHITE,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            bottomLeft: Radius.circular(28),
          ),
        ),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: AppColors.THEME_COLOR,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(28),
                  bottomLeft: Radius.circular(28),
                ),
                boxShadow: [
                  BoxShadow(
                    // blurStyle: BlurStyle.outer,
                    color: Colors.black.withOpacity(0.15),
                    blurRadius: 25,
                    spreadRadius: 0,
                    offset: const Offset(8, 0),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.only(left: 10.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                  ),
                  child:
                      listing.images.isNotEmpty
                          ? Image.network(
                            listing.images.first.thumbUrl,
                            width: 110,
                            height: 110,
                            fit: BoxFit.cover,
                          )
                          // : Icon(Icons.broken_image),
                          : Container(
                            height: 110,
                            width: 110,
                            child: Icon(Icons.broken_image),
                          ),
                ),
              ),
            ),

            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10.0, left: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF111827),
                        letterSpacing: -0.5,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 7),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00897B).withOpacity(0.10),
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                      ),
                      child: Text(
                        listing.category,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF00897B),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        // Filled / half / empty stars
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(5, (i) {
                            final icon =
                                i < listing.rating.floor()
                                    ? Icons.star_rounded
                                    : (i < listing.rating &&
                                        listing.rating - i >= 0.5)
                                    ? Icons.star_half_rounded
                                    : Icons.star_outline_rounded;
                            return Icon(
                              icon,
                              size: 12,
                              color: const Color(0xFFF59E0B),
                            );
                          }),
                        ),

                        const SizedBox(width: 6),
                        Text(
                          listing.rating.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          "(${listing.reviews})",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Column(
              children: [
                SizedBox(height: 42),
                Icon(
                  Icons.keyboard_arrow_right_rounded,
                  color: AppColors.THEME_COLOR,
                ),
              ],
            ),
          ],
        ),

        // child: Padding(
        //   padding: const EdgeInsets.only(left: 6),
        //   child: Column(
        //     crossAxisAlignment: CrossAxisAlignment.start,
        //     children: [
        //       Row(
        //         crossAxisAlignment: CrossAxisAlignment.start,
        //         children: [
        //           ClipRRect(
        //             borderRadius: BorderRadius.only(
        //               topLeft: Radius.circular(18),
        //               bottomLeft: Radius.circular(18),
        //             ),
        //             child:
        //                 listing.images.isNotEmpty
        //                     ? Image.network(
        //                       listing.images.first.thumbUrl,
        //                       width: 120,
        //                       height: 120,
        //                       fit: BoxFit.cover,
        //                     )
        //                     : Icon(Icons.broken_image),
        //           ),
        //           Expanded(
        //             child: Container(
        //               color: Colors.white,
        //               child: Padding(
        //                 padding: const EdgeInsets.only(
        //                   top: 10.0,
        //                   left: 10,
        //                   bottom: 36,
        //                 ),
        //                 child: Column(
        //                   crossAxisAlignment: CrossAxisAlignment.start,
        //                   children: [
        //                     Text(
        //                       listing.name,
        //                       style: const TextStyle(
        //                         fontSize: 17,
        //                         fontWeight: FontWeight.w700,
        //                         color: Color(0xFF111827),
        //                         letterSpacing: -0.2,
        //                       ),
        //                       maxLines: 1,
        //                       overflow: TextOverflow.ellipsis,
        //                     ),
        //                     SizedBox(height: 6),
        //                     Container(
        //                       padding: const EdgeInsets.symmetric(
        //                         horizontal: 10,
        //                         vertical: 5,
        //                       ),
        //                       decoration: BoxDecoration(
        //                         color: const Color(
        //                           0xFF00897B,
        //                         ).withOpacity(0.10),
        //                         borderRadius: BorderRadius.only(
        //                           topRight: Radius.circular(18),
        //                           bottomRight: Radius.circular(18),
        //                         ),
        //                       ),
        //                       child: Text(
        //                         listing.category,
        //                         style: const TextStyle(
        //                           fontSize: 10,
        //                           fontWeight: FontWeight.w600,
        //                           color: Color(0xFF00897B),
        //                           letterSpacing: 0.2,
        //                         ),
        //                       ),
        //                     ),
        //                     const SizedBox(height: 4),
        //                     Row(
        //                       children: [
        //                         // Filled / half / empty stars
        //                         Row(
        //                           mainAxisSize: MainAxisSize.min,
        //                           children: List.generate(5, (i) {
        //                             final icon =
        //                                 i < listing.rating.floor()
        //                                     ? Icons.star_rounded
        //                                     : (i < listing.rating &&
        //                                         listing.rating - i >= 0.5)
        //                                     ? Icons.star_half_rounded
        //                                     : Icons.star_outline_rounded;
        //                             return Icon(
        //                               icon,
        //                               size: 12,
        //                               color: const Color(0xFFF59E0B),
        //                             );
        //                           }),
        //                         ),
        //                         const SizedBox(width: 6),
        //                         Text(
        //                           listing.rating.toStringAsFixed(1),
        //                           style: const TextStyle(
        //                             fontSize: 12,
        //                             fontWeight: FontWeight.w600,
        //                             color: Color(0xFF111827),
        //                           ),
        //                         ),
        //                         const SizedBox(width: 4),
        //                         Text(
        //                           "(${listing.reviews})",
        //                           style: TextStyle(
        //                             fontSize: 12,
        //                             color: Colors.grey.shade400,
        //                           ),
        //                         ),
        //                       ],
        //                     ),
        //                   ],
        //                 ),
        //               ),
        //             ),
        //           ),
        //         ],
        //       ),
        //       // Expanded(
        //       //   child: Row(
        //       //     children: [Container(height: 20, color: Colors.white)],
        //       //   ),
        //       // ),
        //       // const SizedBox(width: 12),
        //       // Expanded(
        //       //   child: Column(
        //       //     crossAxisAlignment: CrossAxisAlignment.start,
        //       //     children: [
        //       //       Text(
        //       //         listing.name,
        //       //         style: const TextStyle(
        //       //           fontSize: 16,
        //       //           fontWeight: FontWeight.bold,
        //       //         ),
        //       //       ),
        //       //       Text(listing.category),
        //       //       const SizedBox(height: 4),
        //       //       Row(
        //       //         children: [
        //       //           const Icon(Icons.star, size: 14, color: Colors.amber),
        //       //           const SizedBox(width: 4),
        //       //           Text(listing.rating.toStringAsFixed(1)),
        //       //           const SizedBox(width: 8),
        //       //           Text("(${listing.reviews})"),
        //       //         ],
        //       //       ),
        //       //     ],
        //       //   ),
        //       // ),
        //     ],
        //   ),
        // ),
      ),
    );
  }
}
