import 'dart:convert';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:startup_20/data/models/listing_model.dart';
import 'package:uuid/uuid.dart';

class AnalyticsTracker {
  static final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;
  static final http.Client _client = http.Client();

  // In-memory cache taaki baar-baar disk read na karna pade
  static String? _cachedVisitorId;

  static const String _visitorIdKey = 'nm_anon_uid';
  static const String _algoliaAppId = 'ULXMZ6K4Q1';
  static const String _algoliaApiKey = 'd109dcb0c3891df78caf00c6d01c7398';

  // -------------------------------------------------------------
  // 1. VISITOR IDENTITY (Web ke visitorIdentity.js ke mutabiq)
  // -------------------------------------------------------------
  // Persistent anonymous UUID jo local store hoti hai bina kisi user tracking ke
  static Future<String> getVisitorId() async {
    if (_cachedVisitorId != null && _cachedVisitorId!.isNotEmpty) {
      return _cachedVisitorId!;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      String? visitorId = prefs.getString(_visitorIdKey);

      if (visitorId == null || visitorId.isEmpty) {
        visitorId = 'anon_${const Uuid().v4()}';
        await prefs.setString(_visitorIdKey, visitorId);
      }

      _cachedVisitorId = visitorId;
      return visitorId;
    } catch (e) {
      debugPrint('Visitor ID retrieve karne me error: $e');
      return 'anonymous_app_client';
    }
  }

  // -------------------------------------------------------------
  // 2. LISTING DETAIL VIEW (GA4 view_item event)
  // -------------------------------------------------------------
  // Jab user listing detail screen kholta hai tab ye event fire hota hai
  static Future<void> trackListingView(
    Listing listing, {
    bool isPreview = false,
  }) async {
    // Agar listing preview mode me hai toh fake view record nahi hona chahiye
    if (isPreview || listing.listingId == 'preview-listing') {
      return;
    }

    try {
      await _analytics.logEvent(
        name: 'view_item',
        parameters: {
          'item_id': listing.listingId,
          'item_name': listing.name,
          'item_category': listing.category,
          'content_type': 'listing',
          'listing_id': listing.listingId,
          'listing_name': listing.name,
          'listing_category': listing.category,
        },
      );
      if (kDebugMode) {
        debugPrint('[Analytics Event: view_item] Listing: ${listing.name}');
      }
    } catch (e) {
      debugPrint('trackListingView error: $e');
    }
  }

  // -------------------------------------------------------------
  // 3. OUTBOUND LEADS TRACKING (GA4 listing_lead_action event)
  // -------------------------------------------------------------
  // Call, WhatsApp, Maps, Website, Share par click hone par ye call hoga
  // Isme Firestore par koi write operation nahi hoti — bilkul free & fast hai!
  static Future<void> trackOutboundAction({
    required Listing listing,
    required String actionType, // 'phone', 'whatsapp', 'directions', 'website', 'share'
    String? targetValue,
    bool isPreview = false,
  }) async {
    if (isPreview || listing.listingId == 'preview-listing') {
      return;
    }

    try {
      await _analytics.logEvent(
        name: 'listing_lead_action',
        parameters: {
          'action_type': actionType,
          'target_value': targetValue ?? '',
          'listing_id': listing.listingId,
          'listing_name': listing.name,
          'listing_category': listing.category,
        },
      );
      if (kDebugMode) {
        debugPrint(
          '[Analytics Event: listing_lead_action] Type: $actionType | Listing: ${listing.name}',
        );
      }
    } catch (e) {
      debugPrint('trackOutboundAction error: $e');
    }
  }

  // -------------------------------------------------------------
  // 4. SEARCH RESULT CLICK (GA4 select_item + Algolia Insights)
  // -------------------------------------------------------------
  // Search me hit tap hone par GA4 aur Algolia dono ko telemetry bhejte hain
  static Future<void> trackSearchClick({
    required String? queryID,
    required String objectID,
    required int position,
    required String listingName,
    required String category,
  }) async {
    final visitorId = await getVisitorId();

    // 1. Firebase GA4 ko select_item event
    try {
      await _analytics.logEvent(
        name: 'select_item',
        parameters: {
          'item_id': objectID,
          'item_name': listingName,
          'item_category': category,
          if (queryID != null && queryID.isNotEmpty) 'search_query_id': queryID,
          'search_position': position,
        },
      );
      if (kDebugMode) {
        debugPrint(
          '[Analytics Event: select_item] ID: $objectID, QueryID: $queryID, Pos: $position',
        );
      }
    } catch (e) {
      debugPrint('trackSearchClick GA4 error: $e');
    }

    // 2. Algolia Insights API ko click event (agar queryID present ho)
    if (queryID == null || queryID.isEmpty || objectID.isEmpty) {
      return;
    }

    try {
      final url = Uri.parse('https://insights.algolia.io/1/events');
      final payload = {
        'events': [
          {
            'eventType': 'click',
            'eventName': 'Listing Clicked After Search',
            'index': 'Listings',
            'userToken': visitorId,
            'queryID': queryID,
            'objectIDs': [objectID],
            'positions': [position <= 0 ? 1 : position],
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          }
        ]
      };

      final response = await _client.post(
        url,
        headers: {
          'X-Algolia-Application-Id': _algoliaAppId,
          'X-Algolia-API-Key': _algoliaApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode != 200 && kDebugMode) {
        debugPrint(
          'Algolia Insights response (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('Algolia Insights click error: $e');
    }
  }
}

