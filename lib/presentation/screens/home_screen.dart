import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/home_model.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/presentation/common_methods/common_methods.dart';
import 'package:startup_20/presentation/common_widgets/common_widgets.dart';
import 'package:startup_20/presentation/screens/listing_screen.dart';
import 'package:startup_20/presentation/screens/search_screen.dart';
import 'package:startup_20/providers/bottom_nav_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<HomeModel> _homeFuture;
  late Future<List<Listing>> _featuredListings;
  late Future<List<Listing>> _recommendedListings;
  List<Listing> listings = [];

  int _currentBanner = 0;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _handleScroll();
    _homeFuture = fetchHomeData();
    _featuredListings = fetchFeaturedListings();
    _recommendedListings = fetchRecommendedListings();
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

  Future<List<Listing>> fetchFeaturedListings() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection("listings")
            .where("tags", arrayContains: "featured")
            .orderBy("createdAt", descending: true) // optional, latest first
            .get();

    return snapshot.docs.map((doc) => Listing.fromJson(doc.data())).toList();
  }

  Future<List<Listing>> fetchRecommendedListings() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection("listings")
            .where("tags", arrayContains: "recommended")
            .orderBy("createdAt", descending: true) // optional, latest first
            .get();

    return snapshot.docs.map((doc) => Listing.fromJson(doc.data())).toList();
  }

  // 🔹 Fetch Firestore HomeScreen Data

  Future<HomeModel> fetchHomeData() async {
    final querySnapshot =
        await FirebaseFirestore.instance
            .collection("home")
            .where("active", isEqualTo: true)
            .limit(1)
            .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception("No active home document found");
    }

    final doc = querySnapshot.docs.first;
    final data = doc.data();

    // ✅ Step 1: Get categories from home doc
    List<String> categories = List<String>.from(data["listings"] ?? []);

    // ✅ Step 2: Fetch listings matching categories
    if (categories.isNotEmpty) {
      final listingsQuery =
          await FirebaseFirestore.instance
              .collection("listings")
              .where("category", whereIn: categories)
              .get();

      listings =
          listingsQuery.docs.map((e) => Listing.fromJson(e.data())).toList();
    }

    return HomeModel.fromJson(doc.data());
  }

  /// Sample Data Generator
  Future<void> generateSampleListings() async {
    final firestore = FirebaseFirestore.instance;
    final random = Random();
    // 🔹 Define 10 categories
    final categories = [
      "Restaurant",
      "Electrician",
      "Plumber",
      "Grocery",
      "Doctor",
      "Salon",
      "Gym",
      "Pharmacy",
      "Cafe",
      "Mechanic",
    ];

    // 🔹 For each category, create 10 sample listings
    for (final category in categories) {
      for (int i = 1; i <= 10; i++) {
        final docRef = firestore.collection("listings").doc();

        final data = {
          "listingId": docRef.id,
          "contributionId": "contrib_${category}_$i",
          "name": "$category Service $i",
          "address": "123 Main Street, City $i",
          "description": "Best $category service in town #$i",
          "geo": {"lat": 37.7749 + (i * 0.001), "lng": -122.4194 + (i * 0.001)},
          "phone": "+91 98765432$i",
          "category": category,
          "tags": ["$category", "Service", "Demo"],
          "addedBy": "system_admin",
          "isClaimed": false,
          "ownerId": null,
          "claimStatus": "unclaimed",
          "verifiedBy": null,
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
          "reviews": random.nextInt(500),
          "rating": double.parse(
            (1 + random.nextDouble() * 4).toStringAsFixed(
              1,
            ), // ensures 1.0 → 5.0 with 1 decimal
          ),
          "images": [
            {
              "fileId": "file_${category}_$i-1",
              "fullUrl": "https://picsum.photos/200",
              "thumbUrl": "https://picsum.photos/200",
            },
            {
              "fileId": "file_${category}_$i-2",
              "fullUrl": "https://picsum.photos/200",
              "thumbUrl": "https://picsum.photos/200",
            },
          ],
        };

        // 🔹 Write to Firestore
        await docRef.set(data);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.GREY_SHADE_50,
      body: FutureBuilder<HomeModel>(
        future: _homeFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return CommonWidgets.shimmerHomeScreen();
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData) {
            return const Center(child: Text("No data found"));
          }

          final homeData = snapshot.data!;

          return CustomScrollView(
            controller: _scrollController,
            slivers: [
              // 🔹 Top Bar + Location Selector
              CommonWidgets.topSection(context),

              // 🔹 Pinned Search Bar
              SliverPersistentHeader(
                pinned: true,
                delegate: SearchBarHeader(child: CommonWidgets.searchBar()),
              ),

              // 🔹 Scrollable Content
              SliverPadding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _promoBanner(homeData.promoBanners),
                    const SizedBox(height: 8),
                    _dotsIndicator(homeData.promoBanners),
                    const SizedBox(height: 20),
                    _headings('Popular Categories'),
                    const SizedBox(height: 12),
                    _categoriesTab(homeData.categories),
                    const SizedBox(height: 20),
                    Container(
                      padding: EdgeInsets.only(bottom: 30, top: 20),
                      color: AppColors.GREY_SHADE_300,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _featuredAdsHeading(),
                          const SizedBox(height: 12),
                          FutureBuilder<List<Listing>>(
                            future: _featuredListings,
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }
                              if (snapshot.hasError) {
                                return Text("Error: ${snapshot.error}");
                              }
                              final featuredListings = snapshot.data ?? [];

                              if (featuredListings.isEmpty) {
                                return const Text(
                                  "No featured listings available",
                                );
                              }

                              return _featuredAds(featuredListings);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _headings('Recommended'),
                    const SizedBox(height: 20),
                    FutureBuilder<List<Listing>>(
                      future: _recommendedListings,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: 6,
                            padding: const EdgeInsets.symmetric(horizontal: 15),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 3 / 3.9,
                                ),
                            itemBuilder:
                                (context, index) =>
                                    CommonWidgets.shimmerlistingCard(),
                          );
                        }
                        if (snapshot.hasError) {
                          return Text("Error: ${snapshot.error}");
                        }

                        final featuredListings = snapshot.data ?? [];

                        if (featuredListings.isEmpty) {
                          return const Text(
                            "No recommended listings available",
                          );
                        }

                        return _listingsData(featuredListings);
                      },
                    ),
                    const SizedBox(height: 20),
                    _bannerData(homeData.banners[0]),

                    for (
                      int index = 0;
                      index < homeData.listings.length;
                      index++
                    ) ...[
                      const SizedBox(height: 20),
                      _headings(homeData.listings[index]),
                      const SizedBox(height: 20),
                      _listingsData(
                        (listings
                                .where(
                                  (listing) =>
                                      listing.category ==
                                      homeData.listings[index],
                                )
                                .toList()
                              ..sort((a, b) => b.rating.compareTo(a.rating)))
                            .take(6)
                            .toList(),
                      ),
                      const SizedBox(height: 20),
                      _bannerData(homeData.banners[0]),
                    ],
                  ]),
                ),
              ),

              //Footer tagline outside padding, full width
              SliverToBoxAdapter(child: CommonWidgets.footerTagline()),
            ],
          );
        },
      ),
    );
  }

  Widget _promoBanner(List<dynamic> promoBanners) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: CarouselSlider.builder(
        itemCount: promoBanners.length,
        itemBuilder: (context, index, realIndex) {
          final imageUrl = promoBanners[index];
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              width: double.infinity,
              fit: BoxFit.cover,
              placeholder: (context, url) {
                return Shimmer.fromColors(
                  baseColor: AppColors.GREY_SHADE_300,
                  highlightColor: AppColors.GREY_SHADE_100,
                  child: Container(
                    width: double.infinity,
                    height: 180,
                    color: Colors.white,
                  ),
                );
              },
              errorWidget:
                  (context, url, error) => Container(
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.image, color: Colors.grey),
                  ),
            ),
          );
        },
        options: CarouselOptions(
          height: 180,
          autoPlay: true,
          enlargeCenterPage: true,
          viewportFraction: 1,
          aspectRatio: 16 / 6,
          onPageChanged: (index, reason) {
            setState(() {
              _currentBanner = index;
            });
          },
        ),
      ),
    );
  }

  Widget _dotsIndicator(List<dynamic> promoBanners) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children:
          promoBanners.asMap().entries.map((entry) {
            return Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    _currentBanner == entry.key
                        ? AppColors.THEME_COLOR
                        : AppColors.GREY_SHADE_300,
              ),
            );
          }).toList(),
    );
  }

  Widget _headings(String heading) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            heading,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          GestureDetector(
            onTap: () {
              if (heading == 'Popular Categories') {
                Provider.of<BottomNavProvider>(
                  context,
                  listen: false,
                ).setIndex(1);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ListingPage(title: heading),
                  ),
                );
              }
            },
            child: const Text(
              "See All >",
              style: TextStyle(color: AppColors.THEME_COLOR),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoriesTab(List<dynamic> categories) {
    return GridView.builder(
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
                builder: (context) => ListingPage(title: category.category),
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
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10), // match container
                  child: CachedNetworkImage(
                    imageUrl:
                        category.imageUrl, // 🔹 replace with your image URL
                    fit: BoxFit.cover,

                    placeholder: (context, url) {
                      return Shimmer.fromColors(
                        baseColor: AppColors.GREY_SHADE_300,
                        highlightColor: AppColors.GREY_SHADE_100,
                        child: Container(
                          width: 60,
                          height: 60,
                          color: Colors.white,
                        ),
                      );
                    },
                    errorWidget:
                        (context, url, error) => const Icon(
                          Icons.broken_image,
                          color: Colors.grey,
                          size: 28,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                category.category,
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
    );
  }

  Widget _featuredAdsHeading() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: const [
          Text(
            "Featured Ads",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _featuredAds(List<Listing> listings) {
    return SizedBox(
      height: 150,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: listings.length,
        itemBuilder: (context, index) {
          final listing = listings[index];
          return GestureDetector(
            onTap: () {
              CommonMethods.navigateToListingDetailScreen(context, listing, listings);
            },
            child: Container(
              width: 280,
              margin: const EdgeInsets.only(left: 5, right: 8),
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.WHITE,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.GREY_SHADE_300, width: 1),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 🔹 Left Side Image
                  ClipRRect(
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(16),
                    ),
                    child: CachedNetworkImage(
                      imageUrl:
                          listing.images.isNotEmpty
                              ? listing.images.first.thumbUrl
                              : "https://firebasestorage.googleapis.com/v0/b/startup20-5eaa7.firebasestorage.app/o/static%2FImage_Placeholder.jpg?alt=media&token=22a0ec73-6352-4885-bfaf-c485750af28f",
            
                      placeholder: (context, url) {
                        return Shimmer.fromColors(
                          baseColor: Colors.grey.shade300,
                          highlightColor: Colors.grey.shade100,
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: Colors.white,
                          ),
                        );
                      },
            
                      errorWidget:
                          (context, url, error) => Container(
                            color: Colors.grey.shade300,
                            child: const Icon(Icons.image, color: Colors.grey),
                          ),
                      width: 140,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  ),
            
                  // 🔹 Right Side Details
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            listing.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            listing.category,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.GREY,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: AppColors.THEME_COLOR,
                                size: 16,
                              ),
                              Text(
                                "${listing.rating} (${listing.reviews})",
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _listingsData(List<Listing> listings) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: listings.length,
      padding: const EdgeInsets.symmetric(horizontal: 15),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 3 / 3.8,
      ),
      itemBuilder: (context, index) {
        final listing = listings[index];

        return GestureDetector(
          onTap: () {
            CommonMethods.navigateToListingDetailScreen(context, listing, listings);
          },
          child: CommonWidgets.listingCard(listing),
        );
      },
    );
  }

  Widget _bannerData(String imageLink) {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      height: 250,
      color: AppColors.GREY_SHADE_300,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: CachedNetworkImage(
          imageUrl: imageLink,
          fit: BoxFit.cover,

          placeholder: (context, url) {
            return Shimmer.fromColors(
              baseColor: Colors.grey.shade300,
              highlightColor: Colors.grey.shade100,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: Colors.white,
              ),
            );
          },

          errorWidget:
              (context, url, error) => Container(
                color: Colors.grey.shade300,
                child: const Icon(Icons.image, color: Colors.grey),
              ),
        ),
      ),
    );
  }
}

class SearchBarHeader extends SliverPersistentHeaderDelegate {
  final Widget child;
  SearchBarHeader({required this.child});

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.WHITE, // keeps background same
        border: Border(
          bottom: BorderSide(
            color: AppColors.GREY_SHADE_300, // line color
            width: 1.0, // line thickness
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: 10, right: 10, top: 5, bottom: 20),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SearchScreen()),
          );
        },
        child: child,
      ),
    );
  }

  @override
  double get maxExtent => 80; // fixed height
  @override
  double get minExtent => 80; // fixed height

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      false;
}
