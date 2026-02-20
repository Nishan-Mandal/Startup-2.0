import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/conversation_model.dart';
import 'package:startup_20/presentation/common_methods/common_methods.dart';
import 'package:startup_20/presentation/common_widgets/common_widgets.dart';
import 'package:startup_20/presentation/screens/conversation/chat_room_screen.dart';
import 'package:startup_20/presentation/screens/home_screen.dart';
import 'package:startup_20/providers/auth_provider.dart';
import 'package:startup_20/providers/bottom_nav_provider.dart';
import 'package:startup_20/providers/chat_provider.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.WHITE,
      body: CustomScrollView(
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
                stream:
                    FirebaseFirestore.instance
                        .collection("conversations")
                        .orderBy("lastMessageAt", descending: true)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData ||
                      FirebaseAuth.instance.currentUser == null) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allConversations =
                      snapshot.data!.docs
                          .map((doc) => Conversation.fromDoc(doc))
                          .toList();

                  // ✅ Filter only group chats OR direct chats containing this user
                  final conversations =
                      allConversations.where((conv) {
                        if (conv.type == 'group') {
                          return true; // include all groups
                        }
                        if (conv.type == 'direct' || conv.type == 'support') {
                          return conv.participantIds.contains(
                            FirebaseAuth.instance.currentUser!.uid,
                          ); // include only if user is participant
                        }
                        return false;
                      }).toList();

                  if (conversations.isEmpty) {
                    return const Center(child: Text("No conversations yet"));
                  }

                  // 🔹 Split into groups & direct chats
                  final groups =
                      conversations.where((c) => c.type == "group").toList();
                  final people =
                      conversations
                          .where(
                            (c) => c.type == "direct" || c.type == "support",
                          )
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
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 0,
                            ),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor: AppColors.AMBER,
                              child: Text(
                                CommonMethods.getInitials(g.groupName ?? 'G'),
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.BLACK,
                                ),
                              ),
                            ),
                            title: Text(
                              g.groupName ?? 'Group',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              g.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: StreamBuilder<QuerySnapshot>(
                              stream:
                                  FirebaseFirestore.instance
                                      .collection('conversations')
                                      .doc(g.conversationId)
                                      .collection('messages')
                                      .where('status', isEqualTo: 'sent')
                                      .where(
                                        'senderId',
                                        isNotEqualTo:
                                            FirebaseAuth
                                                .instance
                                                .currentUser!
                                                .uid,
                                      )
                                      .snapshots(),
                              builder: (context, snapshot) {
                                final hasUnread =
                                    snapshot.hasData &&
                                    snapshot.data!.docs.isNotEmpty;
                                return Text(
                                  CommonMethods.formatMessageTime(
                                    g.lastMessageAt,
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        hasUnread
                                            ? AppColors.THEME_COLOR
                                            : AppColors.BLACK_54,
                                  ),
                                );
                              },
                            ),

                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => ChatRoomScreen(
                                        conversationId: g.conversationId,
                                        otherUserId: "",
                                        type: "group",
                                        title: g.groupName ?? 'Group',
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
                        ...people.map((p) {
                          // Get the other participant's name
                          String otherUserName = "Unknown";
                          for (var participant in p.participants) {
                            if (!participant.containsKey(
                              FirebaseAuth.instance.currentUser!.uid,
                            )) {
                              // pick the first participant that is not the current user
                              otherUserName =
                                  p.type == 'support'
                                      ? p.initiatedBy ==
                                              FirebaseAuth
                                                  .instance
                                                  .currentUser
                                                  ?.displayName
                                          ? 'Support 24/7'
                                          : p.initiatedBy
                                      : participant.values.first;
                              break;
                            }
                          }
                          return ListTile(
                            // splashColor: Colors.transparent,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 0,
                            ),
                            leading: CircleAvatar(
                              radius: 22,
                              backgroundColor:
                                  p.type == 'support'
                                      ? AppColors.WHITE
                                      : AppColors.THEME_COLOR,
                              child:
                                  p.type == 'support'
                                      ? Image.asset(
                                        'assets/images/companyLogo.png',
                                      )
                                      : Text(
                                        CommonMethods.getInitials(
                                          otherUserName,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.WHITE,
                                        ),
                                      ),
                            ),
                            title: Text(
                              otherUserName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              p.lastMessage,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: StreamBuilder<QuerySnapshot>(
                              stream:
                                  FirebaseFirestore.instance
                                      .collection('conversations')
                                      .doc(p.conversationId)
                                      .collection('messages')
                                      .where('status', isEqualTo: 'sent')
                                      .where(
                                        'senderId',
                                        isNotEqualTo:
                                            FirebaseAuth
                                                .instance
                                                .currentUser!
                                                .uid,
                                      )
                                      .snapshots(),
                              builder: (context, snapshot) {
                                final hasUnread =
                                    snapshot.hasData &&
                                    snapshot.data!.docs.isNotEmpty;
                                return Text(
                                  CommonMethods.formatMessageTime(
                                    p.lastMessageAt,
                                  ),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color:
                                        hasUnread
                                            ? AppColors.THEME_COLOR
                                            : AppColors.BLACK_54,
                                  ),
                                );
                              },
                            ),

                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) => ChatRoomScreen(
                                        conversationId: p.conversationId,
                                        otherUserId:
                                            "", // optional, you can pass the userId if needed
                                        type: "direct",
                                        title:
                                            otherUserName, // directly pass the name
                                      ),
                                ),
                              );
                            },
                          );
                        }),
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
