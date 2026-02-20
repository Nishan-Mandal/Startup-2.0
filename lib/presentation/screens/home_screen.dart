import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/home_model.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/presentation/common_methods/cached_network_svg.dart';
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
  late Future<List<Listing>> _newAddedListings;
  late Future<List<Listing>> _recommendedListings;
  List<Listing> listings = [];

  int _currentBanner = 0;

  @override
  void initState() {
    super.initState();
    _homeFuture = fetchHomeData();
    _featuredListings = fetchFeaturedListings();
    _newAddedListings = fetchNewListings();
    _recommendedListings = fetchRecommendedListings();
  }

  Future<List<Listing>> fetchFeaturedListings() async {
    Future<List<Listing>> featuredListings = fetchListingsByTag("featured");
    return featuredListings;
  }

  Future<List<Listing>> fetchNewListings() async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection("listings")
            .where("verifiedBy", isNull: false)
            .orderBy("createdAt", descending: true)
            .limit(8)
            .get();

    return snapshot.docs.map((doc) => Listing.fromJson(doc.data())).toList();
  }

  Future<List<Listing>> fetchRecommendedListings() async {
    Future<List<Listing>> recommendedListings = fetchListingsByTag(
      "recommended",
    );
    return recommendedListings;
  }

  Future<List<Listing>> fetchListingsByTag(String tag) async {
    final snapshot =
        await FirebaseFirestore.instance
            .collection("listings")
            .where("tags", arrayContains: tag)
            .where("verifiedBy", isNull: false)
            .orderBy("createdAt", descending: true)
            .limit(8)
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
              .where("verifiedBy", isNull: false)
              .get();

      listings =
          listingsQuery.docs.map((e) => Listing.fromJson(e.data())).toList();
    }

    return HomeModel.fromJson(doc.data());
  }

  List<Listing> listingsByCategory(String category) {
    return listings.where((l) => l.category == category).toList()
      ..sort((a, b) => b.rating.compareTo(a.rating));
  }

  List<Widget> categorySectionSlivers(HomeModel homeData, int index) {
    final categoryName = homeData.listings[index];
    debugPrint(categoryName);
    final categoryListings = listingsByCategory(categoryName);

    if (categoryListings.isEmpty) return [];

    return [
      // 🔹 Banner
      sectionBanner(homeData, index),

      // 🔹 Category Heading
      SliverToBoxAdapter(child: _headings(categoryName)),
      const SliverToBoxAdapter(child: SizedBox(height: 20)),

      // 🔹 Listings Grid
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 15),
        sliver: SliverGrid(
          delegate: SliverChildBuilderDelegate((context, i) {
            final listing = categoryListings[i];
            return GestureDetector(
              onTap: () {
                CommonMethods.navigateToListingDetailScreen(
                  context,
                  listing,
                  categoryListings,
                );
              },
              child: CommonWidgets.listingCard(listing),
            );
          }, childCount: categoryListings.take(6).length),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 3 / 3.8,
          ),
        ),
      ),
    ];
  }

  SliverToBoxAdapter sectionBanner(HomeModel homeData, int index) {
    if (homeData.banners.length <= index) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: _bannerData(homeData.banners[index].imageUrl),
      ),
    );
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
            slivers: [
              CommonWidgets.topSection(context),

              SliverPersistentHeader(
                pinned: true,
                delegate: SearchBarHeader(child: CommonWidgets.searchBar()),
              ),

              SliverToBoxAdapter(child: const SizedBox(height: 10)),

              /// Promo banner
              SliverToBoxAdapter(child: _promoBanner(homeData.promoBanners)),

              SliverToBoxAdapter(child: const SizedBox(height: 8)),

              SliverToBoxAdapter(child: _dotsIndicator(homeData.promoBanners)),

              SliverToBoxAdapter(child: const SizedBox(height: 20)),

              SliverToBoxAdapter(child: _headings('Popular Categories')),

              SliverToBoxAdapter(child: const SizedBox(height: 12)),

              ///SliverGrid directly (NO wrapper widget)
              _categoriesTab(homeData.categories),

              SliverToBoxAdapter(child: const SizedBox(height: 20)),

              /// Featured ads section
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.only(bottom: 30, top: 20),
                  color: AppColors.BLACK_12,
                  child: Column(
                    children: [
                      _featuredAdsHeading(),
                      const SizedBox(height: 12),
                      FutureBuilder<List<Listing>>(
                        future: _featuredListings,
                        builder: (context, snapshot) {
                          if (!snapshot.hasData) {
                            return const CircularProgressIndicator();
                          }
                          if (snapshot.data!.isEmpty) {
                            return const Text("No featured listings available");
                          }

                          return _featuredAds(snapshot.data!);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(child: const SizedBox(height: 20)),
              SliverToBoxAdapter(child: _headings('Newly Added')),

              SliverToBoxAdapter(child: const SizedBox(height: 20)),
              listingsSliver(_newAddedListings),

              SliverToBoxAdapter(child: const SizedBox(height: 20)),
              SliverToBoxAdapter(child: _headings('Recommended')),

              SliverToBoxAdapter(child: const SizedBox(height: 20)),
              listingsSliver(_recommendedListings),

              for (int i = 0; i < homeData.listings.length; i++) ...[
                ...categorySectionSlivers(homeData, i),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],

              SliverToBoxAdapter(child: const SizedBox(height: 20)),
              SliverToBoxAdapter(child: CommonWidgets.footerTagline()),
            ],
          );
        },
      ),
    );
  }

  Widget _bannerData(String imageLink) {
    return Container(
      // padding: const EdgeInsets.symmetric(vertical: ),
      width: double.infinity,
      height: 250,
      color: AppColors.GREY_SHADE_300,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(0),
        child: CachedNetworkImage(
          imageUrl: imageLink,
          fit: BoxFit.cover,

          placeholder: (context, url) {
            return Shimmer.fromColors(
              baseColor: AppColors.GREY_SHADE_300,
              highlightColor: AppColors.GREY_SHADE_100,
              child: Container(
                width: double.infinity,
                height: double.infinity,
                color: AppColors.WHITE,
              ),
            );
          },

          errorWidget:
              (context, url, error) => Container(
                color: AppColors.GREY_SHADE_300,
                child: const Icon(Icons.image, color: AppColors.GREY),
              ),
        ),
      ),
    );
  }

  Widget _promoBanner(List<BannerModel> promoBanners) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: CarouselSlider.builder(
        itemCount: promoBanners.length,
        itemBuilder: (context, index, realIndex) {
          final imageUrl = promoBanners[index].imageUrl;
          return GestureDetector(
            onTap: () {
              final route = promoBanners[index].route;
              if (route.isNotEmpty) {
                // Check if the route is a listing detail route
                if (route.startsWith('/listing/')) {
                  final listingId = route.split('/').last; // extract '001'
                  Navigator.pushNamed(context, '/listing/$listingId');
                } else {
                  // Navigate to any other route directly
                  Navigator.pushNamed(context, route);
                }
              }
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                fadeInDuration: Duration.zero,
                fadeOutDuration: Duration.zero,
                placeholder: (context, url) {
                  return Container(color: AppColors.GREY_SHADE_100);
                },
                errorWidget:
                    (context, url, error) => Container(
                      color: AppColors.GREY_SHADE_300,
                      child: const Icon(Icons.image, color: AppColors.GREY),
                    ),
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
              } else if (heading == 'Newly Added') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ListingPage(
                          title: heading,
                          query: FirebaseFirestore.instance
                              .collection("listings")
                              .where("verifiedBy", isNull: false)
                              .orderBy("createdAt", descending: true),
                        ),
                  ),
                );
              } else if (heading == 'Recommended') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ListingPage(
                          title: heading,
                          query: FirebaseFirestore.instance
                              .collection("listings")
                              .where("tags", arrayContains: "recommended")
                              .where("verifiedBy", isNull: false)
                              .orderBy("createdAt", descending: true),
                        ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) => ListingPage(
                          title: heading,
                          query: FirebaseFirestore.instance
                              .collection("listings")
                              .where("category", isEqualTo: heading)
                              .where("verifiedBy", isNull: false)
                              .orderBy("createdAt", descending: true),
                        ),
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
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 0.8,
        ),
        delegate: SliverChildBuilderDelegate(childCount: categories.length, (
          context,
          index,
        ) {
          final category = categories[index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => ListingPage(
                        title: category.category,
                        query: FirebaseFirestore.instance
                            .collection("listings")
                            .where("category", isEqualTo: category.category)
                            .where("verifiedBy", isNull: false)
                            .orderBy("createdAt", descending: true),
                      ),
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
                    child: CachedNetworkSvg(
                      url: category.imageUrl,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                      placeholder: Container(color: AppColors.GREY_SHADE_100),
                      errorWidget: const Icon(Icons.broken_image),
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
        }),
      ),
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
              CommonMethods.navigateToListingDetailScreen(
                context,
                listing,
                listings,
              );
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
                          baseColor: AppColors.GREY_SHADE_300,
                          highlightColor: AppColors.GREY_SHADE_100,
                          child: Container(
                            width: double.infinity,
                            height: double.infinity,
                            color: AppColors.WHITE,
                          ),
                        );
                      },

                      errorWidget:
                          (context, url, error) => Container(
                            color: AppColors.GREY_SHADE_300,
                            child: const Icon(
                              Icons.image,
                              color: AppColors.GREY,
                            ),
                          ),
                      width: 140,
                      height: 180,
                      fit: BoxFit.cover,
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                    ),
                  ),

                  // 🔹 Right Side Details
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.THEME_COLOR,
                              borderRadius: BorderRadius.circular(1),
                            ),
                            child: const Text(
                              "Featured",
                              style: TextStyle(
                                color: AppColors.WHITE,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
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
                          Text(
                            listing.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),

                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 14,
                                color: AppColors.GREY,
                              ),
                              Expanded(
                                child: Text(
                                  listing.address,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.GREY,
                                  ),
                                  maxLines: 1, // show only 1 line
                                  overflow:
                                      TextOverflow
                                          .ellipsis, // adds "..." if text too long
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.star,
                                color: AppColors.AMBER,
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

  Widget listingsSliver(Future<List<Listing>> future) {
    return FutureBuilder<List<Listing>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 15),
            sliver: SliverGrid(
              delegate: SliverChildBuilderDelegate(
                (context, index) => CommonWidgets.shimmerlistingCard(),
                childCount: 6,
              ),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 3 / 3.8,
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: Text("No listings found")),
            ),
          );
        }

        final listings = snapshot.data!;

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          sliver: SliverGrid(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final listing = listings[index];
                return GestureDetector(
                  onTap: () {
                    CommonMethods.navigateToListingDetailScreen(
                      context,
                      listing,
                      listings,
                    );
                  },
                  child: CommonWidgets.listingCard(listing),
                );
              },
              childCount: listings.length, // ✅ SAFE
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 3 / 3.8,
            ),
          ),
        );
      },
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
    // 🔹 Determine how far the header has shrunk (0 → fully visible, 1 → pinned)
    final t = (shrinkOffset / maxExtent).clamp(0.0, 1.0);

    // 🔹 Interpolate between two gradients
    final Color base = AppColors.THEME_COLOR;

    final Color startColor =
        Color.lerp(
          base.withValues(alpha: 0.5), // instead of withOpacity(0.7)
          base,
          t,
        )!;

    final Color endColor =
        Color.lerp(
          base.withValues(alpha: 0.2),
          base.withValues(alpha: 0.8),
          t,
        )!;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [startColor, endColor],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1.0),
        ),
      ),
      padding: const EdgeInsets.only(left: 10, right: 10, top: 5, bottom: 20),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SearchScreen()),
          );
        },
        child: child,
      ),
    );
  }

  @override
  double get maxExtent => 80;
  @override
  double get minExtent => 80;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) =>
      true;
}
