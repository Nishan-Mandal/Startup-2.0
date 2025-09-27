import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/data/models/category_model.dart';
import 'package:startup_20/presentation/common_methods/common_methods.dart';
import 'package:startup_20/presentation/common_widgets/common_widgets.dart';
import 'package:startup_20/presentation/screens/listing_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  bool isLoading = false;

  String query = "";
  List<String> recentSearches = ["Plumber", "Grocery", "Salon"];

  List<Category> categoryResults = [];
  List<Listing> listingResults = [];

  /// Debounced Search
  void _onSearchChanged(String text) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _search(text.trim());
    });
  }

  /// Firestore Search
  Future<void> _search(String text) async {
    if (text.isEmpty) {
      setState(() {
        isLoading = false;
        query = "";
        categoryResults = [];
        listingResults = [];
      });
      return;
    }
    text = text[0].toUpperCase() + text.substring(1);
    setState(() {
      isLoading = true;
      query = text;
      categoryResults = [];
      listingResults = [];
    });

    try {
      // 🔹 Categories: match by tags
      final categoryByTags =
          await FirebaseFirestore.instance
              .collection("categories")
              .where("tags", arrayContains: text)
              .get();

      // 🔹 Categories: match by name (prefix search)
      final categoryByName =
          await FirebaseFirestore.instance
              .collection("categories")
              .where("name", isGreaterThanOrEqualTo: text)
              .where("name", isLessThan: text + '\uf8ff')
              .get();

      // 🔹 Listings: match by tags
      final listingByTags =
          await FirebaseFirestore.instance
              .collection("listings")
              .where("tags", arrayContains: text)
              .get();

      // 🔹 Listings: match by name (prefix search)
      final listingByName =
          await FirebaseFirestore.instance
              .collection("listings")
              .where("name", isGreaterThanOrEqualTo: text)
              .where("name", isLessThan: text + '\uf8ff')
              .get();

      // ✅ Merge results (avoid duplicates by using a Set of IDs)
      final seenCategoryNames = <String>{};
      final seenListingIds = <String>{};

      final allCategories =
          [...categoryByTags.docs, ...categoryByName.docs]
              .map((doc) => Category.fromJson(doc.data()))
              .where((category) => seenCategoryNames.add(category.name ?? ''))
              .toList();

      final allListings =
          [...listingByTags.docs, ...listingByName.docs]
              .where((doc) => seenListingIds.add(doc.id))
              .map((doc) => Listing.fromJson(doc.data()))
              .toList();

      setState(() {
        categoryResults = allCategories;
        listingResults = allListings;
        isLoading = false;
        // Save to recent searches
        if (!recentSearches.contains(text)) {
          recentSearches.insert(0, text);
          if (recentSearches.length > 10) {
            recentSearches.removeLast();
          }
        }
      });

      debugPrint("Categories: $categoryResults");
      debugPrint("Listings: $listingResults");
    } catch (e) {
      debugPrint("Search error: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.WHITE,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔹 Search Bar
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: "What service do you need?",
                        prefixIcon: IconButton(
                          icon: Icon(Icons.arrow_back),
                          onPressed: () {
                            Navigator.of(context).pop();
                          },
                        ),
                        suffixIcon: Container(
                          margin: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.THEME_COLOR,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.tune, color: AppColors.WHITE),
                        ),
                        filled: true,
                        fillColor: AppColors.GREY_SHADE_100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // 🔹 Recent Searches
              if (recentSearches.isNotEmpty && query.isEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Recent Searches",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.BLACK_54,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children:
                          recentSearches
                              .map(
                                (item) => ActionChip(
                                  label: Text(item),
                                  onPressed: () {
                                    _controller.text = item;
                                    _search(item);
                                  },
                                  backgroundColor: AppColors.GREY_SHADE_100,
                                ),
                              )
                              .toList(),
                    ),
                  ],
                ),

              const SizedBox(height: 16),

              // 🔹 Results
              Expanded(
                child:
                    query.isEmpty
                        ? const Center(
                          child: Text("Type something to start searching..."),
                        )
                        : isLoading
                        ? SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Categories",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.BLACK_54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              ...List.generate(
                                2,
                                (index) => categoryTileLoader(),
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                "Listings",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.BLACK_54,
                                ),
                              ),
                              const SizedBox(height: 10),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: 4,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 0.75,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                                itemBuilder:
                                    (context, index) =>
                                        CommonWidgets.shimmerlistingCard(),
                              ),
                            ],
                          ),
                        )
                        : SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ✅ Categories
                              const Text(
                                "Categories",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.BLACK_54,
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (categoryResults.isEmpty)
                                const Text("No categories found."),
                              ...categoryResults.map((category) {
                                return ListTile(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder:
                                            (context) => ListingPage(
                                              title: category.name,
                                            ),
                                      ),
                                    );
                                  },
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: CachedNetworkImage(
                                      imageUrl: category.imageUrl,
                                      width: 30,
                                      height: 30,
                                      fit: BoxFit.cover,
                                      placeholder:
                                          (context, url) => Container(
                                            width: 30,
                                            height: 30,
                                            color: AppColors.GREY_SHADE_300,
                                          ),
                                      errorWidget:
                                          (context, url, error) => const Icon(
                                            Icons.broken_image,
                                            color: AppColors.GREY,
                                          ),
                                    ),
                                  ),
                                  title: Text(category.name),
                                );
                              }),

                              const SizedBox(height: 20),

                              // ✅ Listings
                              const Text(
                                "Listings",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.BLACK_54,
                                ),
                              ),
                              const SizedBox(height: 10),
                              if (listingResults.isEmpty)
                                const Text("No listings found."),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: listingResults.length,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      childAspectRatio: 0.75,
                                      crossAxisSpacing: 8,
                                      mainAxisSpacing: 8,
                                    ),
                                itemBuilder: (context, index) {
                                  final listing = listingResults[index];
                                  return GestureDetector(
                                    onTap: () {
                                      CommonMethods.navigateToListingDetailScreen(
                                        context,
                                        listing,
                                        [],
                                      );
                                    },
                                    child: CommonWidgets.listingCard(listing),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget categoryTileLoader() {
    return Shimmer.fromColors(
      baseColor: AppColors.GREY_SHADE_300,
      highlightColor: AppColors.GREY_SHADE_100,
      child: ListTile(
        leading: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.GREY_SHADE_300,
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        title: Container(
          height: 14,
          color: AppColors.GREY_SHADE_300,
          margin: const EdgeInsets.symmetric(vertical: 4),
        ),
      ),
    );
  }
}
