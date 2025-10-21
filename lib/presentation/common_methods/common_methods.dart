import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/presentation/screens/listing_detail_screen.dart';
import 'package:startup_20/presentation/screens/logins/signin_screen.dart';

class CommonMethods {
  static void navigateToListingDetailScreen(
    BuildContext context,
    Listing listing,
    List<Listing> similarListings,
  ) {
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

  static Future<String?> getUserName(String userId) async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection("users")
              .doc(userId)
              .get();

      if (doc.exists) {
        return doc.data()?["name"] as String?;
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
      MaterialPageRoute(builder: (context) => SignInScreen()),
    );
  }
}
