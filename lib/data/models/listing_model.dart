import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class Listing {
  final String listingId;
  final String contributionId;
  final String name;
  final String address;
  final String description;
  final Map<String, dynamic> details;
  final Geo geo;
  final String phone;
  final String alternatePhone;
  final String email;
  final String category;
  final String categoryId;
  final List<String> tags;
  final String addedBy;
  final String updatedBy;
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
  final bool isPremium;
  final Map<String, String> social;
  final Map<String, int> ratingStats;
  final Map<String, double> factorAvgRatings;
  final Map<String, DaySchedule> businessHours;

  Listing({
    required this.listingId,
    required this.contributionId,
    required this.name,
    required this.address,
    required this.description,
    required this.details,
    required this.geo,
    required this.phone,
    required this.alternatePhone,
    required this.email,
    required this.category,
    required this.categoryId,
    required this.tags,
    required this.addedBy,
    required this.updatedBy,
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
    required this.isPremium,
    required this.social,
    required this.ratingStats,
    required this.factorAvgRatings,
    required this.businessHours,
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
      alternatePhone: json['alternatePhone'] ?? '',
      email: json['email'] ?? '',
      category: json['category'] ?? '',
      categoryId: json['categoryId'] ?? '',
      tags: List<String>.from(json['tags'] ?? []),
      addedBy: json['addedBy'] ?? '',
      updatedBy: json['updatedBy'] ?? '',
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
      isPremium: json['isPremium'] ?? false,
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

      businessHours:
          (json['businessHours'] as Map<String, dynamic>?)?.map(
            (day, value) => MapEntry(
              day,
              DaySchedule.fromJson(Map<String, dynamic>.from(value)),
            ),
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
      'email': email,
      'alternatePhone': alternatePhone,
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
      'businessHours': businessHours.map(
        (day, schedule) => MapEntry(day, schedule.toJson()),
      ),
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

    // Handle Firestore GeoPoint
    if (json is GeoPoint) {
      return Geo(lat: json.latitude, lng: json.longitude);
    }

    // Handle Map {lat, lng} (string, int, double)
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

class TimeSlot {
  TimeOfDay open;
  TimeOfDay close;

  TimeSlot({required this.open, required this.close});

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      open: _parseTime(json['open']),
      close: _parseTime(json['close']),
    );
  }

  Map<String, dynamic> toJson() {
    return {"open": _formatTime(open), "close": _formatTime(close)};
  }

  static TimeOfDay _parseTime(String time) {
    final parts = time.split(":");
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  static String _formatTime(TimeOfDay time) {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }
}

class DaySchedule {
  bool isClosed;
  List<TimeSlot> slots;

  DaySchedule({required this.isClosed, required this.slots});

  factory DaySchedule.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return DaySchedule(isClosed: true, slots: []);
    }

    return DaySchedule(
      isClosed: json['isClosed'] ?? false,
      slots:
          (json['slots'] as List<dynamic>? ?? [])
              .map((e) => TimeSlot.fromJson(Map<String, dynamic>.from(e)))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      "isClosed": isClosed,
      "slots": slots.map((e) => e.toJson()).toList(),
    };
  }
}
