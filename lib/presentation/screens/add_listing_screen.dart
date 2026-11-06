import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/core/constants/category_field_schema.dart';
import 'package:startup_20/data/models/category_field_model.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/presentation/common_methods/ai_tag_service.dart';
import 'package:startup_20/presentation/common_methods/category_cache_service.dart';
import 'package:startup_20/presentation/common_methods/location_picker.dart';

import 'package:startup_20/presentation/common_methods/searchable_dropdown.dart';
import 'package:startup_20/presentation/screens/listing_detail_screen.dart';
import 'package:startup_20/data/models/category_model.dart' as models;
import 'package:startup_20/providers/auth_provider.dart';

class DuplicateListingMatch {
  final Listing listing;
  final List<String> matchedReasons;

  DuplicateListingMatch({
    required this.listing,
    required this.matchedReasons,
  });
}

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
  List<models.Category> _categories = [];
  bool _categoriesLoaded = false;
  String? _selectedCategoryId;
  String? _selectedCategoryName;
  bool _draftLoaded = false;

  static const int _maxImagesLimit = 15;
  final List<File> _images = [];
  List<ImageFile> _remoteImages = [];

  int get _totalImagesCount => _remoteImages.length + _images.length;
  int get _remainingImageSlots => _maxImagesLimit - _totalImagesCount;

  Timer? _duplicateCheckDebounce;
  bool _isCheckingDuplicates = false;
  List<DuplicateListingMatch> _duplicateMatches = [];
  String _lastCheckedKey = "";
  int _duplicateCheckCounter = 0;

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
  List<String> _aiSuggestedTags = [];
  bool _isSuggestingTags = false;
  final TextEditingController _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCategories();

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

      if (!isEditing) {
        _onCategorySelected(listing.category);
      }
      _prePopulateDynamicForms(listing);
    }
  }

  @override
  void dispose() {
    _duplicateCheckDebounce?.cancel();
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
    if (_selectedTags.isEmpty) {
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
      _businessHours = {
        for (var day in weekDays)
          day:
              listing.businessHours[day] ??
              DaySchedule(
                isClosed: false,
                is24Hours: false,
                slots: [
                  TimeSlot(
                    open: const TimeOfDay(hour: 9, minute: 0),
                    close: const TimeOfDay(hour: 17, minute: 0),
                  ),
                ],
              ),
      };
      _addOpenHours = true;
    }

    _remoteImages = List<ImageFile>.from(listing.images);

    _socialFormCtrl.values = Map<String, dynamic>.from(listing.social);

    _manualFields.clear();

    final keys =
        listing.detailsOrder.isNotEmpty
            ? listing.detailsOrder
            : listing.details.keys.toList();

    for (final key in keys) {
      if (key == "Accept Online Payments") continue;

      if (!listing.details.containsKey(key)) continue;

      final value = listing.details[key];

      _manualFields.add({
        'key': TextEditingController(text: key),
        'value': TextEditingController(text: value.toString()),
      });
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await CategoryCacheService.getCategories();

      if (!mounted) return;

      setState(() {
        _categories = categories;
        _categoriesLoaded = true;
      });
    } catch (e) {
      debugPrint(e.toString());

      if (!mounted) return;

      setState(() {
        _categoriesLoaded = true;
      });
    }
  }

  /// Pick multiple images from gallery
  Future<void> _pickImages() async {
    try {
      if (_remainingImageSlots <= 0) {
        _showError(
          "Maximum limit of $_maxImagesLimit images reached. Please remove an image to add a new one.",
        );
        return;
      }

      final picker = ImagePicker();
      final pickedFiles = await picker.pickMultiImage(
        limit: _remainingImageSlots,
      );

      if (pickedFiles.isEmpty) return;

      final allowedSlots = _remainingImageSlots;
      final filesToAdd =
          pickedFiles
              .take(allowedSlots)
              .map((file) => File(file.path))
              .toList();

      setState(() {
        _images.addAll(filesToAdd);
      });

      if (pickedFiles.length > allowedSlots) {
        _showError(
          "Added ${filesToAdd.length} image(s). Maximum limit of $_maxImagesLimit reached.",
        );
      }
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
        "is24Hours": schedule.is24Hours,
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
        is24Hours: scheduleData["is24Hours"] ?? false,
        slots: slots,
      );
    });
  }

  void _previewListing() {
    final Map<String, String> details = {};
    final List<String> detailsOrder = [];

    final appUser = context.read<AppAuthProvider>().appUser;

    /// COMMON FIELD
    final dynamic paymentValue =
        _detailedFormCtrl.values["Accept Online Payments"];

    final bool acceptsOnlinePayments =
        paymentValue is bool
            ? paymentValue
            : paymentValue.toString().toLowerCase() == "yes";

    details["Accept Online Payments"] = acceptsOnlinePayments ? "Yes" : "No";
    detailsOrder.add("Accept Online Payments");

    /// ADD MODE
    if (!isEditing) {
      final categoryDetails = convertToStringMap(_categoryFormCtrl.values);

      details.addAll(categoryDetails);

      detailsOrder.addAll(categoryDetails.keys);
    }

    /// MANUAL FIELDS
    for (var field in _manualFields) {
      final key = field['key']?.text.trim() ?? '';
      final value = field['value']?.text.trim() ?? '';

      if (key.isNotEmpty) {
        details[key] = value;
        detailsOrder.add(key);
      }
    }

    final Map<String, String> social = {};

    _socialFormCtrl.values.forEach((key, value) {
      final text = value?.toString().trim() ?? "";

      if (text.isNotEmpty) {
        social[key] = text;
      }
    });

    if (_totalImagesCount > _maxImagesLimit) {
      _showError("Maximum $_maxImagesLimit images allowed.");
      return;
    }

    final listing = Listing(
      listingId: widget.existingListing?.listingId ?? 'draft',
      contributionId: widget.existingListing?.contributionId ?? 'draft',

      name: _basicFormCtrl.values['Shop/Service Name'] ?? '',

      address: _addressController.text.trim(),

      description: _detailedFormCtrl.values['Description'] ?? '',

      details: details,
      detailsOrder: detailsOrder,
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
      isDeleted: false,
      updatedBy: appUser?.name ?? "anonymous",

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

  Map<String, String> convertToStringMap(Map<String, dynamic> source) {
    final result = <String, String>{};

    source.forEach((key, value) {
      if (value == null) return;

      if (value is bool) {
        result[key] = value ? 'Yes' : 'No';
      } else if (value is List) {
        result[key] = value.join(', ');
      } else if (value is Map) {
        final min = value['min'];
        final max = value['max'];

        if (min != null || max != null) {
          result[key] = '₹${min ?? ''} - ₹${max ?? ''}';
        }
      } else {
        result[key] = value.toString();
      }
    });

    return result;
  }

  void _showImageSourcePicker() {
    if (_remainingImageSlots <= 0) {
      _showError(
        "Maximum limit of $_maxImagesLimit images reached. Please remove an image to add a new one.",
      );
      return;
    }

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
    if (_remainingImageSlots <= 0) {
      _showError(
        "Maximum limit of $_maxImagesLimit images reached. Please remove an image to add a new one.",
      );
      return;
    }

    final picker = ImagePicker();

    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 80,
      maxWidth: 1200,
    );

    if (pickedFile != null) {
      if (_remainingImageSlots <= 0) {
        _showError("Maximum limit of $_maxImagesLimit images reached.");
        return;
      }
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
        if (_totalImagesCount > _maxImagesLimit) {
          _showError(
            "Maximum $_maxImagesLimit images allowed. Please remove ${_totalImagesCount - _maxImagesLimit} image(s).",
          );
          return false;
        }
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
    if (isEditing) {
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _buildManualKeyValueSection(),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
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
                      field['key']?.dispose();
                      field['value']?.dispose();

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
    final bool isLimitReached = _remainingImageSlots <= 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Image Upload Box
          GestureDetector(
            onTap: () {
              if (isLimitReached) {
                _showError(
                  "Maximum limit of $_maxImagesLimit images reached. Please remove an image to add a new one.",
                );
                return;
              }
              _showImageSourcePicker();
            },
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color:
                    isLimitReached
                        ? Colors.grey.shade200
                        : AppColors.GREY_SHADE_300,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color:
                      isLimitReached
                          ? Colors.grey.shade400
                          : AppColors.THEME_COLOR.withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isLimitReached
                          ? Icons.check_circle_outline
                          : Icons.cloud_upload,
                      size: 48,
                      color: isLimitReached ? Colors.grey : AppColors.BLACK_54,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isLimitReached
                          ? "Maximum $_maxImagesLimit images added"
                          : "Tap to upload image",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color:
                            isLimitReached
                                ? Colors.grey.shade700
                                : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isLimitReached
                          ? "$_totalImagesCount / $_maxImagesLimit images (Limit reached)"
                          : "$_totalImagesCount / $_maxImagesLimit images ($_remainingImageSlots slots remaining)",
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isLimitReached
                                ? Colors.red.shade700
                                : AppColors.BLACK_54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Remote images
          if (isEditing && _remoteImages.isNotEmpty) ...[
            Text(
              "Existing Images (${_remoteImages.length})",
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _remoteImages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 12),
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
                        right: 16,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _remoteImages.removeAt(index);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppColors.BLACK_54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 18,
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
          ],
          // Selected images
          if (_images.isNotEmpty) ...[
            Text(
              "New Images (${_images.length})",
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _images.length,
                itemBuilder: (context, index) {
                  return Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 12),
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
                      Positioned(
                        top: 4,
                        right: 16,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _images.removeAt(index);
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: AppColors.BLACK_54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 18,
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
          ],
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
          if (!_categoriesLoaded)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_categories.isEmpty)
            const Text("No categories found")
          else
            SearchableDropdown(
              categories: _categories,
              selectedCategoryId: _selectedCategoryId,
              selectedCategoryName: _selectedCategoryName,
              onCategorySelected: (String id, String name) {
                setState(() {
                  _selectedCategoryId = id;
                  _selectedCategoryName = name;
                  _onCategorySelected(name);
                  _aiSuggestedTags = [];
                });
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header("Contact Details"),
          DynamicCategoryForm(
            schema: _contactFields!,
            controller: _contactFormCtrl,
            onFieldChanged: (label, value) => _onContactDetailsChanged(),
          ),
          if (_isCheckingDuplicates)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.THEME_COLOR,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "Checking credentials...",
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          if (_duplicateMatches.isNotEmpty)
            _buildDuplicateListingsSection(),
        ],
      ),
    );
  }

  String _cleanPhoneNumber(String input) {
    String digits = input.replaceAll(RegExp(r'\D'), '');
    while (digits.startsWith('0') && digits.length > 10) {
      digits = digits.substring(1);
    }
    if (digits.startsWith('91') && digits.length > 10) {
      digits = digits.substring(2);
    }
    while (digits.startsWith('0') && digits.length > 10) {
      digits = digits.substring(1);
    }
    return digits;
  }

  void _onContactDetailsChanged() {
    _duplicateCheckDebounce?.cancel();
    _duplicateCheckDebounce = Timer(const Duration(milliseconds: 600), () {
      _checkDuplicateListings();
    });
  }

  Future<void> _checkDuplicateListings() async {
    final rawPhone =
        _contactFormCtrl.values['Phone']?.toString().trim() ?? '';
    final rawAltPhone =
        _contactFormCtrl.values['Alternate Phone (Optional)']
            ?.toString()
            .trim() ??
        '';
    final rawEmail =
        _contactFormCtrl.values['Email']?.toString().trim() ?? '';

    final cleanPhone = _cleanPhoneNumber(rawPhone);
    final cleanAltPhone = _cleanPhoneNumber(rawAltPhone);
    final cleanEmail = rawEmail.toLowerCase();

    final hasValidPhone = cleanPhone.length >= 8 && cleanPhone.length <= 13;
    final hasValidAltPhone =
        cleanAltPhone.length >= 8 && cleanAltPhone.length <= 13;
    final hasValidEmail =
        cleanEmail.length >= 5 &&
        cleanEmail.contains('@') &&
        cleanEmail.contains('.');

    final currentKey = '$cleanPhone|$cleanAltPhone|$cleanEmail';
    if (currentKey == _lastCheckedKey) {
      return;
    }
    _lastCheckedKey = currentKey;

    if (!hasValidPhone && !hasValidAltPhone && !hasValidEmail) {
      if (_duplicateMatches.isNotEmpty || _isCheckingDuplicates) {
        setState(() {
          _lastCheckedKey = currentKey;
          _duplicateMatches = [];
          _isCheckingDuplicates = false;
        });
      } else {
        _lastCheckedKey = currentKey;
      }
      return;
    }

    final requestId = ++_duplicateCheckCounter;
    setState(() {
      _isCheckingDuplicates = true;
    });

    debugPrint(
      '🔍 [DuplicateCheck] Starting: phone="$cleanPhone" (raw: "$rawPhone"), alt="$cleanAltPhone", email="$cleanEmail"',
    );

    try {
      final List<Future<QuerySnapshot>> queries = [];

      List<String> getPhoneVariants(String digits, String raw) {
        final set = <String>{};
        if (raw.isNotEmpty) {
          set.add(raw.trim());
        }
        if (digits.isNotEmpty) {
          set.add(digits);
          set.add('+91$digits');
          set.add('+91 $digits');
          set.add('91$digits');
          set.add('0$digits');
          if (digits.length == 10) {
            set.add('${digits.substring(0, 5)} ${digits.substring(5)}');
            set.add('+91 ${digits.substring(0, 5)} ${digits.substring(5)}');
            set.add('${digits.substring(0, 5)}-${digits.substring(5)}');
            set.add('+91-${digits.substring(0, 5)}-${digits.substring(5)}');
          }
        }
        return set.take(10).toList();
      }

      if (hasValidPhone) {
        final variants = getPhoneVariants(cleanPhone, rawPhone);
        queries.add(
          FirebaseFirestore.instance
              .collection('listings')
              .where('phone', whereIn: variants)
              .limit(10)
              .get(),
        );
        queries.add(
          FirebaseFirestore.instance
              .collection('listings')
              .where('alternatePhone', whereIn: variants)
              .limit(10)
              .get(),
        );

        final intPhone = int.tryParse(cleanPhone);
        if (intPhone != null) {
          queries.add(
            FirebaseFirestore.instance
                .collection('listings')
                .where('phone', isEqualTo: intPhone)
                .limit(10)
                .get(),
          );
          queries.add(
            FirebaseFirestore.instance
                .collection('listings')
                .where('alternatePhone', isEqualTo: intPhone)
                .limit(10)
                .get(),
          );
        }
      }

      if (hasValidAltPhone) {
        final variants = getPhoneVariants(cleanAltPhone, rawAltPhone);
        queries.add(
          FirebaseFirestore.instance
              .collection('listings')
              .where('phone', whereIn: variants)
              .limit(10)
              .get(),
        );
        queries.add(
          FirebaseFirestore.instance
              .collection('listings')
              .where('alternatePhone', whereIn: variants)
              .limit(10)
              .get(),
        );

        final intAlt = int.tryParse(cleanAltPhone);
        if (intAlt != null) {
          queries.add(
            FirebaseFirestore.instance
                .collection('listings')
                .where('phone', isEqualTo: intAlt)
                .limit(10)
                .get(),
          );
          queries.add(
            FirebaseFirestore.instance
                .collection('listings')
                .where('alternatePhone', isEqualTo: intAlt)
                .limit(10)
                .get(),
          );
        }
      }

      if (hasValidEmail) {
        final emailVariants = {cleanEmail, rawEmail.trim()}.toList();
        queries.add(
          FirebaseFirestore.instance
              .collection('listings')
              .where('email', whereIn: emailVariants)
              .limit(10)
              .get(),
        );
      }

      final snapshots = await Future.wait(queries);

      if (!mounted || requestId != _duplicateCheckCounter) return;

      final Map<String, DuplicateListingMatch> matchMap = {};

      for (var snap in snapshots) {
        for (var doc in snap.docs) {
          try {
            final data = doc.data() as Map<String, dynamic>;
            final docId = doc.id;

            // If editing, exclude current listing
            if (widget.existingListing != null &&
                (widget.existingListing!.listingId == docId ||
                    data['listingId'] == widget.existingListing!.listingId)) {
              continue;
            }

            // Exclude deleted listings
            if (data['isDeleted'] == true) {
              continue;
            }

            // Safely read contact fields directly from data
            final rawDocPhone =
                (data['phone'] ?? data['phoneNumber'] ?? '').toString();
            final rawDocAlt = (data['alternatePhone'] ?? '').toString();
            final rawDocEmail = (data['email'] ?? '').toString();

            final docCleanPhone = _cleanPhoneNumber(rawDocPhone);
            final docCleanAlt = _cleanPhoneNumber(rawDocAlt);
            final docEmail = rawDocEmail.trim().toLowerCase();

            final matchedReasons = <String>{};

            if (hasValidPhone) {
              if (docCleanPhone == cleanPhone ||
                  (cleanPhone.length >= 8 &&
                      docCleanPhone.contains(cleanPhone)) ||
                  (rawDocPhone.trim().isNotEmpty &&
                      rawDocPhone.trim() == rawPhone)) {
                matchedReasons.add('Phone');
              }
              if (docCleanAlt == cleanPhone ||
                  (cleanPhone.length >= 8 &&
                      docCleanAlt.contains(cleanPhone)) ||
                  (rawDocAlt.trim().isNotEmpty &&
                      rawDocAlt.trim() == rawPhone)) {
                matchedReasons.add('Alternate Phone');
              }
            }

            if (hasValidAltPhone) {
              if (docCleanPhone == cleanAltPhone ||
                  (cleanAltPhone.length >= 8 &&
                      docCleanPhone.contains(cleanAltPhone)) ||
                  (rawDocPhone.trim().isNotEmpty &&
                      rawDocPhone.trim() == rawAltPhone)) {
                matchedReasons.add('Phone');
              }
              if (docCleanAlt == cleanAltPhone ||
                  (cleanAltPhone.length >= 8 &&
                      docCleanAlt.contains(cleanAltPhone)) ||
                  (rawDocAlt.trim().isNotEmpty &&
                      rawDocAlt.trim() == rawAltPhone)) {
                matchedReasons.add('Alternate Phone');
              }
            }

            if (hasValidEmail &&
                (docEmail == cleanEmail ||
                    rawDocEmail.trim() == rawEmail.trim())) {
              matchedReasons.add('Email');
            }

            if (matchedReasons.isNotEmpty) {
              Listing listing;
              try {
                data['listingId'] = data['listingId'] ?? docId;
                listing = Listing.fromJson(data);
              } catch (e) {
                debugPrint('⚠️ Listing.fromJson fallback for $docId: $e');
                listing = _safeListingFromMap(docId, data);
              }

              if (matchMap.containsKey(docId)) {
                for (var reason in matchedReasons) {
                  if (!matchMap[docId]!.matchedReasons.contains(reason)) {
                    matchMap[docId]!.matchedReasons.add(reason);
                  }
                }
              } else {
                matchMap[docId] = DuplicateListingMatch(
                  listing: listing,
                  matchedReasons: matchedReasons.toList(),
                );
              }
            }
          } catch (docErr) {
            debugPrint('⚠️ Error processing duplicate doc: $docErr');
          }
        }
      }

      debugPrint(
        '🔍 [DuplicateCheck] Done. Found ${matchMap.length} duplicate match(es).',
      );

      setState(() {
        _lastCheckedKey = currentKey;
        _duplicateMatches = matchMap.values.toList();
        _isCheckingDuplicates = false;
      });
    } catch (e, stack) {
      debugPrint('❌ Error checking duplicate listings: $e\n$stack');
      if (mounted && requestId == _duplicateCheckCounter) {
        setState(() {
          _isCheckingDuplicates = false;
        });
      }
    }
  }

  Listing _safeListingFromMap(String docId, Map<String, dynamic> data) {
    return Listing(
      listingId: data['listingId']?.toString() ?? docId,
      contributionId: data['contributionId']?.toString() ?? '',
      name: data['name']?.toString() ?? 'Unnamed Listing',
      address: data['address']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      details: {},
      detailsOrder: [],
      geo: Geo(lat: 0.0, lng: 0.0),
      phone: data['phone']?.toString() ?? '',
      alternatePhone: data['alternatePhone']?.toString() ?? '',
      email: data['email']?.toString() ?? '',
      category: data['category']?.toString() ?? 'General',
      categoryId: data['categoryId']?.toString() ?? '',
      tags: [],
      addedBy: data['addedBy']?.toString() ?? '',
      updatedBy: data['updatedBy']?.toString() ?? '',
      isClaimed: data['isClaimed'] == true,
      ownerId: data['ownerId']?.toString() ?? '',
      ownerName: data['ownerName']?.toString() ?? '',
      claimStatus: data['claimStatus']?.toString() ?? 'pending',
      isDeleted: data['isDeleted'] == true,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      images: [],
      reviews: 0,
      ratingCount: 0,
      rating: 0.0,
      since: 2025,
      likes: 0,
      views: 0,
      isPremium: false,
      social: {},
      ratingStats: {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},
      factorAvgRatings: {},
      businessHours: {},
    );
  }

  Widget _buildDuplicateListingsSection() {
    final count = _duplicateMatches.length;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14, bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header Row (compact)
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: const BoxDecoration(
                  color: Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFD97706),
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  "Past listings with same credentials",
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFBBF24),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  "$count Found",
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: Color(0xFFFDE68A)),
          const SizedBox(height: 10),

          // 2. Listing Cards (compact white cards on yellow)
          Column(
            children: _duplicateMatches.map((match) {
              final listing = match.listing;
              final imageUrl = listing.images.isNotEmpty
                  ? (listing.images.first.thumbUrl.isNotEmpty
                      ? listing.images.first.thumbUrl
                      : listing.images.first.fullUrl)
                  : '';
              final hasImage = imageUrl.isNotEmpty;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFFDE68A), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ListingDetailScreen(
                            listing: listing,
                            similarListings: const [],
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          // Thumbnail (48x48 compact)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: hasImage
                                ? CachedNetworkImage(
                                    imageUrl: imageUrl,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      width: 48,
                                      height: 48,
                                      color: Colors.grey.shade100,
                                    ),
                                    errorWidget: (context, url, error) =>
                                        _duplicateFallbackIcon(),
                                  )
                                : _duplicateFallbackIcon(),
                          ),
                          const SizedBox(width: 10),

                          // Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  listing.name.isNotEmpty
                                      ? listing.name
                                      : "Unnamed Listing",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black87,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  listing.category.isNotEmpty
                                      ? listing.category
                                      : "General",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Wrap(
                                  spacing: 4,
                                  runSpacing: 3,
                                  children: match.matchedReasons.map((reason) {
                                    final isEmail = reason.contains('Email');
                                    final isAlt = reason.contains('Alternate');

                                    final bg = isEmail
                                        ? const Color(0xFFF0FDF4)
                                        : const Color(0xFFFEF3C7);
                                    final border = isEmail
                                        ? const Color(0xFFBBF7D0)
                                        : const Color(0xFFF59E0B);
                                    final textColor = isEmail
                                        ? const Color(0xFF15803D)
                                        : const Color(0xFF92400E);
                                    final iconColor = isEmail
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFFD97706);
                                    final icon = isEmail
                                        ? Icons.email_rounded
                                        : (isAlt
                                            ? Icons.phone_callback_rounded
                                            : Icons.phone_rounded);

                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: bg,
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(
                                          color: border,
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            icon,
                                            size: 10,
                                            color: iconColor,
                                          ),
                                          const SizedBox(width: 3),
                                          Text(
                                            "Matched: $reason",
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color: textColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),

                          // View Action Pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: const [
                                Text(
                                  "View",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                                SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: 14,
                                  color: Color(0xFF92400E),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 2),

          // 3. Footer info note (slim)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFFFDE68A).withValues(alpha: 0.6),
                width: 0.8,
              ),
            ),
            child: Row(
              children: const [
                Icon(
                  Icons.info_outline_rounded,
                  size: 12,
                  color: Color(0xFFB45309),
                ),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    "You can still proceed with Next if this is a separate listing.",
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _duplicateFallbackIcon() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.THEME_COLOR.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: AppColors.THEME_COLOR.withValues(alpha: 0.15),
          width: 0.8,
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.storefront_rounded,
          color: AppColors.THEME_COLOR,
          size: 22,
        ),
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
    final bool isAll24Hours = weekDays.every(
      (day) => _businessHours[day]?.is24Hours == true,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _header("Open Hours"),
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
          if (_addOpenHours) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color:
                    isAll24Hours
                        ? AppColors.THEME_COLOR.withValues(alpha: 0.08)
                        : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color:
                      isAll24Hours
                          ? AppColors.THEME_COLOR.withValues(alpha: 0.35)
                          : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color:
                          isAll24Hours
                              ? AppColors.THEME_COLOR.withValues(alpha: 0.15)
                              : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.all_inclusive_rounded,
                      size: 20,
                      color:
                          isAll24Hours
                              ? AppColors.THEME_COLOR
                              : Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Open 24/7 (All 7 Days)",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color:
                                isAll24Hours
                                    ? AppColors.THEME_COLOR
                                    : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          "Mark business open 24 hours every day",
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Transform.scale(
                    scale: 0.85,
                    child: Switch(
                      value: isAll24Hours,
                      activeTrackColor: AppColors.THEME_COLOR,
                      activeThumbColor: Colors.white,
                      onChanged: (val) {
                        setState(() {
                          for (var day in weekDays) {
                            _businessHours[day]?.is24Hours = val;
                            if (val) {
                              _businessHours[day]?.isClosed = false;
                            } else if (_businessHours[day]?.slots.isEmpty ??
                                true) {
                              _businessHours[day]?.slots = [
                                TimeSlot(
                                  open: const TimeOfDay(hour: 9, minute: 0),
                                  close: const TimeOfDay(hour: 17, minute: 0),
                                ),
                              ];
                            }
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _buildOpenHoursSection(),
          ],
        ],
      ),
    );
  }

  Map<String, dynamic> _buildAiTagInput() {
    final manualDetails = <String, dynamic>{};

    for (final field in _manualFields) {
      final key = field['key']?.text.trim() ?? '';
      final value = field['value']?.text.trim() ?? '';

      if (key.isNotEmpty && value.isNotEmpty) {
        manualDetails[key] = value;
      }
    }

    return {
      "category": _selectedCategoryName ?? '',
      "address": _addressController.text.trim(),

      "existingTags": _selectedTags.toList(),
      "basicDetails": Map<String, dynamic>.from(_basicFormCtrl.values),

      "detailedDetails": Map<String, dynamic>.from(_detailedFormCtrl.values),

      "categoryDetails": Map<String, dynamic>.from(_categoryFormCtrl.values),

      "customDetails": manualDetails,

      "description":
          _detailedFormCtrl.values['Description']?.toString().trim() ?? '',
    };
  }

  Future<void> _suggestTags() async {
    debugPrint("Called Suggestions");
    setState(() {
      _isSuggestingTags = true;
      _aiSuggestedTags = [];
    });

    final listingData = _buildAiTagInput();

    debugPrint("CURRENT USER: ${FirebaseAuth.instance.currentUser?.uid}");
    debugPrint("AI Tag INPUT -> ");
    debugPrint(jsonEncode(listingData));

    try {
      final tags = await AiTagService.generateTags(listingData: listingData);

      if (!mounted) return;

      // Show tags one by one for a more interactive experience.
      for (final tag in tags) {
        if (!mounted) return;

        setState(() {
          _aiSuggestedTags.add(tag);
        });

        await Future.delayed(const Duration(milliseconds: 250));
      }

      if (!mounted) return;

      setState(() {
        _isSuggestingTags = false;
      });
    } catch (e) {
      debugPrint("AI Tag Error: $e");

      if (!mounted) return;

      setState(() {
        _isSuggestingTags = false;
      });

      _showError("Unable to suggest tags right now, kindly check your network");
    }
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
              spacing: 6,
              runSpacing: 6,
              children:
                  _selectedTags.map((tag) {
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTags.remove(tag);
                        });
                      },
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 275),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.THEME_COLOR.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                tag,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.BLACK,
                                ),
                              ),
                            ),

                            const SizedBox(width: 4),

                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _aiSuggestedTags.remove(tag);
                                });
                              },
                              child: Icon(
                                Icons.close_rounded,
                                size: 17,
                                color: AppColors.BLACK_54,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ],

          // if (_aiSuggestedTags.any((tag) => !_selectedTags.contains(tag))) ...[
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              disabledBackgroundColor: AppColors.THEME_COLOR,
              // disabledForegroundColor: AppColors.THEME_COLOR,
              backgroundColor: AppColors.THEME_COLOR,
              foregroundColor: AppColors.WHITE,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 22),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            icon:
                _isSuggestingTags
                    ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 1,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.WHITE,
                        ),
                      ),
                    )
                    : Icon(Icons.auto_awesome_sharp, color: AppColors.WHITE),
            label:
                _isSuggestingTags
                    ? SizedBox(
                      width: 88,
                      child: AnimatedTextKit(
                        repeatForever: true,
                        pause: Duration(milliseconds: 100),
                        animatedTexts: [
                          FadeAnimatedText(
                            "Suggesting...",
                            textStyle: TextStyle(color: AppColors.WHITE),
                          ),
                          FadeAnimatedText(
                            "Sit Tight....",
                            textStyle: TextStyle(color: AppColors.WHITE),
                          ),
                        ],
                      ),
                    )
                    : Text("Suggest Tags"),

            onPressed: _isSuggestingTags ? null : _suggestTags,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children:
                _aiSuggestedTags
                    .where((tag) => !_selectedTags.contains(tag))
                    .map((tag) {
                      final isSelected = _selectedTags.contains(tag);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            isSelected
                                ? _selectedTags.remove(tag)
                                : _selectedTags.add(tag);
                          });
                        },
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 275),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.THEME_COLOR.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  tag,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.BLACK,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 4),

                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _aiSuggestedTags.remove(tag);
                                  });
                                },
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 17,
                                  color: AppColors.BLACK_54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    })
                    .toList(),
          ),
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
                if (_currentStep == 7 && !isEditing) {
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
            final bool isOpen = !schedule.isClosed && !schedule.is24Hours;
            final bool is24 = !schedule.isClosed && schedule.is24Hours;
            final bool isClosed = schedule.isClosed;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color:
                      isClosed
                          ? Colors.red.shade200
                          : is24
                          ? Colors.green.shade300
                          : Colors.grey.shade300,
                  width: (is24 || isClosed) ? 1.2 : 1.0,
                ),
              ),
              color:
                  isClosed
                      ? const Color(0xFFFFF8F8)
                      : is24
                      ? const Color(0xFFF6FBF8)
                      : Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    /// Day Header Row: Day Name + Segmented Pill Selector
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          day,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color:
                                isClosed ? Colors.grey.shade700 : Colors.black87,
                          ),
                        ),
                        _buildDayStatusPills(schedule),
                      ],
                    ),

                    /// If Closed → Show Closed Badge
                    if (isClosed) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade100),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.block_rounded,
                              size: 15,
                              color: Colors.red.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Closed Entire Day",
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    /// If 24 Hours → Show 24 Hours Badge
                    if (is24) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.all_inclusive_rounded,
                              size: 17,
                              color: Colors.green.shade700,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              "Open 24 Hours",
                              style: TextStyle(
                                color: Colors.green.shade800,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    /// If Regular Timings → Show Slots
                    if (isOpen) ...[
                      const SizedBox(height: 14),
                      ...schedule.slots.asMap().entries.map((entry) {
                        final index = entry.key;
                        final slot = entry.value;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
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
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                ),
                                child: Text(
                                  "to",
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontWeight: FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
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
                              if (schedule.slots.length > 1) ...[
                                const SizedBox(width: 6),
                                InkWell(
                                  onTap: () {
                                    setState(() {
                                      schedule.slots.removeAt(index);
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.all(7),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.close_rounded,
                                      size: 16,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      }),
                      InkWell(
                        onTap: () {
                          setState(() {
                            schedule.slots.add(
                              TimeSlot(
                                open: const TimeOfDay(hour: 9, minute: 0),
                                close: const TimeOfDay(hour: 17, minute: 0),
                              ),
                            );
                          });
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 2,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_circle_outline_rounded,
                                size: 16,
                                color: AppColors.THEME_COLOR,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Add Time Slot",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.THEME_COLOR,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }

  Widget _buildDayStatusPills(DaySchedule schedule) {
    final int selectedIndex =
        schedule.isClosed
            ? 2
            : schedule.is24Hours
            ? 1
            : 0;

    final Alignment alignment =
        selectedIndex == 0
            ? const Alignment(-1.0, 0.0)
            : selectedIndex == 1
            ? const Alignment(0.0, 0.0)
            : const Alignment(1.0, 0.0);

    final Color thumbColor =
        selectedIndex == 0
            ? AppColors.THEME_COLOR
            : selectedIndex == 1
            ? const Color(0xFF1B8755)
            : const Color(0xFFD32F2F);

    return Container(
      width: 176,
      height: 33,
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F2F4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Stack(
        children: [
          // 1. Sliding colored thumb indicator
          AnimatedAlign(
            alignment: alignment,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeInOutCubic,
            child: FractionallySizedBox(
              widthFactor: 1 / 3,
              heightFactor: 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOutCubic,
                decoration: BoxDecoration(
                  color: thumbColor,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          // 2. Interactive text tabs
          Row(
            children: [
              _buildSlidingTabItem(
                label: "Open",
                isSelected: selectedIndex == 0,
                onTap: () {
                  setState(() {
                    schedule.isClosed = false;
                    schedule.is24Hours = false;
                    if (schedule.slots.isEmpty) {
                      schedule.slots.add(
                        TimeSlot(
                          open: const TimeOfDay(hour: 9, minute: 0),
                          close: const TimeOfDay(hour: 17, minute: 0),
                        ),
                      );
                    }
                  });
                },
              ),
              _buildSlidingTabItem(
                label: "24 Hrs",
                isSelected: selectedIndex == 1,
                onTap: () {
                  setState(() {
                    schedule.is24Hours = true;
                    schedule.isClosed = false;
                  });
                },
              ),
              _buildSlidingTabItem(
                label: "Closed",
                isSelected: selectedIndex == 2,
                onTap: () {
                  setState(() {
                    schedule.isClosed = true;
                    schedule.is24Hours = false;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSlidingTabItem({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Center(
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeInOutCubic,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? Colors.white : const Color(0xFF555555),
            ),
            child: Text(label),
          ),
        ),
      ),
    );
  }

  Widget _timePickerButton(
    BuildContext context, {
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.access_time_rounded,
              size: 16,
              color: AppColors.THEME_COLOR,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DynamicCategoryForm extends StatefulWidget {
  final List<CategoryField> schema;
  final DynamicFormController controller;
  final void Function(String label, dynamic value)? onFieldChanged;

  const DynamicCategoryForm({
    super.key,
    required this.schema,
    required this.controller,
    this.onFieldChanged,
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
          widget.onFieldChanged?.call(field.label, value);
        },
      ),
    );
  }

  /* ---------------- BOOLEAN ---------------- */

  Widget _booleanRow(CategoryField field) {
    final dynamic rawValue = widget.controller.values[field.label];

    bool value = false;

    if (rawValue is bool) {
      value = rawValue;
    } else if (rawValue is String) {
      value =
          rawValue.toLowerCase() == 'yes' || rawValue.toLowerCase() == 'true';
    }

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
