import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/filter_options_model.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/presentation/common_methods/common_methods.dart';
import 'package:startup_20/presentation/common_methods/searchable_dropdown.dart';
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
  final List<Listing> _allFetchedListings = [];

  final ScrollController _scrollController = ScrollController();

  Timestamp? _lastCreatedAt;
  bool _isLoading = false;
  bool _hasMore = true;

  ListingFilterOptions _filterOptions = const ListingFilterOptions();
  Position? _userPosition;

  static const int _pageSize = 20;

  bool get _isAdminScreen =>
      widget.title == 'Pending Approvals' || widget.title == 'Deleted Listings';

  bool get _isFilterEnabled => !_isAdminScreen;

  @override
  void initState() {
    super.initState();

    _loadListings();
    if (_isFilterEnabled) {
      _determinePosition();
    }

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

  Future<void> _determinePosition() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );
      if (!mounted) return;
      setState(() {
        _userPosition = pos;
      });
      if (_filterOptions.maxDistanceKm != null ||
          _filterOptions.sortBy == 'distance') {
        _onFilterApplied(_filterOptions);
      }
    } catch (e) {
      debugPrint("Error determining location in ListingPage: $e");
    }
  }

  void _onFilterApplied(ListingFilterOptions newFilter) {
    setState(() {
      _filterOptions = newFilter;
      listings = _filterAndSortListings(_allFetchedListings);
    });
  }

  List<Listing> _filterAndSortListings(List<Listing> rawListings) {
    List<Listing> filtered = List.from(rawListings);

    //Filter by Minimum Rating
    if (_filterOptions.minRating != null) {
      filtered =
          filtered.where((l) => l.rating >= _filterOptions.minRating!).toList();
    }

    //Filter by Open Now
    if (_filterOptions.openNowOnly) {
      filtered = filtered.where((l) => _isListingOpenNow(l)).toList();
    }

    //Filter by Online Payments
    if (_filterOptions.acceptsOnlinePayment) {
      filtered =
          filtered.where((l) {
            final val = l.details['Accept Online Payments']?.toLowerCase();
            return val == 'yes' || val == 'true';
          }).toList();
    }

    //Filter by Distance
    if (_filterOptions.maxDistanceKm != null && _userPosition != null) {
      final maxMeters = _filterOptions.maxDistanceKm! * 1000;
      filtered =
          filtered.where((l) {
            if (l.geo.lat == 0.0 && l.geo.lng == 0.0) return false;
            final dist = Geolocator.distanceBetween(
              _userPosition!.latitude,
              _userPosition!.longitude,
              l.geo.lat,
              l.geo.lng,
            );
            return dist <= maxMeters;
          }).toList();
    }

    //Sorting
    switch (_filterOptions.sortBy) {
      case 'rating':
        filtered.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'popular':
        filtered.sort(
          (a, b) => (b.views + b.likes).compareTo(a.views + a.likes),
        );
        break;
      case 'newest':
        filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        break;
      case 'distance':
        if (_userPosition != null) {
          filtered.sort((a, b) {
            final distA =
                (a.geo.lat == 0 && a.geo.lng == 0)
                    ? double.infinity
                    : Geolocator.distanceBetween(
                      _userPosition!.latitude,
                      _userPosition!.longitude,
                      a.geo.lat,
                      a.geo.lng,
                    );
            final distB =
                (b.geo.lat == 0 && b.geo.lng == 0)
                    ? double.infinity
                    : Geolocator.distanceBetween(
                      _userPosition!.latitude,
                      _userPosition!.longitude,
                      b.geo.lat,
                      b.geo.lng,
                    );
            return distA.compareTo(distB);
          });
        }
        break;
      case 'relevance':
      default:
        // Algolia relevance order preserved
        break;
    }

    return filtered;
  }

  bool _isListingOpenNow(Listing listing) {
    if (listing.businessHours.isEmpty) return false;
    const days = [
      "Monday",
      "Tuesday",
      "Wednesday",
      "Thursday",
      "Friday",
      "Saturday",
      "Sunday",
    ];
    final now = DateTime.now();
    final currentDay = days[now.weekday - 1];
    final schedule = listing.businessHours[currentDay];
    if (schedule == null || schedule.isClosed || schedule.slots.isEmpty) {
      return false;
    }
    final nowTime = TimeOfDay.fromDateTime(now);
    final currentMinutes = nowTime.hour * 60 + nowTime.minute;
    for (final slot in schedule.slots) {
      final openMinutes = slot.open.hour * 60 + slot.open.minute;
      final closeMinutes = slot.close.hour * 60 + slot.close.minute;
      if (currentMinutes >= openMinutes && currentMinutes <= closeMinutes) {
        return true;
      }
    }
    return false;
  }

  Widget _buildActiveFilterChips() {
    final chips = <Widget>[];

    //Sorting
    if (_filterOptions.sortBy != 'relevance') {
      final sortLabels = {
        'rating': '★ Highest Rated',
        'distance': 'Nearest First',
        'popular': 'Most Popular',
        'newest': 'Newest First',
      };
      chips.add(
        _buildSingleFilterChip(
          label: sortLabels[_filterOptions.sortBy] ?? _filterOptions.sortBy,
          icon: Icons.swap_vert_rounded,
          onDeleted: () {
            _onFilterApplied(_filterOptions.copyWith(sortBy: 'relevance'));
          },
        ),
      );
    }

    //Rating
    if (_filterOptions.minRating != null) {
      chips.add(
        _buildSingleFilterChip(
          label: "★ ${_filterOptions.minRating}+",
          onDeleted: () {
            _onFilterApplied(_filterOptions.copyWith(clearMinRating: true));
          },
        ),
      );
    }

    //Distance
    if (_filterOptions.maxDistanceKm != null) {
      chips.add(
        _buildSingleFilterChip(
          label: "< ${_filterOptions.maxDistanceKm!.toInt()} km",
          icon: Icons.near_me_rounded,
          onDeleted: () {
            _onFilterApplied(_filterOptions.copyWith(clearMaxDistanceKm: true));
          },
        ),
      );
    }

    //Open Now
    if (_filterOptions.openNowOnly) {
      chips.add(
        _buildSingleFilterChip(
          label: "Open Now",
          icon: Icons.access_time_filled_rounded,
          activeColor: Colors.green,
          onDeleted: () {
            _onFilterApplied(_filterOptions.copyWith(openNowOnly: false));
          },
        ),
      );
    }

    //Online Payment
    if (_filterOptions.acceptsOnlinePayment) {
      chips.add(
        _buildSingleFilterChip(
          label: "Online Payment",
          icon: Icons.payments_rounded,
          onDeleted: () {
            _onFilterApplied(
              _filterOptions.copyWith(acceptsOnlinePayment: false),
            );
          },
        ),
      );
    }

    //Clear All
    chips.add(
      GestureDetector(
        onTap: () {
          _onFilterApplied(const ListingFilterOptions());
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Text(
            "Clear All",
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.redAccent,
            ),
          ),
        ),
      ),
    );

    return SizedBox(
      height: 36,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) => chips[i],
      ),
    );
  }

  Widget _buildSingleFilterChip({
    required String label,
    IconData? icon,
    Color? activeColor,
    required VoidCallback onDeleted,
  }) {
    final iconColor = activeColor ?? AppColors.THEME_COLOR;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.THEME_COLOR.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.BLACK,
            ),
          ),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: onDeleted,
            child: const Icon(
              Icons.close_rounded,
              size: 16,
              color: AppColors.BLACK_54,
            ),
          ),
        ],
      ),
    );
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
        final newDocs =
            snapshot.docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              if (!data.containsKey('listingId') || data['listingId'] == null) {
                data['listingId'] = doc.id;
              }
              return Listing.fromJson(data);
            }).toList();

        _allFetchedListings.addAll(newDocs);

        // Save last createdAt for next page
        _lastCreatedAt = snapshot.docs.last.get('createdAt') as Timestamp;
      }

      // No more data
      if (snapshot.docs.length < _pageSize) {
        _hasMore = false;
      }

      if (_isFilterEnabled) {
        listings = _filterAndSortListings(_allFetchedListings);
      } else {
        listings = List.from(_allFetchedListings);
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
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 38,
                    minHeight: 38,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SearchScreen()),
                    );
                  },
                ),

                // 🔹 Filter icon trigger with badge (only for customer screens)
                if (_isFilterEnabled)
                  SearchableDropdown(
                    style: SearchableDropdownStyle.icon,
                    filterOptions: _filterOptions,
                    activeFilterCount: _filterOptions.activeFilterCount,
                    onFilterApplied: _onFilterApplied,
                    iconMargin: const EdgeInsets.only(left: 4),
                  ),
              ],
            ),
          ),
        ),
      ),

      body: Column(
        children: [
          // 🔹 Active Filter Chips
          if (_isFilterEnabled && _filterOptions.hasActiveFilters) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(15, 10, 15, 6),
              child: _buildActiveFilterChips(),
            ),
          ],
          Expanded(child: _buildBodyContent(context)),
        ],
      ),
    );
  }

  Widget _buildBodyContent(BuildContext context) {
    if (listings.isEmpty && _isLoading) {
      return GridView.builder(
        padding: const EdgeInsets.all(15),
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 3 / 3.5,
        ),
        itemBuilder: (context, index) => CommonWidgets.shimmerlistingCard(),
      );
    }

    if (listings.isEmpty) {
      if (_isFilterEnabled && _filterOptions.hasActiveFilters) {
        return _buildEmptyFilterState(context);
      }
      return _buildEmptyState(context);
    }

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            controller: _scrollController,
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
                  if (_isAdminScreen) {
                    CommonMethods.preloadListingImages(context, listing);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => ListingDetailScreen(
                              listing: listing,
                              similarListings: listings,
                            ),
                      ),
                    ).then((result) async {
                      if (result == true) {
                        listings.clear();
                        _allFetchedListings.clear();
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
          const Padding(
            padding: EdgeInsets.only(bottom: 20),
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }

  Widget _buildEmptyFilterState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.filter_alt_off_rounded,
              size: 70,
              color: AppColors.THEME_COLOR.withOpacity(0.7),
            ),
            const SizedBox(height: 16),
            const Text(
              "No listings match your filters",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Try removing some filters to see listings in '${widget.title}'.",
              style: const TextStyle(fontSize: 14, color: AppColors.GREY),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.THEME_COLOR,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              onPressed: () {
                _onFilterApplied(const ListingFilterOptions());
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text(
                "Reset Filters",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 Interactive Empty State Widget
  Widget _buildEmptyState(BuildContext context) {
    final isPending = widget.title == 'Pending Approvals';
    final isDeleted = widget.title == 'Deleted Listings';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            //Optional illustration
            Icon(
              isPending
                  ? Icons.hourglass_empty_rounded
                  : isDeleted
                  ? Icons.delete_outline_rounded
                  : Icons.storefront_rounded,
              size: 80,
              color: AppColors.THEME_COLOR.withOpacity(0.8),
            ),
            const SizedBox(height: 20),

            Text(
              isPending
                  ? "No pending approvals"
                  : isDeleted
                  ? "No deleted listings"
                  : "No listings found in '${widget.title}'",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            Text(
              isPending
                  ? "All submitted listings have been reviewed and approved!"
                  : isDeleted
                  ? "No listings have been marked as deleted."
                  : "Be the first to contribute by adding a store or service related to this category!",
              style: const TextStyle(fontSize: 15, color: AppColors.GREY),
              textAlign: TextAlign.center,
            ),
            if (!_isAdminScreen) ...[
              const SizedBox(height: 24),

              //Button to navigate to Add Listing
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
          ],
        ),
      ),
    );
  }
}
