import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/category_model.dart';
import 'package:startup_20/presentation/common_methods/cached_network_svg.dart';
import 'package:startup_20/presentation/common_widgets/common_widgets.dart';
import 'package:startup_20/presentation/screens/home_screen.dart';
import 'package:startup_20/presentation/screens/listing_screen.dart';
import 'package:startup_20/providers/bottom_nav_provider.dart';

class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key});

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late ScrollController _scrollController;
  late Future<List<Category>> _categoriesFuture; // cache the future

  @override
  void initState() {
    super.initState();
    _handleScroll();
    _categoriesFuture = _fetchCategories();
  }

  void _handleScroll() {
    _scrollController = ScrollController();

    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        Provider.of<BottomNavProvider>(context, listen: false).hideNavBar();
      } else if (_scrollController.position.userScrollDirection ==
          ScrollDirection.forward) {
        Provider.of<BottomNavProvider>(context, listen: false).showNavBar();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 🔹 Fetch categories from Firestore
  Future<List<Category>> _fetchCategories() async {
    final snapshot =
        await FirebaseFirestore.instance.collection("categories").get();

    return snapshot.docs.map((doc) => Category.fromJson(doc.data())).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.GREY_SHADE_50,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 🔹 Top Bar + Location Selector
          CommonWidgets.topSection(context),

          // 🔹 Pinned Search Bar
          SliverPersistentHeader(
            pinned: true,
            delegate: SearchBarHeader(child: CommonWidgets.searchBar()),
          ),

          // 🔹 Fetch & Render Categories
          SliverToBoxAdapter(
            child: FutureBuilder<List<Category>>(
              future: _categoriesFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Column(
                    children: List.generate(
                      3,
                      (index) => shimmerCategoryScreen(itemCount: 8),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text("Error: ${snapshot.error}"),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text("No categories found"),
                  );
                }

                final categories = snapshot.data!;

                // 🔹 Group categories by section
                final Map<String, List<Category>> groupedCategories = {};
                for (var cat in categories) {
                  groupedCategories.putIfAbsent(cat.section, () => []).add(cat);
                }

                // 🔹 Render each section
                return Column(
                  children:
                      groupedCategories.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 5),
                          child: buildCategorySection(entry.key, entry.value),
                        );
                      }).toList(),
                );
              },
            ),
          ),

          // 🔹 Footer tagline
          SliverToBoxAdapter(child: CommonWidgets.footerTagline()),
        ],
      ),
    );
  }

  Widget buildCategorySection(String title, List<Category> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔹 Section Heading
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),

        // 🔹 Grid
        GridView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.65, // slightly taller to fit 2-line text
          ),
          itemBuilder: (context, index) {
            final category = categories[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ListingPage(
                          title: category.name,
                          query: FirebaseFirestore.instance
                              .collection("listings")
                              .where("category", isEqualTo: category.name)
                              .orderBy("createdAt", descending: true),
                        ),
                  ),
                );
              },
              child: Column(
                children: [
                  Container(
                    height: 60,
                    width: 60,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.WHITE,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.GREY_SHADE_300),
                    ),
                    child:
                        category.imageUrl.isNotEmpty
                            ? CachedNetworkSvg(
                              url: category.imageUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              // show your shimmer while loading
                              placeholder: Shimmer.fromColors(
                                baseColor: AppColors.GREY_SHADE_300,
                                highlightColor: AppColors.GREY_SHADE_100,
                                child: Container(
                                  color: AppColors.GREY_SHADE_300,
                                ),
                              ),
                              errorWidget: const Icon(Icons.broken_image),
                            )
                            // SvgPicture.network(
                            //   category.imageUrl,
                            //   fit: BoxFit.cover,
                            //   width: double.infinity,
                            //   height: double.infinity,
                            //   // show your shimmer while loading
                            //   placeholderBuilder:
                            //       (context) => Shimmer.fromColors(
                            //         baseColor: AppColors.GREY_SHADE_300,
                            //         highlightColor: AppColors.GREY_SHADE_100,
                            //         child: Container(
                            //           color: AppColors.GREY_SHADE_300,
                            //         ),
                            //       ),
                            // )
                            // CachedNetworkImage(
                            //   imageUrl: category.imageUrl,
                            //   fit: BoxFit.cover,
                            //   placeholder:
                            //       (context, url) => Shimmer.fromColors(
                            //         baseColor: AppColors.GREY_SHADE_300,
                            //         highlightColor: AppColors.GREY_SHADE_100,
                            //         child: Container(
                            //           color: AppColors.GREY_SHADE_300,
                            //         ),
                            //       ),
                            //   errorWidget:
                            //       (context, url, error) => const Icon(
                            //         Icons.broken_image,
                            //         color: AppColors.GREY,
                            //       ),
                            // )
                            : const Icon(
                              Icons.image_not_supported,
                              color: AppColors.GREY,
                            ),
                  ),

                  const SizedBox(height: 6),

                  // Flexible to allow 2 lines
                  Flexible(
                    child: Text(
                      category.name,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.BLACK,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  static Widget shimmerCategoryScreen({int itemCount = 8}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 🔹 Heading shimmer
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Shimmer.fromColors(
            baseColor: AppColors.GREY_SHADE_300,
            highlightColor: AppColors.GREY_SHADE_100,
            child: Container(
              height: 16,
              width: 120,
              color: AppColors.GREY_SHADE_300,
            ),
          ),
        ),

        // 🔹 Grid shimmer
        buildGridShimmer(itemCount: itemCount),
      ],
    );
  }

  /// Grid shimmer only
  static Widget buildGridShimmer({int itemCount = 8}) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemBuilder: (context, index) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🔹 Shimmer circle
            Shimmer.fromColors(
              baseColor: AppColors.GREY_SHADE_300,
              highlightColor: AppColors.GREY_SHADE_100,
              child: Container(
                height: 60,
                width: 60,
                decoration: BoxDecoration(
                  color: AppColors.GREY_SHADE_300,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 6),

            // 🔹 Shimmer text
            Shimmer.fromColors(
              baseColor: AppColors.GREY_SHADE_300,
              highlightColor: AppColors.GREY_SHADE_100,
              child: Container(
                height: 12,
                width: 50,
                color: AppColors.GREY_SHADE_300,
              ),
            ),
          ],
        );
      },
    );
  }
}
