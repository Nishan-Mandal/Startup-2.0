import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/presentation/screens/listing_detail_screen.dart';
import 'package:startup_20/presentation/screens/logins/signin_screen.dart';
import 'package:startup_20/providers/auth_provider.dart';
import 'package:url_launcher/url_launcher.dart';

class CommonMethods {
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

  static void navigateToListingDetailScreen(
    BuildContext context,
    Listing listing,
    List<Listing> similarListings,
  ) {
    preloadListingImages(context,listing);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ListingDetailScreen(
              listing: listing,
              similarListings: similarListings,
            ),
      ),
    );
  }

  static Future<String?> getUserData(String userId, String fieldName) async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection("users")
              .doc(userId)
              .get();

      if (doc.exists) {
        return doc.data()?[fieldName] as String?;
      } else {
        debugPrint("User not found for userId: $userId");
        return null;
      }
    } catch (e) {
      debugPrint("Error fetching user name: $e");
      return null;
    }
  }

  static String getInitials(String fullName) {
    if (fullName.trim().isEmpty) return 'U'; // Default initial if empty

    final parts = fullName.trim().split(RegExp(r'\s+')); // Split by spaces

    final firstChar = parts.first.isNotEmpty ? parts.first[0] : '';

    // If only one word, return single initial
    if (parts.length == 1) {
      return firstChar.toUpperCase();
    }

    final lastChar = parts.last.isNotEmpty ? parts.last[0] : '';

    return (firstChar + lastChar).toUpperCase();
  }

  static String formatMessageTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final difference = now.difference(time).inDays;
    if (difference == 0) {
      return DateFormat('hh:mm a').format(time); // today
    } else if (difference == 1) {
      return 'Yesterday, ${DateFormat('hh:mm a').format(time)}';
    } else {
      return DateFormat('MMM d, hh:mm a').format(time);
    }
  }

  static navigateToSignInScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SignInScreen(skip: false)),
    );
  }

  static Future<void> onAppStart() async {
    if (AppAuthProvider.isAnonymousUser()) return;

    final user = _auth.currentUser;
    final userRef = _firestore.collection('users').doc(user?.uid);
    final userSnap = await userRef.get();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (!userSnap.exists) return;

    final usage = userSnap.data()?['dailyUsage'] ?? {};
    final lastActive = (usage['lastActiveOn'] as Timestamp?)?.toDate();
    final packageInfo = await PackageInfo.fromPlatform();

    // If no usage or new day
    if (lastActive == null || lastActive.isBefore(today)) {
      await userRef.update({
        'appVersion': packageInfo.version,
        'dailyUsage': {
          'lastActiveOn': FieldValue.serverTimestamp(),
          'totalMinutes': 0,
        },
      });
      debugPrint("✅ dailyUsage reset for new day");
    } else {
      await userRef.update({
        'appVersion': packageInfo.version,
        'dailyUsage.lastActiveOn': FieldValue.serverTimestamp(),
      });
      debugPrint("✅ Continuing same-day session");
    }
  }

  static Future<void> onAppClose() async {
    if (AppAuthProvider.isAnonymousUser()) return;

    final user = _auth.currentUser;
    final userRef = _firestore.collection('users').doc(user?.uid);
    final userSnap = await userRef.get();
    if (!userSnap.exists) return;

    final usage = userSnap.data()?['dailyUsage'] ?? {};
    final lastActive = (usage['lastActiveOn'] as Timestamp?)?.toDate();
    final totalMinutes = (usage['totalMinutes'] ?? 0) as num;

    if (lastActive == null) return;

    final now = DateTime.now();
    final diffMinutes = now.difference(lastActive).inMinutes;
    await userRef.update({
      'dailyUsage.lastActiveOn': FieldValue.serverTimestamp(),
      'dailyUsage.totalMinutes': totalMinutes + diffMinutes,
    });

    debugPrint(
      "🕒 Updated dailyUsage: +$diffMinutes min (total: ${totalMinutes + diffMinutes})",
    );
  }

  // ✅ Get address from LatLng
  static Future<String> getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        String address =
            "${place.name ?? ''}, ${place.locality ?? ''}, ${place.administrativeArea ?? ''}";
        return address;
      }
    } catch (e) {
      debugPrint("Error in reverse geocoding: $e");
    }
    return '';
  }

  static void preloadListingImages(BuildContext context, Listing listing) {
    for (final img in listing.images) {
      precacheImage(CachedNetworkImageProvider(img.fullUrl), context);
    }
  }

  static void openWhatsApp(String phone) async {
    // Remove spaces, dashes, brackets etc.
    String normalized = phone.replaceAll(RegExp(r'[^0-9+]'), '');

    // Add country code if missing (India +91)
    if (!normalized.startsWith('+')) {
      if (normalized.length == 10) {
        normalized = '91$normalized';
      }
    } else {
      normalized = normalized.replaceFirst('+', '');
    }

    final Uri url = Uri.parse('https://wa.me/$normalized');

    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch WhatsApp');
    }
  }
}
