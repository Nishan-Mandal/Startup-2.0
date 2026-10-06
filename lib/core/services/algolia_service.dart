import 'dart:convert';
import 'package:http/http.dart' as http;

class AlgoliaService {
  static const String appId = "ULXMZ6K4Q1";
  static const String apiKey = "d109dcb0c3891df78caf00c6d01c7398";
  static final http.Client _client = http.Client();

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

  static Future<List<dynamic>> getTopCategories() async {
    final url = Uri.parse(
      "https://$appId-dsn.algolia.net/1/indexes/categories/query",
    );

    final response = await _client.post(
      url,
      headers: {
        "X-Algolia-API-Key": apiKey,
        "X-Algolia-Application-Id": appId,
        "Content-Type": "application/json",
      },
      body: jsonEncode({"query": "", "hitsPerPage": 8}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Algolia categories search failed: ${response.statusCode}",
      );
    }

    final data = jsonDecode(response.body);

    return List<dynamic>.from(data['hits'] ?? []);
  }

  static Future<List<Map<String, dynamic>>> getTrendingSearches() async {
    final url = Uri.parse(
      "https://$appId-dsn.algolia.net/1/indexes/Listings_query_suggestions/query",
    );

    final response = await _client.post(
      url,
      headers: {
        "X-Algolia-API-Key": apiKey,
        "X-Algolia-Application-Id": appId,
        "Content-Type": "application/json",
      },
      body: jsonEncode({"query": "", "hitsPerPage": 6}),
    );

    if (response.statusCode != 200) {
      throw Exception(
        "Algolia trending searches failed: ${response.statusCode}",
      );
    }

    final data = jsonDecode(response.body);

    return List<Map<String, dynamic>>.from(
      (data['hits'] ?? []).map(
        (e) => {
          'query': e['query']?.toString() ?? '',
          'popularity': e['popularity'] ?? 0,
        },
      ),
    );
  }
}
