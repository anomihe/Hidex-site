class TreasureHunt {
  TreasureHunt({
    required this.id,
    required this.groupId,
    required this.title,
    this.description,
    required this.startsAt,
    required this.endsAt,
    required this.status,
  });

  final String id;
  final String groupId;
  final String title;
  final String? description;
  final DateTime startsAt;
  final DateTime endsAt;
  final String status; // scheduled | active | closed

  factory TreasureHunt.fromJson(Map<String, dynamic> json) {
    return TreasureHunt(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      startsAt: DateTime.parse(json['starts_at'] as String),
      endsAt: DateTime.parse(json['ends_at'] as String),
      status: json['status'] as String,
    );
  }
}

class HuntTask {
  HuntTask({
    required this.id,
    required this.huntId,
    required this.position,
    required this.prompt,
    required this.points,
    this.hint,
  });

  final String id;
  final String huntId;
  final int position;
  final String prompt;
  final int points;
  final String? hint;

  factory HuntTask.fromJson(Map<String, dynamic> json) {
    return HuntTask(
      id: json['id'] as String,
      huntId: json['hunt_id'] as String,
      position: json['position'] as int,
      prompt: json['prompt'] as String,
      points: json['points'] as int,
      hint: json['hint'] as String?,
    );
  }
}

class HuntProgress {
  HuntProgress({
    required this.taskId,
    required this.isCorrect,
    required this.attempts,
  });

  final String taskId;
  final bool isCorrect;
  final int attempts;

  factory HuntProgress.fromJson(Map<String, dynamic> json) {
    return HuntProgress(
      taskId: json['task_id'] as String,
      isCorrect: json['is_correct'] as bool,
      attempts: json['attempts'] as int,
    );
  }
}

class Reward {
  Reward({
    required this.id,
    required this.code,
    required this.title,
    this.description,
    required this.pointsRequired,
  });

  final String id;
  final String code;
  final String title;
  final String? description;
  final int pointsRequired;

  factory Reward.fromJson(Map<String, dynamic> json) {
    return Reward(
      id: json['id'] as String,
      code: json['code'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      pointsRequired: json['points_required'] as int,
    );
  }
}
