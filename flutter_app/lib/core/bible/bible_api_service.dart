import 'dart:convert';

import 'package:http/http.dart' as http;

class BiblePassage {
  BiblePassage({required this.reference, required this.text, required this.translationId});

  final String reference;
  final String text;
  final String translationId;

  factory BiblePassage.fromJson(Map<String, dynamic> json) {
    return BiblePassage(
      reference: json['reference'] as String? ?? '',
      // bible-api.com returns verse text with literal newlines between
      // verses; collapse to single spaces for compact display.
      text: (json['text'] as String? ?? '').replaceAll(RegExp(r'\s*\n\s*'), ' ').trim(),
      translationId: (json['translation_id'] as String? ?? 'kjv').toUpperCase(),
    );
  }
}

/// Fetches live scripture text from bible-api.com — free, no API key,
/// public-domain translations (KJV to match `verse_pool`'s default).
/// Swap the base URL / response parsing here if a different provider is
/// preferred later; nothing else in the app depends on this choice.
class BibleApiService {
  BibleApiService(this._client);

  static const _baseUrl = 'https://bible-api.com';

  final http.Client _client;
  final _cache = <String, BiblePassage>{};

  Future<BiblePassage> fetchPassage(String reference, {String translation = 'kjv'}) async {
    final cacheKey = '$translation:$reference';
    final cached = _cache[cacheKey];
    if (cached != null) return cached;

    final uri = Uri.parse('$_baseUrl/${Uri.encodeComponent(reference)}?translation=$translation');
    final response = await _client.get(uri).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Could not load "$reference" (HTTP ${response.statusCode})');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    if (json['error'] != null) {
      throw Exception(json['error'] as String);
    }

    final passage = BiblePassage.fromJson(json);
    _cache[cacheKey] = passage;
    return passage;
  }
}

final bibleApiService = BibleApiService(http.Client());
