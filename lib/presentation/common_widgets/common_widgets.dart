import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/presentation/screens/logins/signin_screen.dart';
import 'package:startup_20/presentation/screens/notification_screen.dart';
import 'package:startup_20/presentation/screens/profile_screen.dart';
import 'package:startup_20/providers/auth_provider.dart';

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
    final authProvider = Provider.of<AppAuthProvider>(context);

    if (AppAuthProvider.isAnonymousUser()) {
      // If not logged in or anonymous → no unread count stream
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const NotificationsScreen(),
            ),
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

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection('users')
              .doc(authProvider.user?.uid)
              .collection('notifications')
              .where('isRead', isEqualTo: false)
              .snapshots(),
      builder: (context, snapshot) {
        int unreadCount = 0;
        if (snapshot.hasData) {
          unreadCount = snapshot.data!.docs.length;
        }

        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const NotificationsScreen(),
              ),
            );
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
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

              // 🔴 Red badge for unread count
              if (unreadCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.RED,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Center(
                      child: Text(
                        unreadCount > 9 ? '9+' : unreadCount.toString(),
                        style: const TextStyle(
                          color: AppColors.WHITE,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// 🔹 Profile Button
  static Widget _profile(BuildContext context) {
    return IconButton(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder:
                (context) =>
                    AppAuthProvider.isAnonymousUser()
                        ? SignInScreen()
                        : const ProfileScreen(),
          ),
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
              const Icon(Icons.location_on_outlined, color: AppColors.BLACK, size: 20,),
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
    return const _AnimatedSearchBar();
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
              height: 100,
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
                    const Icon(Icons.star, color: AppColors.AMBER, size: 16),
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
        color: AppColors.WHITE,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Shimmer.fromColors(
        baseColor: AppColors.GREY_SHADE_300,
        highlightColor: AppColors.GREY_SHADE_100,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fake image
            Container(
              height: 100,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.GREY,
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
                  Container(height: 12, width: 80, color: AppColors.GREY),
                  const SizedBox(height: 8),
                  // Fake subtitle
                  Container(height: 10, width: 60, color: AppColors.GREY),
                  const SizedBox(height: 8),
                  // Fake rating
                  Container(height: 10, width: 40, color: AppColors.GREY),
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
      baseColor: AppColors.GREY_SHADE_300,
      highlightColor: AppColors.GREY_SHADE_100,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: AppColors.WHITE,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }

  /// 🔹 Reusable Shimmer Circle
  static Widget shimmerCircle({required double size}) {
    return Shimmer.fromColors(
      baseColor: AppColors.GREY_SHADE_300,
      highlightColor: AppColors.GREY_SHADE_100,
      child: Container(
        height: size,
        width: size,
        decoration: const BoxDecoration(
          color: AppColors.WHITE,
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

  static OverlayEntry? _overlayEntry;

  /// Show loader overlay
  static void showLoader(BuildContext context, {String? message}) {
    if (_overlayEntry != null) return; // Prevent multiple overlays

    _overlayEntry = OverlayEntry(
      builder:
          (_) => Stack(
            children: [
              // Dim background
              Opacity(
                opacity: 0.5,
                child: ModalBarrier(color: AppColors.BLACK, dismissible: false),
              ),
              // Centered circular progress indicator
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      color: AppColors.WHITE,
                      strokeWidth: 3,
                    ),
                    if (message != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        message,
                        style: const TextStyle(
                          color: AppColors.WHITE,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
    );

    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  /// Hide loader overlay
  static void hideLoader() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class _AnimatedSearchBar extends StatefulWidget {
  const _AnimatedSearchBar({Key? key}) : super(key: key);

  @override
  State<_AnimatedSearchBar> createState() => _AnimatedSearchBarState();
}

class _AnimatedSearchBarState extends State<_AnimatedSearchBar> {
  final List<String> keywords = [
    "\"Room Rent\"",
    "\"Electrician\"",
    "\"Salons\"",
    "\"Cafe\"",
    "\"Gym\"",
  ];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // rotate every 2 seconds
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) return;
      setState(() {
        _index = (_index + 1) % keywords.length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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

          // "Search for" fixed + animated keyword
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  "Search for ",
                  style: TextStyle(
                    color: AppColors.GREY,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                Text(
                  keywords[_index],
                  key: ValueKey<int>(_index),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.GREY,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.THEME_COLOR,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.tune, color: AppColors.WHITE, size: 20),
          ),
        ],
      ),
    );
  }
}
