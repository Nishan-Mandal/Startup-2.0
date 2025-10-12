class AppNotification {
  final String notificationId;
  final String title;
  final String body;
  final String type; // "system" | "chat" | "offer" | "alert" | "reminder"
  final NotificationData? data;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.notificationId,
    required this.title,
    required this.body,
    required this.type,
    this.data,
    required this.isRead,
    required this.createdAt,
  });

  /// Factory constructor to create AppNotification from Firestore JSON
  factory AppNotification.fromJson(Map<String, dynamic> json, String id) {
    return AppNotification(
      notificationId: id,
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      type: json['type'] ?? 'system',
      data: json['data'] != null
          ? NotificationData.fromJson(Map<String, dynamic>.from(json['data']))
          : null,
      isRead: json['isRead'] ?? false,
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
    );
  }

  /// Convert AppNotification to JSON (for Firestore or local storage)
  Map<String, dynamic> toJson() {
    return {
      'notificationId': notificationId,
      'title': title,
      'body': body,
      'type': type,
      'data': data?.toJson(),
      'isRead': isRead,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}

/// Nested data object for navigation or contextual info
class NotificationData {
  final String? route;
  final String? listingId;
  final String? conversationId;

  NotificationData({
    this.route,
    this.listingId,
    this.conversationId,
  });

  factory NotificationData.fromJson(Map<String, dynamic> json) {
    return NotificationData(
      route: json['route'],
      listingId: json['listingId'],
      conversationId: json['conversationId'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'route': route,
      'listingId': listingId,
      'conversationId': conversationId,
    };
  }
}
