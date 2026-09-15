class Quiz {
  Quiz({
    required this.id,
    required this.groupId,
    required this.title,
    required this.startsAt,
    required this.joinWindowSeconds,
    required this.status,
  });

  final String id;
  final String groupId;
  final String title;
  final DateTime startsAt;
  final int joinWindowSeconds;
  final String status; // scheduled | join_open | live | closed

  DateTime get joinOpensAt => startsAt.subtract(Duration(seconds: joinWindowSeconds));

  factory Quiz.fromJson(Map<String, dynamic> json) {
    return Quiz(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      title: json['title'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String),
      joinWindowSeconds: json['join_window_seconds'] as int,
      status: json['status'] as String,
    );
  }
}

class QuizQuestion {
  QuizQuestion({
    required this.id,
    required this.quizId,
    required this.position,
    required this.question,
    required this.options,
    required this.points,
    required this.timeLimitSeconds,
  });

  final String id;
  final String quizId;
  final int position;
  final String question;
  final List<String> options;
  final int points;
  final int timeLimitSeconds;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'] as String,
      quizId: json['quiz_id'] as String,
      position: json['position'] as int,
      question: json['question'] as String,
      options: (json['options'] as List).map((o) => o.toString()).toList(),
      points: json['points'] as int,
      timeLimitSeconds: json['time_limit_seconds'] as int,
    );
  }
}

class QuizParticipant {
  QuizParticipant({
    required this.userId,
    required this.score,
    required this.joinedAt,
    this.displayName,
  });

  final String userId;
  final int score;
  final DateTime joinedAt;
  final String? displayName;

  factory QuizParticipant.fromJson(Map<String, dynamic> json, {String? displayName}) {
    return QuizParticipant(
      userId: json['user_id'] as String,
      score: json['score'] as int,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      displayName: displayName,
    );
  }
}
