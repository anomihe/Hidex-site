import 'quiz.dart';

/// Derives "which question should be showing right now" purely from
/// `quiz.startsAt` + each question's `timeLimitSeconds`, so the client
/// stays in sync with the same clock-based logic the
/// `advance-quiz-status` cron job uses to close the quiz.
class QuizTimeline {
  QuizTimeline(this.quiz, this.questions);

  final Quiz quiz;
  final List<QuizQuestion> questions;

  /// Index into [questions], or -1 if the quiz hasn't started / has
  /// already run through every question.
  int currentIndexAt(DateTime now) {
    if (questions.isEmpty) return -1;
    var elapsed = now.difference(quiz.startsAt).inMilliseconds;
    if (elapsed < 0) return -1;

    for (var i = 0; i < questions.length; i++) {
      final limitMs = questions[i].timeLimitSeconds * 1000;
      if (elapsed < limitMs) return i;
      elapsed -= limitMs;
    }
    return -1;
  }

  QuizQuestion? currentQuestionAt(DateTime now) {
    final index = currentIndexAt(now);
    return index == -1 ? null : questions[index];
  }

  /// Seconds remaining on the current question, 0 if none is active.
  int remainingSecondsAt(DateTime now) {
    final index = currentIndexAt(now);
    if (index == -1) return 0;

    var elapsed = now.difference(quiz.startsAt).inMilliseconds;
    for (var i = 0; i < index; i++) {
      elapsed -= questions[i].timeLimitSeconds * 1000;
    }
    final remainingMs = (questions[index].timeLimitSeconds * 1000) - elapsed;
    return (remainingMs / 1000).ceil().clamp(0, questions[index].timeLimitSeconds);
  }

  Duration totalDuration() {
    final totalSeconds = questions.fold<int>(0, (sum, q) => sum + q.timeLimitSeconds);
    return Duration(seconds: totalSeconds);
  }

  bool hasFinishedAt(DateTime now) {
    if (questions.isEmpty) return now.isAfter(quiz.startsAt);
    return now.isAfter(quiz.startsAt.add(totalDuration()));
  }
}
