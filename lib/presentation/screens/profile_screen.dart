import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/presentation/common_methods/common_methods.dart';
import 'package:startup_20/presentation/screens/logins/signin_screen.dart';
import 'package:startup_20/providers/auth_provider.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text("Profile"),
        centerTitle: true,
        backgroundColor: AppColors.THEME_COLOR,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            /// 🔹 User Info Section
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundImage: NetworkImage(
                      "https://i.pravatar.cc/150?img=12",
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Nishan Mandal",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Text("Haldia, West Bengal"),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            /// 🔹 Kudos Wallet
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Your Kudos",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.handshake, color: Colors.amber),
                      const SizedBox(width: 6),
                      const Text("250"),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text("Redeem"),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            /// 🔹 My Activity Section
            _buildSection("My Activity", [
              _buildTile(Icons.store, "My Listings", () {}),
              _buildTile(Icons.group_add, "My Referrals", () {}),
              _buildTile(Icons.chat, "My Chats", () {}),
              _buildTile(Icons.favorite, "Saved Services", () {}),
            ]),

            /// 🔹 Rewards Section
            _buildSection("Rewards & Kudos", [
              _buildTile(Icons.wallet_giftcard, "Kudos Wallet", () {}),
              _buildTile(Icons.history, "Redeem History", () {}),
            ]),

            /// 🔹 Settings Section
            _buildSection("Settings", [
              _buildTile(Icons.notifications, "Notifications", () {}),
              _buildTile(Icons.lock, "Privacy & Security", () {}),
              _buildTile(Icons.language, "Language & Region", () {}),
              _buildTile(Icons.help, "Help & Support", () {}),
              _buildTile(Icons.info, "About Us", () {}),
            ]),

            const SizedBox(height: 20),

            /// 🔹 Logout Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: () {
                  authProvider.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => SignInScreen()),
                  );
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
            const SizedBox(height: 40),
          ],
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
      leading: Icon(icon, color: Colors.orange),
      title: Text(text),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}
