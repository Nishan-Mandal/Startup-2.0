import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:startup_20/core/constants/app_colors.dart';
import 'package:startup_20/data/models/message_model.dart';

class ChatRoomScreen extends StatefulWidget {
  final String conversationId;
  final String currentUserId;
  final String title;
  const ChatRoomScreen({
    super.key,
    required this.conversationId,
    required this.currentUserId,
    required this.title,
  });

  @override
  State<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends State<ChatRoomScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _sendMessage() async {
    final text = _messageController.text.trim();
    _messageController.clear();
    if (text.isEmpty) return;

    final docRef =
        FirebaseFirestore.instance
            .collection("conversations")
            .doc(widget.conversationId)
            .collection("messages")
            .doc();

    await docRef.set({
      "messageId": docRef.id,
      "senderId": widget.currentUserId,
      "text": text,
      "attachments": [],
      "status": "sent",
      "createdAt": FieldValue.serverTimestamp(),
    });

    // update last message in conversation
    await FirebaseFirestore.instance
        .collection("conversations")
        .doc(widget.conversationId)
        .update({
          "lastMessage": text,
          "lastMessageAt": FieldValue.serverTimestamp(),
        });

    Future.delayed(const Duration(milliseconds: 200), () {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.GREY_SHADE_50,
      appBar: AppBar(
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
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
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
                    final isMe = m.senderId == widget.currentUserId;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ), // spacing between bubbles
                      child: Row(
                        mainAxisAlignment:
                            isMe
                                ? MainAxisAlignment.end
                                : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          // Avatar for others
                          if (!isMe)
                            const CircleAvatar(
                              maxRadius: 15,
                              backgroundColor: AppColors.GREY_SHADE_300,
                              child: Icon(
                                Icons.person,
                                color: AppColors.BLACK,
                                size: 15,
                              ),
                            ),
                          if (!isMe)
                            const SizedBox(
                              width: 5,
                            ), // spacing between avatar and bubble
                          // Chat bubble
                          Flexible(
                            child: Column(
                              crossAxisAlignment:
                                  isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 5,
                                    horizontal: 10,
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
                                      color:
                                          isMe
                                              ? AppColors.WHITE
                                              : AppColors.BLACK,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                const SizedBox(
                                  height: 2,
                                ), // spacing between bubble and time
                                Text(
                                  m.createdAt != null
                                      ? "${m.createdAt.hour}:${m.createdAt.minute.toString().padLeft(2, '0')}"
                                      : "",
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.GREY,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (isMe)
                            const SizedBox(
                              width: 5,
                            ), // spacing between bubble and avatar
                          // Avatar for me
                          if (isMe)
                            const CircleAvatar(
                              maxRadius: 15,
                              backgroundColor: AppColors.GREY,
                              child: Icon(
                                Icons.person,
                                color: AppColors.WHITE,
                                size: 15,
                              ),
                            ),
                        ],
                      ),
                    );
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
}
