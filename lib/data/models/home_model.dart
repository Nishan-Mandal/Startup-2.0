class Category {
  final String category;
  final String imageUrl;

  Category({
    required this.category,
    required this.imageUrl,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      category: json['category'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
    );
  }
}

class HomeModel {
  final bool active;
  final List<String> promoBanners;
  final List<Category> categories;
  final List<String> listings;
  final List<String> banners;

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
      promoBanners: List<String>.from(json['promoBanners'] ?? []),
      categories: (json['categories'] as List<dynamic>? ?? [])
          .map((cat) => Category.fromJson(Map<String, dynamic>.from(cat)))
          .toList(),
      listings: List<String>.from(json['listings'] ?? []),
      banners: List<String>.from(json['banners'] ?? []),
    );
  }
}
