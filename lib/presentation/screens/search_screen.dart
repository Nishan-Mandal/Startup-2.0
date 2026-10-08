import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
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
  bool isListingLoading = false;
  bool isSearching = false;
  int _searchRequestId = 0;
  final FocusNode _searchFocusNode = FocusNode();

  String query = "";
  List<String> recentSearches = [];
  List<String> sessionSearches = [];

  List<Category> categoryResults = [];
  List<Listing> listingResults = [];
  List<String> tagResults = [];
  List<Category> topCategories = [];
  List<Map<String, dynamic>> trendingSearches = [];
  bool isTopCategoriesLoading = true;
  bool isTrendingSearchesLoading = true;
  bool showSuggestions = true;

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
    _loadTopCategories();
    _loadTrendingSearches();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_searchFocusNode);
    });
  }

  /// 🔹 Load recent searches from SharedPreferences
  Future<void> _loadRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSearches = prefs.getStringList('recentSearches') ?? [];
    final limitedSearches = savedSearches.take(5).toList();

    await prefs.setStringList('recentSearches', limitedSearches);

    if (!mounted) return;

    setState(() {
      recentSearches = limitedSearches;
    });
  }

  Future<void> _loadTopCategories() async {
    try {
      final results = await AlgoliaService.getTopCategories();

      if (!mounted) return;

      setState(() {
        topCategories =
            results.map((e) => Category.fromJson(e)).take(8).toList();

        isTopCategoriesLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading top categories: $e");

      if (!mounted) return;

      setState(() {
        isTopCategoriesLoading = false;
      });
    }
  }

  Future<void> _loadTrendingSearches() async {
    try {
      final results = await AlgoliaService.getTrendingSearches();

      if (!mounted) return;

      setState(() {
        trendingSearches = results.take(6).toList();

        isTrendingSearchesLoading = false;
      });
    } catch (e) {
      debugPrint("Error loading trending searches: $e");

      if (!mounted) return;

      setState(() {
        isTrendingSearchesLoading = false;
      });
    }
  }

  /// 🔹 Save recent searches to SharedPreferences
  Future<void> _saveRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('recentSearches', recentSearches);
  }

  Future<void> _addRecentSearch(String term) async {
    final value = term.trim();
    if (value.isEmpty) return;
    setState(() {
      recentSearches.remove(value); // duplicate htane ke lie add kie hain
      recentSearches.insert(0, value); // hrr baar most recent search upar rhega
      if (recentSearches.length > 5) {
        recentSearches = recentSearches.take(5).toList();
      }

      sessionSearches.remove(value);
      sessionSearches.add(value);
    });
    await _saveRecentSearches();
  }

  /// 🔹 Remove a specific search term
  Future<void> _removeRecentSearch(String term) async {
    setState(() => recentSearches.remove(term));
    await _saveRecentSearches();
  }

  /// Debounced Search
  void _onSearchChanged(String text) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 150), () {
      _search(text.trim());
    });
  }

  /// Firestore Search
  Future<void> _search(String text, {bool showTagSuggestions = true}) async {
    final requestId = ++_searchRequestId;

    if (text.isEmpty) {
      setState(() {
        query = "";
        listingResults = [];
        categoryResults = [];
        tagResults = [];
        showSuggestions = showTagSuggestions;
        isLoading = false;
        isSearching = false;
        isListingLoading = false;
      });
      return;
    }

    setState(() {
      isSearching = true;
      query = text;
      showSuggestions = showTagSuggestions;
      if (listingResults.isEmpty) {
        isListingLoading = true;
      }
    });

    final appUser = context.read<AppAuthProvider>().appUser;
    final isAdmin = appUser?.role == 'admin';

    try {
      final results = await AlgoliaService.search(text);

      final listingHits = results['Listings'] ?? [];
      final categoryHits = results['categories'] ?? [];

      final Set<String> matchedTags = {};

      for (final hit in listingHits) {
        final tags = List<String>.from(hit['tags'] ?? []);

        for (final tag in tags) {
          if (tag.toLowerCase().contains(text.toLowerCase())) {
            matchedTags.add(tag);
          }
        }
      }

      final categories = categoryHits.map((e) => Category.fromJson(e)).toList();

      if (!mounted || requestId != _searchRequestId) {
        return;
      }

      setState(() {
        categoryResults = categories.take(6).toList();
        tagResults = matchedTags.take(6).toList();
        isSearching = false;
        isLoading = false;
        isListingLoading = true;
      });
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

      if (!mounted || requestId != _searchRequestId) {
        return;
      }
      // 🔹 Update UI
      setState(() {
        listingResults = filteredListings;
        isListingLoading = false;
        isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint("Algolia error: $e");
      debugPrint("📍 StackTrace:\n$stackTrace");

      if (!mounted || requestId != _searchRequestId) {
        return;
      }

      setState(() {
        isLoading = false;
        isListingLoading = false;
      });
    }
  }

  Future<void> _saveSearchSessionToFirestore() async {
    try {
      if (AppAuthProvider.isAnonymousUser() || sessionSearches.isEmpty) return;

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
                    const SizedBox(height: 10),

                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children:
                          recentSearches.map((item) {
                            return GestureDetector(
                              onTap: () {
                                _controller.text = item;
                                _search(item, showTagSuggestions: false);
                              },
                              child: Container(
                                constraints: const BoxConstraints(
                                  maxWidth: 275,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 11,
                                  vertical: 9,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.THEME_COLOR.withOpacity(
                                    0.05,
                                  ),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.history_rounded,
                                      size: 17,
                                      color: AppColors.THEME_COLOR,
                                    ),
                                    const SizedBox(width: 5),

                                    Flexible(
                                      child: Text(
                                        item,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.BLACK,
                                        ),
                                      ),
                                    ),

                                    const SizedBox(width: 4),

                                    GestureDetector(
                                      onTap: () {
                                        _removeRecentSearch(item);
                                      },
                                      child: Icon(
                                        Icons.close_rounded,
                                        size: 17,
                                        color: AppColors.BLACK_54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                    ),
                  ],
                ),
              // 🔹 Results Section
              Expanded(
                child: query.isEmpty ? _emptySearchContent() : _searchResults(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptySearchContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (trendingSearches.isNotEmpty) ...[
            const SizedBox(height: 20),

            Row(
              children: [
                const Text(
                  "Trending Searches",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.BLACK_54,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.GREY_SHADE_100,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  padding: const EdgeInsets.all(2),
                  child: const Icon(
                    Icons.trending_up_rounded,
                    color: AppColors.THEME_COLOR,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            Wrap(
              spacing: 6,
              runSpacing: 6,
              children:
                  trendingSearches.map((item) {
                    final searchTerm = item['query']?.toString() ?? "";
                    final popularity = item['popularity'] ?? 0;
                    return GestureDetector(
                      onTap: () async {
                        _controller.text = searchTerm;

                        await _addRecentSearch(searchTerm);

                        _search(searchTerm, showTagSuggestions: false);
                      },
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 275),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.THEME_COLOR.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.trending_up_rounded,
                              size: 17,
                              color: AppColors.THEME_COLOR,
                            ),
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                searchTerm,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.BLACK,
                                ),
                              ),
                            ),

                            const SizedBox(width: 7),

                            Text(
                              popularity.toString() + "k",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.THEME_COLOR,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ],
          if (topCategories.isNotEmpty) ...[
            const SizedBox(height: 20),

            Row(
              children: [
                const Text(
                  "Trending Categories",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.BLACK_54,
                  ),
                ),
                SizedBox(width: 5),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.GREY_SHADE_100,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(2.0),
                    child: Icon(
                      Icons.trending_up_rounded,
                      color: AppColors.THEME_COLOR,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: topCategories.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                mainAxisExtent: 118,
              ),
              itemBuilder: (context, index) {
                final category = topCategories[index];

                return GestureDetector(
                  onTap: () {
                    _controller.text = category.name;
                    _search(category.name, showTagSuggestions: false);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.THEME_COLOR.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      // border: Border.all(
                      //   color: AppColors.THEME_COLOR.withOpacity(0.2),
                      // ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 44,
                          height: 44,
                          child: CachedNetworkImage(
                            imageUrl: category.imageUrl,
                            fit: BoxFit.contain,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          category.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.BLACK,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Widget _highlightMatch(String text, String searchQuery, {TextStyle? style}) {
    final query = searchQuery.trim();

    final baseStyle = (style ?? const TextStyle()).copyWith(
      decoration: TextDecoration.none,
    );

    if (query.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final regex = RegExp(RegExp.escape(query), caseSensitive: false);

    final matches = regex.allMatches(text).toList();

    if (matches.isEmpty) {
      return Text(text, style: baseStyle);
    }

    final spans = <InlineSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      // Normal text before match
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: baseStyle,
          ),
        );
      }

      // Highlighted match
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.THEME_COLOR.withOpacity(0.10),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              text.substring(match.start, match.end),
              style: baseStyle.copyWith(
                color: AppColors.THEME_COLOR,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      );

      lastEnd = match.end;
    }

    // Normal text after match
    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }

    return RichText(text: TextSpan(style: baseStyle, children: spans));
  }

  Widget _searchResults() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSearching &&
              listingResults.isEmpty &&
              categoryResults.isEmpty &&
              tagResults.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.only(top: 24),
                child: SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.THEME_COLOR,
                  ),
                ),
              ),
            )
          else if (!isSearching &&
              listingResults.isEmpty &&
              categoryResults.isEmpty &&
              tagResults.isEmpty)
            const Center(
              child: Column(
                children: [
                  SizedBox(height: 15),
                  Text(
                    "Uh-oh!",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.BLACK_54,
                    ),
                  ),
                  Text(
                    "No results found!",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.BLACK_54,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if (showSuggestions && tagResults.isNotEmpty) ...[
              ...tagResults.map((tag) {
                return Theme(
                  data: Theme.of(context).copyWith(
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                    splashFactory: NoSplash.splashFactory,
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.only(left: 2),
                    leading: CircleAvatar(
                      backgroundColor: AppColors.GREY_SHADE_100,
                      child: Icon(
                        Icons.timer_sharp,
                        color: AppColors.THEME_COLOR.withOpacity(0.7),
                      ),
                    ),

                    title: _highlightMatch(
                      tag,
                      query,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.BLACK,
                      ),
                    ),
                    // title: Text(tag),
                    onTap: () async {
                      _controller.text = tag;
                      await _addRecentSearch(tag);
                      _search(tag, showTagSuggestions: false);
                    },
                  ),
                );
              }),

              const SizedBox(height: 20),
            ],
            if (categoryResults.isNotEmpty) ...[
              const Text(
                "Categories",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.BLACK_54,
                ),
              ),
              const SizedBox(height: 8),
              ...categoryResults.map((category) {
                return ListTile(
                  onTap: () {
                    unawaited(
                      AlgoliaService.trackCategoryFilter(category.name),
                    );
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
                    child: CachedNetworkImage(imageUrl: category.imageUrl),
                  ),
                  title: _highlightMatch(
                    category.name,
                    query,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.BLACK,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],
            if (isListingLoading) ...[
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
                itemBuilder:
                    (context, index) => CommonWidgets.shimmerlistingCard(),
              ),
            ] else if (listingResults.isNotEmpty) ...[
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
          ],
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
