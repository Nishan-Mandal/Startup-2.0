import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/user_model.dart';
import 'package:startup_20/presentation/screens/add_listing_screen.dart';
import 'package:startup_20/presentation/screens/listing_map_screen.dart';
import 'package:startup_20/presentation/screens/listing_screen.dart';
import 'package:startup_20/providers/auth_provider.dart';

class ContributionScreen extends StatefulWidget {
  const ContributionScreen({super.key});

  @override
  State<ContributionScreen> createState() => _ContributionScreenState();
}

class _ContributionScreenState extends State<ContributionScreen> {
  AppUser? currentUser;
  bool isLoading = true;

  /// 🔹 Leaderboard state
  List<Map<String, dynamic>> topContributors = [];
  bool leaderboardLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
    _fetchTopContributors();
  }

  Future<void> _loadUser() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId != null) {
        final doc = FirebaseFirestore.instance.collection('users').doc(userId);
        final user = await doc.get();
        if (user.exists) {
          setState(() {
            currentUser = AppUser.fromMap(user.data()!, user.id);
            isLoading = false;
          });
        } else {
          setState(() => isLoading = false);
        }
      } else {
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching user: $e");
      setState(() => isLoading = false);
    }
  }

  /// 🔹 Fetch top contributors for the current week
  Future<void> _fetchTopContributors() async {
    try {
      // You can add filters using .where('from', isLessThanOrEqualTo: DateTime.now()) etc.
      final snapshot =
          await FirebaseFirestore.instance
              .collection('top-contributors')
              .orderBy('kudos', descending: true)
              .limit(3)
              .get();

      final data = snapshot.docs.map((doc) => doc.data()).toList();

      if (mounted) {
        setState(() {
          topContributors = data;
          leaderboardLoading = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error fetching top contributors: $e");
      if (mounted) setState(() => leaderboardLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.WHITE,
      appBar: AppBar(
        backgroundColor: AppColors.THEME_COLOR,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          "Your Contribution",
          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.WHITE),
        ),
        actions: [
          Row(
            children: [
              Icon(Icons.handshake, color: AppColors.AMBER),
              SizedBox(width: 4),
              Text(
                currentUser == null ? '0' : '${currentUser?.kudos}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: AppColors.WHITE,
                ),
              ),
              SizedBox(width: 12),
            ],
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kudos Balance Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.GREY_SHADE_100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.handshake, color: AppColors.AMBER, size: 40),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Your Kudos",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            currentUser == null ? '0' : '${currentUser?.kudos}',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.THEME_COLOR,
                      foregroundColor: AppColors.BLACK,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {},
                    child: const Text(
                      "Redeem",
                      style: TextStyle(color: AppColors.WHITE),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Contribution Options
            GridView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.1,
              ),
              children: [
                _contributionCard(
                  icon: Icons.storefront,
                  title: "Add a Store/Service",
                  subtitle: "Help expand the community",
                  reward: "200",
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => AddListingScreen()),
                    );
                  },
                ),
                if (!AppAuthProvider.isAnonymousUser() &&
                    currentUser?.role == 'admin')
                  _contributionCard(
                    icon: Icons.list_alt,
                    title: "Submitted Listings",
                    subtitle: "Waiting for your approval",
                    reward: null,
                    comingSoon: false,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder:
                              (context) => ListingPage(
                                title: 'Pending Approvals',
                                query: FirebaseFirestore.instance
                                    .collection("listings")
                                    .where("verifiedBy", isNull: true)
                                    .orderBy("createdAt"),
                              ),
                        ),
                      );
                    },
                  ),
                _contributionCard(
                  icon: Icons.group_add,
                  title: "Refer a friend",
                  subtitle: "Invite & earn extra Kudos",
                  reward: "150",
                  comingSoon: true,
                ),
                _contributionCard(
                  icon: Icons.card_giftcard,
                  title: "Redeem Kudos",
                  subtitle: "Exchange for rewards",
                  reward: null,
                  comingSoon: true,
                ),
              ],
            ),

            const SizedBox(height: 20),

            // ✅ Leaderboard Section
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.GREY_SHADE_100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "🔥 Top Contributors This Week",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),

                  if (leaderboardLoading)
                    const Center(child: CircularProgressIndicator())
                  else if (topContributors.isEmpty)
                    const Text("No contributors this week 😅")
                  else
                    Column(
                      children: List.generate(topContributors.length, (index) {
                        final contributor = topContributors[index];
                        final medals = ["🥇", "🥈", "🥉"];
                        return _leaderboardItem(
                          medal: medals[index],
                          name: contributor['name'] ?? 'Unknown',
                          kudos: contributor['kudos'] ?? 0,
                        );
                      }),
                    ),

                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: () {
                        if (!AppAuthProvider.isAnonymousUser() &&
                            currentUser?.role == 'admin') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const ListingMapScreen(),
                            ),
                          );
                          return;
                        }

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              "✨ That’s all for now! Check back soon for more top contributors.",
                            ),
                            duration: Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.BLACK_54,
                          ),
                        );
                      },
                      child: const Text("See all"),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contributionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    String? reward,
    VoidCallback? onTap,
    bool comingSoon = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.GREY_SHADE_100,
              borderRadius: BorderRadius.circular(12),
            ),
            width: double.infinity,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 40, color: AppColors.BLACK_54),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.BLACK_54,
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          if (reward != null)
            Positioned(
              right: 8,
              top: 8,
              child: Row(
                children: [
                  const Icon(Icons.handshake, color: AppColors.AMBER, size: 16),
                  Text(
                    reward,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

          if (comingSoon)
            Positioned(
              left: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  color: AppColors.THEME_COLOR,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: const Text(
                  "Coming Soon",
                  style: TextStyle(
                    color: AppColors.WHITE,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _leaderboardItem({
    required String medal,
    required String name,
    required int kudos,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(medal, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          Text(
            "$kudos Kudos",
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
