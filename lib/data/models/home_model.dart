import 'package:startup_20/data/models/category_model.dart';

class BannerModel {
  final String imageUrl;
  final String route;

  BannerModel({required this.imageUrl, required this.route});

  factory BannerModel.fromJson(Map<String, dynamic> json) {
    return BannerModel(
      imageUrl: json['imageUrl'] ?? '',
      route: json['route'] ?? '', // could be a named route or URL
    );
  }

  Map<String, dynamic> toJson() {
    return {'imageUrl': imageUrl, 'route': route};
  }
}

class Category {
  final String category;
  final String imageUrl;
  Category({required this.category, required this.imageUrl});
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      category: json['category'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
    );
  }
}

class HomeModel {
  final bool active;
  final List<BannerModel> promoBanners;
  final List<Category> categories;
  final List<String> listings;
  final List<BannerModel> banners;

  HomeModel({
    required this.active,
    required this.promoBanners,
    required this.categories,
    required this.listings,
    required this.banners,
  });

  factory HomeModel.fromJson(Map<String, dynamic> json) {
    return HomeModel(
      active: json["active"] ?? false,
      promoBanners:
          (json['promoBanners'] as List<dynamic>? ?? [])
              .map((b) => BannerModel.fromJson(Map<String, dynamic>.from(b)))
              .toList(),
      categories:
          (json['categories'] as List<dynamic>? ?? [])
              .map((cat) => Category.fromJson(Map<String, dynamic>.from(cat)))
              .toList(),
      listings: List<String>.from(json['listings'] ?? []),
      banners:
          (json['banners'] as List<dynamic>? ?? [])
              .map((b) => BannerModel.fromJson(Map<String, dynamic>.from(b)))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'active': active,
      'promoBanners': promoBanners.map((b) => b.toJson()).toList(),
      'categories':
          categories
              .map((c) => {'category': c.category, 'imageUrl': c.imageUrl})
              .toList(),
      'listings': listings,
      'banners': banners.map((b) => b.toJson()).toList(),
    };
  }
}
