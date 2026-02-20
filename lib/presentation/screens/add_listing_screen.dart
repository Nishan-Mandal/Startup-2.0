import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/core/constants/category_field_schema.dart';
import 'package:startup_20/data/models/category_field_model.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/presentation/common_methods/common_methods.dart';
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
  bool get isEditing => widget.existingListing != null;

  final TextEditingController _addressController = TextEditingController();
  final _commonFormCtrl = DynamicFormController();
  final _socialFormCtrl = DynamicFormController();
  final _categoryFormCtrl = DynamicFormController();

  List<CategoryField>? _commonFields;
  List<CategoryField>? _socialFields;
  List<CategoryField>? _categoryFields;

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

  @override
  void initState() {
    super.initState();
    _categoriesFuture = fetchCategories();

    _commonFields =
        (CategoryFieldSchema.commonFields['formSchema'] as List)
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

      _onCategorySelected(listing.category);
      _prePopulateDynamicForms(listing);
    }
  }

  void _onCategorySelected(String name) {
    late Map<String, dynamic> categorySchema;

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
      _categoryFields =
          (categorySchema['formSchema'] as List)
              .map((e) => CategoryField.fromJson(e))
              .toList();
    });
  }

  void _prePopulateDynamicForms(Listing listing) {
    _commonFormCtrl.values = {
      "Shop/Service Name": listing.name,
      "Owners Name": listing.ownerName,
      "Phone": listing.phone,
      "Since": listing.since,
      "Email": listing.details["Email"],
      "Description": listing.description,
      "Accept Online Payments":
          listing.details["Accept Online Payments"] ?? true,
    };
    _addressController.text = listing.address;
    _latitude = listing.geo.lat;
    _longitude = listing.geo.lng;
    _selectedCategoryId = listing.categoryId;
    _selectedCategoryName = listing.category;
    if (listing.openHours.isNotEmpty) {
      _openHours = listing.openHours;
      _addOpenHours = true;
    }

    _remoteImages = List<ImageFile>.from(listing.images);

    _socialFormCtrl.values = Map<String, dynamic>.from(listing.social);

    _categoryFormCtrl.values = Map<String, dynamic>.from(listing.details);
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

  void _previewListing() {
    final Map<String, dynamic> details = {..._categoryFormCtrl.values};

    final Map<String, String> social = _socialFormCtrl.values.map(
      (k, v) => MapEntry(k, v.toString()),
    );

    final listing = Listing(
      listingId: widget.existingListing?.listingId ?? 'draft',
      contributionId: widget.existingListing?.contributionId ?? 'draft',

      name: _commonFormCtrl.values['Shop/Service Name'] ?? '',
      address: _addressController.text.trim(),
      description: _commonFormCtrl.values['Description'] ?? '',

      details: details,
      social: social,

      geo: Geo(lat: _latitude, lng: _longitude),
      phone: _commonFormCtrl.values['Phone'] ?? '',

      category: _selectedCategoryName!,
      categoryId: _selectedCategoryId!,
      tags: [_selectedCategoryName!],

      ownerName: _commonFormCtrl.values['Owners Name'] ?? '',
      addedBy: FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',
      ownerId: FirebaseAuth.instance.currentUser?.uid ?? 'anonymous',

      createdAt: widget.existingListing?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),

      images: _remoteImages,
      localImages: _images,

      reviews: 0,
      rating: 0,
      ratingCount: 0,

      since: int.tryParse(details['Since']?.toString() ?? '2025') ?? 2025,
      likes: 0,
      views: 0,

      ratingStats: {},
      factorAvgRatings: {},
      openHours: _addOpenHours ? _openHours : {},
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
                            _onCategorySelected(name);
                          });
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 16),

                  DynamicCategoryForm(
                    schema: _commonFields!,
                    controller: _commonFormCtrl,
                  ),

                  // const SizedBox(height: 24),
                  DynamicCategoryForm(
                    schema: _socialFields!,
                    controller: _socialFormCtrl,
                  ),

                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Add Open Hours",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
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
                  ),

                  if (_addOpenHours) ...[
                    const SizedBox(height: 12),
                    _buildOpenHoursTable(),
                    const SizedBox(height: 12),
                  ],

                  if (_categoryFields != null)
                    DynamicCategoryForm(
                      schema: _categoryFields!,
                      controller: _categoryFormCtrl,
                    ),

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
    final hasCountryCode = field.label == 'Phone' || field.label == 'WhatsApp';

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: _mapKeyboardType(field.keyboardType),
        maxLines: field.keyboardType == 'multiline' ? null : 1,
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
