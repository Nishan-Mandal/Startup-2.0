import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/category_model.dart';
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

  @override
  void initState() {
    super.initState();
    _handleScroll();
    // importCategories();
  }

  Future<void> importCategories() async {
    final List<Map<String, dynamic>> categories = [
      {
        "id": "1",
        "name": "Gym",
        "description": "Fitness & training centers",
        "imageUrl":
            "https://firebasestorage.googleapis.com/v0/b/startup20-5eaa7.firebasestorage.app/o/categories%2FElectrician%2FRoom%20Rent%20v1.png?alt=media&token=74973bd6-d121-46fa-b66a-f9798c039b59",
        "tags": ["fitness", "workout", "training"],
        "section": "Health & Fitness",
        "createdAt": DateTime.parse("2025-09-16T10:00:00Z"),
      },
      {
        "id": "2",
        "name": "Electrician",
        "description": "Electrical repair and services",
        "imageUrl":
            "https://firebasestorage.googleapis.com/v0/b/startup20-5eaa7.firebasestorage.app/o/categories%2FElectrician%2FRoom%20Rent%20v1.png?alt=media&token=74973bd6-d121-46fa-b66a-f9798c039b59",
        "tags": ["wiring", "repair", "appliance"],
        "section": "Home Services",
        "createdAt": DateTime.parse("2025-09-16T10:05:00Z"),
      },
      {
        "id": "3",
        "name": "Plumber",
        "description": "Water, drainage, and pipe services",
        "imageUrl":
            "https://firebasestorage.googleapis.com/v0/b/startup20-5eaa7.firebasestorage.app/o/categories%2FElectrician%2FRoom%20Rent%20v1.png?alt=media&token=74973bd6-d121-46fa-b66a-f9798c039b59",
        "tags": ["water", "pipes", "repair"],
        "section": "Home Services",
        "createdAt": DateTime.parse("2025-09-16T10:10:00Z"),
      },
      {
        "id": "4",
        "name": "Doctor",
        "description": "General physicians & specialists",
        "imageUrl":
            "https://firebasestorage.googleapis.com/v0/b/startup20-5eaa7.firebasestorage.app/o/categories%2FElectrician%2FRoom%20Rent%20v1.png?alt=media&token=74973bd6-d121-46fa-b66a-f9798c039b59",
        "tags": ["health", "clinic", "checkup"],
        "section": "Health & Fitness",
        "createdAt": DateTime.parse("2025-09-16T10:15:00Z"),
      },
      {
        "id": "5",
        "name": "Yoga",
        "description": "Yoga classes & meditation centers",
        "imageUrl":
            "https://firebasestorage.googleapis.com/v0/b/startup20-5eaa7.firebasestorage.app/o/categories%2FElectrician%2FRoom%20Rent%20v1.png?alt=media&token=74973bd6-d121-46fa-b66a-f9798c039b59",
        "tags": ["yoga", "wellness", "meditation"],
        "section": "Health & Fitness",
        "createdAt": DateTime.parse("2025-09-16T10:20:00Z"),
      },
      {
        "id": "6",
        "name": "Restaurants",
        "description": "Dine-in & takeaway food services",
        "imageUrl":
            "https://firebasestorage.googleapis.com/v0/b/startup20-5eaa7.firebasestorage.app/o/categories%2FElectrician%2FRoom%20Rent%20v1.png?alt=media&token=74973bd6-d121-46fa-b66a-f9798c039b59",
        "tags": ["food", "dining", "takeaway"],
        "section": "Food & Beverages",
        "createdAt": DateTime.parse("2025-09-16T10:25:00Z"),
      },
      {
        "id": "7",
        "name": "Cafes",
        "description": "Coffee shops & casual eateries",
        "imageUrl":
            "https://firebasestorage.googleapis.com/v0/b/startup20-5eaa7.firebasestorage.app/o/categories%2FElectrician%2FRoom%20Rent%20v1.png?alt=media&token=74973bd6-d121-46fa-b66a-f9798c039b59",
        "tags": ["coffee", "snacks", "casual"],
        "section": "Food & Beverages",
        "createdAt": DateTime.parse("2025-09-16T10:30:00Z"),
      },
      {
        "id": "8",
        "name": "Tutors",
        "description": "Private tutors for different subjects",
        "imageUrl":
            "https://firebasestorage.googleapis.com/v0/b/startup20-5eaa7.firebasestorage.app/o/categories%2FElectrician%2FRoom%20Rent%20v1.png?alt=media&token=74973bd6-d121-46fa-b66a-f9798c039b59",
        "tags": ["education", "learning", "study"],
        "section": "Education",
        "createdAt": DateTime.parse("2025-09-16T10:35:00Z"),
      },
      {
        "id": "9",
        "name": "Music Classes",
        "description": "Learn guitar, piano, and vocals",
        "imageUrl":
            "https://firebasestorage.googleapis.com/v0/b/startup20-5eaa7.firebasestorage.app/o/categories%2FElectrician%2FRoom%20Rent%20v1.png?alt=media&token=74973bd6-d121-46fa-b66a-f9798c039b59",
        "tags": ["music", "guitar", "piano"],
        "section": "Education",
        "createdAt": DateTime.parse("2025-09-16T10:40:00Z"),
      },
      {
        "id": "10",
        "name": "Carpenter",
        "description": "Woodwork and furniture repairs",
        "imageUrl":
            "https://firebasestorage.googleapis.com/v0/b/startup20-5eaa7.firebasestorage.app/o/categories%2FElectrician%2FRoom%20Rent%20v1.png?alt=media&token=74973bd6-d121-46fa-b66a-f9798c039b59",
        "tags": ["furniture", "wood", "repair"],
        "section": "Home Services",
        "createdAt": DateTime.parse("2025-09-16T10:45:00Z"),
      },
    ];

    for (var category in categories) {
      await FirebaseFirestore.instance.collection("categories").doc().set({
        "name": category["name"],
        "description": category["description"],
        "imageUrl": category["imageUrl"],
        "tags": category["tags"],
        "section": category["section"],
        "createdAt": category["createdAt"],
      });
      print("✅ Imported: ${category['name']}");
    }
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
              future: _fetchCategories(),
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
                        return buildCategorySection(entry.key, entry.value);
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),

        // 🔹 Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.8,
          ),
          itemBuilder: (context, index) {
            final category = categories[index];
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ListingPage(title: category.name),
                  ),
                );
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 60,
                    width: 60,
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.WHITE,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.GREY_SHADE_300),
                    ),
                    child:
                        category.imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                              imageUrl: category.imageUrl,
                              fit: BoxFit.cover,
                              placeholder:
                                  (context, url) => Shimmer.fromColors(
                                    baseColor: AppColors.GREY_SHADE_300,
                                    highlightColor: AppColors.GREY_SHADE_100,
                                    child: Container(
                                      color: AppColors.GREY_SHADE_300,
                                    ),
                                  ),
                              errorWidget:
                                  (context, url, error) => const Icon(
                                    Icons.broken_image,
                                    color: AppColors.GREY,
                                  ),
                            )
                            : const Icon(
                              Icons.image_not_supported,
                              color: AppColors.GREY,
                            ),
                  ),

                  const SizedBox(height: 6),
                  Text(
                    category.name,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.BLACK,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
