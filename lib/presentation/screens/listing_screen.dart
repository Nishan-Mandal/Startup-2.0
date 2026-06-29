import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/presentation/common_methods/common_methods.dart';
import 'package:startup_20/presentation/common_widgets/common_widgets.dart';
import 'package:startup_20/presentation/screens/listing_detail_screen.dart';
import 'package:startup_20/presentation/screens/logins/signin_screen.dart';
import 'package:startup_20/presentation/screens/search_screen.dart';
import 'package:startup_20/presentation/screens/add_listing_screen.dart';
import 'package:startup_20/providers/auth_provider.dart';

class ListingPage extends StatefulWidget {
  final String title;
  final Query query;
  const ListingPage({super.key, required this.title, required this.query});

  @override
  State<ListingPage> createState() => _ListingPageState();
}

class _ListingPageState extends State<ListingPage> {
  List<Listing> listings = [];

  final ScrollController _scrollController = ScrollController();

  Timestamp? _lastCreatedAt;
  bool _isLoading = false;
  bool _hasMore = true;

  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();

    _loadListings();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
              _scrollController.position.maxScrollExtent - 300 &&
          !_isLoading &&
          _hasMore) {
        _loadListings();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadListings() async {
    if (_isLoading || !_hasMore) return;

    setState(() {
      _isLoading = true;
    });

    try {
      Query query = widget.query.limit(_pageSize);

      // Pagination using createdAt value
      if (_lastCreatedAt != null) {
        query = query.startAfter([_lastCreatedAt]);
      }

      final snapshot = await query.get();

      if (snapshot.docs.isNotEmpty) {
        listings.addAll(
          snapshot.docs.map(
            (doc) => Listing.fromJson(doc.data() as Map<String, dynamic>),
          ),
        );

        // Save last createdAt for next page
        _lastCreatedAt = snapshot.docs.last.get('createdAt') as Timestamp;
      }

      // No more data
      if (snapshot.docs.length < _pageSize) {
        _hasMore = false;
      }
    } catch (e) {
      debugPrint('Pagination Error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
              children: [
                // 🔹 Back button
                IconButton(
                  icon: const Icon(Icons.arrow_back_ios, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),

                // 🔹 Title (STRICTLY constrained)
                Expanded(
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // 🔹 Search icon (fixed width)
                IconButton(
                  icon: const Icon(Icons.search, size: 24),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SearchScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),

      body:
          listings.isEmpty && _isLoading
              ? GridView.builder(
                padding: const EdgeInsets.all(15),
                itemCount: 6,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 3 / 3.5,
                ),
                itemBuilder:
                    (context, index) => CommonWidgets.shimmerlistingCard(),
              )
              : listings.isEmpty
              ? _buildEmptyState(context)
              : Column(
                children: [
                  Expanded(
                    child: GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(15),
                      itemCount: listings.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 3 / 3.8,
                          ),
                      itemBuilder: (context, index) {
                        final listing = listings[index];

                        return GestureDetector(
                          onTap: () {
                            if (widget.title == 'Pending Approvals' ||
                                widget.title == "Deleted Listings") {
                              CommonMethods.preloadListingImages(
                                context,
                                listing,
                              );
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (context) => ListingDetailScreen(
                                        listing: listing,
                                        similarListings: listings,
                                      ),
                                ),
                              ).then((deleted) async {
                                if (deleted == true) {
                                  listings.clear();
                                  _lastCreatedAt = null;
                                  _hasMore = true;
                                  await _loadListings();
                                }
                              });
                            } else {
                              CommonMethods.navigateToListingDetailScreen(
                                context,
                                listing,
                                listings,
                              );
                            }
                          },
                          child: CommonWidgets.listingCard(listing),
                        );
                      },
                    ),
                  ),
                  if (_isLoading && listings.isNotEmpty)
                    if (_isLoading && listings.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 20),
                        child: CircularProgressIndicator(),
                      ),
                ],
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
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            const Text(
              "Be the first to contribute by adding a store or service related to this category!",
              style: TextStyle(fontSize: 15, color: AppColors.GREY),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // 🔹 Button to navigate to Add Listing
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.THEME_COLOR,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.add, color: AppColors.WHITE),
              label: const Text(
                "Contribute Now",
                style: TextStyle(
                  color: AppColors.WHITE,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder:
                        (context) =>
                            AppAuthProvider.isAnonymousUser()
                                ? SignInScreen(skip: false)
                                : AddListingScreen(),
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
