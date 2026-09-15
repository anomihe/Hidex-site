class ReadingPlan {
  ReadingPlan({
    required this.id,
    required this.title,
    this.description,
    required this.durationDays,
    this.coverImageUrl,
  });

  final String id;
  final String title;
  final String? description;
  final int durationDays;
  final String? coverImageUrl;

  factory ReadingPlan.fromJson(Map<String, dynamic> json) {
    return ReadingPlan(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      durationDays: json['duration_days'] as int,
      coverImageUrl: json['cover_image_url'] as String?,
    );
  }
}

class ReadingPlanDay {
  ReadingPlanDay({
    required this.id,
    required this.planId,
    required this.dayNumber,
    required this.reference,
    this.readingText,
    this.reflection,
  });

  final String id;
  final String planId;
  final int dayNumber;
  final String reference;
  final String? readingText;
  final String? reflection;

  factory ReadingPlanDay.fromJson(Map<String, dynamic> json) {
    return ReadingPlanDay(
      id: json['id'] as String,
      planId: json['plan_id'] as String,
      dayNumber: json['day_number'] as int,
      reference: json['reference'] as String,
      readingText: json['reading_text'] as String?,
      reflection: json['reflection'] as String?,
    );
  }
}

class ReadingPlanEnrollment {
  ReadingPlanEnrollment({
    required this.id,
    required this.planId,
    required this.userId,
    required this.startedAt,
  });

  final String id;
  final String planId;
  final String userId;
  final DateTime startedAt;

  factory ReadingPlanEnrollment.fromJson(Map<String, dynamic> json) {
    return ReadingPlanEnrollment(
      id: json['id'] as String,
      planId: json['plan_id'] as String,
      userId: json['user_id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
    );
  }
}

class UserStreak {
  const UserStreak({
    required this.currentStreak,
    required this.longestStreak,
    this.lastActivityDate,
  });

  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActivityDate;

  static const zero = UserStreak(currentStreak: 0, longestStreak: 0);

  factory UserStreak.fromJson(Map<String, dynamic> json) {
    return UserStreak(
      currentStreak: json['current_streak'] as int,
      longestStreak: json['longest_streak'] as int,
      lastActivityDate: json['last_activity_date'] != null
          ? DateTime.parse(json['last_activity_date'] as String)
          : null,
    );
  }
}
