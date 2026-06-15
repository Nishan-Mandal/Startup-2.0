import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/core/services/algolia_service.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/data/models/category_model.dart';
import 'package:startup_20/presentation/common_methods/cached_network_svg.dart';
import 'package:startup_20/presentation/common_methods/common_methods.dart';
import 'package:startup_20/presentation/common_widgets/common_widgets.dart';
import 'package:startup_20/presentation/screens/listing_screen.dart';
import 'package:startup_20/providers/auth_provider.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({Key? key}) : super(key: key);

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  bool isLoading = false;
  final FocusNode _searchFocusNode = FocusNode();

  String query = "";
  List<String> recentSearches = [];
  List<String> sessionSearches = [];

  List<Category> categoryResults = [];
  List<Listing> listingResults = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_searchFocusNode);
    });
  }

  /// 🔹 Load recent searches from SharedPreferences
  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSearches = prefs.getStringList('recentSearches') ?? [];
    setState(() => recentSearches = savedSearches);
  }

  /// 🔹 Save recent searches to SharedPreferences
  Future<void> _saveRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recentSearches', recentSearches);
  }

  /// 🔹 Remove a specific search term
  Future<void> _removeRecentSearch(String term) async {
    setState(() => recentSearches.remove(term));
    await _saveRecentSearches();
  }

  /// Debounced Search
  void _onSearchChanged(String text) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 1000), () {
      _search(text.trim());
    });
  }

  /// Firestore Search
  Future<void> _search(String text) async {
    if (text.isEmpty) {
      setState(() {
        query = "";
        listingResults = [];
        categoryResults = [];
        isLoading = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
      query = text;
    });

    final appUser = context.read<AppAuthProvider>().appUser;
    final isAdmin = appUser?.role == 'admin';

    try {
      // 🔹 Parallel search
      final results = await Future.wait([
        AlgoliaService.searchListings(text),
        AlgoliaService.searchCategories(text),
      ]);

      final listingHits = results[0];
      final categoryHits = results[1];

      // 🔹 Extract listing IDs
      final ids =
          listingHits
              .map((e) => e['objectID']?.toString())
              .where((id) => id != null && id.isNotEmpty)
              .cast<String>()
              .toList();

      // 🔹 Fetch listings from Firestore
      List<Listing> fetchedListings = [];

      for (int i = 0; i < ids.length; i += 10) {
        final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);

        final snapshot =
            await FirebaseFirestore.instance
                .collection("listings")
                .where(FieldPath.documentId, whereIn: chunk)
                .get();

        final listingsChunk =
            snapshot.docs.map((doc) {
              final data = doc.data();
              data['listingId'] = doc.id;
              return Listing.fromJson(data);
            }).toList();

        fetchedListings.addAll(listingsChunk);
      }

      // 🔹 Maintain order
      final listingMap = {
        for (var item in fetchedListings) item.listingId: item,
      };

      final orderedListings =
          ids
              .map((id) => listingMap[id])
              .where((item) => item != null)
              .cast<Listing>()
              .toList();

      final filteredListings =
          orderedListings.where((listing) {
            return isAdmin ||
                (listing.verifiedBy != null && listing.verifiedBy!.isNotEmpty);
          }).toList();

      // 🔹 Map categories (NO Firestore call needed)cine
      final categories = categoryHits.map((e) => Category.fromJson(e)).toList();
      // 🔹 Update UI
      setState(() {
        listingResults = filteredListings;
        categoryResults = categories;
        isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint("Algolia error: $e");
      debugPrint("📍 StackTrace:\n$stackTrace");
      setState(() => isLoading = false);
    }
  }

  Future<void> _saveSearchSessionToFirestore() async {
    try {
      if (AppAuthProvider.isAnonymousUser() || recentSearches.isEmpty) return;

      final user = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user?.uid)
          .collection('searches')
          .doc()
          .set({
            'searches': sessionSearches,
            'createdAt': FieldValue.serverTimestamp(),
          });

      debugPrint("✅ New search session saved");
    } catch (e) {
      debugPrint("❌ Error saving search session: $e");
    }
  }

  @override
  void dispose() {
    _saveSearchSessionToFirestore();
    _controller.dispose();
    _debounce?.cancel();
    _searchFocusNode.dispose();
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
                      focusNode: _searchFocusNode,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: "What service do you need?",
                        prefixIcon: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.of(context).pop(),
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
                          recentSearches.map((item) {
                            return InputChip(
                              label: Text(item),
                              backgroundColor: AppColors.GREY_SHADE_100,
                              onPressed: () {
                                _controller.text = item;
                                _search(item);
                              },
                              deleteIcon: const Icon(Icons.close, size: 18),
                              onDeleted: () async {
                                // Remove from list
                                _removeRecentSearch(item);
                              },
                            );
                          }).toList(),
                    ),
                  ],
                ),

              const SizedBox(height: 16),

              // 🔹 Results Section
              Expanded(
                child:
                    query.isEmpty
                        ? const Center(
                          child: Text("Type something to start searching..."),
                        )
                        : isLoading
                        ? _loadingSkeleton()
                        : _searchResults(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _loadingSkeleton() {
    return SingleChildScrollView(
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
          ...List.generate(2, (index) => categoryTileLoader()),
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
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) => CommonWidgets.shimmerlistingCard(),
          ),
        ],
      ),
    );
  }

  Widget _searchResults() {
    return SingleChildScrollView(
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
          if (categoryResults.isEmpty) const Text("No categories found."),
          ...categoryResults.map((category) {
            return ListTile(
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
                              .where("verifiedBy", isNull: false)
                              .orderBy("createdAt", descending: true),
                        ),
                  ),
                );
              },
              leading: SizedBox(
                width: 30,
                height: 30,
                child: CachedNetworkSvg(url: category.imageUrl),
              ),
              title: Text(category.name),
            );
          }),
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
          if (listingResults.isEmpty) const Text("No listings found."),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: listingResults.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.75,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              final listing = listingResults[index];
              return GestureDetector(
                onTap:
                    () => CommonMethods.navigateToListingDetailScreen(
                      context,
                      listing,
                      [],
                    ),
                child: CommonWidgets.listingCard(listing),
              );
            },
          ),
        ],
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
