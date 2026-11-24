import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/data/models/review_model.dart';
import 'package:startup_20/presentation/common_methods/common_methods.dart';

class ListingAnalyticsScreen extends StatefulWidget {
  final Listing listing;

  const ListingAnalyticsScreen({super.key, required this.listing});

  @override
  State<ListingAnalyticsScreen> createState() => _ListingAnalyticsScreenState();
}

class _ListingAnalyticsScreenState extends State<ListingAnalyticsScreen> {
  String _selectedReviewFilter = 'all'; // 'all', '5', '4', 'critical'
  int _touchedBarIndex = -1;

  // Time range selection: '7d' (7 Days), '30d' (30 Days - default), '90d' (90 Days)
  String _selectedTimeRange = '30d';

  // Web analytics doc ke mutabiq baseline multipliers: 0.3x for 7d, 1.0x for 30d, 2.6x for 90d
  double get _timeMultiplier {
    switch (_selectedTimeRange) {
      case '7d':
        return 0.3;
      case '90d':
        return 2.6;
      case '30d':
      default:
        return 1.0;
    }
  }

  // Selected time period ke hisab se numbers dynamically calculate ho rahe hain
  int _scaleValue(int baseline) {
    if (baseline <= 0) return 0;
    final scaled = (baseline * _timeMultiplier).round();
    return scaled <= 0 && baseline > 0 ? 1 : scaled;
  }

  String _getTimeRangeLabel() {
    switch (_selectedTimeRange) {
      case '7d':
        return "Last 7 days";
      case '90d':
        return "Last 90 days";
      case '30d':
      default:
        return "Last 30 days";
    }
  }

  static const String _placeholderImageUrl =
      "https://firebasestorage.googleapis.com/v0/b/startup20-5eaa7.firebasestorage.app/o/static%2FImage_Placeholder.jpg?alt=media&token=22a0ec73-6352-4885-bfaf-c485750af28f";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.WHITE,
      appBar: AppBar(
        backgroundColor: AppColors.WHITE,
        surfaceTintColor: AppColors.WHITE,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            size: 20,
            color: AppColors.BLACK,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Analytics",
          style: TextStyle(
            color: AppColors.BLACK,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            height: 1,
            color: AppColors.GREY_SHADE_300.withValues(alpha: 0.7),
          ),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('listings')
            .doc(widget.listing.listingId)
            .snapshots(),
        builder: (context, snapshot) {
          Listing currentListing = widget.listing;
          if (snapshot.hasData &&
              snapshot.data != null &&
              snapshot.data!.data() != null) {
            final data = snapshot.data!.data() as Map<String, dynamic>;
            if (!data.containsKey('listingId') || data['listingId'] == null) {
              data['listingId'] = snapshot.data!.id;
            }
            currentListing = Listing.fromJson(data);
          }

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Store Header Strip
                _buildStoreHeader(currentListing),
                _buildSectionDivider(),

                // 2. Time Range Selector Bar (7d / 30d / 90d)
                _buildTimeRangeSelector(),
                _buildSectionDivider(),

                // 3. Overview Metrics (2x2 Grid)
                _buildOverviewMetricsSection(currentListing),
                _buildSectionDivider(),

                // 4. Customer Leads Bar Chart (fl_chart) + Lead Conversion
                _buildLeadsBarChartSection(currentListing),
                _buildSectionDivider(),

                // 5. Ratings & Breakdown (aligned with ListingDetailScreen)
                _buildRatingDistributionSection(currentListing),

                // 6. Factor Performance (if available)
                if (currentListing.factorAvgRatings.isNotEmpty) ...[
                  _buildSectionDivider(),
                  _buildFactorRatingsSection(currentListing),
                ],
                _buildSectionDivider(),

                // 7. Customer Feedback & Reviews
                _buildReviewsFeedSection(currentListing),
                _buildSectionDivider(),

                // 8. Store Profile Health
                _buildStoreHealthSection(currentListing),
                const SizedBox(height: 28),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionDivider() {
    return Container(
      height: 6,
      width: double.infinity,
      color: AppColors.GREY_SHADE_100,
    );
  }

  // ==============================================================
  // 1. STORE HEADER STRIP
  // ==============================================================
  Widget _buildStoreHeader(Listing listing) {
    final thumbUrl = listing.images.isNotEmpty
        ? (listing.images.first.thumbUrl.isNotEmpty
            ? listing.images.first.thumbUrl
            : listing.images.first.fullUrl)
        : _placeholderImageUrl;

    final displayName = listing.name.trim().isNotEmpty
        ? listing.name.trim()
        : (listing.category.trim().isNotEmpty
            ? listing.category.trim()
            : "My Listing");

    final showCategorySeparately = listing.name.trim().isNotEmpty &&
        listing.category.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: thumbUrl,
              width: 58,
              height: 58,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                width: 58,
                height: 58,
                color: AppColors.GREY_SHADE_100,
              ),
              errorWidget: (context, url, error) => Container(
                width: 58,
                height: 58,
                color: AppColors.GREY_SHADE_300,
                child: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.GREY,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.BLACK,
                        ),
                      ),
                    ),
                    if (listing.isPremium)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.AMBER,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.workspace_premium,
                          size: 14,
                          color: AppColors.BLACK,
                        ),
                      ),
                  ],
                ),
                if (showCategorySeparately) ...[
                  const SizedBox(height: 2),
                  Text(
                    listing.category,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.THEME_COLOR,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 13,
                      color: AppColors.GREY,
                    ),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        listing.address.isNotEmpty
                            ? listing.address
                            : "No address provided",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.GREY,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // 2. TIME RANGE SELECTOR BAR (Web standard: 7d / 30d / 90d)
  // ==============================================================
  Widget _buildTimeRangeSelector() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.WHITE,
      child: Row(
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 15,
                color: AppColors.BLACK_54,
              ),
              const SizedBox(width: 6),
              Text(
                "Period: ${_getTimeRangeLabel()}",
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColors.BLACK_54,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Web dashboard ke mutabiq 3 options: 7d, 30d (default), 90d
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.GREY_SHADE_50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppColors.GREY_SHADE_300.withValues(alpha: 0.8),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTimeRangePill('7d', '7D'),
                _buildTimeRangePill('30d', '30D'),
                _buildTimeRangePill('90d', '90D'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeRangePill(String key, String label) {
    final isSelected = _selectedTimeRange == key;
    return GestureDetector(
      onTap: () {
        if (_selectedTimeRange != key) {
          setState(() {
            _selectedTimeRange = key;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.THEME_COLOR : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.THEME_COLOR.withValues(alpha: 0.28),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? AppColors.WHITE : AppColors.BLACK_54,
          ),
        ),
      ),
    );
  }

  // ==============================================================
  // 3. OVERVIEW KPI METRICS (2x2 Flat Bordered Tiles)
  // ==============================================================
  Widget _buildOverviewMetricsSection(Listing listing) {
    // Selected time range ke hisab se dynamically calculated numbers
    final scaledViews = _scaleValue(listing.views);
    final scaledLikes = _scaleValue(listing.likes);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Overview",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.BLACK,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.THEME_COLOR.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _getTimeRangeLabel(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.THEME_COLOR,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildKpiTile(
                  title: "Total Views",
                  value: "$scaledViews",
                  subtitle: "${_getTimeRangeLabel()} visits",
                  icon: Icons.visibility_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiTile(
                  title: "Total Likes",
                  value: "$scaledLikes",
                  subtitle: "${_getTimeRangeLabel()} saves",
                  icon: Icons.favorite_border_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildKpiTile(
                  title: "Avg Rating",
                  value: "${listing.rating.toStringAsFixed(1)} ★",
                  subtitle: "${listing.ratingCount} verified ratings",
                  icon: Icons.star_outline_rounded,
                  iconColor: AppColors.AMBER,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiTile(
                  title: "Reviews",
                  value: "${listing.reviews}",
                  subtitle: "Customer feedback",
                  icon: Icons.rate_review_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKpiTile({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    Color iconColor = AppColors.THEME_COLOR,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.GREY_SHADE_50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.GREY_SHADE_300.withValues(alpha: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.BLACK_54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(icon, size: 18, color: iconColor),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.BLACK,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.GREY,
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // 4. CUSTOMER LEADS & INQUIRIES (fl_chart Bar Chart)
  // ==============================================================
  Widget _buildLeadsBarChartSection(Listing listing) {
    // Time range ke mutabiq scaled leads data
    final calls = _scaleValue(listing.leads['calls'] ?? 0);
    final whatsapp = _scaleValue(listing.leads['whatsapp'] ?? 0);
    final directions = _scaleValue(listing.leads['directions'] ?? 0);
    final website = _scaleValue(listing.leads['website'] ?? 0);
    final shares = _scaleValue(listing.leads['shares'] ?? 0);

    final totalLeads = calls + whatsapp + directions + website + shares;
    final scaledViews = _scaleValue(listing.views);

    final List<Map<String, dynamic>> barData = [
      {'label': 'Calls', 'value': calls, 'icon': Icons.call_outlined},
      {'label': 'WhatsApp', 'value': whatsapp, 'icon': Icons.chat_bubble_outline},
      {'label': 'Maps', 'value': directions, 'icon': Icons.directions_outlined},
      {'label': 'Web', 'value': website, 'icon': Icons.language_outlined},
      {'label': 'Shares', 'value': shares, 'icon': Icons.share_outlined},
    ];

    final maxVal = barData
        .map((e) => e['value'] as int)
        .fold<int>(0, (max, v) => v > max ? v : max);
    final double maxY = maxVal <= 5 ? 5.0 : ((maxVal / 5).ceil() * 5).toDouble();
    final double yInterval = maxY <= 5 ? 1.0 : (maxY / 5).ceilToDouble();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Customer Leads",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.BLACK,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.THEME_COLOR.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  "$totalLeads Total ($_selectedTimeRange)",
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.THEME_COLOR,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            "Outbound inquiries for ${_getTimeRangeLabel().toLowerCase()}",
            style: const TextStyle(fontSize: 12, color: AppColors.GREY),
          ),
          const SizedBox(height: 18),

          SizedBox(
            height: 170,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.BLACK,
                    tooltipRoundedRadius: 8,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = barData[group.x.toInt()];
                      return BarTooltipItem(
                        "${item['label']}: ${rod.toY.toInt()}",
                        const TextStyle(
                          color: AppColors.WHITE,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                  touchCallback: (FlTouchEvent event, barTouchResponse) {
                    setState(() {
                      if (!event.isInterestedForInteractions ||
                          barTouchResponse == null ||
                          barTouchResponse.spot == null) {
                        _touchedBarIndex = -1;
                        return;
                      }
                      _touchedBarIndex =
                          barTouchResponse.spot!.touchedBarGroupIndex;
                    });
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 26,
                      interval: yInterval,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toInt().toString(),
                          style: const TextStyle(
                            fontSize: 10.5,
                            color: AppColors.GREY,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= barData.length) {
                          return const SizedBox.shrink();
                        }
                        final item = barData[index];
                        final isTouched = index == _touchedBarIndex;
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            item['label'],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isTouched
                                  ? FontWeight.bold
                                  : FontWeight.w500,
                              color: isTouched
                                  ? AppColors.THEME_COLOR
                                  : AppColors.BLACK_54,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: yInterval,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: AppColors.GREY_SHADE_300.withValues(alpha: 0.6),
                    strokeWidth: 0.8,
                  ),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: const Border(
                    bottom: BorderSide(
                      color: AppColors.GREY_SHADE_300,
                      width: 1,
                    ),
                  ),
                ),
                barGroups: List.generate(barData.length, (i) {
                  final item = barData[i];
                  final isTouched = i == _touchedBarIndex;
                  final val = (item['value'] as int).toDouble();

                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: val,
                        color: isTouched
                            ? AppColors.THEME_COLOR
                            : AppColors.THEME_COLOR.withValues(alpha: 0.82),
                        width: isTouched ? 22 : 18,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: maxY,
                          color: AppColors.GREY_SHADE_50,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),

          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: barData.map((e) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.GREY_SHADE_50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.GREY_SHADE_300.withValues(alpha: 0.7),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      e['icon'] as IconData,
                      size: 13,
                      color: AppColors.THEME_COLOR,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      "${e['label']}: ${e['value']}",
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.BLACK,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          // Web telemetry standard ke according Lead Conversion Banner (Section 7.6)
          _buildConversionBanner(totalLeads, scaledViews),
        ],
      ),
    );
  }

  // Web section 7.6 ke mutabiq lead conversion rate banner
  Widget _buildConversionBanner(int totalLeads, int views) {
    final double convRate = views > 0 ? ((totalLeads / views) * 100) : 0.0;
    final Color badgeColor;
    final String convTitle;

    // Web color tiers: >=12% emerald teal, >=5% blue, <5% grey
    if (convRate >= 12.0) {
      badgeColor = AppColors.THEME_COLOR;
      convTitle = "High Intent Conversion";
    } else if (convRate >= 5.0) {
      badgeColor = Colors.blue.shade700;
      convTitle = "Healthy Engagement Rate";
    } else {
      badgeColor = AppColors.GREY;
      convTitle = "Directory Engagement";
    }

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_up_rounded, size: 22, color: badgeColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      convTitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                    Text(
                      "${convRate.toStringAsFixed(1)}% Conv.",
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  "$totalLeads total inquiries generated from $views visits (${_getTimeRangeLabel().toLowerCase()})",
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: AppColors.BLACK_54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // 4. RATING DISTRIBUTION (Aligned with ListingDetailScreen)
  // ==============================================================
  Widget _buildRatingDistributionSection(Listing listing) {
    final stats = listing.ratingStats;
    final totalRatings = listing.ratingCount > 0 ? listing.ratingCount : 1;

    final starTiers = [5, 4, 3, 2, 1];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Ratings Breakdown",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.BLACK,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                children: [
                  Text(
                    listing.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.bold,
                      color: AppColors.BLACK,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(5, (index) {
                      return Icon(
                        index + 1 <= listing.rating.round()
                            ? Icons.star
                            : Icons.star_border,
                        size: 15,
                        color: AppColors.AMBER,
                      );
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${listing.ratingCount} ratings",
                    style: const TextStyle(fontSize: 11.5, color: AppColors.GREY),
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                height: 92,
                width: 1,
                color: AppColors.GREY_SHADE_300,
              ),
              Expanded(
                child: Column(
                  children: starTiers.map((star) {
                    final count = stats['$star'] ?? 0;
                    final pct = count / totalRatings;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2.5),
                      child: Row(
                        children: [
                          Text(
                            "$star",
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.BLACK_54,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.star,
                            size: 12,
                            color: AppColors.AMBER,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: pct,
                                minHeight: 6,
                                backgroundColor: AppColors.GREY_SHADE_100,
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  AppColors.THEME_COLOR,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 22,
                            child: Text(
                              "$count",
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.GREY,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==============================================================
  // 5. CATEGORY FACTOR RATINGS
  // ==============================================================
  Widget _buildFactorRatingsSection(Listing listing) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Performance Factors",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.BLACK,
            ),
          ),
          const SizedBox(height: 12),
          ...listing.factorAvgRatings.entries.map((entry) {
            final score = entry.value;
            final pct = (score / 5.0).clamp(0.0, 1.0);

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.BLACK,
                        ),
                      ),
                      Text(
                        "${score.toStringAsFixed(1)} / 5",
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.THEME_COLOR,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: AppColors.GREY_SHADE_100,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                        AppColors.THEME_COLOR,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==============================================================
  // 6. CUSTOMER FEEDBACK & REVIEWS
  // ==============================================================
  Widget _buildReviewsFeedSection(Listing listing) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Customer Feedback",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.BLACK,
                ),
              ),
              Text(
                "${listing.reviews} Reviews",
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColors.GREY,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip("All", 'all'),
                const SizedBox(width: 8),
                _buildFilterChip("5 ★", '5'),
                const SizedBox(width: 8),
                _buildFilterChip("4 ★", '4'),
                const SizedBox(width: 8),
                _buildFilterChip("1-3 ★", 'critical'),
              ],
            ),
          ),
          const SizedBox(height: 14),

          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('listings')
                .doc(listing.listingId)
                .collection('reviews')
                .orderBy('createdAt', descending: true)
                .limit(25)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 22),
                  decoration: BoxDecoration(
                    color: AppColors.GREY_SHADE_50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.GREY_SHADE_300.withValues(alpha: 0.7),
                    ),
                  ),
                  child: const Column(
                    children: [
                      Icon(
                        Icons.rate_review_outlined,
                        size: 32,
                        color: AppColors.GREY,
                      ),
                      SizedBox(height: 8),
                      Text(
                        "No customer reviews yet",
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.BLACK_54,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "Customer ratings and comments will appear here.",
                        style: TextStyle(fontSize: 11.5, color: AppColors.GREY),
                      ),
                    ],
                  ),
                );
              }

              final allReviews = snap.data!.docs
                  .map(
                    (d) => Review.fromJson(
                      d.data() as Map<String, dynamic>,
                      d.id,
                    ),
                  )
                  .toList();

              final filtered = allReviews.where((r) {
                if (_selectedReviewFilter == '5') return r.rating >= 4.5;
                if (_selectedReviewFilter == '4') {
                  return r.rating >= 3.5 && r.rating < 4.5;
                }
                if (_selectedReviewFilter == 'critical') return r.rating < 3.5;
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Center(
                    child: Text(
                      "No reviews in this filter",
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.GREY,
                      ),
                    ),
                  ),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (context, index) => Divider(
                  color: AppColors.GREY_SHADE_300.withValues(alpha: 0.7),
                  height: 18,
                ),
                itemBuilder: (context, i) => _buildReviewTile(filtered[i]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String key) {
    final isSelected = _selectedReviewFilter == key;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        setState(() {
          _selectedReviewFilter = key;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.THEME_COLOR : AppColors.GREY_SHADE_100,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected ? AppColors.WHITE : AppColors.BLACK_54,
          ),
        ),
      ),
    );
  }

  Widget _buildReviewTile(Review r) {
    final initials = CommonMethods.getInitials(r.userName);
    final dateStr = DateFormat('MMM d, yyyy').format(r.createdAt);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 15,
              backgroundColor: AppColors.GREY_SHADE_300,
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.BLACK,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.userName.isNotEmpty ? r.userName : "Customer",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.BLACK,
                    ),
                  ),
                  Text(
                    dateStr,
                    style: const TextStyle(fontSize: 11, color: AppColors.GREY),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.GREY_SHADE_100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star, size: 13, color: AppColors.AMBER),
                  const SizedBox(width: 3),
                  Text(
                    r.rating.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.BLACK,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (r.comment.isNotEmpty) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Text(
              r.comment,
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.BLACK_54,
                height: 1.35,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ==============================================================
  // 7. STORE PROFILE HEALTH
  // ==============================================================
  Widget _buildStoreHealthSection(Listing listing) {
    int score = 30;
    if (listing.images.length >= 3) score += 20;
    if (listing.description.isNotEmpty && listing.description.length > 30) {
      score += 15;
    }
    if (listing.businessHours.isNotEmpty) score += 15;
    if (listing.social.isNotEmpty) score += 10;
    if (listing.phone.isNotEmpty) score += 10;

    score = score.clamp(0, 100);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Profile Health",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.BLACK,
                ),
              ),
              Text(
                "$score% Complete",
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.THEME_COLOR,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: score / 100.0,
              minHeight: 7,
              backgroundColor: AppColors.GREY_SHADE_100,
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.THEME_COLOR,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.GREY_SHADE_50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.GREY_SHADE_300.withValues(alpha: 0.7),
              ),
            ),
            child: Column(
              children: [
                _buildHealthCheckItem(
                  title: "Store Photos Added",
                  completed: listing.images.length >= 3,
                  tip: "Add 3+ quality photos to attract more views.",
                ),
                const Divider(height: 16),
                _buildHealthCheckItem(
                  title: "Business Hours Configured",
                  completed: listing.businessHours.isNotEmpty,
                  tip: "Shows 'Open Now' status to nearby users.",
                ),
                const Divider(height: 16),
                _buildHealthCheckItem(
                  title: "Social & Contact Channels",
                  completed:
                      listing.social.isNotEmpty && listing.phone.isNotEmpty,
                  tip: "Add WhatsApp & Website to get more inquiries.",
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHealthCheckItem({
    required String title,
    required bool completed,
    required String tip,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          completed ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: completed ? AppColors.THEME_COLOR : AppColors.GREY,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: completed ? AppColors.BLACK : AppColors.BLACK_54,
                  decoration: completed ? TextDecoration.lineThrough : null,
                ),
              ),
              if (!completed) ...[
                const SizedBox(height: 2),
                Text(
                  tip,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.GREY,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}