import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';

class Listing {
  final String listingId;
  final String contributionId;
  final String name;
  final String address;
  final String description;
  final Map<String, dynamic> details;
  final Geo geo;
  final String phone;
  final String category;
  final String categoryId;
  final List<String> tags;
  final String addedBy;
  final bool isClaimed;
  final String ownerId;
  final String ownerName;
  final String claimStatus;
  final String? verifiedBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<ImageFile> images;
  final int reviews;
  final int ratingCount;
  final double rating;
  final List<File>? localImages;
  final int since;
  int likes; //Keeping is non final for UI optimisation
  final int views;
  final Map<String, String> social;
  final Map<String, int> ratingStats; // NEW
  final Map<String, double> factorAvgRatings; // NEW
  final Map<String, OpenHours> openHours;

  Listing({
    required this.listingId,
    required this.contributionId,
    required this.name,
    required this.address,
    required this.description,
    required this.details,
    required this.geo,
    required this.phone,
    required this.category,
    required this.categoryId,
    required this.tags,
    required this.addedBy,
    required this.isClaimed,
    required this.ownerId,
    required this.ownerName,
    required this.claimStatus,
    this.verifiedBy,
    required this.createdAt,
    required this.updatedAt,
    required this.images,
    required this.reviews,
    required this.ratingCount,
    required this.rating,
    this.localImages,
    required this.since,
    required this.likes,
    required this.views,
    required this.social,
    required this.ratingStats,
    required this.factorAvgRatings,
    required this.openHours,
  });

  factory Listing.fromJson(Map<String, dynamic> json) {
    return Listing(
      listingId: json['listingId'] ?? '',
      contributionId: json['contributionId'] ?? '',
      name: json['name'] ?? '',
      address: json['address'] ?? '',
      description: json['description'] ?? '',
      details:
          json['details'] != null
              ? Map<String, dynamic>.from(json['details'])
              : {},
      geo: Geo.fromJson(json['geo'] ?? {}),
      phone: json['phone'] ?? '',
      category: json['category'] ?? '',
      categoryId: json['categoryId'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      addedBy: json['addedBy'] ?? '',
      isClaimed: json['isClaimed'] ?? false,
      ownerId: json['ownerId'],
      ownerName: json['ownerName'] ?? 'Unknown',
      claimStatus: json['claimStatus'] ?? 'unclaimed',
      verifiedBy: json['verifiedBy'],
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      updatedAt: (json['updatedAt'] as Timestamp).toDate(),
      images:
          (json['images'] as List<dynamic>? ?? [])
              .map((e) => ImageFile.fromJson(e))
              .toList(),
      reviews: json['reviews'] ?? 0,
      ratingCount: json['ratingCount'] ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      since: json['since'] ?? 2025,
      likes: json['likes'] ?? 0,
      views: json['views'] ?? 0,
      social:
          json['social'] != null
              ? Map<String, String>.from(json['social'])
              : {},

      ratingStats:
          (json['ratingStats'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toInt()),
          ) ??
          {'1': 0, '2': 0, '3': 0, '4': 0, '5': 0},

      factorAvgRatings:
          (json['factorAvgRatings'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          ) ??
          {},

      openHours:
          (json['openHours'] as Map<String, dynamic>?)?.map(
            (day, value) => MapEntry(day, OpenHours.fromJson(value)),
          ) ??
          {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'listingId': listingId,
      'contributionId': contributionId,
      'name': name,
      'address': address,
      'description': description,
      'details': details,
      'geo': geo.toJson(),
      'phone': phone,
      'category': category,
      'categoryId': categoryId,
      'tags': tags,
      'addedBy': addedBy,
      'isClaimed': isClaimed,
      'ownerId': ownerId,
      'ownerName': ownerName,
      'claimStatus': claimStatus,
      'verifiedBy': verifiedBy,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'images': images.map((e) => e.toJson()).toList(),
      // 'reviews': reviews,
      // 'rating': reviews,
      'since': since,
      // 'likes': likes,
      // 'views': views,
      'social': social,
      'openHours': openHours.map((day, hours) => MapEntry(day, hours.toJson())),
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

class OpenHours {
  final String open;
  final String close;
  final bool closed;

  OpenHours({required this.open, required this.close, required this.closed});

  factory OpenHours.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return OpenHours(open: '', close: '', closed: true);
    }

    return OpenHours(
      open: json['open'] ?? '',
      close: json['close'] ?? '',
      closed: json['closed'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {'open': open, 'close': close, 'closed': closed};
  }
}
