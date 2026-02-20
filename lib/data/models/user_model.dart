import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String userId;
  final String? fcmToken;
  final int? kudos;
  final String name;
  final String? phone;
  final String? role;
  final Timestamp? createdAt;
  final Timestamp? updatedAt;

  AppUser({
    required this.userId,
    this.fcmToken,
    this.kudos,
    required this.name,
    this.phone,
    this.role,
    this.createdAt,
    this.updatedAt,
  });

  /// 🟢 Factory constructor to create from Firestore
  factory AppUser.fromMap(Map<String, dynamic> data, String documentId) {
    return AppUser(
      userId: documentId,
      fcmToken: data['fcmToken'],
      kudos: (data['kudos'] is int)
          ? data['kudos']
          : int.tryParse(data['kudos']?.toString() ?? '0'),
      name: data['name'] ?? '',
      phone: data['phone'],
      role: data['role'],
      createdAt: data['createdAt'],
      updatedAt: data['updatedAt'],
    );
  }

  /// 🔵 Convert to map (useful for saving)
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'fcmToken': fcmToken,
      'kudos': kudos,
      'name': name,
      'phone': phone,
      'role': role,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
}
