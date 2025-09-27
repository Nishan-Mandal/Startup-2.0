import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String reviewId; // Unique ID
  final String userId;
  final String userName;
  final double rating;
  final String comment;
  final DateTime createdAt;

  Review({
    required this.reviewId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json, String docId) {
    return Review(
      reviewId: docId, // Take Firestore docId
      userId: json['userId'],
      userName: json['userName'],
      rating: (json['rating'] as num).toDouble(),
      comment: json['comment'],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reviewId': reviewId, // Optional: store in Firestore
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt,
    };
  }
}
