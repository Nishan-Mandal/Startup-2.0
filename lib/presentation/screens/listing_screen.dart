import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/presentation/common_methods/common_methods.dart';
import 'package:startup_20/presentation/common_widgets/common_widgets.dart';

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
    final snapshot =
        await FirebaseFirestore.instance
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
                    // TODO: Add search logic
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
              itemCount: 6, // number of shimmer cards you want
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 3 / 3.5,
              ),
              itemBuilder:
                  (context, index) => CommonWidgets.shimmerlistingCard(),
            );
          }
          if (snapshot.hasError) {
            debugPrint("Error: ${snapshot.error}");
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final listings = snapshot.data ?? [];

          if (listings.isEmpty) {
            return const Center(child: Text("No listings found"));
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
                  CommonMethods.navigateToListingDetailScreen(context, listing, listings);
                },
                child: CommonWidgets.listingCard(listing),
              );
            },
          );
        },
      ),
    );
  }
}
