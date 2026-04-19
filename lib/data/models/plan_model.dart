import 'package:cloud_firestore/cloud_firestore.dart';

class Plan {
  final String planName;
  final String planId;
  final String apiKey;
  final String durationInMonths;
  final int price;
  final int durationInDays; 
  final bool isPopular;
  final List<String> featuresAvailable;
  final List<String> images;
  final Timestamp? createdAt;

  Plan({
    required this.planName,
    required this.planId,
    required this.apiKey,
    required this.durationInMonths,
    required this.price,
    required this.durationInDays,
    this.isPopular = false,
    this.featuresAvailable = const [],
    this.images = const [],
    this.createdAt,
  });

  /// 🔹 FROM FIRESTORE
  factory Plan.fromMap(Map<String, dynamic> data, String id) {
    return Plan(
      planName: data['planName'] ?? '',
      planId: data['planId'] ?? id,
      apiKey: data['apiKey'] ?? '',
      durationInMonths: data['durationInMonths'] ?? '',
      price: (data['price'] as num?)?.toInt() ?? 0,
      durationInDays: (data['durationInDays'] as num?)?.toInt() ?? 0,
      isPopular: data['isPopular'] ?? false,
      featuresAvailable: List<String>.from(
        data['featuresAvailable'] ?? [],
      ),
      images: List<String>.from(
        data['images'] ?? [],
      ),
      createdAt: data['createdAt'],
    );
  }

  /// 🔹 TO FIRESTORE
  Map<String, dynamic> toMap() {
    return {
      'planName': planName,
      'planId': planId,
      'durationInMonths': durationInMonths,
      'price': price,
      'durationInDays': durationInDays,
      'isPopular': isPopular,
      'featuresAvailable': featuresAvailable,
      'images': images,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}