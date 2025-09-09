import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/presentation/common_widgets/common_widgets.dart';
import 'package:startup_20/presentation/screens/category_screen.dart';
import 'package:startup_20/presentation/screens/listing_detail_screen.dart';
import 'package:startup_20/presentation/screens/listing_screen.dart';
import 'package:startup_20/providers/bottom_nav_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentBanner = 0;
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _handleScroll();
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

  final List<Map<String, String>> promoBanners = [
    {
      "title": "TofuNTreat",
      "subtitle": "Order now & get 30% off",
      "image": "https://picsum.photos/seed/picsum/150/150",
    },
    {
      "title": "FreshVeggies",
      "subtitle": "Healthy & Organic",
      "image": "https://picsum.photos/seed/picsum/150/150",
    },
    {
      "title": "Daily Essentials",
      "subtitle": "Discount up to 20%",
      "image": "https://picsum.photos/seed/picsum/150/150",
    },
  ];

  final List<Map<String, dynamic>> categories = [
    {"label": "Water", "icon": Icons.local_drink},
    {"label": "Electrician", "icon": Icons.electrical_services},
    {"label": "Beauty", "icon": Icons.content_cut},
    {"label": "Gas", "icon": Icons.local_gas_station},
    {"label": "Plumber", "icon": Icons.plumbing},
    {"label": "Carpenter", "icon": Icons.chair_alt},
    {"label": "Painter", "icon": Icons.format_paint},
    {"label": "Cleaning", "icon": Icons.cleaning_services},
    // {"label": "Laundry", "icon": Icons.local_laundry_service},
    // {"label": "Groceries", "icon": Icons.shopping_basket},
    // {"label": "Medicines", "icon": Icons.local_hospital},
    // {"label": "Mechanic", "icon": Icons.car_repair},
  ];

  final List<Map<String, dynamic>> services = [
    {
      "title": "JalMate Water",
      "subtitle": "2 Years ago",
      "rating": 4.8,
      "reviews": 200,
      "image": "https://picsum.photos/seed/picsum/500/300",
    },
    {
      "title": "Raj Gas Supply",
      "subtitle": "5 Years ago",
      "rating": 4.5,
      "reviews": 150,
      "image": "https://picsum.photos/seed/picsum/500/300",
    },
    {
      "title": "JalMate Water",
      "subtitle": "2 Years ago",
      "rating": 4.8,
      "reviews": 200,
      "image": "https://picsum.photos/seed/picsum/500/300",
    },
    {
      "title": "Raj Gas Supply",
      "subtitle": "5 Years ago",
      "rating": 4.5,
      "reviews": 150,
      "image": "https://picsum.photos/seed/picsum/500/300",
    },
    {
      "title": "JalMate Water",
      "subtitle": "2 Years ago",
      "rating": 4.8,
      "reviews": 200,
      "image": "https://picsum.photos/seed/picsum/500/300",
    },
    {
      "title": "Raj Gas Supply",
      "subtitle": "5 Years ago",
      "rating": 4.5,
      "reviews": 150,
      "image": "https://picsum.photos/seed/picsum/500/300",
    },
    {
      "title": "JalMate Water",
      "subtitle": "2 Years ago",
      "rating": 4.8,
      "reviews": 200,
      "image": "https://picsum.photos/seed/picsum/500/300",
    },
    {
      "title": "Raj Gas Supply",
      "subtitle": "5 Years ago",
      "rating": 4.5,
      "reviews": 150,
      "image": "https://picsum.photos/seed/picsum/500/300",
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            // 🔹 Top Bar + Location Selector
            CommonWidgets.topSection(context),

            // 🔹 Pinned Search Bar
            SliverPersistentHeader(
              pinned: true,
              delegate: SearchBarHeader(child: _searchBar()),
            ),

            // 🔹 Scrollable Content
            SliverPadding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _promoBanner(),
                  const SizedBox(height: 8),
                  _dotsIndicator(),
                  const SizedBox(height: 20),
                  _headings('Popular Categories', services),
                  const SizedBox(height: 12),
                  _categoriesTab(),
                  const SizedBox(height: 20),
                  Container(
                    padding: EdgeInsets.only(bottom: 30, top: 20),
                    color: Colors.grey.shade100,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _featuredAdsHeading(),
                        const SizedBox(height: 12),
                        _featuredAds(),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _headings("Recommended", services),
                  const SizedBox(height: 20),
                  _listingsData(services),
                  const SizedBox(height: 20),
                  _bannerData(''),
                  const SizedBox(height: 20),
                  _headings("Rentals", services),
                  const SizedBox(height: 20),
                  _listingsData(services),
                  const SizedBox(height: 20),
                  _bannerData(''),
                  const SizedBox(height: 20),
                  _headings("Stores", services),
                  const SizedBox(height: 20),
                  _listingsData(services),
                  const SizedBox(height: 20),
                  _bannerData(''),
                ]),
              ),
            ),
            //Footer tagline outside padding, full width
            SliverToBoxAdapter(child: CommonWidgets.footerTagline()),
          ],
        ),
      ),
    );
  }

  Widget _searchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: "What service do you need?",
        prefixIcon: const Icon(Icons.search),
        suffixIcon: Container(
          margin: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.tune, color: AppColors.white),
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _promoBanner() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15),
      child: CarouselSlider.builder(
        itemCount: promoBanners.length,
        itemBuilder: (context, index, realIndex) {
          final banner = promoBanners[index];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.shade300,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          "Popular",
                          style: TextStyle(color: Colors.black, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        banner["title"]!,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Text(
                      //   banner["subtitle"]!,
                      //   style: const TextStyle(fontSize: 14),
                      // ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text("Order Now"),
                      ),
                    ],
                  ),
                ),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    banner["image"]!,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) => Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey.shade300,
                          child: const Icon(Icons.image, color: Colors.grey),
                        ),
                  ),
                ),
              ],
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

  Widget _dotsIndicator() {
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
                        ? Colors.orange
                        : Colors.grey.shade300,
              ),
            );
          }).toList(),
    );
  }

  Widget _headings(String heading, List<Map<String, dynamic>> listings) {
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
              // Switch to Category tab instead of pushing a new screen
              Provider.of<BottomNavProvider>(
                context,
                listen: false,
              ).setIndex(1);
            },
            child: const Text(
              "See All >",
              style: TextStyle(color: Colors.orange),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoriesTab() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4, // 4 items per row
        mainAxisSpacing: 16, // spacing between rows
        crossAxisSpacing: 16, // spacing between columns
        childAspectRatio: 0.8, // taller cells to fit icon + label
      ),
      itemBuilder: (context, index) {
        final category = categories[index];
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🔹 Icon Box
            Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Icon(category["icon"], color: Colors.black54, size: 28),
            ),
            const SizedBox(height: 6),
            // 🔹 Label outside box
            Text(
              category["label"],
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
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

  Widget _featuredAds() {
    return SizedBox(
      height: 150, // shorter height
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: services.length,
        itemBuilder: (context, index) {
          final service = services[index];
          return Container(
            width: 280, // wider card for rectangular look
            margin: const EdgeInsets.only(left: 5, right: 8),
            padding: EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade300, width: 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 🔹 Left Side Image
                ClipRRect(
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(16),
                  ),
                  child: Image.network(
                    service["image"],
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
                          service["title"],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          service["subtitle"],
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.star,
                              color: Colors.orange,
                              size: 16,
                            ),
                            Text(
                              "${service["rating"]} (${service["reviews"]})",
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
          );
        },
      ),
    );
  }

  Widget _listingsData(List<Map<String, dynamic>> listings) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: listings.length,
      padding: EdgeInsets.symmetric(horizontal: 15),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 3 / 3.5,
      ),
      itemBuilder: (context, index) {
        final service = listings[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder:
                    (context) => ListingDetailScreen(
                      title: "Fruit Shop",
                      location: "City Center, Haldia",
                      rating: 4.5,
                      images: [
                        "https://picsum.photos/200/300",
                        "https://picsum.photos/201/300",
                        "https://picsum.photos/202/300",
                      ],
                      sellerName: "Jone Doe",
                      sellerRole: "Owner",
                      sellerImage: "https://i.pravatar.cc/150?img=3",
                      description:
                          "Passage became common when Letraset revolutionized...",
                      reviews: [
                        Review(text: "Nice shop... love it", rating: 4.0),
                        Review(text: "Great service!", rating: 5.0),
                        Review(text: "Fresh fruits at good price", rating: 4.5),
                      ],
                    ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 6,
                  offset: const Offset(1, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  child: Image.network(
                    service["image"],
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service["title"],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        service["subtitle"],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.star,
                            color: Colors.orange,
                            size: 16,
                          ),
                          Text(
                            "${service["rating"]} (${service["reviews"]})",
                            style: const TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bannerData(String imageLink) {
    return Container(
      padding: EdgeInsets.all(20),
      width: double.infinity,
      height: 250,
      color: Colors.grey.shade100,
      child: Container(
        height: double.infinity,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.orange.shade100,
          borderRadius: BorderRadius.all(Radius.circular(20)),
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
        color: Colors.white, // keeps background same
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.shade300, // line color
            width: 1.0, // line thickness
          ),
        ),
      ),
      padding: const EdgeInsets.only(left: 10, right: 10, top: 5, bottom: 20),
      child: child,
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
