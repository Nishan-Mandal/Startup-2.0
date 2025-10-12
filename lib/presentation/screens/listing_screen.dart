import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/presentation/common_methods/common_methods.dart';
import 'package:startup_20/presentation/common_widgets/common_widgets.dart';
import 'package:startup_20/presentation/screens/search_screen.dart';
import 'package:startup_20/presentation/screens/add_listing_screen.dart'; // ✅ Import your AddListingScreen

class ListingPage extends StatefulWidget {
  final String title;
  const ListingPage({super.key, required this.title});

  @override
  State<ListingPage> createState() => _ListingPageState();
}

class _ListingPageState extends State<ListingPage> {
  late List<Listing> listings;

  /// 🔹 Fetch listings from Firestore using the Listing model
  Future<List<Listing>> fetchListings() async {
    final snapshot = await FirebaseFirestore.instance
        .collection("listings")
        .where("category", isEqualTo: widget.title)
        .orderBy("createdAt", descending: true)
        .get();

    listings = snapshot.docs.map((doc) => Listing.fromJson(doc.data())).toList();
    return listings;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.WHITE,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.WHITE,
              boxShadow: [
                BoxShadow(
                  color: AppColors.BLACK_12,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 🔹 Back Arrow + Title
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                // 🔹 Search Icon
                IconButton(
                  icon: const Icon(Icons.search, size: 24),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => SearchScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),

      // 🔹 Listings Grid with FutureBuilder
      body: FutureBuilder<List<Listing>>(
        future: fetchListings(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return GridView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: 6,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 3 / 3.5,
              ),
              itemBuilder: (context, index) =>
                  CommonWidgets.shimmerlistingCard(),
            );
          }

          if (snapshot.hasError) {
            debugPrint("Error: ${snapshot.error}");
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final listings = snapshot.data ?? [];

          if (listings.isEmpty) {
            return _buildEmptyState(context);
          }

          return GridView.builder(
            padding: const EdgeInsets.all(15),
            itemCount: listings.length,
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
                  CommonMethods.navigateToListingDetailScreen(
                    context,
                    listing,
                    listings,
                  );
                },
                child: CommonWidgets.listingCard(listing),
              );
            },
          );
        },
      ),
    );
  }

  /// 🔹 Interactive Empty State Widget
  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 🖼 Optional illustration (if you have one)
            Icon(
              Icons.storefront_rounded,
              size: 80,
              color: AppColors.THEME_COLOR.withOpacity(0.8),
            ),
            const SizedBox(height: 20),

            Text(
              "No listings found in '${widget.title}'",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            const Text(
              "Be the first to contribute by adding a store or service related to this category!",
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // 🔹 Button to navigate to Add Listing
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.THEME_COLOR,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                "Contribute Now",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => AddListingScreen(
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
