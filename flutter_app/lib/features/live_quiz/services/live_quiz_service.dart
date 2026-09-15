import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_init.dart';
import '../models/quiz.dart';

class SubmitAnswerResult {
  SubmitAnswerResult({required this.isCorrect, required this.pointsAwarded});
  final bool isCorrect;
  final int pointsAwarded;
}

class LiveQuizService {
  LiveQuizService(this._client);

  final SupabaseClient _client;

  Future<Quiz> fetchQuiz(String quizId) async {
    final row = await _client.from('quizzes').select().eq('id', quizId).single();
    return Quiz.fromJson(row);
  }

  Future<List<Quiz>> fetchQuizzesForGroup(String groupId) async {
    final rows = await _client.from('quizzes').select().eq('group_id', groupId).order('starts_at', ascending: false);
    return (rows as List).map((r) => Quiz.fromJson(r as Map<String, dynamic>)).toList();
  }

  Future<Quiz> createQuiz({
    required String groupId,
    required String title,
    required DateTime startsAt,
    int joinWindowSeconds = 120,
  }) async {
    final row = await _client
        .from('quizzes')
        .insert({
          'group_id': groupId,
          'title': title,
          'starts_at': startsAt.toIso8601String(),
          'join_window_seconds': joinWindowSeconds,
          'created_by': _client.auth.currentUser!.id,
        })
        .select()
        .single();
    return Quiz.fromJson(row);
  }

  /// Live updates to quiz status (scheduled -> join_open -> live ->
  /// closed), driven server-side by the `advance-quiz-status` cron job.
  Stream<Quiz> watchQuiz(String quizId) {
    return _client
        .from('quizzes')
        .stream(primaryKey: ['id'])
        .eq('id', quizId)
        .map((rows) => Quiz.fromJson(rows.first));
  }

  Future<List<QuizQuestion>> fetchQuestions(String quizId) async {
    final rows = await _client
        .from('quiz_questions_public')
        .select()
        .eq('quiz_id', quizId)
        .order('position');
    return (rows as List).map((r) => QuizQuestion.fromJson(r as Map<String, dynamic>)).toList();
  }

  /// Joins the quiz through the join_quiz edge function so the join
  /// window is enforced by the server's clock, not the device's.
  Future<void> joinQuiz(String quizId) async {
    final res = await _client.functions.invoke('join_quiz', body: {'quiz_id': quizId});
    if (res.status != 200) {
      final error = (res.data is Map) ? res.data['error'] : 'Failed to join quiz';
      throw Exception(error);
    }
  }

  /// Live list of everyone who has joined (and their running score),
  /// used for both the participant list and the leaderboard.
  Stream<List<QuizParticipant>> watchParticipants(String quizId) {
    return _client
        .from('quiz_participants')
        .stream(primaryKey: ['id'])
        .eq('quiz_id', quizId)
        .map((rows) => rows.map((r) => QuizParticipant.fromJson(r)).toList());
  }

  /// Grades server-side via submit_quiz_answer() — the client never
  /// sees `correct_option`, only the outcome of its own submission.
  Future<SubmitAnswerResult> submitAnswer({
    required String questionId,
    required int selectedOption,
    int? responseMs,
  }) async {
    final rows = await _client.rpc('submit_quiz_answer', params: {
      'p_question_id': questionId,
      'p_selected_option': selectedOption,
      'p_response_ms': responseMs,
    });
    final row = (rows as List).first as Map<String, dynamic>;
    return SubmitAnswerResult(
      isCorrect: row['is_correct'] as bool,
      pointsAwarded: row['points_awarded'] as int,
    );
  }

  Future<bool> hasAnswered(String questionId) async {
    final row = await _client
        .from('quiz_answers')
        .select('id')
        .eq('question_id', questionId)
        .eq('user_id', _client.auth.currentUser!.id)
        .maybeSingle();
    return row != null;
  }
}

final liveQuizService = LiveQuizService(supabase);
