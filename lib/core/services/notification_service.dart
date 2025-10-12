import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:startup_20/main.dart';
import 'package:startup_20/providers/auth_provider.dart';

class NotificationService {
  static final _firebaseMessaging = FirebaseMessaging.instance;
  static final _localNotifications = FlutterLocalNotificationsPlugin();

  /// Initialize Firebase Messaging + Local Notifications
  static Future<void> initialize() async {
    // 🔹 Request permission (for iOS and macOS)
    await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // 🔹 Android initialization
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');

    // 🔹 iOS initialization
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    // 🔹 Combine both
    const initSettings = InitializationSettings(
      android: androidInit,
      iOS: iosInit,
    );

    // 🔹 Initialize local notifications
    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _handleNavigation(response.payload);
      },
    );

    // 🔹 Foreground message handling
    FirebaseMessaging.onMessage.listen((message) async {
      await _showLocalNotification(message);
      await _saveNotificationToFirestore(message);
    });

    // 🔹 When tapped (background → foreground)
    FirebaseMessaging.onMessageOpenedApp.listen((message) async {
      _handleNavigation(message.data);
      await _saveNotificationToFirestore(message);
    });

    // 🔹 When opened from terminated state
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNavigation(initialMessage.data);
      await _saveNotificationToFirestore(initialMessage);
    }

    // Optional: print FCM token for testing
    final token = await _firebaseMessaging.getToken();
    debugPrint("📱 FCM Token: $token");
  }

  /// Show local notification
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'startup_channel',
      'Startup Notifications',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails();

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      0,
      message.notification?.title ?? "Notification",
      message.notification?.body ?? "",
      notificationDetails,
      payload: message.data['route'],
    );
  }

  /// Save user-specific notification to Firestore
  static Future<void> _saveNotificationToFirestore(RemoteMessage message) async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null || user.isAnonymous) {
        debugPrint('⚠️ Skipped saving notification: No authenticated user');
        return;
      }

      final userId = user.uid;
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc();

      final notificationData = {
        'notificationId': docRef.id,
        'title': message.notification?.title ?? '',
        'body': message.notification?.body ?? '',
        'type': message.data['type'] ?? 'system',
        'data': {
          'route': message.data['route'],
          'listingId': message.data['listingId'],
          'conversationId': message.data['conversationId'],
        },
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await docRef.set(notificationData);

      debugPrint('✅ Notification saved for user → ${user.email}');
    } catch (e) {
      debugPrint('❌ Error saving user notification: $e');
    }
  }

  /// Handle navigation when notification is tapped
  static void _handleNavigation(dynamic payload) {
    if (payload == null) return;

    // payload can be string or map, handle both
    String? route;
    String? listingId;

    if (payload is Map<String, dynamic>) {
      route = payload['route'];
      listingId = payload['listingId'];
    } else if (payload is String) {
      route = payload;
    }

    if (route != null) {
      navigatorKey.currentState?.pushNamed(
        route,
        arguments: {'listingId': listingId},
      );
    }
  }
}
