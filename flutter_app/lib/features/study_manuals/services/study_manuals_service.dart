import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_init.dart';
import '../models/study_manual.dart';

class StudyManualsService {
  StudyManualsService(this._client);

  final SupabaseClient _client;

  Future<List<StudyManual>> fetchManuals() async {
    final rows = await _client.from('study_manuals').select().order('created_at', ascending: false);
    return (rows as List).map((r) => StudyManual.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<List<StudyManualChapter>> fetchChapters(String manualId) async {
    final rows = await _client
        .from('study_manual_chapters')
        .select()
        .eq('manual_id', manualId)
        .order('chapter_number');
    return (rows as List).map((r) => StudyManualChapter.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<Set<String>> fetchCompletedChapterIds(String manualId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};
    final rows = await _client
        .from('study_manual_progress')
        .select('chapter_id, study_manual_chapters!inner(manual_id)')
        .eq('user_id', userId)
        .eq('study_manual_chapters.manual_id', manualId);
    return (rows as List).map((r) => r['chapter_id'] as String).toSet();
  }

  Future<void> markChapterComplete(String chapterId) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('study_manual_progress').upsert(
      {'user_id': userId, 'chapter_id': chapterId},
      onConflict: 'user_id,chapter_id',
    );
  }
}

final studyManualsService = StudyManualsService(supabase);
