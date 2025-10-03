import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String id;
  final String type; // "direct" or "group"
  final String groupName;
  final List<String> participants;
  final String lastMessage;
  final DateTime lastMessageAt;

  Conversation({
    required this.id,
    required this.type,
    required this.groupName,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageAt,
  });

  factory Conversation.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Conversation(
      id: doc.id,
      type: data['type'] ?? 'direct',
      groupName: data['groupName'],
      participants: List<String>.from(data['participants'] ?? []),
      lastMessage: data['lastMessage'] ?? '',
      lastMessageAt:
          (data['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
