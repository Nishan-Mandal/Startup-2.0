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

  static Future<List<Map<String, dynamic>>>
  _fetchSearchCandidatesForCategories() async {
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
        "Category search candidates failed: "
        "${response.statusCode} ${response.body}",
      );
    }

    final data = jsonDecode(response.body);
    final searches = data["searches"];

    if (searches is! List) {
      throw Exception("Invalid Algolia Analytics searches response");
    }

    final candidates = <Map<String, dynamic>>[];

    for (final item in searches) {
      final query = item["search"]?.toString().trim() ?? "";
      final count = item["count"];

      if (query.isEmpty) continue;

      final normalizedQuery =
          query
              .toLowerCase()
              .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();

      final queryTokens =
          normalizedQuery
              .split(' ')
              .where((token) => token.isNotEmpty)
              .toList();

      // Ignore obvious incomplete one/two-character queries like "jo".
      if (normalizedQuery.length < 3 ||
          queryTokens.isEmpty ||
          queryTokens.every((token) => token.length < 3)) {
        continue;
      }

      final popularity =
          count is num
              ? count.toInt()
              : int.tryParse(count?.toString() ?? "") ?? 0;

      if (popularity <= 0) continue;

      candidates.add({"query": query, "popularity": popularity});
    }
    return candidates;
  }

  static Future<List<Map<String, dynamic>>> _fetchListingsForCategoryCandidates(
    List<Map<String, dynamic>> candidates,
  ) async {
    if (candidates.isEmpty) return [];

    final url = Uri.parse("https://$appId-dsn.algolia.net/1/indexes/*/queries");

    final requests =
        candidates.map((candidate) {
          final query = candidate["query"].toString();

          return {
            "indexName": "Listings",
            "params":
                Uri(
                  queryParameters: {
                    "query": query,
                    "hitsPerPage": "5",
                    "attributesToRetrieve": "objectID,category,tags,name",
                  },
                ).query,
          };
        }).toList();

    final response = await _client.post(
      url,
      headers: {
        "X-Algolia-API-Key": apiKey,
        "X-Algolia-Application-Id": appId,
        "Content-Type": "application/json",
      },
      body: jsonEncode({"requests": requests}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Category listing lookup failed: "
        "${response.statusCode} ${response.body}",
      );
    }

    final data = jsonDecode(response.body);
    final results = data["results"];

    if (results is! List) {
      throw Exception("Invalid Algolia multi-query response");
    }

    final matchedCandidates = <Map<String, dynamic>>[];

    for (int i = 0; i < candidates.length && i < results.length; i++) {
      final candidate = candidates[i];
      final hits = results[i]["hits"];

      if (hits is! List || hits.isEmpty) continue;

      matchedCandidates.add({
        "query": candidate["query"],
        "popularity": candidate["popularity"],
        "hits": hits,
      });
    }

    return matchedCandidates;
  }

  static List<Map<String, dynamic>> _buildTrendingCategoryScores(
    List<Map<String, dynamic>> matchedCandidates,
  ) {
    final categoryScores = <String, int>{};

    for (final candidate in matchedCandidates) {
      final popularity = candidate["popularity"] as int? ?? 0;
      final hits = candidate["hits"];

      if (hits is! List) continue;

      // Ek search ke andar same category ko ek hi baar count karo.
      final categoriesForSearch = <String>{};

      for (final hit in hits) {
        if (hit is! Map) continue;

        final category = hit["category"]?.toString().trim() ?? "";

        if (category.isNotEmpty) {
          categoriesForSearch.add(category);
        }
      }

      for (final category in categoriesForSearch) {
        categoryScores.update(
          category,
          (score) => score + popularity,
          ifAbsent: () => popularity,
        );
      }
    }

    final rankedCategories =
        categoryScores.entries
            .map(
              (entry) => <String, dynamic>{
                "name": entry.key,
                "score": entry.value,
              },
            )
            .toList();

    rankedCategories.sort(
      (a, b) => (b["score"] as int).compareTo(a["score"] as int),
    );

    return rankedCategories;
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

    //Fetch popular search queries from Algolia Analytics.
    final candidates = await _fetchSearchCandidatesForCategories();

    if (candidates.isEmpty) {
      debugPrint("No search candidates available for trending categories.");
      return [];
    }

    //Match popular searches against Listings.
    final matchedCandidates = await _fetchListingsForCategoryCandidates(
      candidates,
    );

    if (matchedCandidates.isEmpty) {
      debugPrint("No listings matched trending category searches.");
      return [];
    }

    //Rank categories by the popularity of matching searches.
    final rankedCategories = _buildTrendingCategoryScores(matchedCandidates);

    if (rankedCategories.isEmpty) {
      debugPrint("No categories found from matching listings.");
      return [];
    }

    // Keep the top candidates; exact matching happens during hydration.
    final categoryNames =
        rankedCategories
            .map((item) => item["name"]?.toString().trim() ?? "")
            .where((name) => name.isNotEmpty)
            .take(20)
            .toList();

    if (categoryNames.isEmpty) return [];

    // Fetch matching documents from the categories index.
    final requests =
        categoryNames.map((categoryName) {
          return {
            "indexName": "categories",
            "params":
                Uri(
                  queryParameters: {
                    "query": categoryName,
                    "hitsPerPage": "5",
                    "attributesToRetrieve":
                        "categoryId,name,description,imageUrl,tags,section,createdAt",
                  },
                ).query,
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
        "Algolia category hydration failed: "
        "${searchResponse.statusCode} ${searchResponse.body}",
      );
    }

    final searchData = jsonDecode(searchResponse.body);
    final results = searchData["results"];

    if (results is! List) {
      throw Exception("Invalid Algolia category hydration response");
    }

    final List<dynamic> trendingCategories = [];
    final seenCategoryNames = <String>{};

    // Preserve popularity ranking and accept only exact category names.
    for (int i = 0; i < categoryNames.length && i < results.length; i++) {
      final expectedName = categoryNames[i].toLowerCase();
      final hits = results[i]["hits"];

      if (hits is! List || hits.isEmpty) continue;

      Map<String, dynamic>? exactHit;

      for (final item in hits) {
        if (item is! Map) continue;

        final actualName = item["name"]?.toString().trim().toLowerCase() ?? "";

        if (actualName == expectedName) {
          exactHit = Map<String, dynamic>.from(item);
          break;
        }
      }

      if (exactHit == null) continue;
      if (!seenCategoryNames.add(expectedName)) continue;

      trendingCategories.add(exactHit);

      if (trendingCategories.length == 8) break;
    }

    // Cache only a successful non-empty result.
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

      if (validSearches.length == 8) {
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
