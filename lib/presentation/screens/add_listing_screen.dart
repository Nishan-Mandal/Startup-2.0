import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';

class AddListingScreen extends StatefulWidget {
  @override
  _AddListingScreenState createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _selectedCategory;

  final List<String> _categories = ["Restaurant", "Shop", "Service", "Other"];

  final List<File> _images = [];
  bool _isLoading = false;

  /// Pick multiple images
  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedFiles = await picker.pickMultiImage();
    if (pickedFiles != null && pickedFiles.isNotEmpty) {
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
  Future<Map<String, dynamic>> _uploadImage(
    File file,
    String listingId,
  ) async {
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
    final fullRef = storageRef.child(
      "listings/$listingId/full_$fileId.jpg",
    );
    await fullRef.putData(
      fullData!,
      SettableMetadata(contentType: "image/jpeg"),
    );
    final fullUrl = await fullRef.getDownloadURL();

    // Upload thumbnail
    final thumbRef = storageRef.child(
      "listings/$listingId/thumb_$fileId.jpg",
    );
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

  Future<void> _getCurrentLocation() async {
    try {
      // Check permission
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

      setState(() {
        _latitudeController.text = position.latitude.toStringAsFixed(6);
        _longitudeController.text = position.longitude.toStringAsFixed(6);
      });

      debugPrint(
        "📍 Current Location: ${position.latitude}, ${position.longitude}",
      );
    } catch (e) {
      debugPrint("Error getting location: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error getting location: $e")));
    }
  }

  /// Submit contribution
  Future<void> _submitContribution() async {
    // if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final contributionId = Uuid().v4();
      final listingId = Uuid().v4();
      final images = await _uploadImages(contributionId);

      await FirebaseFirestore.instance
          .collection("listings")
          .doc(contributionId)
          .set({
            "listingId": listingId, 
            "contributionId": contributionId,      
            "name":  _nameController.text.trim(),
            "description": "string",
            "images": images, // ✅ full + thumb urls stored
            "address": "string",
            "geo": {
              "lat":  _latitudeController.text.trim(),
              "lng":  _longitudeController.text.trim()
            },
            "phone": _phoneController.text.trim(),
            "category": _selectedCategory,      
            "tags": [_selectedCategory],
            "addedBy": "admin",       
            "isClaimed": false,    
            "ownerId": "string|null", 
            "claimStatus": "pending",  
            "verifiedBy": "string|null",
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
          });


      await FirebaseFirestore.instance
          .collection("contributions")
          .doc(contributionId)
          .set({
            "contributionId": contributionId,
            "userId": "mockUser123", // replace with FirebaseAuth.currentUser!.uid
            "listingId": listingId, 
            "type": "add",
            "status": "pending",
            "reviewedBy": null,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp(),
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Contribution submitted for review ✅")),
      );

      Navigator.pop(context);
    } catch (e) {
      // Print both for debugging
      debugPrint("Error: $e");

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    }

    setState(() => _isLoading = false);
  }

  /// Convert EXIF rationals to degrees
  double _convertToDegree(List values) {
    var d = values[0].toDouble();
    var m = values[1].toDouble();
    var s = values[2].toDouble();
    return d + (m / 60.0) + (s / 3600.0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Upload Listing")),
      body: Padding(
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
                            margin: const EdgeInsets.symmetric(horizontal: 8),
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
                      controller: _latitudeController,
                      decoration: const InputDecoration(
                        labelText: "Latitude",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _longitudeController,
                      decoration: const InputDecoration(
                        labelText: "Longitude",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.gps_fixed, color: Colors.black87),
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
                  labelText: "Shop/Service Name",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Phone
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: "Phone",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),

              // Category Dropdown
              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items:
                    _categories
                        .map(
                          (cat) =>
                              DropdownMenuItem(value: cat, child: Text(cat)),
                        )
                        .toList(),
                decoration: const InputDecoration(
                  labelText: "Category",
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) {
                  setState(() {
                    _selectedCategory = value;
                  });
                },
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
                onPressed: () {
                  _submitContribution();
                },
                child: const Text(
                  "Submit Listing",
                  style: TextStyle(color: AppColors.BLACK, fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
