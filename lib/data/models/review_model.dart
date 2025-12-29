import 'package:cloud_firestore/cloud_firestore.dart';

class Review {
  final String reviewId;
  final String userId;
  final String userName;

  /// Overall / average rating
  final double rating;

  /// Multi-factor ratings (NEW)
  /// Example:
  /// {
  ///   "behaviour": 4,
  ///   "quality": 5,
  ///   "value": 4,
  ///   "overall": 5
  /// }
  final Map<String, double> factorRatings;

  final String comment;
  final DateTime createdAt;

  Review({
    required this.reviewId,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.factorRatings,
    required this.comment,
    required this.createdAt,
  });

  /// 🔹 Firestore → Model
  factory Review.fromJson(Map<String, dynamic> json, String docId) {
    return Review(
      reviewId: docId,
      userId: json['userId'] ?? '',
      userName: json['userName'] ?? 'Anonymous',

      /// Handle int / double safely
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,

      /// NEW – Safe parsing for factor ratings
      factorRatings:
          (json['factorRatings'] as Map<String, dynamic>?)
                  ?.map(
                    (key, value) =>
                        MapEntry(key, (value as num).toDouble()),
                  ) ??
              {},

      comment: json['comment'] ?? '',
      createdAt:
          (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// 🔹 Model → Firestore
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'userName': userName,
      'rating': rating, // overall rating
      'factorRatings': factorRatings, // NEW
      'comment': comment,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
