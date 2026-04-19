import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/core/constants/category_field_schema.dart';
import 'package:startup_20/data/models/category_field_model.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/presentation/common_methods/location_picker.dart';
import 'package:startup_20/presentation/screens/listing_detail_screen.dart';
import 'package:startup_20/data/models/category_model.dart' as models;

class AddListingScreen extends StatefulWidget {
  final Listing? existingListing;
  const AddListingScreen({this.existingListing, super.key});
  @override
  _AddListingScreenState createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  int _currentStep = 0;
  final PageController _pageController = PageController();

  bool get isEditing => widget.existingListing != null;

  final TextEditingController _addressController = TextEditingController();
  final _basicFormCtrl = DynamicFormController();
  final _contactFormCtrl = DynamicFormController();
  final _detailedFormCtrl = DynamicFormController();
  final _socialFormCtrl = DynamicFormController();
  final _categoryFormCtrl = DynamicFormController();

  List<CategoryField>? _basicFields;
  List<CategoryField>? _contactFields;
  List<CategoryField>? _detailedFields;
  List<CategoryField>? _socialFields;
  List<CategoryField>? _categoryFields;
  List<Map<String, TextEditingController>> _manualFields = [];

  double _latitude = 0;
  double _longitude = 0;
  late Future<List<models.Category>> _categoriesFuture;
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  bool _draftLoaded = false;

  final List<File> _images = [];
  List<ImageFile> _remoteImages = [];

  bool _addOpenHours = false;

  static const List<String> weekDays = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
  ];
  Map<String, DaySchedule> _businessHours = {
    for (var day in weekDays)
      day: DaySchedule(
        isClosed: false,
        slots: [
          TimeSlot(
            open: const TimeOfDay(hour: 9, minute: 0),
            close: const TimeOfDay(hour: 17, minute: 0),
          ),
        ],
      ),
  };

  Set<String> _selectedTags = {};
  final TextEditingController _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _categoriesFuture = fetchCategories();

    if (!isEditing) {
      _checkDraftOnStart();
    } else {
      _draftLoaded = true;
    }

    _basicFields =
        (CategoryFieldSchema.basicFields['formSchema'] as List)
            .map((e) => CategoryField.fromJson(e))
            .toList();

    _contactFields =
        (CategoryFieldSchema.contactFields['formSchema'] as List)
            .map((e) => CategoryField.fromJson(e))
            .toList();

    _detailedFields =
        (CategoryFieldSchema.detailedFields['formSchema'] as List)
            .map((e) => CategoryField.fromJson(e))
            .toList();

    _socialFields =
        (CategoryFieldSchema.socialFields['formSchema'] as List)
            .map((e) => CategoryField.fromJson(e))
            .toList();

    if (widget.existingListing != null) {
      final listing = widget.existingListing!;

      _selectedCategoryId = listing.categoryId;
      _selectedCategoryName = listing.category;

      _selectedTags = Set<String>.from(widget.existingListing!.tags);

      _onCategorySelected(listing.category);
      _prePopulateDynamicForms(listing);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_draftLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

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
      body: Column(
        children: [
          _buildProgressIndicator(),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 8,
              itemBuilder: (context, index) {
                switch (index) {
                  case 0:
                    return _stepBasicInfo();
                  case 1:
                    return _stepContactDetails();
                  case 2:
                    return _stepSocialMediaDetails();
                  case 3:
                    return _stepDetailedDetails();
                  case 4:
                    return _stepCategoryDetails();
                  case 5:
                    return _stepOpenHourDetails();
                  case 6:
                    return _stepImages();
                  case 7:
                    return _stepTagging();

                  default:
                    return const SizedBox();
                }
              },
            ),
          ),
          _buildNavigationButtons(),
        ],
      ),
    );
  }

  void _addManualField() {
    setState(() {
      _manualFields.add({
        'key': TextEditingController(),
        'value': TextEditingController(),
      });
    });
  }

  Future<void> _saveDraft() async {
    if (isEditing) return;
    final prefs = await SharedPreferences.getInstance();

    Map<String, dynamic> draft = {
      "address": _addressController.text,
      "lat": _latitude,
      "lng": _longitude,
      "categoryId": _selectedCategoryId,
      "categoryName": _selectedCategoryName,

      "basic": _basicFormCtrl.values,
      "contact": _contactFormCtrl.values,
      "detailed": _detailedFormCtrl.values,
      "social": _socialFormCtrl.values,
      "categoryDetails": _categoryFormCtrl.values,

      "tags": _selectedTags.toList(),

      "addOpenHours": _addOpenHours,
      "businessHours": _businessHoursToJson(),

      "manualFields":
          _manualFields
              .map((f) => {"key": f['key']!.text, "value": f['value']!.text})
              .toList(),
    };

    await prefs.setString("listingDraft", jsonEncode(draft));
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();

    final draftString = prefs.getString("listingDraft");

    if (draftString == null) return;

    final draft = jsonDecode(draftString);

    setState(() {
      _addressController.text = draft["address"] ?? "";
      _latitude = draft["lat"] ?? 0;
      _longitude = draft["lng"] ?? 0;

      _selectedCategoryId = draft["categoryId"];
      _selectedCategoryName = draft["categoryName"];

      _basicFormCtrl.values = Map<String, dynamic>.from(draft["basic"] ?? {});

      _contactFormCtrl.values = Map<String, dynamic>.from(
        draft["contact"] ?? {},
      );
      _detailedFormCtrl.values = Map<String, dynamic>.from(
        draft["detailed"] ?? {},
      );
      _socialFormCtrl.values = Map<String, dynamic>.from(draft["social"] ?? {});
      _categoryFormCtrl.values = Map<String, dynamic>.from(
        draft["categoryDetails"] ?? {},
      );

      _selectedTags = Set<String>.from(draft["tags"] ?? []);

      _addOpenHours = draft["addOpenHours"] ?? false;

      if (draft["businessHours"] != null) {
        _businessHoursFromJson(
          Map<String, dynamic>.from(draft["businessHours"]),
        );
      }

      _manualFields.clear();

      for (var field in draft["manualFields"] ?? []) {
        _manualFields.add({
          "key": TextEditingController(text: field["key"]),
          "value": TextEditingController(text: field["value"]),
        });
      }
    });
    setState(() {
      _draftLoaded = true;
    });
  }

  Future<void> _clearDraft() async {
    if (isEditing) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove("listingDraft");
  }

  Future<void> _nextStep() async {
    await _saveDraft();
    if (_currentStep < 7) {
      setState(() {
        _currentStep++;
      });

      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _previewListing();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });

      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showResumeDraftDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          title: const Text("Resume Draft"),
          content: const Text(
            "You have an unfinished listing draft.\n\nWould you like to continue editing it?",
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await _clearDraft();
                Navigator.pop(context);

                setState(() {
                  _draftLoaded = true;
                });
              },
              child: const Text("Discard", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.THEME_COLOR,
              ),
              onPressed: () async {
                Navigator.pop(context);
                await _loadDraft();
              },
              child: const Text(
                "Continue",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _addAutoTags() {
    final category = _selectedCategoryName ?? '';
    final shopName = _basicFormCtrl.values['Shop/Service Name'] ?? '';
    final owner = _basicFormCtrl.values['Owners Name'] ?? '';

    _selectedTags.add(category);
    _selectedTags.add("$category near me");
    _selectedTags.add("$category nearby");

    if (shopName.isNotEmpty) {
      _selectedTags.add(shopName);
    }

    if (owner.isNotEmpty) {
      _selectedTags.add(owner);
    }
  }

  void _onCategorySelected(String name) {
    late Map<String, dynamic>? categorySchema;
    _categoryFields = null;
    switch (name) {
      case 'Room Rent':
        categorySchema = CategoryFieldSchema.roomRentFields;
        break;

      case 'Makeup Artists/Beauty Services':
        categorySchema = CategoryFieldSchema.makupArtistFields;
        break;

      case 'Salons (Men/Women)':
        categorySchema = CategoryFieldSchema.salonsMenWomen;
        break;

      case 'Spa & Massage':
        categorySchema = CategoryFieldSchema.spaAndMassage;
        break;

      default:
        return;
    }

    setState(() {
      if (categorySchema != null) {
        _categoryFields =
            (categorySchema['formSchema'] as List)
                .map((e) => CategoryField.fromJson(e))
                .toList();
      }
    });
  }

  void _prePopulateDynamicForms(Listing listing) {
    _basicFormCtrl.values = {
      "Shop/Service Name": listing.name,
      "Owners Name": listing.ownerName,
    };
    _contactFormCtrl.values = {
      "Phone": listing.phone,
      "Alternate Phone (Optional)": listing.alternatePhone,
      "Email": listing.email,
    };
    _detailedFormCtrl.values = {
      "Description": listing.description,
      "Since": listing.since,
      "Accept Online Payments":
          listing.details["Accept Online Payments"] ?? true,
    };
    _addressController.text = listing.address;
    _latitude = listing.geo.lat;
    _longitude = listing.geo.lng;
    _selectedCategoryId = listing.categoryId;
    _selectedCategoryName = listing.category;
    if (listing.businessHours.isNotEmpty) {
      _businessHours = listing.businessHours;
      _addOpenHours = true;
    }

    _remoteImages = List<ImageFile>.from(listing.images);

    _socialFormCtrl.values = Map<String, dynamic>.from(listing.social);

    _categoryFormCtrl.values = Map<String, dynamic>.from(listing.details);

    _manualFields.clear();

    listing.details.forEach((key, value) {
      if (_categoryFields != null) {
        final schemaLabels =
            _categoryFields!.map((field) => field.label).toSet();
        if (!schemaLabels.contains(key)) {
          _manualFields.add({
            'key': TextEditingController(text: key),
            'value': TextEditingController(text: value.toString()),
          });
        }
      } else {
        _manualFields.add({
          'key': TextEditingController(text: key),
          'value': TextEditingController(text: value.toString()),
        });
      }
    });
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
    try {
      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage();

      if (pickedFiles.isEmpty) return;

      setState(() {
        _images.addAll(pickedFiles.map((file) => File(file.path)));
      });
    } catch (e) {
      debugPrint("Image pick error: $e");

      _showError("Failed to pick images");
    }
  }

  Map<String, int> _timeToJson(TimeOfDay time) {
    return {"hour": time.hour, "minute": time.minute};
  }

  TimeOfDay _timeFromJson(Map<String, dynamic> json) {
    return TimeOfDay(hour: json["hour"], minute: json["minute"]);
  }

  Map<String, dynamic> _businessHoursToJson() {
    Map<String, dynamic> data = {};

    _businessHours.forEach((day, schedule) {
      data[day] = {
        "isClosed": schedule.isClosed,
        "slots":
            schedule.slots.map((slot) {
              return {
                "open": _timeToJson(slot.open),
                "close": _timeToJson(slot.close),
              };
            }).toList(),
      };
    });

    return data;
  }

  void _businessHoursFromJson(Map<String, dynamic> json) {
    _businessHours.clear();

    json.forEach((day, scheduleData) {
      final slots =
          (scheduleData["slots"] as List)
              .map(
                (slot) => TimeSlot(
                  open: _timeFromJson(slot["open"]),
                  close: _timeFromJson(slot["close"]),
                ),
              )
              .toList();

      _businessHours[day] = DaySchedule(
        isClosed: scheduleData["isClosed"] ?? false,
        slots: slots,
      );
    });
  }

  void _previewListing() {
    final Map<String, dynamic> details = {..._categoryFormCtrl.values};
    details["Accept Online Payments"] =
        _detailedFormCtrl.values["Accept Online Payments"] ?? false;
    for (var field in _manualFields) {
      final key = field['key']!.text.trim();
      final value = field['value']!.text.trim();

      if (key.isNotEmpty) {
        details[key] = value;
      }
    }

    final Map<String, String> social = _socialFormCtrl.values.map(
      (k, v) => MapEntry(k, v.toString()),
    );

    final listing = Listing(
      listingId: widget.existingListing?.listingId ?? 'draft',
      contributionId: widget.existingListing?.contributionId ?? 'draft',

      name: _basicFormCtrl.values['Shop/Service Name'] ?? '',
      address: _addressController.text.trim(),
      description: _detailedFormCtrl.values['Description'] ?? '',

      details: details,
      social: social,

      geo: Geo(lat: _latitude, lng: _longitude),
      phone: _contactFormCtrl.values['Phone'] ?? '',
      alternatePhone:
          _contactFormCtrl.values['Alternate Phone (Optional)'] ?? '',
      email: _contactFormCtrl.values['Email'] ?? '',

      category: _selectedCategoryName ?? '',
      categoryId: _selectedCategoryId ?? '',
      tags: _selectedTags.toList(),

      ownerName: _basicFormCtrl.values['Owners Name'] ?? '',
      addedBy: FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
      ownerId: FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',

      createdAt: widget.existingListing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),

      images: _remoteImages,
      localImages: _images,

      reviews: 0,
      rating: 0,
      ratingCount: 0,

      since:
          int.tryParse(
            _detailedFormCtrl.values['Since']?.toString() ?? '2025',
          ) ??
          2025,
      likes: 0,
      views: 0,
      isPremium: false,
      ratingStats: {},
      factorAvgRatings: {},
      businessHours:
          _addOpenHours
              ? _businessHours.map((day, schedule) => MapEntry(day, schedule))
              : {},
      isClaimed: widget.existingListing?.isClaimed ?? false,
      updatedBy: FirebaseAuth.instance.currentUser?.uid ?? "anonymous",
      claimStatus: widget.existingListing?.claimStatus ?? "draft",
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => ListingDetailScreen(
              listing: listing,
              isPreview: true,
              isEditing: isEditing,
              similarListings: const [],
            ),
      ),
    );
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text("Take Photo"),
                onTap: () {
                  Navigator.pop(context);
                  _takePhoto();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text("Choose From Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImages();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();

    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1200,
    );

    if (pickedFile != null) {
      setState(() {
        _images.add(File(pickedFile.path));
      });
    }
  }

  Future<void> _checkDraftOnStart() async {
    if (isEditing) {
      setState(() => _draftLoaded = true);
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    final draftString = prefs.getString("listingDraft");

    if (draftString == null) {
      setState(() => _draftLoaded = true);
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showResumeDraftDialog();
    });
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      /// STEP 0 — BASIC INFO
      case 0:
        if (_addressController.text.trim().isEmpty) {
          _showError("Please select address");
          return false;
        }

        if (_selectedCategoryId == null) {
          _showError("Please select category");
          return false;
        }

        return true;

      /// STEP 1 — CONTACT DETAILS
      case 1:
        return true;

      /// STEP 2 — SOCIAL MEDIA
      case 2:
        return true;

      /// STEP 3 — COMMON DETAILS
      case 3:
        return true;

      /// STEP 4 — CATEGORY DETAILS
      case 4:
        return true;

      /// STEP 5 — OPEN HOURS
      case 5:
        return true;

      /// STEP 6 — IMAGES
      case 6:
        return true;

      /// STEP 7 — TAGS
      case 7:
        return true;

      default:
        return true;
    }
  }

  Widget _stepDetailedDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _header("Common Details"),
          DynamicCategoryForm(
            schema: _detailedFields!,
            controller: _detailedFormCtrl,
          ),
        ],
      ),
    );
  }

  Widget _stepCategoryDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (_categoryFields != null) _header("Detailed Info"),
          if (_categoryFields != null)
            DynamicCategoryForm(
              schema: _categoryFields!,
              controller: _categoryFormCtrl,
            ),
          _buildManualKeyValueSection(),
        ],
      ),
    );
  }

  Widget _buildManualKeyValueSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header("Custom Details"),
        ..._manualFields.asMap().entries.map((entry) {
          int index = entry.key;
          var field = entry.value;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: field['key'],
                    decoration: const InputDecoration(
                      labelText: "Key",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: field['value'],
                    decoration: const InputDecoration(
                      labelText: "Value",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.red),
                  onPressed: () {
                    setState(() {
                      _manualFields.removeAt(index);
                    });
                  },
                ),
              ],
            ),
          );
        }).toList(),

        const SizedBox(height: 16),

        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.THEME_COLOR,
          ),
          onPressed: _addManualField,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text("Add Field", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }

  Widget _stepImages() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 👉 Paste:
          // Image Upload Box
          GestureDetector(
            onTap: () {
              _showImageSourcePicker();
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
          SizedBox(height: 10),
          // Remote images
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
                          margin: const EdgeInsets.symmetric(horizontal: 8),
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
                                _remoteImages.removeAt(index);
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
          SizedBox(height: 10),
          // Selected images
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
          SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _stepBasicInfo() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header("Basic Details"),
          // Address row
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
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return "Required";
                    }
                    return null;
                  },
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

                  final Address? address = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const LocationPicker(),
                    ),
                  );

                  if (address != null) {
                    debugPrint(
                      "📍 Selected Location: ${address.latLng.latitude}, ${address.latLng.latitude}",
                    );
                    _addressController.text = address.addressText;

                    // Example: Update your text field with selected address or coordinates
                    setState(() {
                      _latitude = address.latLng.latitude;
                      _longitude = address.latLng.longitude;
                    });
                  }
                },
              ),
            ],
          ),
          SizedBox(height: 16),
          // Category dropdown
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
                selectedCategoryId: _selectedCategoryId,
                selectedCategoryName: _selectedCategoryName,
                onCategorySelected: (String id, String name) {
                  setState(() {
                    _selectedCategoryId = id;
                    _selectedCategoryName = name;
                    _onCategorySelected(name);
                  });
                },
              );
            },
          ),
          SizedBox(height: 16),
          // DynamicCategoryForm(_basicFields)
          DynamicCategoryForm(
            schema: _basicFields!,
            controller: _basicFormCtrl,
          ),
        ],
      ),
    );
  }

  Widget _stepSocialMediaDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _header("Social Media Info"),
          DynamicCategoryForm(
            schema: _socialFields!,
            controller: _socialFormCtrl,
          ),
        ],
      ),
    );
  }

  Widget _stepContactDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _header("Contact Details"),
          DynamicCategoryForm(
            schema: _contactFields!,
            controller: _contactFormCtrl,
          ),
        ],
      ),
    );
  }

  Widget _header(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Center(
        child: Text(
          text,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
    );
  }

  Widget _stepOpenHourDetails() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _header("Open Hours"),
          // 👉 Paste Add Open Hours Row
          Row(
            children: [
              const Expanded(
                child: Text(
                  "Add Business Hours",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
              Transform.scale(
                scale: 1.3,
                child: Checkbox(
                  value: _addOpenHours,
                  onChanged: (v) {
                    setState(() {
                      _addOpenHours = v ?? false;
                    });
                  },
                ),
              ),
            ],
          ),
          // 👉 Paste _buildOpenHoursTable()
          _addOpenHours ? _buildOpenHoursSection() : SizedBox(),
        ],
      ),
    );
  }

  Widget _stepTagging() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header("Add Tags"),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tagController,
                  decoration: const InputDecoration(
                    hintText: "Enter tag name",
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.THEME_COLOR,
                ),
                onPressed: () {
                  final tag = _tagController.text.trim();
                  if (tag.isNotEmpty && !_selectedTags.contains(tag)) {
                    setState(() {
                      _selectedTags.add(tag);
                    });
                    _tagController.clear();
                  }
                },
                child: const Text("Add", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),

          const SizedBox(height: 30),

          /// 🔹 Selected Tags
          if (_selectedTags.isNotEmpty) ...[
            const Text(
              "Selected Tags",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _selectedTags.map((tag) {
                    return Chip(
                      label: Text(tag),
                      deleteIcon: const Icon(Icons.close),
                      onDeleted: () {
                        setState(() {
                          _selectedTags.remove(tag);
                        });
                      },
                    );
                  }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavigationButtons() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _previousStep,
                child: const Text("Back"),
              ),
            ),

          if (_currentStep > 0) const SizedBox(width: 12),

          Expanded(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.THEME_COLOR,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () async {
                if (!_validateCurrentStep()) {
                  return;
                }
                await _nextStep();
                if (_currentStep == 7) {
                  _addAutoTags();
                }
              },
              child: Text(
                _currentStep == 7 ? "Preview" : "Next",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator() {
    const totalSteps = 8;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: List.generate(totalSteps, (index) {
          final isActive = index <= _currentStep;

          return Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              height: 6,
              decoration: BoxDecoration(
                color: isActive ? AppColors.THEME_COLOR : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildOpenHoursSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children:
          weekDays.map((day) {
            final schedule = _businessHours[day]!;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Day Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          day,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        /// Closed Toggle
                        Row(
                          children: [
                            const Text("Closed"),
                            Switch(
                              value: schedule.isClosed,
                              onChanged: (value) {
                                setState(() {
                                  schedule.isClosed = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    /// If Closed → Show Label Only
                    if (schedule.isClosed)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: const Text(
                          "Closed Entire Day",
                          style: TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                    /// If Not Closed → Show Slots
                    if (!schedule.isClosed) ...[
                      ...schedule.slots.asMap().entries.map((entry) {
                        final index = entry.key;
                        final slot = entry.value;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            children: [
                              Expanded(
                                child: _timePickerButton(
                                  context,
                                  label: slot.open.format(context),
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: slot.open,
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        schedule.slots[index] = TimeSlot(
                                          open: picked,
                                          close: slot.close,
                                        );
                                      });
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Text("to"),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _timePickerButton(
                                  context,
                                  label: slot.close.format(context),
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: slot.close,
                                    );
                                    if (picked != null) {
                                      setState(() {
                                        schedule.slots[index] = TimeSlot(
                                          open: slot.open,
                                          close: picked,
                                        );
                                      });
                                    }
                                  },
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: Colors.red,
                                ),
                                onPressed: () {
                                  setState(() {
                                    if (schedule.slots.length > 1) {
                                      schedule.slots.removeAt(index);
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      }),

                      /// Add Slot Button
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            schedule.slots.add(
                              TimeSlot(
                                open: const TimeOfDay(hour: 9, minute: 0),
                                close: const TimeOfDay(hour: 17, minute: 0),
                              ),
                            );
                          });
                        },
                        icon: const Icon(Icons.add),
                        label: const Text("Add Time Slot"),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _timePickerButton(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade400),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(child: Text(label, style: const TextStyle(fontSize: 15))),
      ),
    );
  }
}

class SearchableDropdown extends StatefulWidget {
  final List<models.Category> categories;
  final Function(String, String) onCategorySelected;

  final String? selectedCategoryName;
  final String? selectedCategoryId;

  const SearchableDropdown({
    super.key,
    required this.categories,
    required this.onCategorySelected,
    required this.selectedCategoryId,
    required this.selectedCategoryName,
  });

  @override
  State<SearchableDropdown> createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<SearchableDropdown> {
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
                                'id': cat.id,
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
      widget.onCategorySelected(result['id'] ?? '', result['name'] ?? '');
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
                widget.selectedCategoryName ?? "Select Category",
                style: TextStyle(
                  color:
                      widget.selectedCategoryName == null
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

class DynamicCategoryForm extends StatefulWidget {
  final List<CategoryField> schema;
  final DynamicFormController controller;

  const DynamicCategoryForm({
    super.key,
    required this.schema,
    required this.controller,
  });

  @override
  State<DynamicCategoryForm> createState() => _DynamicCategoryFormState();
}

class _DynamicCategoryFormState extends State<DynamicCategoryForm> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
  }

  TextEditingController _controllerFor(String label) {
    if (!_controllers.containsKey(label)) {
      _controllers[label] = TextEditingController(
        text: widget.controller.values[label]?.toString() ?? '',
      );
    }
    return _controllers[label]!;
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [...widget.schema.map(_buildField)]);
  }

  Widget _buildField(CategoryField field) {
    switch (field.type) {
      case 'number':
        return _numberRow(field);

      case 'currency':
        return _currencyRow(field);

      case 'currency_range':
        return _currencyRangeRow(field);

      case 'string':
        return _stringField(field);

      case 'boolean':
        return _booleanRow(field);

      case 'counter':
        return _counterRow(field);

      case 'single_select':
        return _singleSelect(field);

      case 'multi_select':
        return _multiSelect(field);

      default:
        return const SizedBox.shrink();
    }
  }

  TextInputType _mapKeyboardType(String? keyboardType) {
    switch (keyboardType) {
      case 'email':
        return TextInputType.emailAddress;
      case 'phone':
        return TextInputType.phone;
      case 'url':
        return TextInputType.url;
      case 'multiline':
        return TextInputType.multiline;
      case 'number':
        return TextInputType.number;
      case 'name':
        return TextInputType.name;
      case 'address':
        return TextInputType.streetAddress;
      default:
        return TextInputType.text;
    }
  }

  /* ---------------- NUMBER ---------------- */

  Widget _numberRow(CategoryField field) {
    return _rowField(
      label: field.label,
      child: _smallInput(
        onChanged: (value) => widget.controller.values[field.label] = value,
      ),
    );
  }

  /* ---------------- CURRENCY ---------------- */

  Widget _currencyRow(CategoryField field) {
    final controller = _controllerFor(field.label);

    return _rowField(
      label: field.label,
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: _inputDecoration(prefix: const Text("₹ ")),
        onChanged: (value) {
          widget.controller.values[field.label] = int.tryParse(value) ?? 0;
        },
      ),
    );
  }

  Widget _currencyRangeRow(CategoryField field) {
    widget.controller.values.putIfAbsent(
      field.label,
      () => {'min': null, 'max': null},
    );

    final range = widget.controller.values[field.label];

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Expanded(flex: 2, child: _label(field.label)),

          Expanded(
            child: TextFormField(
              controller: _rangeController(field.label, 'min'),
              keyboardType: TextInputType.number,
              decoration: _inputDecoration(
                prefix: const Text("₹ "),
                hintText: "Min",
              ),
              onChanged: (v) {
                range['min'] = int.tryParse(v);
              },
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Text("-"),
          ),

          Expanded(
            child: TextFormField(
              controller: _rangeController(field.label, 'max'),
              keyboardType: TextInputType.number,
              decoration: _inputDecoration(
                prefix: const Text("₹ "),
                hintText: "Max",
              ),
              onChanged: (v) {
                range['max'] = int.tryParse(v);
              },
            ),
          ),
        ],
      ),
    );
  }

  TextEditingController _rangeController(String label, String key) {
    final id = '$label-$key';

    if (!_controllers.containsKey(id)) {
      final value = widget.controller.values[label]?[key];
      _controllers[id] = TextEditingController(text: value?.toString() ?? '');
    }
    return _controllers[id]!;
  }

  /* ---------------- STRING ---------------- */

  Widget _stringField(CategoryField field) {
    final controller = _controllerFor(field.label);
    final hasCountryCode =
        field.label == 'Phone' ||
        field.label == 'Alternate Phone (Optional)' ||
        field.label == 'WhatsApp';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: _mapKeyboardType(field.keyboardType),
        maxLines: field.keyboardType == 'multiline' ? 6 : 1,
        decoration: InputDecoration(
          labelText: field.label,
          border: const OutlineInputBorder(),
          prefixText: hasCountryCode ? '+91 ' : null,
        ),
        onChanged: (value) {
          widget.controller.values[field.label] = value;
        },
      ),
    );
  }

  /* ---------------- BOOLEAN ---------------- */

  Widget _booleanRow(CategoryField field) {
    // ✅ Initialize default value ONCE
    widget.controller.values.putIfAbsent(
      field.label,
      () => field.label == 'Accept Online Payments',
    );

    final bool value = widget.controller.values[field.label] as bool;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Expanded(child: _label(field.label)),
          Transform.scale(
            scale: 1.3,
            child: Checkbox(
              value: value,
              onChanged: (v) {
                setState(() {
                  widget.controller.values[field.label] = v ?? false;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  /* ---------------- COUNTER ---------------- */

  Widget _counterRow(CategoryField field) {
    final value = widget.controller.values[field.label] ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Expanded(child: _label(field.label)),
          _counterButton(Icons.remove, () {
            if (value > 0) {
              setState(() => widget.controller.values[field.label] = value - 1);
            }
          }),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(value.toString(), style: const TextStyle(fontSize: 16)),
          ),
          _counterButton(Icons.add, () {
            setState(() => widget.controller.values[field.label] = value + 1);
          }),
        ],
      ),
    );
  }

  /* ---------------- SINGLE SELECT ---------------- */

  Widget _singleSelect(CategoryField field) {
    final selectedValue = widget.controller.values[field.label];

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: InputDecorator(
        decoration: InputDecoration(
          // labelText: field.label,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 5,
          ),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: selectedValue,
            hint: Text(field.label),
            items:
                field.options!
                    .map(
                      (o) => DropdownMenuItem<String>(value: o, child: Text(o)),
                    )
                    .toList(),
            onChanged: (v) {
              setState(() {
                widget.controller.values[field.label] = v;
              });
            },
          ),
        ),
      ),
    );
  }

  /* ---------------- MULTI SELECT ---------------- */

  Widget _multiSelect(CategoryField field) {
    final List selected = widget.controller.values[field.label] ?? [];

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(field.label),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.start,
            runAlignment: WrapAlignment.start,
            spacing: 8,
            runSpacing: 8,
            children:
                field.options!.map((o) {
                  final isSelected = selected.contains(o);
                  return ChoiceChip(
                    label: Text(o),
                    selected: isSelected,
                    onSelected: (v) {
                      setState(() {
                        v ? selected.add(o) : selected.remove(o);
                        widget.controller.values[field.label] = selected;
                      });
                    },
                  );
                }).toList(),
          ),
        ],
      ),
    );
  }

  /* ---------------- UI HELPERS ---------------- */

  Widget _rowField({required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        children: [
          Expanded(child: _label(label)),
          SizedBox(width: 120, child: child),
        ],
      ),
    );
  }

  Widget _label(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
    );
  }

  Widget _smallInput({Widget? prefix, required Function(String) onChanged}) {
    return TextFormField(
      keyboardType: TextInputType.number,
      decoration: _inputDecoration(prefix: prefix, hintText: 'Eg. ₹500'),
      onChanged: onChanged,
    );
  }

  InputDecoration _inputDecoration({Widget? prefix, String? hintText}) {
    return InputDecoration(
      isDense: true,
      prefix: prefix,
      hintText: hintText,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _counterButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          border: Border.all(),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}

class DynamicFormController {
  Map<String, dynamic> values = {};
}
