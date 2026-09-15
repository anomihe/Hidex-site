import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_init.dart';
import '../models/weekly_story.dart';

class StudiesService {
  StudiesService(this._client);

  final SupabaseClient _client;

  Future<List<WeeklyStory>> fetchStories({int limit = 20}) async {
    final rows = await _client
        .from('weekly_stories')
        .select()
        .order('week_start_date', ascending: false)
        .limit(limit);
    return (rows as List).map((r) => WeeklyStory.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<WeeklyStory> fetchOne(String id) async {
    final row = await _client.from('weekly_stories').select().eq('id', id).single();
    return WeeklyStory.fromJson(row);
  }
}

final studiesService = StudiesService(supabase);
