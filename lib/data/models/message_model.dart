import 'package:cloud_firestore/cloud_firestore.dart';

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String text;
  final Map<String, dynamic>? attachments;
  final String status;
  final DateTime createdAt;

  // 🔥 New fields for replying/tagging
  final ReplyMessage? replyTo;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.attachments,
    required this.status,
    required this.createdAt,
    this.replyTo,
  });

  factory ChatMessage.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      text: data['text'] ?? '',
      attachments: data['attachments'] ?? {},
      status: data['status'] ?? 'sent',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),

      // 🔥 Parse replyTo object
      replyTo: data['replyTo'] != null
          ? ReplyMessage.fromMap(data['replyTo'])
          : null,
    );
  }
}

// ---------------------------------------------------
// 🔥 Reply Message Model
// ---------------------------------------------------

class ReplyMessage {
  final String messageId;
  final String senderName;
  final String text;

  ReplyMessage({
    required this.messageId,
    required this.senderName,
    required this.text,
  });

  factory ReplyMessage.fromMap(Map<String, dynamic> map) {
    return ReplyMessage(
      messageId: map['messageId'] ?? '',
      senderName: map['senderName'] ?? '',
      text: map['text'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'messageId': messageId,
      'senderName': senderName,
      'text': text,
    };
  }
}
