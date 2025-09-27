import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/presentation/screens/notification_screen.dart';
import 'package:startup_20/presentation/screens/profile_screen.dart';

class CommonWidgets {
  CommonWidgets._(); // private constructor so it can't be instantiated

  /// 🔹 Top Section (Company + Notifications + Profile + Location Selector)
  static Widget topSection(BuildContext context) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.only(top: 20),
        decoration: BoxDecoration(
          color: AppColors.WHITE,
          // gradient: LinearGradient(
          //   begin: Alignment.topCenter,
          //   end: Alignment.bottomCenter,
          //   colors: [AppColors.THEME_COLOR, AppColors.WHITE, AppColors.WHITE, AppColors.WHITE, AppColors.WHITE],
          // ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              /// 🔹 Top Row: Company | Notifications | Profile
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Company",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.THEME_COLOR,
                    ),
                  ),
                  Row(children: [_notifications(context), _profile(context)]),
                ],
              ),
              const SizedBox(height: 30),

              /// 🔹 Location Selector
              _locationSelector(context),
            ],
          ),
        ),
      ),
    );
  }

  /// 🔹 Notifications Button
  static Widget _notifications(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const NotificationsScreen()),
        );
      },
      child: Container(
        height: 30,
        width: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.GREY_SHADE_100,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(
          Icons.notifications_outlined,
          size: 20,
          color: AppColors.BLACK,
        ),
      ),
    );
  }

  /// 🔹 Profile Button
  static Widget _profile(BuildContext context) {
    return IconButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
      },
      icon: const Icon(Icons.person_outline, color: AppColors.BLACK),
    );
  }

  /// 🔹 Location Selector with PopupMenu
  static Widget _locationSelector(BuildContext context) {
    String currentLocation = "Haldia, West Bengal";

    return StatefulBuilder(
      builder: (context, setState) {
        return PopupMenuButton<String>(
          offset: const Offset(0, 40), // position of dropdown
          color: AppColors.WHITE,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) {
            setState(() {
              currentLocation = value;
            });
          },
          itemBuilder:
              (context) => [
                const PopupMenuItem(
                  value: "Haldia, West Bengal",
                  child: Text(
                    "Haldia, West Bengal",
                    style: TextStyle(color: AppColors.BLACK),
                  ),
                ),
                // 🔹 Add more locations here later
              ],
          child: Row(
            children: [
              const Icon(Icons.location_on_outlined, color: AppColors.BLACK),
              const SizedBox(width: 4),
              Text(
                currentLocation,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  color: AppColors.BLACK,
                ),
              ),
              const Icon(Icons.arrow_drop_down, color: AppColors.BLACK),
            ],
          ),
        );
      },
    );
  }

  static Widget searchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.GREY_SHADE_100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, color: AppColors.GREY),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              "What service do you need?",
              style: TextStyle(color: AppColors.GREY, fontSize: 16),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.THEME_COLOR,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: const Icon(Icons.tune, color: AppColors.WHITE, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  /// Listing Card
  static Widget listingCard(var listing) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.WHITE,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.BLACK_12,
            blurRadius: 6,
            offset: const Offset(1, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 🔹 Image
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Image.network(
              listing.images.isNotEmpty
                  ? (listing.images.first.thumbUrl.isNotEmpty
                      ? listing.images.first.thumbUrl
                      : listing.images.first.fullUrl)
                  : "http://firebasestorage.googleapis.com/v0/b/startup20-5eaa7.firebasestorage.app/o/static%2FImage_Placeholder.jpg?alt=media&token=22a0ec73-6352-4885-bfaf-c485750af28f",
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder:
                  (_, __, ___) => Container(
                    height: 100,
                    width: double.infinity,
                    color: AppColors.GREY_SHADE_300,
                    child: const Icon(
                      Icons.image_not_supported,
                      color: AppColors.GREY,
                    ),
                  ),
            ),
          ),

          // 🔹 Info
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.category,
                  style: const TextStyle(fontSize: 12, color: AppColors.GREY),
                ),
                const SizedBox(height: 4),
                Text(
                  listing.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 14,
                      color: AppColors.GREY,
                    ),
                    const SizedBox(width: 4),
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
                      color: AppColors.THEME_COLOR,
                      size: 16,
                    ),
                    Text(
                      '${listing.rating} (${listing.reviews})',
                      style: const TextStyle(fontSize: 12),
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

  //Shimmer Listing Card
  static Widget shimmerlistingCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300,
        highlightColor: Colors.grey.shade100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fake image
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fake title
                  Container(height: 12, width: 80, color: Colors.grey),
                  const SizedBox(height: 8),
                  // Fake subtitle
                  Container(height: 10, width: 60, color: Colors.grey),
                  const SizedBox(height: 8),
                  // Fake rating
                  Container(height: 10, width: 40, color: Colors.grey),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 Call this method to get the shimmer UI
  static Widget shimmerHomeScreen() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Top Row (Company + Icons)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                shimmerBox(height: 20, width: 100, radius: 4), // Company text
                Row(
                  children: [
                    shimmerCircle(size: 36), // bell icon
                    const SizedBox(width: 12),
                    shimmerCircle(size: 36), // profile icon
                  ],
                ),
              ],
            ),

            const SizedBox(height: 30),

            // 🔹 Location Row
            Row(
              children: [
                shimmerCircle(size: 20),
                const SizedBox(width: 8),
                shimmerBox(height: 16, width: 150, radius: 4),
              ],
            ),

            const SizedBox(height: 16),

            // 🔹 Search Bar
            shimmerBox(height: 50, width: double.infinity, radius: 12),

            const SizedBox(height: 50),

            // 🔹 Banner
            shimmerBox(height: 180, width: double.infinity, radius: 16),

            const SizedBox(height: 30),

            // 🔹 Section Header (Popular Categories + See All)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                shimmerBox(height: 18, width: 120, radius: 4),
                shimmerBox(height: 14, width: 50, radius: 4),
              ],
            ),

            const SizedBox(height: 30),

            // 🔹 Categories Grid (3x3 placeholders)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.8,
              ),
              itemCount: 8,
              itemBuilder: (context, index) {
                return Column(
                  children: [
                    shimmerBox(height: 50, width: 50, radius: 12),
                    const SizedBox(height: 6),
                    shimmerBox(height: 12, width: 40, radius: 4),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 🔹 Reusable Shimmer Box
  static Widget shimmerBox({
    required double height,
    required double width,
    double radius = 8,
  }) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  /// 🔹 Reusable Shimmer Circle
  static Widget shimmerCircle({required double size}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade300,
      highlightColor: Colors.grey.shade100,
      child: Container(
        height: size,
        width: size,
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  /// 🔹 Footer Tagline
  static Widget footerTagline() {
    return Container(
      width: double.infinity,
      color: AppColors.GREY_SHADE_300,
      padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 25),
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Shops \n& Services \nThat Matter to You!",
            style: TextStyle(
              fontSize: 30, // Bigger for impact
              fontWeight: FontWeight.bold,
              color: AppColors.BLACK_54,
            ),
            textAlign: TextAlign.left,
          ),
          const SizedBox(height: 20),
          Text(
            "Crafted with ❤️ in West Bengal",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
