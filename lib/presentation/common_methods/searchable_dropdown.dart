import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/core/constants/app_locations.dart';
import 'package:startup_20/data/models/category_model.dart' as models;
import 'package:startup_20/data/models/filter_options_model.dart';
import 'package:startup_20/providers/location_provider.dart';

enum SearchableDropdownStyle { field, compact, icon, location }

class SearchableDropdown extends StatefulWidget {
  final List<models.Category> categories;

  final Function(String, String)? onCategorySelected;

  final String? selectedCategoryName;

  final String? selectedCategoryId;
  final SearchableDropdownStyle style;

  final ListingFilterOptions? filterOptions;
  final ValueChanged<ListingFilterOptions>? onFilterApplied;
  final int activeFilterCount;
  final EdgeInsetsGeometry? iconMargin;

  const SearchableDropdown({
    super.key,
    this.style = SearchableDropdownStyle.field,
    this.categories = const [],
    this.onCategorySelected,
    this.selectedCategoryId,
    this.selectedCategoryName,
    this.filterOptions,
    this.onFilterApplied,
    this.activeFilterCount = 0,
    this.iconMargin,
  });

  @override
  State<SearchableDropdown> createState() => _SearchableDropdownState();
}

class _SearchableDropdownState extends State<SearchableDropdown> {
  final TextEditingController _searchController = TextEditingController();

  final FocusNode _searchFocus = FocusNode();

  Future<void> _openSearchDialog() async {
    if (widget.style == SearchableDropdownStyle.location) {
      await _showLocationPicker();
      return;
    }

    if (widget.style == SearchableDropdownStyle.icon ||
        widget.onFilterApplied != null) {
      await _showFilterSheet();
      return;
    }

    final result = await _showCategoryPicker();

    if (result != null) {
      widget.onCategorySelected?.call(result['id'] ?? '', result['name'] ?? '');
    }
  }

  Future<Map<String, String>?> _showCategoryPicker() async {
    switch (widget.style) {
      case SearchableDropdownStyle.field:
        return _showFieldCategoryPicker();

      case SearchableDropdownStyle.compact:
        return _showCompactCategoryPicker();

      case SearchableDropdownStyle.icon:
        await _showFilterSheet();
        return null;

      case SearchableDropdownStyle.location:
        await _showLocationPicker();
        return null;
    }
  }

  Future<Map<String, String>?> _showFieldCategoryPicker() async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        List<models.Category> filtered = widget.categories;

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _searchFocus.requestFocus();
            });

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.82,
              maxChildSize: 0.92,
              minChildSize: 0.6,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      /// Drag Handle
                      const SizedBox(height: 12),

                      Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Select Category",
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),

                                  SizedBox(height: 4),

                                  Text(
                                    "Choose from ${filtered.length} Categories",
                                    style: TextStyle(
                                      color: Colors.grey,
                                      letterSpacing: 0.02,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            InkWell(
                              borderRadius: BorderRadius.circular(50),
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      /// Search Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocus,
                          decoration: InputDecoration(
                            hintText: "Search categories",

                            prefixIcon: const Icon(Icons.search),

                            suffixIcon:
                                _searchController.text.isNotEmpty
                                    ? IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();

                                        setStateDialog(() {
                                          filtered = widget.categories;
                                        });
                                      },
                                    )
                                    : null,

                            filled: true,

                            fillColor: Colors.grey.shade100,

                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 15,
                            ),

                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),

                          onChanged: (query) {
                            setStateDialog(() {
                              filtered =
                                  widget.categories.where((cat) {
                                    return cat.name.toLowerCase().contains(
                                      query.toLowerCase(),
                                    );
                                  }).toList();
                            });
                          },
                        ),
                      ),

                      const SizedBox(height: 10),

                      Expanded(
                        child:
                            filtered.isEmpty
                                ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.search_off_rounded,
                                        size: 70,
                                        color: Colors.grey.shade400,
                                      ),

                                      const SizedBox(height: 16),

                                      const Text(
                                        "No Category Found",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),

                                      const SizedBox(height: 6),

                                      Text(
                                        "Try searching with another keyword",
                                        style: TextStyle(
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                                : ListView.separated(
                                  controller: scrollController,
                                  padding: const EdgeInsets.fromLTRB(
                                    20,
                                    5,
                                    20,
                                    20,
                                  ),
                                  itemCount: filtered.length,

                                  separatorBuilder:
                                      (_, __) => const SizedBox(height: 10),

                                  itemBuilder: (context, index) {
                                    final cat = filtered[index];

                                    final bool selected =
                                        widget.selectedCategoryName == cat.name;

                                    return AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 180,
                                      ),

                                      decoration: BoxDecoration(
                                        color:
                                            selected
                                                ? AppColors.THEME_COLOR
                                                    .withOpacity(.08)
                                                : Colors.white,

                                        borderRadius: BorderRadius.circular(18),

                                        border: Border.all(
                                          color:
                                              selected
                                                  ? AppColors.THEME_COLOR
                                                  : Colors.grey.shade300,
                                          width: selected ? 1.5 : 1,
                                        ),
                                      ),

                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(18),

                                        onTap: () async {
                                          await Future.delayed(
                                            const Duration(milliseconds: 120),
                                          );

                                          Navigator.pop(context, {
                                            "id": cat.id,
                                            "name": cat.name,
                                          });
                                        },

                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),

                                          child: Row(
                                            children: [
                                              /// ICON
                                              Container(
                                                height: 50,
                                                width: 50,

                                                decoration: BoxDecoration(
                                                  color: AppColors.THEME_COLOR
                                                      .withOpacity(.08),

                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),

                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    10,
                                                  ),

                                                  child: CachedNetworkImage(
                                                    imageUrl: cat.imageUrl,

                                                    fit: BoxFit.contain,

                                                    fadeInDuration:
                                                        const Duration(
                                                          milliseconds: 150,
                                                        ),

                                                    placeholder: (
                                                      context,
                                                      url,
                                                    ) {
                                                      return Center(
                                                        child: SizedBox(
                                                          width: 18,
                                                          height: 18,
                                                          child: CircularProgressIndicator(
                                                            strokeWidth: 2,
                                                            color:
                                                                AppColors
                                                                    .THEME_COLOR,
                                                          ),
                                                        ),
                                                      );
                                                    },

                                                    errorWidget:
                                                        (
                                                          context,
                                                          url,
                                                          error,
                                                        ) => Icon(
                                                          Icons
                                                              .image_not_supported_outlined,
                                                          color:
                                                              Colors
                                                                  .grey
                                                                  .shade500,
                                                        ),
                                                  ),
                                                ),
                                              ),

                                              const SizedBox(width: 16),

                                              /// NAME
                                              Expanded(
                                                child: Text(
                                                  cat.name,

                                                  style: TextStyle(
                                                    fontSize: 15.5,

                                                    fontWeight:
                                                        selected
                                                            ? FontWeight.w700
                                                            : FontWeight.w500,
                                                  ),
                                                ),
                                              ),

                                              /// CHECK
                                              AnimatedSwitcher(
                                                duration: const Duration(
                                                  milliseconds: 200,
                                                ),

                                                child:
                                                    selected
                                                        ? Container(
                                                          key: const ValueKey(
                                                            1,
                                                          ),

                                                          height: 30,
                                                          width: 30,

                                                          decoration:
                                                              const BoxDecoration(
                                                                color:
                                                                    AppColors
                                                                        .THEME_COLOR,

                                                                shape:
                                                                    BoxShape
                                                                        .circle,
                                                              ),

                                                          child: const Icon(
                                                            Icons.check,
                                                            color: Colors.white,
                                                            size: 14,
                                                          ),
                                                        )
                                                        : Icon(
                                                          Icons
                                                              .keyboard_arrow_right_rounded,
                                                          key: const ValueKey(
                                                            2,
                                                          ),
                                                          color: Colors.grey,
                                                        ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );

    if (result != null) {
      widget.onCategorySelected?.call(result["id"] ?? "", result["name"] ?? "");
    }
    return result;
  }

  Future<Map<String, String>?> _showCompactCategoryPicker() async {
    List<models.Category> filtered = List.from(widget.categories);

    return await showModalBottomSheet<Map<String, String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.72,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: const EdgeInsets.only(top: 10),
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppColors.GREY_SHADE_300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            "Select Category",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        InkWell(
                          borderRadius: BorderRadius.circular(50),
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Search
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: TextField(
                      controller: _searchController,
                      onChanged: (query) {
                        setSheetState(() {
                          final search = query.trim().toLowerCase();

                          filtered =
                              widget.categories.where((category) {
                                return category.name.toLowerCase().contains(
                                  search,
                                );
                              }).toList();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: "Search category...",
                        prefixIcon: const Icon(Icons.search_rounded),
                        filled: true,
                        fillColor: AppColors.GREY_SHADE_50,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Categories
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      itemCount: filtered.length + 1,
                      itemBuilder: (context, index) {
                        // All Categories
                        if (index == 0) {
                          final isSelected =
                              widget.selectedCategoryName == null ||
                              widget.selectedCategoryName!.isEmpty;

                          return _buildCompactCategoryTile(
                            title: "All Categories",
                            imageUrl: null,
                            selected: isSelected,
                            onTap: () {
                              Navigator.pop(context, {'id': '', 'name': ''});
                            },
                          );
                        }

                        final category = filtered[index - 1];

                        final isSelected =
                            widget.selectedCategoryName == category.name;

                        return _buildCompactCategoryTile(
                          title: category.name,
                          imageUrl: category.imageUrl,
                          selected: isSelected,
                          onTap: () {
                            Navigator.pop(context, {
                              'id': category.id,
                              'name': category.name,
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCompactCategoryTile({
    required String title,
    required String? imageUrl,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color:
              selected
                  ? AppColors.THEME_COLOR.withOpacity(0.08)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color:
                selected
                    ? AppColors.THEME_COLOR.withOpacity(0.35)
                    : AppColors.GREY_SHADE_300,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.GREY_SHADE_300),
              ),
              child:
                  imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                        imageUrl: imageUrl,
                        fit: BoxFit.contain,
                      )
                      : Icon(
                        Icons.grid_view_rounded,
                        size: 22,
                        color: AppColors.THEME_COLOR,
                      ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: AppColors.BLACK,
                ),
              ),
            ),

            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                size: 21,
                color: AppColors.THEME_COLOR,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLocationPicker() async {
    final allLocations = AppLocationMasterList.allLocations;
    final TextEditingController locationSearchController =
        TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        String searchQuery = "";

        return StatefulBuilder(
          builder: (context, setSheetState) {
            final currentLocationProv = context.watch<LocationProvider>();

            final filteredLocations = searchQuery.trim().isEmpty
                ? allLocations
                : allLocations.where((loc) {
                    final q = searchQuery.trim().toLowerCase();
                    return loc.name.toLowerCase().contains(q) ||
                        loc.district.toLowerCase().contains(q);
                  }).toList();

            final purbaList = filteredLocations
                .where((l) => l.district == "Purba Medinipur")
                .toList();
            final paschimList = filteredLocations
                .where((l) => l.district == "Paschim Medinipur")
                .toList();

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.82,
              maxChildSize: 0.92,
              minChildSize: 0.6,
              builder: (context, scrollController) {
                return Container(
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  child: Column(
                    children: [
                      /// Drag Handle
                      const SizedBox(height: 12),
                      Container(
                        width: 45,
                        height: 5,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      const SizedBox(height: 18),

                      /// Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Select Location",
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.BLACK,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Choose from ${allLocations.length} Locations",
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(50),
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.close, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      /// Search Bar
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextField(
                          controller: locationSearchController,
                          decoration: InputDecoration(
                            hintText: "Search city, town or area...",
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: locationSearchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      locationSearchController.clear();
                                      setSheetState(() {
                                        searchQuery = "";
                                      });
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          onChanged: (query) {
                            setSheetState(() {
                              searchQuery = query;
                            });
                          },
                        ),
                      ),
                      const SizedBox(height: 12),

                      /// Use Current GPS Location Button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            Navigator.pop(context);
                            await context.read<LocationProvider>().initLocation();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.THEME_COLOR.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.THEME_COLOR.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.my_location_rounded,
                                  color: AppColors.THEME_COLOR,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Use Current GPS Location",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: AppColors.THEME_COLOR,
                                        ),
                                      ),
                                      Text(
                                        "Auto-detects closest town or hub",
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios_rounded,
                                  size: 14,
                                  color: AppColors.THEME_COLOR,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Divider(height: 1),

                      /// Locations List
                      Expanded(
                        child: filteredLocations.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.location_off_outlined,
                                      size: 60,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 12),
                                    const Text(
                                      "No Location Found",
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Try searching with another keyword",
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView(
                                controller: scrollController,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 8,
                                ),
                                children: [
                                  if (purbaList.isNotEmpty) ...[
                                    _buildLocationDistrictHeader(
                                      "Purba Medinipur (East Midnapore)",
                                      purbaList.length,
                                    ),
                                    ...purbaList.map(
                                      (loc) => _buildLocationItemTile(
                                        context: context,
                                        location: loc,
                                        isSelected: currentLocationProv
                                                .selectedLocation ==
                                            loc,
                                      ),
                                    ),
                                  ],
                                  if (paschimList.isNotEmpty) ...[
                                    _buildLocationDistrictHeader(
                                      "Paschim Medinipur (West Midnapore)",
                                      paschimList.length,
                                    ),
                                    ...paschimList.map(
                                      (loc) => _buildLocationItemTile(
                                        context: context,
                                        location: loc,
                                        isSelected: currentLocationProv
                                                .selectedLocation ==
                                            loc,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildLocationDistrictHeader(String title, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 6, left: 4),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.GREY,
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "$count",
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationItemTile({
    required BuildContext context,
    required AppLocation location,
    required bool isSelected,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        context.read<LocationProvider>().setLocation(location);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.THEME_COLOR.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.location_on_outlined,
              size: 20,
              color: isSelected ? AppColors.THEME_COLOR : Colors.grey.shade400,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                location.name,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? AppColors.THEME_COLOR : AppColors.BLACK,
                ),
              ),
            ),
            Text(
              location.district,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationTrigger() {
    return Consumer<LocationProvider>(
      builder: (context, locationProv, _) {
        final locationText = locationProv.isLoading
            ? "Detecting location..."
            : "${locationProv.selectedLocation.name}, West Bengal";

        return GestureDetector(
          onTap: _openSearchDialog,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on_outlined,
                color: AppColors.BLACK_54,
                size: 20,
              ),
              const SizedBox(width: 4),
              Text(
                locationText,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: AppColors.BLACK_54,
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: AppColors.BLACK_54),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    switch (widget.style) {
      case SearchableDropdownStyle.field:
        return _buildFieldTrigger();

      case SearchableDropdownStyle.compact:
        return _buildCompactTrigger();

      case SearchableDropdownStyle.icon:
        return _buildIconTrigger();

      case SearchableDropdownStyle.location:
        return _buildLocationTrigger();
    }
  }

  Widget _buildIconTrigger() {
    final count = widget.activeFilterCount;
    final bool hasFilters =
        count > 0 || (widget.filterOptions?.hasActiveFilters ?? false);

    return GestureDetector(
      onTap: _openSearchDialog,
      child: Container(
        width: 40,
        height: 40,
        margin: widget.iconMargin ?? const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: AppColors.THEME_COLOR,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            const Icon(Icons.tune, color: AppColors.WHITE, size: 20),
            if (hasFilters && count > 0)
              Positioned(
                top: 2,
                right: 2,
                child: Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: const BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 15,
                    minHeight: 15,
                  ),
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.BLACK,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      height: 1,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldTrigger() {
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
            const Icon(Icons.select_all_rounded, color: AppColors.THEME_COLOR),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactTrigger() {
    final selectedCategory = widget.categories
        .cast<models.Category?>()
        .firstWhere(
          (category) => category?.name == widget.selectedCategoryName,
          orElse: () => null,
        );

    final bool isAllCategories =
        widget.selectedCategoryName == null ||
        widget.selectedCategoryName!.isEmpty;

    return GestureDetector(
      onTap: _openSearchDialog,
      child: Container(
        height: 52,
        padding: const EdgeInsets.only(left: 8, right: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.GREY_SHADE_300),
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              height: 40,
              width: 40,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.GREY_SHADE_100,
                borderRadius: BorderRadius.circular(9),
              ),
              child:
                  !isAllCategories &&
                          selectedCategory != null &&
                          selectedCategory.imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                        imageUrl: selectedCategory.imageUrl,
                        fit: BoxFit.contain,
                      )
                      : Icon(
                        Icons.grid_view_rounded,
                        size: 20,
                        color: AppColors.THEME_COLOR,
                      ),
            ),

            const SizedBox(width: 10),

            Expanded(
              child: Text(
                isAllCategories
                    ? "All Categories"
                    : widget.selectedCategoryName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.w600,
                  color: AppColors.BLACK,
                ),
              ),
            ),

            Container(
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
          ],
        ),
      ),
    );
  }

  Future<void> _showFilterSheet() async {
    ListingFilterOptions current =
        widget.filterOptions ?? const ListingFilterOptions();

    final double sheetHeight = MediaQuery.of(context).size.height * 0.72;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: sheetHeight,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                children: [
                  // Drag Handle
                  const SizedBox(height: 12),
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 16, 10),
                    child: SizedBox(
                      height: 40,
                      child: Row(
                        children: [
                          const Text(
                            "Filters",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppColors.BLACK,
                            ),
                          ),
                          if (current.activeFilterCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.THEME_COLOR.withOpacity(0.06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${current.activeFilterCount} active",
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.THEME_COLOR,
                                ),
                              ),
                            ),
                          ],
                          const Spacer(),
                          if (current.hasActiveFilters)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: GestureDetector(
                                onTap: () {
                                  setSheetState(() {
                                    current = const ListingFilterOptions();
                                  });
                                },
                                child: const Text(
                                  "Reset All",
                                  style: TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          InkWell(
                            borderRadius: BorderRadius.circular(50),
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),

                  // Scrollable content
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                      children: [
                        // 1. Sort By Section
                        _buildFilterSectionTitle("Sort By"),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildFilterChip(
                              label: "Relevance",
                              icon: Icons.auto_awesome_rounded,
                              isSelected: current.sortBy == 'relevance',
                              onTap: () {
                                setSheetState(() {
                                  current = current.copyWith(
                                    sortBy: 'relevance',
                                  );
                                });
                              },
                            ),
                            _buildFilterChip(
                              label: "Highest Rated",
                              icon: Icons.star_rounded,
                              isSelected: current.sortBy == 'rating',
                              onTap: () {
                                setSheetState(() {
                                  current = current.copyWith(sortBy: 'rating');
                                });
                              },
                            ),
                            _buildFilterChip(
                              label: "Nearest First",
                              icon: Icons.near_me_rounded,
                              isSelected: current.sortBy == 'distance',
                              onTap: () {
                                setSheetState(() {
                                  current = current.copyWith(
                                    sortBy: 'distance',
                                  );
                                });
                              },
                            ),
                            _buildFilterChip(
                              label: "Most Popular",
                              icon: Icons.local_fire_department_rounded,
                              isSelected: current.sortBy == 'popular',
                              onTap: () {
                                setSheetState(() {
                                  current = current.copyWith(sortBy: 'popular');
                                });
                              },
                            ),
                            _buildFilterChip(
                              label: "Newest First",
                              icon: Icons.schedule_rounded,
                              isSelected: current.sortBy == 'newest',
                              onTap: () {
                                setSheetState(() {
                                  current = current.copyWith(sortBy: 'newest');
                                });
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // 2. Minimum Rating Section
                        _buildFilterSectionTitle("Minimum Rating"),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildFilterChip(
                              label: "Any Rating",
                              isSelected: current.minRating == null,
                              onTap: () {
                                setSheetState(() {
                                  current = current.copyWith(
                                    clearMinRating: true,
                                  );
                                });
                              },
                            ),
                            _buildFilterChip(
                              label: "★ 3.0+",
                              isSelected: current.minRating == 3.0,
                              onTap: () {
                                setSheetState(() {
                                  current = current.copyWith(minRating: 3.0);
                                });
                              },
                            ),
                            _buildFilterChip(
                              label: "★ 4.0+",
                              isSelected: current.minRating == 4.0,
                              onTap: () {
                                setSheetState(() {
                                  current = current.copyWith(minRating: 4.0);
                                });
                              },
                            ),
                            _buildFilterChip(
                              label: "★ 4.5+",
                              isSelected: current.minRating == 4.5,
                              onTap: () {
                                setSheetState(() {
                                  current = current.copyWith(minRating: 4.5);
                                });
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // 3. Distance Radius Section
                        _buildFilterSectionTitle("Distance Radius"),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildFilterChip(
                              label: "Any Distance",
                              isSelected: current.maxDistanceKm == null,
                              onTap: () {
                                setSheetState(() {
                                  current = current.copyWith(
                                    clearMaxDistanceKm: true,
                                  );
                                });
                              },
                            ),
                            _buildFilterChip(
                              label: "Less than 2 km",
                              isSelected: current.maxDistanceKm == 2.0,
                              onTap: () {
                                setSheetState(() {
                                  current = current.copyWith(
                                    maxDistanceKm: 2.0,
                                  );
                                });
                              },
                            ),
                            _buildFilterChip(
                              label: "Less than 5 km",
                              isSelected: current.maxDistanceKm == 5.0,
                              onTap: () {
                                setSheetState(() {
                                  current = current.copyWith(
                                    maxDistanceKm: 5.0,
                                  );
                                });
                              },
                            ),
                            _buildFilterChip(
                              label: "Less than 10 km",
                              isSelected: current.maxDistanceKm == 10.0,
                              onTap: () {
                                setSheetState(() {
                                  current = current.copyWith(
                                    maxDistanceKm: 10.0,
                                  );
                                });
                              },
                            ),
                            _buildFilterChip(
                              label: "Less than 25 km",
                              isSelected: current.maxDistanceKm == 25.0,
                              onTap: () {
                                setSheetState(() {
                                  current = current.copyWith(
                                    maxDistanceKm: 25.0,
                                  );
                                });
                              },
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // 4. Quick Toggles / Preferences
                        _buildFilterSectionTitle("Preferences"),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _buildToggleCard(
                                title: "Open Now",
                                icon: Icons.access_time_filled_rounded,
                                activeColor: Colors.green,
                                isActive: current.openNowOnly,
                                onTap: () {
                                  setSheetState(() {
                                    current = current.copyWith(
                                      openNowOnly: !current.openNowOnly,
                                    );
                                  });
                                },
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _buildToggleCard(
                                title: "Online Payments",
                                icon: Icons.payments_rounded,
                                activeColor: AppColors.THEME_COLOR,
                                isActive: current.acceptsOnlinePayment,
                                onTap: () {
                                  setSheetState(() {
                                    current = current.copyWith(
                                      acceptsOnlinePayment:
                                          !current.acceptsOnlinePayment,
                                    );
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Sticky Footer
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 10,
                          offset: const Offset(0, -3),
                        ),
                      ],
                    ),
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.THEME_COLOR,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onFilterApplied?.call(current);
                          },
                          child: Text(
                            current.activeFilterCount > 0
                                ? "Apply Filters (${current.activeFilterCount})"
                                : "Apply Filters",
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.BLACK_54,
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    IconData? icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppColors.THEME_COLOR.withOpacity(0.05)
                  : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? Colors.transparent : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 17,
                color:
                    isSelected ? AppColors.THEME_COLOR : Colors.grey.shade700,
              ),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.BLACK,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleCard({
    required String title,
    required IconData icon,
    required Color activeColor,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color:
              isActive
                  ? AppColors.THEME_COLOR.withOpacity(0.05)
                  : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? Colors.transparent : Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? AppColors.THEME_COLOR : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.BLACK,
                ),
              ),
            ),
            Icon(
              isActive ? Icons.check_circle_rounded : Icons.circle_outlined,
              size: 18,
              color: isActive ? AppColors.THEME_COLOR : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
