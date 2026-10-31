class ListingFilterOptions {
  final String sortBy; // 'relevance', 'rating', 'distance', 'popular', 'newest'
  final double? minRating; // null, 3.0, 4.0, 4.5
  final double? maxDistanceKm; // null, 2.0, 5.0, 10.0, 25.0
  final bool openNowOnly;
  final bool acceptsOnlinePayment;
  final String? selectedCategoryId;
  final String? selectedCategoryName;

  const ListingFilterOptions({
    this.sortBy = 'relevance',
    this.minRating,
    this.maxDistanceKm,
    this.openNowOnly = false,
    this.acceptsOnlinePayment = false,
    this.selectedCategoryId,
    this.selectedCategoryName,
  });

  bool get hasActiveFilters =>
      sortBy != 'relevance' ||
      minRating != null ||
      maxDistanceKm != null ||
      openNowOnly ||
      acceptsOnlinePayment ||
      (selectedCategoryName != null && selectedCategoryName!.isNotEmpty);

  int get activeFilterCount {
    int count = 0;
    if (sortBy != 'relevance') count++;
    if (minRating != null) count++;
    if (maxDistanceKm != null) count++;
    if (openNowOnly) count++;
    if (acceptsOnlinePayment) count++;
    if (selectedCategoryName != null && selectedCategoryName!.isNotEmpty) {
      count++;
    }
    return count;
  }

  ListingFilterOptions copyWith({
    String? sortBy,
    double? minRating,
    bool clearMinRating = false,
    double? maxDistanceKm,
    bool clearMaxDistanceKm = false,
    bool? openNowOnly,
    bool? acceptsOnlinePayment,
    String? selectedCategoryId,
    bool clearCategory = false,
    String? selectedCategoryName,
  }) {
    return ListingFilterOptions(
      sortBy: sortBy ?? this.sortBy,
      minRating: clearMinRating ? null : (minRating ?? this.minRating),
      maxDistanceKm:
          clearMaxDistanceKm ? null : (maxDistanceKm ?? this.maxDistanceKm),
      openNowOnly: openNowOnly ?? this.openNowOnly,
      acceptsOnlinePayment: acceptsOnlinePayment ?? this.acceptsOnlinePayment,
      selectedCategoryId:
          clearCategory ? null : (selectedCategoryId ?? this.selectedCategoryId),
      selectedCategoryName:
          clearCategory
              ? null
              : (selectedCategoryName ?? this.selectedCategoryName),
    );
  }

  ListingFilterOptions clear() {
    return const ListingFilterOptions();
  }
}
