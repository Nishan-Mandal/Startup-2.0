import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/category_model.dart' as models;

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

  final FocusNode _searchFocus = FocusNode();

  void _openSearchDialog() async {
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
            const Icon(Icons.select_all_rounded, color: AppColors.THEME_COLOR),
          ],
        ),
      ),
    );
  }
}
