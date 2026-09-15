import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/quiz.dart';
import '../services/live_quiz_service.dart';

final quizStreamProvider = StreamProvider.autoDispose.family<Quiz, String>((ref, quizId) {
  return liveQuizService.watchQuiz(quizId);
});

final quizQuestionsProvider = FutureProvider.autoDispose.family<List<QuizQuestion>, String>((ref, quizId) {
  return liveQuizService.fetchQuestions(quizId);
});

final quizParticipantsStreamProvider =
    StreamProvider.autoDispose.family<List<QuizParticipant>, String>((ref, quizId) {
  return liveQuizService.watchParticipants(quizId);
});
