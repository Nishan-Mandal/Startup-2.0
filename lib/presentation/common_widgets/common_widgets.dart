import 'package:flutter/material.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/presentation/screens/notification_screen.dart';
import 'package:startup_20/presentation/screens/profile_screen.dart';

class CommonWidgets {
  CommonWidgets._(); // private constructor so it can't be instantiated

  /// 🔹 Top Section (Company + Notifications + Profile + Location Selector)
  static Widget topSection(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.pastelOrnage, AppColors.white],
            ),
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
          color: AppColors.white,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Icon(Icons.notifications_outlined, size: 20),
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
      icon: const Icon(Icons.person_outline),
    );
  }

  /// 🔹 Location Selector with PopupMenu
  static Widget _locationSelector(BuildContext context) {
    String currentLocation = "Haldia, West Bengal";

    return StatefulBuilder(
      builder: (context, setState) {
        return PopupMenuButton<String>(
          offset: const Offset(0, 40), // position of dropdown
          color: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (value) {
            setState(() {
              currentLocation = value;
            });
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: "Haldia, West Bengal",
              child: Text("Haldia, West Bengal"),
            ),
            // 🔹 Add more locations here later
          ],
          child: Row(
            children: [
              const Icon(Icons.location_on_outlined, color: Colors.orange),
              const SizedBox(width: 4),
              Text(
                currentLocation,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        );
      },
    );
  }

  /// 🔹 Footer Tagline
  static Widget footerTagline() {
    return Container(
      width: double.infinity,
      color: Colors.grey.shade200,
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
              color: Colors.black54,
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
