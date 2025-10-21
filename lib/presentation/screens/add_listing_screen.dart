import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/presentation/common_methods/cached_network_svg.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:startup_20/data/models/category_model.dart' as models;
import 'package:geocoding/geocoding.dart';

class AddListingScreen extends StatefulWidget {
  @override
  _AddListingScreenState createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  late double _latitude;
  late double _longitude;
  late Future<List<models.Category>> _categoriesFuture;
  String? _selectedCategory;
  bool _isLoading = false;

  final List<File> _images = [];

  @override
  void initState() {
    super.initState();
    _categoriesFuture = fetchCategories();
  }

  /// 🔹 Fetch categories from Firestore
  Future<List<models.Category>> fetchCategories() async {
    final snapshot =
        await FirebaseFirestore.instance.collection("categories").get();

    return snapshot.docs
        .map((doc) => models.Category.fromJson(doc.data()))
        .toList();
  }

  /// Pick multiple images
  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _images.addAll(pickedFiles.map((file) => File(file.path)).toList());
      });
    }
  }

  /// Compress an image to Uint8List
  /// Compress an image to Uint8List (nullable in case of failure)
  Future<Uint8List?> _compressImage(
    File file, {
    required int minWidth,
    required int minHeight,
    required int quality,
  }) async {
    try {
      if (kIsWeb) {
        // Compression not supported on Web
        debugPrint(
          "Compression not supported on Web. Returning original file bytes.",
        );
        return await file.readAsBytes();
      }

      debugPrint('->>> Starting compression');
      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        minWidth: minWidth,
        minHeight: minHeight,
        quality: quality,
      );
      debugPrint('->>> Compression finished');

      if (result == null) throw Exception("Image compression failed");
      return result;
    } catch (e, stack) {
      debugPrint("Compression error: $e");
      debugPrint("Stack trace: $stack");

      // Fallback → return original bytes instead of crashing
      try {
        return await file.readAsBytes();
      } catch (_) {
        return null; // ultimate fallback
      }
    }
  }

  /// Upload single image (full + thumbnail)
  Future<Map<String, dynamic>> _uploadImage(File file, String listingId) async {
    final storageRef = FirebaseStorage.instance.ref();
    final fileId = const Uuid().v4();

    // 📌 Print original file size
    final originalSize = await file.length();
    debugPrint(
      "📷 Original image size: ${(originalSize / 1024).toStringAsFixed(2)} KB",
    );

    // Compress full image
    final Uint8List? fullData = await _compressImage(
      file,
      minWidth: 1080,
      minHeight: 1080,
      quality: 75,
    );

    debugPrint(
      "📷 Full image size: ${(fullData?.lengthInBytes ?? 0) / 1024} KB",
    );

    // Compress thumbnail
    final Uint8List? thumbData = await _compressImage(
      file,
      minWidth: 300,
      minHeight: 300,
      quality: 50,
    );

    debugPrint(
      "📷 Thumbnail size: ${(thumbData?.lengthInBytes ?? 0) / 1024} KB",
    );

    // Upload full
    final fullRef = storageRef.child("listings/$listingId/full_$fileId.jpg");
    await fullRef.putData(
      fullData!,
      SettableMetadata(contentType: "image/jpeg"),
    );
    final fullUrl = await fullRef.getDownloadURL();

    // Upload thumbnail
    final thumbRef = storageRef.child("listings/$listingId/thumb_$fileId.jpg");
    await thumbRef.putData(
      thumbData!,
      SettableMetadata(contentType: "image/jpeg"),
    );
    final thumbUrl = await thumbRef.getDownloadURL();

    return {"fullUrl": fullUrl, "thumbUrl": thumbUrl, "fileId": fileId};
  }

  /// Upload multiple images
  Future<List<Map<String, dynamic>>> _uploadImages(
    String contributionId,
  ) async {
    List<Map<String, dynamic>> uploaded = [];
    for (var img in _images) {
      final data = await _uploadImage(img, contributionId);
      uploaded.add(data);
    }
    return uploaded;
  }

  /// Get current location and update address
  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Location permission denied")),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Location permissions are permanently denied"),
          ),
        );
        return;
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      await _getAddressFromLatLng(position);

      debugPrint(
        "📍 Current Location: ${position.latitude}, ${position.longitude}",
      );
    } catch (e) {
      _isLoading = false;
      debugPrint("Error getting location: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error getting location: $e")));
    }
  }

  /// Convert lat/lng to address
  Future<void> _getAddressFromLatLng(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;

        String address =
            "${place.street}, ${place.locality}, ${place.administrativeArea}";

        setState(() {
          _addressController.text = address;
          _latitude = position.latitude.toDouble();
          _longitude = position.longitude.toDouble();
          _isLoading = false;
        });
      } else {
        debugPrint("⚠️ No address found");
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("No address found")));
      }
    } catch (e) {
      _isLoading = false;
      debugPrint("❌ Error reverse geocoding: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error getting address")));
    }
  }

  /// Submit contribution
Future<void> _submitContribution() async {
  setState(() {
    _isLoading = true;
  });

  try {
    // ✅ Validate mandatory fields
    if (_addressController.text.trim().isEmpty ||
        _nameController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in all required fields."),
          backgroundColor: AppColors.RED,
        ),
      );
      return;
    }

    final firestore = FirebaseFirestore.instance;

    final listingDocRef = firestore.collection("listings").doc();
    final contributionDocRef = firestore.collection("contributions").doc();

    // ✅ Upload images
    final imageList = await _uploadImages(listingDocRef.id);

    // Convert uploaded image maps → ImageFile models
    final images = imageList
        .map<ImageFile>(
          (img) => ImageFile(
            fileId: img['fileId'],
            fullUrl: img['fullUrl'],
            thumbUrl: img['thumbUrl'],
          ),
        )
        .toList();

    // ✅ Create the Listing model object
    final listing = Listing(
      listingId: listingDocRef.id,
      contributionId: contributionDocRef.id,
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      description: _descriptionController.text.trim(),
      geo: Geo(lat: _latitude ?? 0.0, lng: _longitude ?? 0.0),
      phone: _phoneController.text.trim(),
      category: _selectedCategory!,
      tags: [_selectedCategory!],
      addedBy: FirebaseAuth.instance.currentUser?.uid ?? "anonymous",
      isClaimed: false,
      ownerId: FirebaseAuth.instance.currentUser?.uid ?? "anonymous",
      claimStatus: "pending",
      verifiedBy: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      images: images,
      reviews: 0,
      rating: 0,
    );

    // ✅ Create Contribution data
    final contributionData = {
      "contributionId": contributionDocRef.id,
      "userId": FirebaseAuth.instance.currentUser?.uid ?? "anonymous",
      "listingId": listingDocRef.id,
      "type": "add",
      "status": "pending",
      "reviewedBy": null,
      "createdAt": FieldValue.serverTimestamp(),
      "updatedAt": FieldValue.serverTimestamp(),
    };

    // ✅ Save both documents
    await listingDocRef.set(listing.toJson());
    await contributionDocRef.set(contributionData);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("✅ Contribution submitted for review!"),
          backgroundColor: AppColors.GREEN,
        ),
      );
      Navigator.pop(context);
    }
  } catch (e, st) {
    debugPrint("❌ Error while submitting contribution: $e\n$st");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }
}


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.WHITE,
      appBar: AppBar(
        iconTheme: IconThemeData(color: AppColors.WHITE),
        title: const Text(
          "Upload Listing",
          style: TextStyle(color: AppColors.WHITE),
        ),
        backgroundColor: AppColors.THEME_COLOR,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Image Upload Box
                  GestureDetector(
                    onTap: () {
                      _pickImages();
                    },
                    child: Container(
                      height: 150,
                      decoration: BoxDecoration(
                        color: AppColors.GREY_SHADE_300,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_upload,
                              size: 50,
                              color: AppColors.BLACK_54,
                            ),
                            SizedBox(height: 8),
                            Text("Tap to upload image"),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 📸 Preview selected images
                  if (_images.isNotEmpty)
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _images.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    _images[index],
                                    width: 120,
                                    height: 120,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                              // ❌ Remove button
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      _images.removeAt(index);
                                    });
                                  },
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: AppColors.BLACK_54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 20,
                                      color: AppColors.WHITE,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Latitude & Longitude + GPS Button
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _addressController,
                          decoration: const InputDecoration(
                            labelText: "*Address",
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 1,
                          enabled: false, // ensure this is true (default)
                          readOnly: true,
                        ),
                      ),

                      IconButton(
                        icon: Icon(
                          Icons.gps_fixed,
                          color:
                              _addressController.text.isEmpty
                                  ? AppColors.BLACK_54
                                  : Colors.blue,
                        ),
                        onPressed: () {
                          _getCurrentLocation();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Shop/Service Name
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "*Shop/Service Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Phone
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "*Phone",
                      border: OutlineInputBorder(),
                      prefixText: "+91 ",
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Category Dropdown
                  FutureBuilder<List<models.Category>>(
                    future: _categoriesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return Text("Error: ${snapshot.error}");
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Text("No categories found");
                      }

                      final categories = snapshot.data!;

                      return DropdownButtonFormField<String>(
                        isExpanded: true,
                        value: _selectedCategory,
                        alignment: Alignment.center,
                        items:
                            categories
                                .map(
                                  (cat) => DropdownMenuItem(
                                    value:
                                        cat.name, // store category name as value
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 30,
                                          height: 30,
                                          child: CachedNetworkSvg(
                                            url: cat.imageUrl,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            cat.name,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),

                                    // Text(cat.name),
                                  ),
                                )
                                .toList(),
                        decoration: const InputDecoration(
                          labelText: "*Category",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _selectedCategory = value;
                          });
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Description",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Submit Button
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.THEME_COLOR,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isLoading ? null : _submitContribution,
                    child: const Text(
                      "Submit Listing",
                      style: TextStyle(color: AppColors.WHITE, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // 🔹 Loading overlay
          if (_isLoading)
            Container(
              color: AppColors.BLACK_54,
              child: const Center(
                child: CircularProgressIndicator(color: AppColors.THEME_COLOR),
              ),
            ),
        ],
      ),
    );
  }
}
