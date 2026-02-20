import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:shimmer/shimmer.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/category_model.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/presentation/common_methods/cached_network_svg.dart';
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
  GoogleMapController? _mapController;
  Set<Marker> _markers = {};
  Listing? _selectedListing;

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
    FirebaseFirestore.instance.collection('listings').where("verifiedBy", isNull: false).snapshots().listen((
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
        icon: BitmapDescriptor.defaultMarkerWithHue(
          BitmapDescriptor.hueRed,
        ),
        onTap: () => setState(() => _selectedListing = listing),
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
      onTap: () => setState(() => _selectedListing = listing),
    );

    if (!mounted) return;

    setState(() {
      _markers.removeWhere(
        (m) => m.markerId.value == listing.listingId,
      );
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

    final descriptor = BitmapDescriptor.fromBytes(
      byteData!.buffer.asUint8List(),
    );

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
            onMapCreated: (controller) => _mapController = controller,
            onTap: (_) => setState(() => _selectedListing = null),
          ),

          if (_selectedListing != null)
            Positioned(
              bottom: 20,
              left: 16,
              right: 16,
              child: ListingPreviewCard(listing: _selectedListing!),
            ),

          Positioned(
            top: 50,
            left: 16,
            right: 16,
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
    return Material(
      elevation: 6,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: selected,
            isExpanded: true,
            icon: const Icon(Icons.filter_list),
            items: [
              const DropdownMenuItem(
                value: 'All Categories',
                child: Text('All Categories'),
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
                          child: CachedNetworkSvg(
                            url: c.imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                            // show your shimmer while loading
                            placeholder: Shimmer.fromColors(
                              baseColor: AppColors.GREY_SHADE_300,
                              highlightColor: AppColors.GREY_SHADE_100,
                              child: Container(color: AppColors.GREY_SHADE_300),
                            ),
                            errorWidget: const Icon(Icons.broken_image),
                          ),
                        ),

                      if (c.imageUrl.isNotEmpty) const SizedBox(width: 8),
                      Text(c.name),
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
      child: Card(
        elevation: 6,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),

        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: listing.images.isNotEmpty? Image.network(
                  listing.images.first.thumbUrl,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover
                ):Icon(Icons.broken_image)
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listing.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(listing.category),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(listing.rating.toStringAsFixed(1)),
                        const SizedBox(width: 8),
                        Text("(${listing.reviews})"),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
