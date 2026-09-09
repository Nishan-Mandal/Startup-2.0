import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/category_model.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/presentation/common_methods/common_methods.dart';
import 'package:startup_20/presentation/common_methods/searchable_dropdown.dart';

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
  int _filterRequestId = 0;

  List<Category> _categories = [];
  final Map<String, String> _catIconsURL = {};

  bool _categoriesLoading = true;

  /// Cache marker icons by image URL
  final Map<String, BitmapDescriptor> _markerCache = {};
  final Map<String, Future<BitmapDescriptor>> _markerFutureCache = {};

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

      if (!mounted) return;

      setState(() {
        _categories = fetched;

        _catIconsURL.clear();

        for (final cat in fetched) {
          _catIconsURL[cat.name.trim().toLowerCase()] = cat.imageUrl;
        }

        _categoriesLoading = false;
      });

      // Listings may have loaded before categories.
      // Rebuild markers now that category icons are ready.
      if (_allListings.isNotEmpty) {
        await _applyCategoryFilter();
      }
    } catch (e) {
      debugPrint('Failed to fetch categories: $e');

      if (mounted) {
        setState(() {
          _categoriesLoading = false;
        });
      }
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

  Set<Marker> _buildDefaultMarkers(List<Listing> listings) {
    return listings.map((listing) {
      return Marker(
        markerId: MarkerId(listing.listingId),
        position: LatLng(listing.geo.lat, listing.geo.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        onTap: () async {
          if (!mounted) return;

          setState(() {
            _selectedListing = listing;
          });

          await _animateToListing(listing);
        },
      );
    }).toSet();
  }

  Future<void> _applyCategoryFilter() async {
    final int requestId = ++_filterRequestId;

    final selectedCategory = _selectedCategory.trim().toLowerCase();

    final filteredListings =
        selectedCategory == 'all categories'
            ? List<Listing>.from(_allListings)
            : _allListings.where((listing) {
              return listing.category.trim().toLowerCase() == selectedCategory;
            }).toList();

    debugPrint(
      'Map filter: $_selectedCategory → '
      '${filteredListings.length} listings',
    );

    // --------------------------------------------------
    // STEP 1: Show normal markers immediately.
    // No network / image processing here.
    // --------------------------------------------------

    final defaultMarkers = _buildDefaultMarkers(filteredListings);

    if (!mounted || requestId != _filterRequestId) {
      return;
    }

    setState(() {
      _markers = defaultMarkers;
      _selectedListing = null;
    });

    // --------------------------------------------------
    // STEP 2: Load category icons in background.
    // --------------------------------------------------

    _loadCategoryMarkers(filteredListings, requestId);
  }

  Future<void> _loadCategoryMarkers(
    List<Listing> listings,
    int requestId,
  ) async {
    // Group listings by category icon URL.
    //
    // 30 Bike Showrooms = 1 icon request
    // 20 Hospitals = 1 icon request
    //
    // Not one request per listing.

    final Map<String, List<Listing>> grouped = {};

    for (final listing in listings) {
      final categoryName = listing.category.trim().toLowerCase();

      final imageUrl = _catIconsURL[categoryName];

      if (imageUrl == null || imageUrl.isEmpty) {
        continue;
      }

      grouped.putIfAbsent(imageUrl, () => []).add(listing);
    }

    // Process category icons in small batches.
    //
    // This prevents 100+ image downloads/decodes
    // from hitting the UI/network at once.
    final entries = grouped.entries.toList();

    const batchSize = 5;

    for (int i = 0; i < entries.length; i += batchSize) {
      if (!mounted || requestId != _filterRequestId) {
        return;
      }

      final batch = entries.skip(i).take(batchSize);

      await Future.wait(
        batch.map((entry) async {
          final imageUrl = entry.key;

          final marker = await _getMarkerForImage(imageUrl);

          if (!mounted || requestId != _filterRequestId) {
            return;
          }

          final listingIds =
              entry.value.map((listing) => listing.listingId).toSet();

          setState(() {
            _markers =
                _markers.map((existingMarker) {
                  if (listingIds.contains(existingMarker.markerId.value)) {
                    return Marker(
                      markerId: existingMarker.markerId,
                      position: existingMarker.position,
                      icon: marker,
                      onTap: existingMarker.onTap,
                      infoWindow: existingMarker.infoWindow,
                      rotation: existingMarker.rotation,
                      anchor: existingMarker.anchor,
                      flat: existingMarker.flat,
                      draggable: existingMarker.draggable,
                      visible: existingMarker.visible,
                      zIndex: existingMarker.zIndex,
                    );
                  }

                  return existingMarker;
                }).toSet();
          });
        }),
      );

      // Give Flutter a chance to render between batches.
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
  }

  Future<void> _animateToListing(Listing listing) async {
    if (_mapController == null) return;

    await _mapController!.animateCamera(
      duration: Duration(milliseconds: 920),
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(listing.geo.lat, listing.geo.lng),

          zoom: 9.5,
        ),
      ),
    );
  }

  Future<BitmapDescriptor> _getMarkerForImage(String imageUrl) async {
    // Already generated
    final cachedMarker = _markerCache[imageUrl];

    if (cachedMarker != null) {
      return cachedMarker;
    }

    // Already being generated/downloaded
    final existingFuture = _markerFutureCache[imageUrl];

    if (existingFuture != null) {
      return existingFuture;
    }

    final future = _createMarkerFromUrl(imageUrl);

    _markerFutureCache[imageUrl] = future;

    try {
      final marker = await future;

      _markerCache[imageUrl] = marker;

      return marker;
    } finally {
      _markerFutureCache.remove(imageUrl);
    }
  }

  Future<BitmapDescriptor> _createMarkerFromUrl(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));

      if (response.statusCode != 200) {
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      }

      return await _createCategoryMarker(response.bodyBytes);
    } catch (e) {
      debugPrint('Marker image error: $e');

      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }
  }

  Future<BitmapDescriptor> _createCategoryMarker(Uint8List imageBytes) async {
    final codec = await ui.instantiateImageCodec(
      imageBytes,
      targetWidth: 80,
      targetHeight: 80,
    );

    final frame = await codec.getNextFrame();
    final iconImage = frame.image;

    const double size = 120;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..isAntiAlias = true;

    // custom pin -> APPTHEME -> GREEN
    _drawPin(canvas, paint, size);

    // icon ke lie circle -> WHITE
    _drawCategoryCircle(canvas, paint, size);

    // Category icon inside WHITE circle
    _drawCategoryIcon(canvas, iconImage, size);

    // --------------------------------------------------
    // Convert to BitmapDescriptor
    // --------------------------------------------------
    final picture = recorder.endRecording();

    final image = await picture.toImage(size.toInt(), size.toInt());

    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    }

    return BitmapDescriptor.bytes(byteData.buffer.asUint8List(), width: 55);
  }

  void _drawPin(Canvas canvas, Paint paint, double size) {
    paint.color = AppColors.RED;

    final centerX = size / 2;

    final pinPath =
        Path()
          ..moveTo(centerX, 108)
          ..quadraticBezierTo(25, 70, centerX, 48)
          ..quadraticBezierTo(size - 25, 70, centerX, 108);

    canvas.drawPath(pinPath, paint);
  }

  void _drawCategoryCircle(Canvas canvas, Paint paint, double size) {
    paint.color = AppColors.WHITE;

    canvas.drawCircle(Offset(size / 2, 40), 40, paint);

    paint.color = AppColors.RED;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 4.0;
    canvas.drawCircle(Offset(size / 2, 42), 40, paint);
  }

  void _drawCategoryIcon(Canvas canvas, ui.Image iconImage, double size) {
    const double iconSize = 50;

    final destination = Rect.fromCenter(
      center: Offset(size / 2, 42),
      width: iconSize,
      height: iconSize,
    );

    canvas.drawImageRect(
      iconImage,
      Rect.fromLTWH(
        0,
        0,
        iconImage.width.toDouble(),
        iconImage.height.toDouble(),
      ),
      destination,
      Paint()..isAntiAlias = true,
    );
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
            // mapType: MapType.hybrid,
            initialCameraPosition: const CameraPosition(
              target: LatLng(22.5744, 88.3629),
              zoom: 9.5,
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

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child:
                  _categoriesLoading
                      ? const SizedBox(
                        height: 48,
                        child: Center(child: CircularProgressIndicator()),
                      )
                      : SearchableDropdown(
                        categories: _categories,
                        onCategorySelected: (id, name) async {
                          final newCategory =
                              name.isEmpty ? 'All Categories' : name;

                          if (newCategory == _selectedCategory) return;

                          setState(() {
                            _selectedCategory = newCategory;
                          });
                          await _applyCategoryFilter();
                        },
                        selectedCategoryId: null,
                        selectedCategoryName:
                            _selectedCategory == 'All Categories'
                                ? null
                                : _selectedCategory,
                        style: SearchableDropdownStyle.compact,
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
      ),
    );
  }
}
