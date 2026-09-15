import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/devotion.dart';
import '../services/devotions_service.dart';

final devotionsFeedProvider = FutureProvider.autoDispose<List<Devotion>>((ref) {
  return devotionsService.fetchFeed();
});

final devotionDetailProvider = FutureProvider.autoDispose.family<Devotion, String>((ref, id) {
  return devotionsService.fetchOne(id);
});
