import 'dart:convert';
import 'package:http/http.dart' as http;



class AlgoliaService {
  static const String appId = "ULXMZ6K4Q1";
  static const String apiKey = "d109dcb0c3891df78caf00c6d01c7398";

  static Future<List<dynamic>> searchListings(String query) async {
    return _search(query, "Listings");
  }

  static Future<List<dynamic>> searchCategories(String query) async {
    return _search(query, "categories");
  }

  static Future<List<dynamic>> _search(String query, String index) async {
    final url = Uri.parse(
      "https://$appId-dsn.algolia.net/1/indexes/$index/query",
    );

    final response = await http.post(
      url,
      headers: {
        "X-Algolia-API-Key": apiKey,
        "X-Algolia-Application-Id": appId,
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "query": query,
        "hitsPerPage": 10,
      }),
    );

    final data = jsonDecode(response.body);
    return data['hits'];
  }
}