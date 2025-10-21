import 'package:cloud_firestore/cloud_firestore.dart';

class Listing {
  final String listingId;
  final String contributionId;
  final String name;
  final String address;
  final String description;
  final Geo geo;
  final String phone;
  final String category;
  final List<String> tags;
  final String addedBy;
  final bool isClaimed;
  final String ownerId;
  final String claimStatus;
  final String? verifiedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ImageFile> images;
  final int reviews;
  final double rating;

  Listing({
    required this.listingId,
    required this.contributionId,
    required this.name,
    required this.address,
    required this.description,
    required this.geo,
    required this.phone,
    required this.category,
    required this.tags,
    required this.addedBy,
    required this.isClaimed,
    required this.ownerId,
    required this.claimStatus,
    this.verifiedBy,
    required this.createdAt,
    required this.updatedAt,
    required this.images,
    required this.reviews,
    required this.rating,
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      listingId: json['listingId'] ?? '',
      contributionId: json['contributionId'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      description: json['description'] ?? '',
      geo: Geo.fromJson(json['geo'] ?? {}),
      phone: json['phone'] ?? '',
      category: json['category'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      addedBy: json['addedBy'] ?? '',
      isClaimed: json['isClaimed'] ?? false,
      ownerId: json['ownerId'],
      claimStatus: json['claimStatus'] ?? 'unclaimed',
      verifiedBy: json['verifiedBy'],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      images:
          (json['images'] as List<dynamic>? ?? [])
              .map((e) => ImageFile.fromJson(e))
              .toList(),
      reviews: json['reviews']??0,
      rating: json['rating']??1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'listingId': listingId,
      'contributionId': contributionId,
      'name': name,
      'address': address,
      'description': description,
      'geo': geo.toJson(),
      'phone': phone,
      'category': category,
      'tags': tags,
      'addedBy': addedBy,
      'isClaimed': isClaimed,
      'ownerId': ownerId,
      'claimStatus': claimStatus,
      'verifiedBy': verifiedBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'images': images.map((e) => e.toJson()).toList(),
    };
  }
}

class Geo {
  final double lat;
  final double lng;

  Geo({required this.lat, required this.lng});

  factory Geo.fromJson(dynamic json) {
    if (json == null) {
      return Geo(lat: 0.0, lng: 0.0);
    }

    // ✅ Handle Firestore GeoPoint
    if (json is GeoPoint) {
      return Geo(lat: json.latitude, lng: json.longitude);
    }

    // ✅ Handle Map {lat, lng} (string, int, double)
    if (json is Map<String, dynamic>) {
      double parse(dynamic value) {
        if (value is int) return value.toDouble();
        if (value is double) return value;
        if (value is String) return double.tryParse(value) ?? 0.0;
        return 0.0;
      }

      return Geo(lat: parse(json['lat']), lng: parse(json['lng']));
    }

    return Geo(lat: 0.0, lng: 0.0);
  }

  Map<String, dynamic> toJson() {
    return {'lat': lat, 'lng': lng};
  }
}

class ImageFile {
  final String fileId;
  final String fullUrl;
  final String thumbUrl;

  ImageFile({
    required this.fileId,
    required this.fullUrl,
    required this.thumbUrl,
  });

  factory ImageFile.fromJson(Map<String, dynamic> json) {
    return ImageFile(
      fileId: json['fileId'] ?? '',
      fullUrl: json['fullUrl'] ?? '',
      thumbUrl: json['thumbUrl'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'fileId': fileId,
    'fullUrl': fullUrl,
    'thumbUrl': thumbUrl,
  };
}
