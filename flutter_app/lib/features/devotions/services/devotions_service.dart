import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_init.dart';
import '../models/devotion.dart';

class DevotionsService {
  DevotionsService(this._client);

  final SupabaseClient _client;

  Future<List<Devotion>> fetchFeed({int limit = 20, DateTime? before}) async {
    var filterQuery = _client.from('devotions').select();
    if (before != null) {
      filterQuery = filterQuery.lt('published_at', before.toIso8601String());
    }
    final rows = await filterQuery.order('published_at', ascending: false).limit(limit);

    final likedIds = await _fetchMyLikedIds();
    return (rows as List)
        .map((r) => Devotion.fromJson(r as Map<String, dynamic>, likedByMe: likedIds.contains(r['id'])))
        .toList();
  }

  Future<Devotion> fetchOne(String id) async {
    final row = await _client.from('devotions').select().eq('id', id).single();
    final likedIds = await _fetchMyLikedIds();
    return Devotion.fromJson(row, likedByMe: likedIds.contains(id));
  }

  Future<Set<String>> _fetchMyLikedIds() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};
    final rows = await _client.from('devotion_likes').select('devotion_id').eq('user_id', userId);
    return (rows as List).map((r) => r['devotion_id'] as String).toSet();
  }

  Future<void> toggleLike(String devotionId, bool currentlyLiked) async {
    final userId = _client.auth.currentUser!.id;
    if (currentlyLiked) {
      await _client.from('devotion_likes').delete().eq('devotion_id', devotionId).eq('user_id', userId);
    } else {
      await _client.from('devotion_likes').insert({'devotion_id': devotionId, 'user_id': userId});
    }
  }
}

final devotionsService = DevotionsService(supabase);
