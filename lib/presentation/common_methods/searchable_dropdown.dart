import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/category_model.dart' as models;

enum SearchableDropdownStyle { field, compact }

class SearchableDropdown extends StatefulWidget {
  final List<models.Category> categories;

  final Function(String, String) onCategorySelected;

  final String? selectedCategoryName;

  final String? selectedCategoryId;
  final SearchableDropdownStyle style;

  const SearchableDropdown({
    super.key,
    this.style = SearchableDropdownStyle.field,
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

  final FocusNode _searchFocus = FocusNode();

  Future<void> _openSearchDialog() async {
    final result = await _showCategoryPicker();

    if (result != null) {
      widget.onCategorySelected(result['id'] ?? '', result['name'] ?? '');
    }
  }

  Future<Map<String, String>?> _showCategoryPicker() async {
    switch (widget.style) {
      case SearchableDropdownStyle.field:
        return _showFieldCategoryPicker();

      case SearchableDropdownStyle.compact:
        return _showCompactCategoryPicker();
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
      widget.onCategorySelected(result["id"] ?? "", result["name"] ?? "");
    }
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
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close_rounded),
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

  @override
  Widget build(BuildContext context) {
    switch (widget.style) {
      case SearchableDropdownStyle.field:
        return _buildFieldTrigger();

      case SearchableDropdownStyle.compact:
        return _buildCompactTrigger();
    }
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
}
