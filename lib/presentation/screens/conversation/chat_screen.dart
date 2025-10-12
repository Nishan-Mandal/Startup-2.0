import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/conversation_model.dart';
import 'package:startup_20/presentation/common_widgets/common_widgets.dart';
import 'package:startup_20/presentation/screens/conversation/chat_room_screen.dart';
import 'package:startup_20/presentation/screens/home_screen.dart';
import 'package:startup_20/providers/bottom_nav_provider.dart';

class ChatScreen extends StatefulWidget {
  final String currentUserId; // Pass logged-in userId
  const ChatScreen({super.key, required this.currentUserId});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late ScrollController _scrollController;

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

          // 🔹 Conversations List from Firestore
          SliverPadding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 15),
            sliver: SliverToBoxAdapter(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection("conversations")
                    .orderBy("lastMessageAt", descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final conversations = snapshot.data!.docs
                      .map((doc) => Conversation.fromDoc(doc))
                      .toList();

                  if (conversations.isEmpty) {
                    return const Center(child: Text("No conversations yet"));
                  }

                  // 🔹 Split into groups & direct chats
                  final groups = conversations
                      .where((c) => c.type == "group")
                      .toList();
                  final people = conversations
                      .where((c) => c.type == "direct")
                      .toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      /// Groups
                      if (groups.isNotEmpty) ...[
                        const Text(
                          "Groups",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        ...groups.map(
                          (g) => ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 0),
                            leading: CircleAvatar(
                              radius: 20,
                              backgroundColor: AppColors.AMBER,
                              child: Text(
                                g.groupName[0],
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.BLACK,
                                ),
                              ),
                            ),
                            title: Text(
                              g.groupName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              g.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              "${g.lastMessageAt.hour}:${g.lastMessageAt.minute.toString().padLeft(2, '0')}",
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.THEME_COLOR,
                              ),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatRoomScreen(
                                    conversationId: g.id,
                                    currentUserId: widget.currentUserId,
                                    title: g.groupName,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      /// People
                      if (people.isNotEmpty) ...[
                        const Text(
                          "People",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        ...people.map(
                          (p) => ListTile(
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 0),
                            leading: const CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.THEME_COLOR,
                              child: Icon(Icons.person,
                                  color: AppColors.WHITE, size: 18),
                            ),
                            title: Text(
                              p.participants
                                  .where((id) => id != widget.currentUserId)
                                  .join(", "),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              p.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Text(
                              "${p.lastMessageAt.hour}:${p.lastMessageAt.minute.toString().padLeft(2, '0')}",
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.BLACK_54,
                              ),
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatRoomScreen(
                                    conversationId: p.id,
                                    currentUserId: widget.currentUserId,
                                    title: "Chat",
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
