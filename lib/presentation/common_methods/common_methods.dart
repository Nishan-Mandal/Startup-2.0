import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/presentation/screens/listing_detail_screen.dart';

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

  static guestLogin() async {
    await FirebaseAuth.instance.signInAnonymously();
  }

  static logout() async {
    await FirebaseAuth.instance.signOut();
  }
}
