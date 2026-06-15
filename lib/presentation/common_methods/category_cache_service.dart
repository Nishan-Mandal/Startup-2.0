import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:startup_20/data/models/category_model.dart';

class CategoryCacheService {
  static const String _cacheKey = 'cached_categories';

  CategoryCacheService._();

  /// Get categories immediately from cache.
  static Future<List<Category>> getCachedCategories() async {
    final prefs = await SharedPreferences.getInstance();

    final jsonString = prefs.getString(_cacheKey);

    if (jsonString == null) {
      return [];
    }

    try {
      final List decoded = jsonDecode(jsonString);

      return decoded
          .map((e) => Category.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// Refresh categories from Firestore
  static Future<List<Category>> refreshCategories() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('categories').get();

    final categories =
        snapshot.docs.map((e) => Category.fromJson(e.data())).toList();

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _cacheKey,
      jsonEncode(categories.map((e) => e.toJson()).toList()),
    );

    return categories;
  }

  /// Main method used throughout app
  static Future<List<Category>> getCategories() async {
    final cached = await getCachedCategories();

    if (cached.isNotEmpty) {
      refreshCategories(); // refresh silently
      return cached;
    }

    final fresh = await refreshCategories();

    return fresh;
  }

  /// Force refresh if required
  static Future<void> clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
}
