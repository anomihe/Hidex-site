import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_init.dart';
import '../models/treasure_hunt.dart';

class SubmitHuntAnswerResult {
  SubmitHuntAnswerResult({
    required this.isCorrect,
    required this.attempts,
    required this.pointsAwarded,
    this.alreadySolved = false,
  });

  final bool isCorrect;
  final int attempts;
  final int pointsAwarded;
  final bool alreadySolved;
}

class TreasureHuntsService {
  TreasureHuntsService(this._client);

  final SupabaseClient _client;

  Future<List<TreasureHunt>> fetchHunts(String groupId) async {
    final rows = await _client
        .from('treasure_hunts')
        .select()
        .eq('group_id', groupId)
        .order('starts_at', ascending: false);
    return (rows as List).map((r) => TreasureHunt.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<TreasureHunt> fetchHunt(String huntId) async {
    final row = await _client.from('treasure_hunts').select().eq('id', huntId).single();
    return TreasureHunt.fromJson(row);
  }

  /// Tasks come from `hunt_tasks_public`, which never includes the
  /// `answer` column — grading happens server-side via
  /// submit_hunt_answer, never on the client.
  Future<List<HuntTask>> fetchTasks(String huntId) async {
    final rows = await _client.from('hunt_tasks_public').select().eq('hunt_id', huntId).order('position');
    return (rows as List).map((r) => HuntTask.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<Map<String, HuntProgress>> fetchMyProgress(String huntId) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return {};
    final rows = await _client
        .from('hunt_progress')
        .select('task_id, is_correct, attempts')
        .eq('hunt_id', huntId)
        .eq('user_id', userId);
    return {
      for (final r in (rows as List)) r['task_id'] as String: HuntProgress.fromJson(r as Map<String, dynamic>),
    };
  }

  Future<SubmitHuntAnswerResult> submitAnswer({required String taskId, required String answer}) async {
    final res = await _client.functions.invoke(
      'submit_hunt_answer',
      body: {'task_id': taskId, 'answer': answer},
    );
    if (res.status != 200) {
      final error = (res.data is Map) ? res.data['error'] : 'Failed to submit answer';
      throw Exception(error);
    }
    final data = res.data as Map<String, dynamic>;
    return SubmitHuntAnswerResult(
      isCorrect: data['is_correct'] as bool,
      attempts: data['attempts'] as int? ?? 0,
      pointsAwarded: data['points_awarded'] as int? ?? 0,
      alreadySolved: data['already_solved'] as bool? ?? false,
    );
  }

  Future<int> fetchMyTotalPoints() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return 0;
    final row = await _client.from('user_points').select('total_points').eq('user_id', userId).maybeSingle();
    return row == null ? 0 : row['total_points'] as int;
  }

  Future<List<Reward>> fetchRewards() async {
    final rows = await _client.from('rewards').select().order('points_required');
    return (rows as List).map((r) => Reward.fromJson(r as Map<String, dynamic>)).toList();
  }
}

final treasureHuntsService = TreasureHuntsService(supabase);
