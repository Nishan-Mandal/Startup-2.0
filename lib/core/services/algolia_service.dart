import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AlgoliaService {
  static const String appId = "ULXMZ6K4Q1";
  static const String apiKey = "d109dcb0c3891df78caf00c6d01c7398";
  static const String analyticsApiKey = "fcde150bf430da93c48f3408c9a5a74e";
  static final http.Client _client = http.Client();

  static const String _trendingSearchesCacheKey = 'trendingSearchesCache';
  static const String _trendingSearchesCacheTimeKey =
      'trendingSearchesCacheTime';
  static const Duration _trendingSearchesCacheDuration = Duration(hours: 12);

  static const String _trendingCategoriesCacheKey = 'trendingCategoriesCache';
  static const String _trendingCategoriesCacheTimeKey =
      'trendingCategoriesCacheTime';
  static const Duration _trendingCategoriesCacheDuration = Duration(hours: 12);

  static Future<List<dynamic>> searchListings(String query) async {
    final results = await search(query);
    return results['Listings'] ?? [];
  }

  static Future<List<dynamic>> searchCategories(String query) async {
    final results = await search(query);
    return results['categories'] ?? [];
  }

  static Future<Map<String, List<dynamic>>> search(String query) async {
    final url = Uri.parse("https://$appId-dsn.algolia.net/1/indexes/*/queries");

    final response = await _client.post(
      url,
      headers: {
        "X-Algolia-API-Key": apiKey,
        "X-Algolia-Application-Id": appId,
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "requests": [
          {
            "indexName": "Listings",
            "params": "query=${Uri.encodeQueryComponent(query)}&hitsPerPage=10",
          },
          {
            "indexName": "categories",
            "params": "query=${Uri.encodeQueryComponent(query)}&hitsPerPage=10",
          },
        ],
      }),
    );

    if (response.statusCode != 200) {
      throw Exception("Algolia search failed: ${response.statusCode}");
    }

    final data = jsonDecode(response.body);

    final results = data['results'];

    if (results is! List || results.length < 2) {
      throw Exception("Invalid Algolia response");
    }

    return {
      "Listings": List<dynamic>.from(results[0]['hits'] ?? []),
      "categories": List<dynamic>.from(results[1]['hits'] ?? []),
    };
  }

  static void dispose() {
    _client.close();
  }

  static Future<void> trackCategoryFilter(String category) async {
  final categoryName = category.trim();

  if (categoryName.isEmpty) return;

  try {
    final url = Uri.parse(
      "https://$appId-dsn.algolia.net/1/indexes/Listings/query",
    );

    final response = await _client.post(
      url,
      headers: {
        "X-Algolia-API-Key": apiKey,
        "X-Algolia-Application-Id": appId,
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "query": "",
        "hitsPerPage": 1,
        "attributesToRetrieve": ["objectID"],
        "facetFilters": [
          ["category:$categoryName"],
        ],
      }),
    );

    if (response.statusCode != 200) {
      debugPrint(
        "Algolia category tracking failed: "
        "${response.statusCode} ${response.body}",
      );
    }
  } catch (e) {
    debugPrint("Algolia category tracking error: $e");
  }
}

  static Future<List<dynamic>> getTopCategories() async {
    final prefs = await SharedPreferences.getInstance();

    final cachedData = prefs.getString(_trendingCategoriesCacheKey);
    final cachedTime = prefs.getInt(_trendingCategoriesCacheTimeKey);

    // Fresh cache hai → directly return
    if (cachedData != null && cachedTime != null) {
      final cacheAge = DateTime.now().millisecondsSinceEpoch - cachedTime;

      if (cacheAge < _trendingCategoriesCacheDuration.inMilliseconds) {
        try {
          final decoded = jsonDecode(cachedData);

          if (decoded is List) {
            return List<dynamic>.from(decoded);
          }
        } catch (e) {
          // Invalid cache → fresh data fetch hoga
        }
      }
    }

    // Purana cache hai → pehle old data return karo aur background mein refresh kar do
    if (cachedData != null) {
      try {
        final decoded = jsonDecode(cachedData);

        if (decoded is List) {
          final oldCategories = List<dynamic>.from(decoded);

          // UI ko wait nahi karna padega
          unawaited(_refreshTrendingCategories());

          return oldCategories;
        }
      } catch (e) {
        // Invalid old cache → fresh data fetch hoga
      }
    }

    // Cache nahi hai toh fresh data fetch karo
    return await _refreshTrendingCategories();
  }

  static Future<List<dynamic>> _refreshTrendingCategories() async {
  final prefs = await SharedPreferences.getInstance();

  //Analytics se trending categories lao
  final analyticsUrl = Uri.https(
    "analytics.de.algolia.com",
    "/2/filters/category",
    {
      "index": "Listings",
      "limit": "8",
    },
  );

  final analyticsResponse = await _client.get(
    analyticsUrl,
    headers: {
      "X-Algolia-API-Key": analyticsApiKey,
      "X-Algolia-Application-Id": appId,
    },
  );

  if (analyticsResponse.statusCode != 200) {
    throw Exception(
      "Algolia trending categories failed: "
      "${analyticsResponse.statusCode} "
      "${analyticsResponse.body}",
    );
  }

  final analyticsData = jsonDecode(analyticsResponse.body);
  final values = analyticsData["values"];

  if (values is! List || values.isEmpty) {
    return [];
  }

  // Analytics se category names nikalo
  final categoryNames =
      values
          .map((item) => item["value"]?.toString().trim() ?? "")
          .where((name) => name.isNotEmpty)
          .toList();

  if (categoryNames.isEmpty) {
    return [];
  }

  // categories index se sirf required fields lao
  final requests =
      categoryNames.map((categoryName) {
        return {
          "indexName": "categories",
          "params":
              "query=${Uri.encodeQueryComponent(categoryName)}"
              "&hitsPerPage=1"
              "&attributesToRetrieve="
              "categoryId,name,description,imageUrl,tags,section,createdAt",
        };
      }).toList();

  final searchUrl = Uri.parse(
    "https://$appId-dsn.algolia.net/1/indexes/*/queries",
  );

  final searchResponse = await _client.post(
    searchUrl,
    headers: {
      "X-Algolia-API-Key": apiKey,
      "X-Algolia-Application-Id": appId,
      "Content-Type": "application/json",
    },
    body: jsonEncode({
      "requests": requests,
    }),
  );

  if (searchResponse.statusCode != 200) {
    throw Exception(
      "Algolia category hydration failed: "
      "${searchResponse.statusCode} "
      "${searchResponse.body}",
    );
  }

  final searchData = jsonDecode(searchResponse.body);
  final results = searchData["results"];

  if (results is! List) {
    return [];
  }

  final List<dynamic> trendingCategories = [];

  // Analytics ka original order preserve krna hai
  for (
    int i = 0;
    i < categoryNames.length && i < results.length;
    i++
  ) {
    final expectedName =
        categoryNames[i].trim().toLowerCase();

    final hits = results[i]["hits"];

    if (hits is! List || hits.isEmpty) {
      continue;
    }

    final hit = hits.first;

    final actualName =
        hit["name"]?.toString().trim().toLowerCase() ?? "";

    // Exact category match hona chahie
    if (actualName == expectedName) {
      trendingCategories.add(hit);
    }

    if (trendingCategories.length == 8) {
      break;
    }
  }

  // Successful result ko cache karo
  if (trendingCategories.isNotEmpty) {
    await prefs.setString(
      _trendingCategoriesCacheKey,
      jsonEncode(trendingCategories),
    );

    await prefs.setInt(
      _trendingCategoriesCacheTimeKey,
      DateTime.now().millisecondsSinceEpoch,
    );
  }

  return trendingCategories;
}
  static Future<List<Map<String, dynamic>>> getTrendingSearches() async {
    final prefs = await SharedPreferences.getInstance();

    final cachedData = prefs.getString(_trendingSearchesCacheKey);
    final cachedTime = prefs.getInt(_trendingSearchesCacheTimeKey);

    //fresh cache return kro turant
    if (cachedData != null && cachedTime != null) {
      final cacheAge = DateTime.now().millisecondsSinceEpoch - cachedTime;

      if (cacheAge < _trendingSearchesCacheDuration.inMilliseconds) {
        try {
          final decoded = jsonDecode(cachedData);

          if (decoded is List) {
            return decoded
                .map<Map<String, dynamic>>(
                  (item) => Map<String, dynamic>.from(item),
                )
                .toList();
          }
        } catch (e) {
          // print("Error reading trending searches cache: $e");
        }
      }
    }

    //agr hai purana cache to show and bg mein refresh kro
    if (cachedData != null) {
      try {
        final decoded = jsonDecode(cachedData);

        if (decoded is List) {
          final oldSearches =
              decoded
                  .map<Map<String, dynamic>>(
                    (item) => Map<String, dynamic>.from(item),
                  )
                  .toList();

          // bina refresh ke ui mein dikhao
          unawaited(_refreshTrendingSearches());

          return oldSearches;
        }
      } catch (e) {
        // print("Error reading old trending searches cache: $e");
      }
    }

    // cache agr empty hai toh call algolia
    return await _refreshTrendingSearches();
  }

  static Future<List<Map<String, dynamic>>> _refreshTrendingSearches() async {
    final url = Uri.https("analytics.de.algolia.com", "/2/searches", {
      "index": "Listings",
      "limit": "10",
      "orderBy": "searchCount",
      "direction": "desc",
    });

    final response = await _client.get(
      url,
      headers: {
        "X-Algolia-API-Key": analyticsApiKey,
        "X-Algolia-Application-Id": appId,
      },
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Algolia trending searches failed: "
        "${response.statusCode} ${response.body}",
      );
    }

    final data = jsonDecode(response.body);
    final searches = data["searches"];

    if (searches is! List || searches.isEmpty) {
      return [];
    }

    final candidates =
        searches
            .map<Map<String, dynamic>>(
              (item) => {
                "query": item["search"]?.toString() ?? "",
                "popularity": item["count"] ?? 0,
              },
            )
            .where((item) => item["query"].toString().trim().isNotEmpty)
            .toList();

    if (candidates.isEmpty) {
      return [];
    }

    // Listings index se compare kro candidates ko
    final requests =
        candidates.map((item) {
          final query = item["query"].toString();

          return {
            "indexName": "Listings",
            "params":
                "query=${Uri.encodeQueryComponent(query)}"
                "&hitsPerPage=1"
                "&attributesToRetrieve=objectID",
          };
        }).toList();

    final searchUrl = Uri.parse(
      "https://$appId-dsn.algolia.net/1/indexes/*/queries",
    );

    final searchResponse = await _client.post(
      searchUrl,
      headers: {
        "X-Algolia-API-Key": apiKey,
        "X-Algolia-Application-Id": appId,
        "Content-Type": "application/json",
      },
      body: jsonEncode({"requests": requests}),
    );

    if (searchResponse.statusCode != 200) {
      throw Exception(
        "Algolia trending search validation failed: "
        "${searchResponse.statusCode} "
        "${searchResponse.body}",
      );
    }

    final searchData = jsonDecode(searchResponse.body);
    final results = searchData["results"];

    if (results is! List) {
      return [];
    }

    final List<Map<String, dynamic>> validSearches = [];

    for (int i = 0; i < candidates.length && i < results.length; i++) {
      final hits = results[i]["hits"];

      // jis search ke pass listing hai bss usiko rkho
      if (hits is List && hits.isNotEmpty) {
        validSearches.add(candidates[i]);
      }

      if (validSearches.length == 6) {
        break;
      }
    }

    // Sirf succesfull result hi cache mein jaega
    if (validSearches.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(
        _trendingSearchesCacheKey,
        jsonEncode(validSearches),
      );

      await prefs.setInt(
        _trendingSearchesCacheTimeKey,
        DateTime.now().millisecondsSinceEpoch,
      );
    }

    return validSearches;
  }
}
