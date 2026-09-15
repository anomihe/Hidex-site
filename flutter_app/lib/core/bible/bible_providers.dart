import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'bible_api_service.dart';

/// Live scripture text for a reference (e.g. "John 3:16-21"), fetched
/// from bible-api.com and cached in-memory by BibleApiService. Used
/// wherever a screen has a reference but no admin-entered text to show.
final biblePassageProvider = FutureProvider.autoDispose.family<BiblePassage, String>((ref, reference) {
  return bibleApiService.fetchPassage(reference);
});
