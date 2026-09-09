import 'package:cloud_functions/cloud_functions.dart';

class AiTagService {
  AiTagService._();

  static final FirebaseFunctions _functions =
      FirebaseFunctions.instance;

  static Future<List<String>> generateTags({
    required Map<String, dynamic> listingData,
  }) async {
    final callable = _functions.httpsCallable(
      'generateListingTags',
    );

    final result = await callable.call({
      'listingData': listingData,
    });

    final data = result.data;

    if (data is! Map) {
      throw Exception('Invalid AI response');
    }

    final tags = data['tags'];

    if (tags is! List) {
      throw Exception('Invalid tags response');
    }

    return tags
        .whereType<String>()
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toList();
  }
}