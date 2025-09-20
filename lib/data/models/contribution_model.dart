import 'package:cloud_firestore/cloud_firestore.dart';

class Contribution {
  final String id;
  final String userId;
  final String type;
  final int kudos;
  final DateTime? timestamp;

  Contribution({
    required this.id,
    required this.userId,
    required this.type,
    required this.kudos,
    this.timestamp,
  });

  factory Contribution.fromFirestore(Map<String, dynamic> data, String docId) {
    return Contribution(
      id: docId,
      userId: data['userId'] ?? '',
      type: data['type'] ?? '',
      kudos: data['kudos'] ?? 0,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'type': type,
      'kudos': kudos,
      'timestamp': timestamp ?? DateTime.now(),
    };
  }
}
