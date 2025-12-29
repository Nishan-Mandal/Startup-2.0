import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/presentation/common_methods/cached_network_svg.dart';
import 'package:startup_20/presentation/common_methods/common_methods.dart';
import 'package:startup_20/presentation/common_methods/location_picker.dart';
import 'package:startup_20/presentation/screens/listing_detail_screen.dart';
import 'package:uuid/uuid.dart';
import 'package:geolocator/geolocator.dart';
import 'package:startup_20/data/models/category_model.dart' as models;
import 'package:geocoding/geocoding.dart';

class AddListingScreen extends StatefulWidget {
  final Listing? existingListing;
  const AddListingScreen({this.existingListing, Key? key}) : super(key: key);
  @override
  _AddListingScreenState createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  bool get isEditing => widget.existingListing != null;

  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _sinceController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _websiteController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _instagramController = TextEditingController();
  final TextEditingController _facebookController = TextEditingController();
  final TextEditingController _linkedInController = TextEditingController();

  bool acceptOnlinePayment = true;

  late double _latitude;
  late double _longitude;
  late Future<List<models.Category>> _categoriesFuture;
  String? _selectedCategoryId;
  String? _selectedCategoryName;

  final List<File> _images = [];
  List<ImageFile> _remoteImages = [];

  bool _addOpenHours = false;
  Map<String, OpenHours> _openHours = {
    "Monday": OpenHours(open: "10:00 AM", close: "10:00 PM", closed: false),
    "Tuesday": OpenHours(open: "10:00 AM", close: "10:00 PM", closed: false),
    "Wednesday": OpenHours(open: "10:00 AM", close: "10:00 PM", closed: false),
    "Thursday": OpenHours(open: "10:00 AM", close: "10:00 PM", closed: false),
    "Friday": OpenHours(open: "10:00 AM", close: "10:00 PM", closed: false),
    "Saturday": OpenHours(open: "10:00 AM", close: "10:00 PM", closed: false),
    "Sunday": OpenHours(open: "10:00 AM", close: "10:00 PM", closed: false),
  };

  // Sub Category Multi-select
  List<String> subCategories = ["Office", "Bachelors", "MES", "Family"];
  List<String> selectedSubCategories = [];

  List<String> appartmentTypes = ["1 RK", "1 BHK", "2 BHK", "3 BHK"];
  String? selectedAppartmentType;

  // Property Type Inputs
  int roomNumber = 0;
  int bathroomNumber = 0;
  int balcony = 0;
  int floorNumber = 0;
  bool twoWheelerparking = false;
  bool fourWheelerparking = false;

  // Rent Price Inputs
  int monthlyRent = 0;
  bool cautionMoney = false;
  int electricCharge = 0;
  bool waterCharge = false;
  bool otherCharge = false;
  bool cctv = false;
  bool diningRoom = false;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = fetchCategories();
    _prePopulateData();
  }

  void _prePopulateData() {
    if (isEditing) {
      final listing = widget.existingListing!;

      _nameController.text = listing.name;
      _addressController.text = listing.address;
      _descriptionController.text = listing.description;
      _phoneController.text = listing.phone;
      _ownerNameController.text = listing.ownerName;
      _latitude = listing.geo.lat;
      _longitude = listing.geo.lng;
      _selectedCategoryId = listing.categoryId;
      _selectedCategoryName = listing.category;

      _sinceController.text = listing.since.toString();
      _emailController.text = listing.details['Email'] ?? '';
      _websiteController.text = listing.social['Website'] ?? '';
      _whatsappController.text = listing.social['WhatsApp'] ?? '';
      _instagramController.text = listing.social['Instagram'] ?? '';
      _facebookController.text = listing.social['Facebook'] ?? '';
      _linkedInController.text = listing.social['LinkedIn'] ?? '';
      acceptOnlinePayment =
          listing.details['Accept Online Payments'] != null
              ? listing.details['Accept Online Payments'] == 'Yes'
                  ? true
                  : false
              : false;

      if (listing.openHours.isNotEmpty) {
        _openHours = listing.openHours;
        _addOpenHours = true;
      }

      //Room Rent
      final availableFor = listing.details['Available For'];

      if (availableFor is String) {
        selectedSubCategories =
            availableFor
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
      } else if (availableFor is List) {
        selectedSubCategories =
            availableFor
                .map((e) => e.toString().trim())
                .where((s) => s.isNotEmpty)
                .toList();
      } else {
        selectedSubCategories = [];
      }

      selectedAppartmentType = listing.details['Appartment Type'];

      roomNumber = listing.details['Room (s)'] ?? 0;
      bathroomNumber = listing.details['Bathroom (s)'] ?? 0;
      balcony = listing.details['Balcony (s)'] ?? 0;
      floorNumber = listing.details['Floor Number'] ?? 0;
      twoWheelerparking =
          listing.details['Two Wheeler Parking'] != null
              ? listing.details['Two Wheeler Parking'] == 'Yes'
                  ? true
                  : false
              : false;
      fourWheelerparking =
          listing.details['Four Wheeler Parking'] != null
              ? listing.details['Four Wheeler Parking'] == 'Yes'
                  ? true
                  : false
              : false;
      monthlyRent = listing.details['Monthly Rent'] ?? 0;
      cautionMoney =
          listing.details['Caution Money'] != null
              ? listing.details['Caution Money'] == 'Yes'
                  ? true
                  : false
              : false;
      electricCharge = listing.details['Electric Charge'] ?? 0;
      waterCharge =
          listing.details['Water Charge'] != null
              ? listing.details['Water Charge'] == 'Yes'
                  ? true
                  : false
              : false;
      otherCharge =
          listing.details['Other Charges'] != null
              ? listing.details['Other Charges'] == 'Yes'
                  ? true
                  : false
              : false;
      cctv =
          listing.details['CCTV'] != null
              ? listing.details['CCTV'] == 'Yes'
                  ? true
                  : false
              : false;

      diningRoom =
          listing.details['Dining Room'] != null
              ? listing.details['Dining Room'] == 'Yes'
                  ? true
                  : false
              : false;

      // ⭐ Load already uploaded images (thumbnails) for preview
      _remoteImages = List<ImageFile>.from(listing.images);
    }
    if (mounted) {
      setState(() {});
    }
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

  bool _didDataChange() {
    final listing = widget.existingListing;

    // If NEW listing → enable if user entered anything
    if (listing == null) {
      return _nameController.text.isNotEmpty ||
          _addressController.text.isNotEmpty ||
          _descriptionController.text.isNotEmpty ||
          _ownerNameController.text.isNotEmpty ||
          _phoneController.text.isNotEmpty ||
          _selectedCategoryId != null ||
          _images.isNotEmpty;
    }
    return true;
  }

  void _previewListing() {
    if (!_didDataChange()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please update the data to preview!")),
      );
      return;
    }

    if (widget.existingListing == null &&
        (_nameController.text.isEmpty ||
            _addressController.text.isEmpty ||
            _ownerNameController.text.isEmpty ||
            _phoneController.text.isEmpty ||
            _selectedCategoryId == null ||
            _images.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required details!")),
      );
      return;
    }

    Map<String, dynamic> details = {};
    Map<String, String> social = {};

    if (_selectedCategoryName == 'Room Rent') {
      details = {
        'Appartment Type': selectedAppartmentType,
        'Monthly Rent': monthlyRent,
        'Available For': selectedSubCategories.join(", "),
        'Room (s)': roomNumber,
        'Bathroom (s)': bathroomNumber,
        'Balcony (s)': balcony,
        'Dining Room': diningRoom ? 'Yes' : 'No',
        'Floor Number': floorNumber,
        'Two Wheeler Parking': twoWheelerparking ? 'Yes' : 'No',
        'Four Wheeler Parking': fourWheelerparking ? 'Yes' : 'No',
        'Caution Money': cautionMoney ? 'Yes' : 'No',
        'Electric Charge': electricCharge,
        'Water Charge': waterCharge ? 'Yes' : 'No',
        'Other Charges': otherCharge ? 'Yes' : 'No',
        'CCTV': cctv ? 'Yes' : 'No',
      };
    }

    addIfValid(details, 'Email', _emailController.text.trim());

    if (!acceptOnlinePayment) {
      addIfValid(details, 'Accept Online Payments', 'No');
    }

    //Social Media
    addIfValid(social, 'Website', _websiteController.text.trim());
    addIfValid(social, 'WhatsApp', _whatsappController.text.trim());
    addIfValid(social, 'Instagram', _instagramController.text.trim());
    addIfValid(social, 'Facebook', _facebookController.text.trim());
    addIfValid(social, 'LinkedIn', _linkedInController.text.trim());

    final draftListing = Listing(
      listingId: widget.existingListing?.listingId ?? "draft",
      contributionId: widget.existingListing?.contributionId ?? "draft",
      name: _nameController.text.trim(),
      address: _addressController.text.trim(),
      description: _descriptionController.text.trim(),
      details: details,
      geo: Geo(lat: _latitude, lng: _longitude),
      phone: _phoneController.text.trim(),
      category: _selectedCategoryName!,
      categoryId: _selectedCategoryId!,
      tags: [_selectedCategoryName!],
      addedBy: FirebaseAuth.instance.currentUser?.uid ?? "anonymous",
      ownerId: FirebaseAuth.instance.currentUser?.uid ?? "anonymous",
      ownerName: _ownerNameController.text.trim(),
      isClaimed: widget.existingListing?.isClaimed ?? false,
      claimStatus: widget.existingListing?.claimStatus ?? "draft",
      verifiedBy: widget.existingListing?.verifiedBy,
      createdAt: widget.existingListing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),

      // ⭐ REMOTE IMAGES (only if editing)
      images: _remoteImages,

      // ⭐ LOCAL IMAGES
      localImages: _images, // files selected now

      reviews: widget.existingListing?.reviews ?? 0,
      ratingCount: widget.existingListing?.ratingCount ?? 0,
      rating: widget.existingListing?.rating ?? 0,

      since: widget.existingListing?.since ?? 2025,
      likes: widget.existingListing?.likes ?? 0,
      views: widget.existingListing?.views ?? 0,
      social: widget.existingListing?.social ?? social,
      ratingStats: widget.existingListing?.ratingStats ?? {},
      factorAvgRatings: widget.existingListing?.factorAvgRatings ?? {},
      openHours: _addOpenHours? _openHours:{},
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ListingDetailScreen(
              listing: draftListing,
              similarListings: [],
              isPreview: true,
              isEditing: isEditing,
            ),
      ),
    );
  }

  void addIfValid(Map<String, dynamic> map, String key, dynamic value) {
    if (value == null) return;
    if (value is String && value.trim().isEmpty) return;
    if (value is num && value == 0) return;
    map[key] = value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.WHITE,
      appBar: AppBar(
        iconTheme: IconThemeData(color: AppColors.WHITE),
        centerTitle: true,
        title: Text(
          widget.existingListing == null ? "Add New Listing" : "Update Listing",
          style: TextStyle(color: AppColors.WHITE, fontWeight: FontWeight.bold),
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

                  // ⭐ NEW — show remote images if editing
                  if (isEditing && _remoteImages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: SizedBox(
                        height: 120,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _remoteImages.length,
                          itemBuilder: (context, index) {
                            return Stack(
                              children: [
                                Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      _remoteImages[index].thumbUrl,
                                      width: 120,
                                      height: 120,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        debugPrint(
                                          widget.existingListing?.images.length
                                              .toString(),
                                        );
                                        _remoteImages.removeAt(index);
                                        debugPrint(
                                          widget.existingListing?.images.length
                                              .toString(),
                                        );
                                        debugPrint(
                                          _remoteImages.length.toString(),
                                        );
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
                    ),

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
                        onPressed: () async {
                          // _getCurrentLocation();
                          final selectedLatLng = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LocationPicker(),
                            ),
                          );

                          if (selectedLatLng != null) {
                            debugPrint(
                              "📍 Selected Location: ${selectedLatLng.latitude}, ${selectedLatLng.longitude}",
                            );
                            _addressController.text =
                                await CommonMethods.getAddressFromLatLng(
                                  selectedLatLng,
                                );

                            // Example: Update your text field with selected address or coordinates
                            setState(() {
                              _latitude = selectedLatLng.latitude;
                              _longitude = selectedLatLng.longitude;
                            });
                          }
                        },
                      ),
                    ],
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

                      return SearchableDropdown(
                        categories: categories,
                        onCategorySelected: (String id, String name) {
                          setState(() {
                            _selectedCategoryId = id;
                            _selectedCategoryName = name;
                          });
                        },
                      );
                    },
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

                  //Owner's Name
                  TextFormField(
                    controller: _ownerNameController,
                    decoration: const InputDecoration(
                      labelText: "*Owner's Name",
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

                  // Whatsapp
                  TextFormField(
                    controller: _whatsappController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: "WhatsApp",
                      border: OutlineInputBorder(),
                      prefixText: "+91 ",
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _sinceController,
                    keyboardType: TextInputType.number,
                    maxLength: 4, // Accept only 4 digits
                    decoration: const InputDecoration(
                      labelText: "Since",
                      border: OutlineInputBorder(),
                      counterText: "", // hides the 0/4 counter
                    ),

                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly, // digits only
                      LengthLimitingTextInputFormatter(4), // max 4 digits
                    ],

                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "Please enter a year";
                      }
                      if (value.length != 4) {
                        return "Year must be 4 digits";
                      }

                      final year = int.tryParse(value);
                      final currentYear = DateTime.now().year;

                      if (year == null || year < 1900 || year > currentYear) {
                        return "Enter a valid year (1900–$currentYear)";
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // TextFormField(
                  //   controller: _availabilityController,
                  //   maxLines: 7,
                  //   decoration: const InputDecoration(
                  //     labelText: "Availability",
                  //     border: OutlineInputBorder(),
                  //   ),
                  // ),
                  CheckboxListTile(
                    value: _addOpenHours,
                    title: const Text("Add Open Hours"),
                    onChanged: (value) {
                      setState(() {
                        _addOpenHours = value ?? false;
                      });
                    },
                  ),

                  if (_addOpenHours) ...[
                    const SizedBox(height: 12),
                    _buildOpenHoursTable(),
                  ],

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: "Email",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _websiteController,
                    decoration: const InputDecoration(
                      labelText: "Website",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _instagramController,
                    decoration: const InputDecoration(
                      labelText: "Instagram",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _facebookController,
                    decoration: const InputDecoration(
                      labelText: "Facebook",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _linkedInController,
                    decoration: const InputDecoration(
                      labelText: "LinkedIn",
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  TextFormField(
                    controller: _descriptionController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: "Description (Optional)",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  SizedBox(height: 16),
                  switchTile(
                    "Accept Online Payments",
                    acceptOnlinePayment,
                    (v) => setState(() => acceptOnlinePayment = v),
                  ),
                  const SizedBox(height: 16),

                  if (_selectedCategoryName == 'Room Rent') _roomRentInfo(),

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
                      _previewListing();
                    },
                    child: Text(
                      // isEditing ? "Update Listing" : "Submit Listing",
                      "Pewiew",
                      style: const TextStyle(
                        color: AppColors.WHITE,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roomRentInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 25),

        // Sub Category (Multi-select)
        label("Available For"),

        Wrap(
          spacing: 10,
          children:
              subCategories.map((cat) {
                final isSelected = selectedSubCategories.contains(cat);
                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: Colors.blue.shade200,
                  onSelected: (val) {
                    setState(() {
                      if (isSelected) {
                        selectedSubCategories.remove(cat);
                      } else {
                        selectedSubCategories.add(cat);
                      }
                    });
                  },
                );
              }).toList(),
        ),
        const SizedBox(height: 25),
        label("Appartment Type"),

        Wrap(
          spacing: 10,
          children:
              appartmentTypes.map((cat) {
                final isSelected = selectedAppartmentType == cat;

                return ChoiceChip(
                  label: Text(cat),
                  selected: isSelected,
                  selectedColor: Colors.blue.shade200,
                  onSelected: (selected) {
                    setState(() {
                      selectedAppartmentType = selected ? cat : null;
                    });
                  },
                );
              }).toList(),
        ),

        const SizedBox(height: 25),

        CounterInput(
          label: "Room (s)",
          value: roomNumber,
          onChanged: (val) => setState(() => roomNumber = val),
        ),

        CounterInput(
          label: "Bathroom (s)",
          value: bathroomNumber,
          onChanged: (val) => setState(() => bathroomNumber = val),
        ),

        CounterInput(
          label: "Balcony (s)",
          value: balcony,
          onChanged: (val) => setState(() => balcony = val),
        ),

        CounterInput(
          label: "Floor Number",
          value: floorNumber,
          onChanged: (val) => setState(() => floorNumber = val),
        ),

        CounterInput(
          label: "Monthly Rent",
          value: monthlyRent,
          onChanged: (val) => setState(() => monthlyRent = val),
        ),

        CounterInput(
          label: "Electric Charge",
          value: electricCharge,
          onChanged: (val) => setState(() => electricCharge = val),
        ),

        switchTile(
          "Dining Room",
          diningRoom,
          (v) => setState(() => diningRoom = v),
        ),

        switchTile(
          "2 Wheeler Parking",
          twoWheelerparking,
          (v) => setState(() => twoWheelerparking = v),
        ),

        switchTile(
          "4 Wheeler Parking",
          fourWheelerparking,
          (v) => setState(() => fourWheelerparking = v),
        ),

        switchTile(
          "Other Charges",
          otherCharge,
          (v) => setState(() => otherCharge = v),
        ),

        switchTile("CCTV", cctv, (v) => setState(() => cctv = v)),
      ],
    );
  }

  Widget label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
    );
  }

  Widget switchTile(String label, bool value, Function(bool) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  Widget _buildOpenHoursTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Open Hours",
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        Table(
          border: TableBorder.all(color: Colors.grey.shade300),
          columnWidths: const {
            0: FlexColumnWidth(2),
            1: FlexColumnWidth(2),
            2: FlexColumnWidth(2),
            3: FlexColumnWidth(1.5),
          },
          children: [
            /// Header
            const TableRow(
              decoration: BoxDecoration(color: Color(0xFFF5F5F5)),
              children: [
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    "Day",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    "Open",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    "Close",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    "Closed",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            /// Rows
            ..._openHours.entries.map((entry) {
              final day = entry.key;
              final hours = entry.value;

              return TableRow(
                children: [
                  Padding(padding: const EdgeInsets.all(8), child: Text(day)),

                  /// Open Time
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: TextFormField(
                      initialValue: hours.open,
                      enabled: !hours.closed,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        _openHours[day] = OpenHours(
                          open: value,
                          close: hours.close,
                          closed: hours.closed,
                        );
                      },
                    ),
                  ),

                  /// Close Time
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: TextFormField(
                      initialValue: hours.close,
                      enabled: !hours.closed,
                      decoration: const InputDecoration(
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        _openHours[day] = OpenHours(
                          open: hours.open,
                          close: value,
                          closed: hours.closed,
                        );
                      },
                    ),
                  ),

                  /// Closed Checkbox
                  Padding(
                    padding: const EdgeInsets.all(6),
                    child: Checkbox(
                      value: hours.closed,
                      onChanged: (val) {
                        setState(() {
                          _openHours[day] = OpenHours(
                            open: hours.open,
                            close: hours.close,
                            closed: val ?? false,
                          );
                        });
                      },
                    ),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ],
    );
  }
}

class SearchableDropdown extends StatefulWidget {
  final List<models.Category> categories;
  final Function(String, String) onCategorySelected;

  const SearchableDropdown({
    super.key,
    required this.categories,
    required this.onCategorySelected,
  });

  @override
  State<SearchableDropdown> createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<SearchableDropdown> {
  String? _selectedCategoryName;
  String? _selectedCategoryId;
  final TextEditingController _searchController = TextEditingController();

  void _openSearchDialog() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        List<models.Category> filtered = widget.categories;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Select Category"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: "Search category...",
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (query) {
                        setStateDialog(() {
                          filtered =
                              widget.categories
                                  .where(
                                    (cat) => cat.name.toLowerCase().contains(
                                      query.toLowerCase(),
                                    ),
                                  )
                                  .toList();
                        });
                      },
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4,
                      width: double.maxFinite,
                      child: ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          models.Category cat = filtered[index];
                          return ListTile(
                            leading: SizedBox(
                              width: 30,
                              height: 30,
                              child: SvgPicture.network(
                                cat.imageUrl,
                                height: 10,
                                width: 10,
                              ),
                            ),
                            title: Text(cat.name),
                            onTap: () {
                              Navigator.pop(context, {
                                'id': cat.id ?? '',
                                'name': cat.name,
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
              ],
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedCategoryId = result['id'];
        _selectedCategoryName = result['name'];
      });
      widget.onCategorySelected(
        _selectedCategoryId ?? '',
        _selectedCategoryName ?? '',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openSearchDialog,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: "*Category",
          border: OutlineInputBorder(),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _selectedCategoryName ?? "Select Category",
                style: TextStyle(
                  color:
                      _selectedCategoryName == null
                          ? Colors.grey
                          : Colors.black,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}

class CounterInput extends StatefulWidget {
  final String label;
  final int value;
  final Function(int) onChanged;

  const CounterInput({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  State<CounterInput> createState() => _CounterInputState();
}

class _CounterInputState extends State<CounterInput> {
  late TextEditingController controller;

  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(CounterInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Update text only when external value changes
    if (oldWidget.value != widget.value &&
        controller.text != widget.value.toString()) {
      controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),

          _roundButton(
            icon: Icons.remove,
            onTap: () {
              if (widget.value > 0) widget.onChanged(widget.value - 1);
            },
          ),

          const SizedBox(width: 10),

          SizedBox(
            width: 70,
            child: TextField(
              controller: controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: BoxDecorationStyles.box(),
              onChanged: (val) {
                final parsed = int.tryParse(val);
                if (parsed != null) widget.onChanged(parsed);
              },
            ),
          ),

          const SizedBox(width: 10),

          _roundButton(
            icon: Icons.add,
            onTap: () => widget.onChanged(widget.value + 1),
          ),
        ],
      ),
    );
  }

  Widget _roundButton({required IconData icon, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.BLACK_12,
        ),
        child: Icon(icon, size: 20, color: AppColors.BLACK),
      ),
    );
  }
}

class BoxDecorationStyles {
  static InputDecoration box() {
    return InputDecoration(
      contentPadding: const EdgeInsets.symmetric(vertical: 8),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.GREY),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: AppColors.THEME_COLOR),
      ),
    );
  }
}
