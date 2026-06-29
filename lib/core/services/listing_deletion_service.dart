import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:startup_20/data/models/listing_model.dart';

class ListingDeletionService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Future<void> deleteListing(String listingId) async {
    final listingRef = _firestore.collection('listings').doc(listingId);
    final deletedRf = _firestore.collection('deleted_listings').doc(listingId);


    final listingDoc = await listingRef.get();

    if (!listingDoc.exists) {
      throw Exception("Listing not found");
    }

    final listing = Listing.fromJson(listingDoc.data() as Map<String, dynamic>);


    listing.isDeleted = true;
    listing.deletedAt = DateTime.now();
    listing.deletedBy = FirebaseAuth.instance.currentUser?.uid;

    await deletedRf.set(listing.toJson()); //deleted mein leke jao

    await listingRef.delete(); //listings se htao
  }

  // restore krne ka logic

  static Future<void> restoreListing(String listingId) async {
    final deletedRef = _firestore.collection('deleted_listings').doc(listingId);

    final listingRef = _firestore.collection('listings').doc(listingId);



    final deletedDoc = await deletedRef.get();

    if (!deletedDoc.exists) {
      throw Exception("Listing not found");
    }

    final listing = Listing.fromJson(deletedDoc.data() as Map<String, dynamic>);



    listing.verifiedBy = null;
    listing.isDeleted = false;
    listing.deletedAt = null;
    listing.deletedBy = null;

    await listingRef.set(listing.toJson()); //listing mein leke jao
    await deletedRef.delete(); //delete se htao
  }
}
