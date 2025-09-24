import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/presentation/common_widgets/common_widgets.dart';
import 'package:startup_20/presentation/screens/home_screen.dart';
import 'package:startup_20/providers/bottom_nav_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ScrollController _scrollController;
  final List<Map<String, dynamic>> groups = [
    {
      "name": "Haldia",
      "message": "Can anyone help?",
      "time": "Now",
      "unreadCount": 6,
    },
  ];

  final List<Map<String, dynamic>> people = [
    {
      "name": "Souvik",
      "message": "Is this still available for sale?",
      "time": "Yesterday",
      "avatar": "https://i.pravatar.cc/150?img=1",
    },
    {
      "name": "Soumen",
      "message": "Thanks for your help.",
      "time": "14 Sep",
      "avatar": "https://i.pravatar.cc/150?img=2",
    },
    {
      "name": "Nishan",
      "message": "Can anyone help?",
      "time": "12 Sep",
      "avatar": "https://i.pravatar.cc/150?img=3",
    },
    {
      "name": "Gourav",
      "message": "Thanks!",
      "time": "25 Aug",
      "avatar": "https://i.pravatar.cc/150?img=4",
    },
  ];

  @override
  void initState() {
    super.initState();
    _handleScroll();
  }

  void _handleScroll() {
    _scrollController = ScrollController();

    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection ==
          ScrollDirection.reverse) {
        Provider.of<BottomNavProvider>(context, listen: false).hideNavBar();
      } else if (_scrollController.position.userScrollDirection ==
          ScrollDirection.forward) {
        Provider.of<BottomNavProvider>(context, listen: false).showNavBar();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.WHITE,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // 🔹 Top Bar + Location Selector
          CommonWidgets.topSection(context),
      
          // 🔹 Pinned Search Bar
          SliverPersistentHeader(
            pinned: true,
            delegate: SearchBarHeader(child: CommonWidgets.searchBar()),
          ),
      
          // 🔹 Scrollable Content
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                /// Groups
                const Text(
                  "Groups",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                ...groups.map(
                  (g) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.THEME_COLOR,
                      child: Text(
                        g["name"],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.BLACK,
                        ),
                      ),
                    ),
                    title: Text(
                      g["name"],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(g["message"]),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          g["time"],
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.THEME_COLOR,
                          ),
                        ),
                        if (g["unreadCount"] > 0)
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.all(6),
                            decoration: const BoxDecoration(
                              color: AppColors.THEME_COLOR,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              "${g["unreadCount"]}",
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.WHITE
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
      
                /// People
                const Text(
                  "People",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                ...people.map(
                  (p) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 0),
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundImage: NetworkImage(p["avatar"]),
                    ),
                    title: Text(
                      p["name"],
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(p["message"]),
                    trailing: Text(
                      p["time"],
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.BLACK_54,
                      ),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}
