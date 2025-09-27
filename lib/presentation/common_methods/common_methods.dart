import 'package:flutter/material.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:startup_20/presentation/screens/listing_detail_screen.dart';

class CommonMethods {
  static void navigateToListingDetailScreen(
    BuildContext context,
    Listing listing,
    List<Listing> similarListings
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ListingDetailScreen(listing: listing, similarListings: similarListings,),
      ),
    );
  }
}
