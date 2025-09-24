import 'package:cloud_firestore/cloud_firestore.dart';

class Category {
  final String id;          // Firestore doc ID
  final String name;        // Category name
  final String description; // Optional description
  final String imageUrl;        // imageUrl or imageUrl URL
  final List<String> tags;  // ✅ tags for search/filter
  final String section; 
  final DateTime createdAt;

  Category({
    required this.id,
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.tags,
    required this.section,
    required this.createdAt,
  });

  // 🔹 Convert Firestore -> Dart Model
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id']??'',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      section: json['section'] ?? 'others',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // 🔹 Convert Dart Model -> Firestore JSON
  Map<String, dynamic> toJson() {
    return {
      "name": name,
      "description": description,
      "imageUrl": imageUrl,
      "tags": tags,
      "section": section,
      "createdAt": Timestamp.fromDate(createdAt),
    };
  }
}
