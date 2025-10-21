import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String conversationId;
  final String type; // "direct" or "group"
  final String? groupName;
  final List<String> participantIds;

  // Change: list of maps { userId: userName }
  final List<Map<String, String>> participants;

  final String lastMessage;
  final DateTime lastMessageAt;

  Conversation({
    required this.conversationId,
    required this.type,
    this.groupName,
    required this.participantIds,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageAt,
  });

  factory Conversation.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    List<Map<String, String>> parsedParticipants = [];
    if (data['participants'] != null) {
      for (var p in data['participants']) {
        // Assuming Firestore stores it as a map
        parsedParticipants.add(Map<String, String>.from(p));
      }
    }

    return Conversation(
      conversationId: doc.id,
      type: data['type'] ?? 'direct',
      groupName: data['groupName'],
      participantIds: List<String>.from(data['participantIds'] ?? []),
      participants: parsedParticipants,
      lastMessage: data['lastMessage'] ?? '',
      lastMessageAt:
          (data['lastMessageAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Optional: method to convert back to Firestore format
  Map<String, dynamic> toJson() {
    return {
      "type": type,
      "groupName": groupName,
      "participantIds": participantIds,
      "participants": participants, // Firestore can store List<Map<String,String>>
      "lastMessage": lastMessage,
      "lastMessageAt": lastMessageAt,
    };
  }
}
