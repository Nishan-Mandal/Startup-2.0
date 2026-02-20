import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/user_model.dart';
import 'package:startup_20/presentation/common_methods/common_methods.dart';
import 'package:startup_20/presentation/screens/legal_page_screen.dart';
import 'package:startup_20/presentation/screens/listing_screen.dart';
import 'package:startup_20/presentation/screens/logins/signin_screen.dart';
import 'package:startup_20/providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool isLoading = true;
  AppUser? currentUser;
  List<String>? favIds;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  /// 🔹 Fetch current user data from Firestore
  Future<void> _loadUser() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final doc = FirebaseFirestore.instance.collection('users').doc(userId);

        final user = await doc.get();

        final favSnapshot = await doc.collection("favorites").get();

        if (user.exists) {
          setState(() {
            currentUser = AppUser.fromMap(user.data()!, user.id);
            favIds = favSnapshot.docs.map((doc) => doc.id).toList();
            isLoading = false;
          });
        } else {
          setState(() => isLoading = false);
        }
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      print("Error fetching user: $e");
      setState(() => isLoading = false);
    }
  }

  void _showLogoutConfirmation() {
  showDialog(
    context: context,
    barrierDismissible: false, // user must choose Yes/No
    builder: (context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        title: const Text(
          "Logout",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: const Text(
          "Are you sure you want to logout?",
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // close dialog

              // Perform logout
              final authProvider =
                  Provider.of<AppAuthProvider>(context, listen: false);
              authProvider.signOut();

              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => SignInScreen(skip: false),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.THEME_COLOR,
            ),
            child: const Text("Logout",style: TextStyle(color: AppColors.WHITE),),
          ),
        ],
      );
    },
  );
}


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text(
            "Profile",
            style: TextStyle(color: AppColors.WHITE),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: AppColors.WHITE),
          backgroundColor: AppColors.THEME_COLOR,
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("User data not found")));
    }

    return Scaffold(
      backgroundColor: AppColors.GREY_SHADE_100,
      appBar: AppBar(
        title: const Text("Profile", style: TextStyle(color: AppColors.WHITE)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: AppColors.WHITE),
        backgroundColor: AppColors.THEME_COLOR,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 🧍 User Info Section
              Container(
                padding: const EdgeInsets.all(16),
                color: AppColors.WHITE,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      child: Text(
                        CommonMethods.getInitials(currentUser!.name),
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentUser!.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(currentUser!.phone ?? ""),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // 💰 Kudos Wallet
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.WHITE,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      "Your Kudos",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        const Icon(Icons.handshake, color: AppColors.AMBER),
                        const SizedBox(width: 6),
                        Text("${currentUser!.kudos ?? 0}"),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.THEME_COLOR,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            "Redeem",
                            style: TextStyle(color: AppColors.WHITE),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              /// 🔹 My Activity Section
              _buildSection("My Activity", [
                _buildTile(Icons.store, "My Listings", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (context) => ListingPage(
                            title: "My Listings",
                            query: FirebaseFirestore.instance
                                .collection("listings")
                                .where(
                                  "addedBy",
                                  isEqualTo: currentUser!.userId,
                                )
                                .orderBy("createdAt", descending: true),
                          ),
                    ),
                  );
                }),
                _buildTile(Icons.group_add, "My Referrals", () {}),
                _buildTile(Icons.favorite, "Saved Services", () {
                  if (favIds != null && favIds!.isNotEmpty) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => ListingPage(
                              title: "Saved Services",
                              query: FirebaseFirestore.instance
                                  .collection("listings")
                                  .where("listingId", whereIn: favIds)
                                  .where("verifiedBy", isNull: false),
                            ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("You don't have any saved listing yet!"),
                      ),
                    );
                  }
                }),
              ]),

              /// 🔹 Rewards Section
              _buildSection("Rewards & Kudos (coming soon..)", [
                _buildTile(Icons.wallet_giftcard, "Kudos Wallet", () {}),
                _buildTile(Icons.history, "Redeem History", () {}),
              ]),

              /// 🔹 Settings Section
              _buildSection("Help & Information", [
                _buildTile(Icons.info, "About Us", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LegalPageScreen(pageId: "about_us"),
                    ),
                  );
                }),
                _buildTile(Icons.lock, "Privacy Policy", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LegalPageScreen(pageId: "privacy_policy"),
                    ),
                  );
                }),
                _buildTile(Icons.language, "Terms of Service", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LegalPageScreen(pageId: "terms_service"),
                    ),
                  );
                }),
                _buildTile(Icons.help, "Help & Support", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LegalPageScreen(pageId: "contact_us"),
                    ),
                  );
                }),
              ]),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: ElevatedButton(
                  onPressed: () {
                    _showLogoutConfirmation();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.WHITE,
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text("Logout"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> tiles) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const Divider(),
          ...tiles,
        ],
      ),
    );
  }

  Widget _buildTile(IconData icon, String text, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: AppColors.THEME_COLOR),
      title: Text(text),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
