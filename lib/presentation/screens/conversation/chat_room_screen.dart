import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/data/models/message_model.dart';
import 'package:startup_20/presentation/common_methods/common_methods.dart';
import 'package:startup_20/presentation/common_widgets/common_widgets.dart';
import 'package:startup_20/providers/auth_provider.dart';

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
  bool unreadSeparatorShown = false;
  ChatMessage? _replyingTo;

  @override
  void dispose() {
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
      "attachments": {},
      "status": "sent",
      "createdAt": FieldValue.serverTimestamp(),
      "replyTo":
          _replyingTo == null
              ? null
              : {
                "messageId": _replyingTo!.id,
                "senderName": _replyingTo!.senderName,
                "text": _replyingTo!.text,
              },
    });

    final userName = await CommonMethods.getUserData(user.uid, 'name');

    // 🔹 Step 2: Handle conversation update based on type and first-time message
    if (widget.type == 'direct') {
      final conversationSnap = await conversationRef.get();

      if (!conversationSnap.exists) {
        // 🆕 First message in direct chat → create conversation document
        final otherUserName = await CommonMethods.getUserData(
          widget.otherUserId,
          'name',
        );

        await conversationRef.set({
          "conversationId": widget.conversationId,
          "type": "direct",
          "initiatedBy": FirebaseAuth.instance.currentUser?.displayName ?? '',
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
    if (mounted) {
      setState(() {
        _replyingTo = null;
      });
      setState(() => _replyingTo = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appUser = context.read<AppAuthProvider>().appUser;
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
                      .orderBy("createdAt", descending: true)
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
                  reverse: true,
                  itemCount: messages.length,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    final isMe = m.senderId == appUser!.userId;

                    // Insert separator before the first unread message
                    if (!unreadSeparatorShown && m.status != "seen" && !isMe) {
                      unreadSeparatorShown = true;
                      return Column(
                        children: [
                          const Padding(
                            padding: EdgeInsets.all(15.0),
                            child: Text(
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
                    return GestureDetector(
                      onLongPress: () {
                        setState(() {
                          _replyingTo = m;
                        });
                      },
                      child: _buildMessageBubble(m, isMe),
                    );
                  },
                );
              },
            ),
          ),
          // input field
          SafeArea(
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.GREY_SHADE_300, width: 1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // -------------------- REPLY BOX (WhatsApp style) --------------------
                  if (_replyingTo != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Replying to ${_replyingTo!.senderName}",
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  _replyingTo!.text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() => _replyingTo = null),
                          ),
                        ],
                      ),
                    ),

                  // -------------------- TEXT FIELD + SEND ROW --------------------
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: const InputDecoration(
                            hintText: "Type a message...",
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 0,
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.send,
                          color: AppColors.THEME_COLOR,
                        ),
                        onPressed: _sendMessage,
                      ),
                    ],
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
    final appUser = context.read<AppAuthProvider>().appUser;
    // ---------------------- LISTING ATTACHMENT ----------------------
    if (m.attachments != null &&
        m.attachments.length > 0 &&
        m.attachments!["type"] == "listing") {
      final listingData = m.attachments!["data"];
      final listing = Listing.fromJson(Map<String, dynamic>.from(listingData));

      return _buildListingAttachmentBubble(listing, isMe, m);
    }
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
                widget.type == 'support' && appUser?.role != 'admin'
                    ? 'S'
                    : CommonMethods.getInitials(m.senderName ?? 'U'),
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
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.7,
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color:
                          isMe
                              ? AppColors.THEME_COLOR
                              : AppColors.GREY_SHADE_300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ---------------------- REPLY BOX ----------------------
                        if (m.replyTo != null)
                          Container(
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(
                              left: 6,
                              right: 6,
                              top: 6,
                              bottom: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isMe
                                      ? AppColors.THEME_COLOR.withValues(
                                        alpha: 1.1,
                                      )
                                      : AppColors.GREY_SHADE_300.withValues(
                                        alpha: 1.1,
                                      ),
                              borderRadius: BorderRadius.circular(8),
                              border: Border(
                                left: BorderSide(
                                  color:
                                      isMe
                                          ? AppColors.WHITE
                                          : AppColors.THEME_COLOR,
                                  width: 4,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.replyTo!.senderName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: isMe ? Colors.white : Colors.black,
                                  ),
                                ),
                                Text(
                                  m.replyTo!.text,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isMe ? Colors.white : Colors.black,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // ---------------------- MAIN MESSAGE ----------------------
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 6,
                            horizontal: 10,
                          ),
                          margin: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                isMe
                                    ? AppColors.THEME_COLOR
                                    : AppColors.GREY_SHADE_300,
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
                      ],
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

  Widget _buildListingAttachmentBubble(Listing listing, bool isMe, m) {
    return GestureDetector(
      onTap: () {
        CommonMethods.navigateToListingDetailScreen(context, listing, []);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,

          children: [
            SizedBox(
              height: 200,
              width: 150,
              child: CommonWidgets.listingCard(listing),
            ),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              margin: const EdgeInsets.symmetric(vertical: 4),
              decoration: BoxDecoration(
                color: isMe ? AppColors.THEME_COLOR : AppColors.GREY_SHADE_300,
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
            const SizedBox(height: 2),
            Text(
              CommonMethods.formatMessageTime(m.createdAt),
              style: const TextStyle(fontSize: 10, color: AppColors.GREY),
            ),
          ],
        ),
      ),
    );
  }
}
