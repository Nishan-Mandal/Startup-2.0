import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/message_model.dart';
import 'package:startup_20/presentation/common_methods/common_methods.dart';
import 'package:startup_20/providers/auth_provider.dart';
import 'package:startup_20/providers/chat_provider.dart';

class ChatRoomScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserId;
  final String type;
  final String title;

  const ChatRoomScreen({
    super.key,
    required this.conversationId,
    required this.otherUserId,
    required this.type,
    required this.title,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool unreadSeparatorShown = false;


  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    _markMessagesAsRead();
  }

  void _markMessagesAsRead() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final conversationRef = FirebaseFirestore.instance
        .collection("conversations")
        .doc(widget.conversationId);

    final messagesRef = conversationRef.collection("messages");

    // Step 1: Fetch messages not sent by the current user and not yet seen
    final messagesSnap =
        await messagesRef
            .where("senderId", isNotEqualTo: currentUser.uid)
            .where("status", isEqualTo: "sent")
            .get();

    // Step 2: Batch update messages to 'seen'
    final batch = FirebaseFirestore.instance.batch();
    for (var doc in messagesSnap.docs) {
      batch.update(doc.reference, {"status": "seen"});
    }

    // Step 3: Update conversation's updatedAt field
    batch.update(conversationRef, {"updatedAt": FieldValue.serverTimestamp()});

    // Step 4: Commit batch
    await batch.commit();
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    _messageController.clear();
    if (text.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final conversationRef = FirebaseFirestore.instance
        .collection("conversations")
        .doc(widget.conversationId);

    final messageRef = conversationRef.collection("messages").doc();

    // 🔹 Step 1: Add message to messages subcollection
    await messageRef.set({
      "messageId": messageRef.id,
      "senderId": user.uid,
      "senderName": user.displayName,
      "text": text,
      "attachments": [],
      "status": "sent",
      "createdAt": FieldValue.serverTimestamp(),
    });

    final userName = await CommonMethods.getUserName(user.uid);

    // 🔹 Step 2: Handle conversation update based on type and first-time message
    if (widget.type == 'direct') {
      final conversationSnap = await conversationRef.get();

      if (!conversationSnap.exists) {
        // 🆕 First message in direct chat → create conversation document
        final otherUserName = await CommonMethods.getUserName(
          widget.otherUserId,
        );

        await conversationRef.set({
          "conversationId": widget.conversationId,
          "type": "direct",
          "participantIds": [user.uid, widget.otherUserId],
          "participants": [
            {user.uid: userName ?? "You"},
            {widget.otherUserId: otherUserName ?? "Unknown"},
          ],
          "lastMessage": text,
          "lastMessageAt": FieldValue.serverTimestamp(),
          "createdAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        });
      } else {
        // ✏️ Conversation exists → just update message info
        await conversationRef.update({
          "lastMessage": text,
          "lastMessageAt": FieldValue.serverTimestamp(),
          "updatedAt": FieldValue.serverTimestamp(),
        });
      }
    } else {
      // 🔸 For non-direct (e.g., group) conversations
      await conversationRef.update({
        "conversationId": FieldValue.arrayUnion([user.uid]),
        "lastMessage": text,
        "lastMessageAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      });
    }

    // 🔹 Step 3: Scroll to bottom
    Future.delayed(const Duration(milliseconds: 200), () {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AppAuthProvider>(context);
    return Scaffold(
      backgroundColor: AppColors.GREY_SHADE_50,
      appBar: AppBar(
        centerTitle: true,
        title: Text(
          widget.title,
          style: TextStyle(color: AppColors.WHITE, fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.THEME_COLOR,
        iconTheme: IconThemeData(color: AppColors.WHITE),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream:
                  FirebaseFirestore.instance
                      .collection("conversations")
                      .doc(widget.conversationId)
                      .collection("messages")
                      .orderBy("createdAt")
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages =
                    snapshot.data!.docs
                        .map((doc) => ChatMessage.fromDoc(doc))
                        .toList();

                return ListView.builder(
                  controller: _scrollController,
                  itemCount: messages.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final isMe = m.senderId == authProvider.user!.uid;

                    // Insert separator before the first unread message
                    if (!unreadSeparatorShown && m.status != "seen" && !isMe) {
                      unreadSeparatorShown = true;
                      return Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: const Text(
                              "Unread messages",
                              style: TextStyle(
                                color: AppColors.GREY,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),

                          _buildMessageBubble(m, isMe),
                        ],
                      );
                    }
                    return _buildMessageBubble(m, isMe);
                  },
                );
              },
            ),
          ),
          // input field
          SafeArea(
            child: Container(
              margin: const EdgeInsets.all(
                8,
              ), // optional spacing from screen edges
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.GREY_SHADE_300,
                  width: 1,
                ), // border color & width
                borderRadius: BorderRadius.circular(20), // rounded corners
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: "Type a message...",
                        border: InputBorder.none, // remove default underline
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 0,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: AppColors.THEME_COLOR),
                    onPressed: _sendMessage,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(m, isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 4,
        horizontal: 8,
      ), // spacing between bubbles
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar for others
          if (!isMe)
            CircleAvatar(
              maxRadius: 15,
              backgroundColor: AppColors.GREY_SHADE_300,
              child: Text(
                CommonMethods.getInitials(m.senderName ?? 'U'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.BLACK,
                ),
              ),
            ),
          if (!isMe)
            const SizedBox(width: 5), // spacing between avatar and bubble
          // Chat bubble
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 5,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isMe ? AppColors.THEME_COLOR : AppColors.GREY_SHADE_300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    m.text,
                    style: TextStyle(
                      color: isMe ? AppColors.WHITE : AppColors.BLACK,
                      fontSize: 15,
                    ),
                  ),
                ),
                const SizedBox(height: 2), // spacing between bubble and time
                Text(
                  CommonMethods.formatMessageTime(m.createdAt),
                  style: const TextStyle(fontSize: 10, color: AppColors.GREY),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
