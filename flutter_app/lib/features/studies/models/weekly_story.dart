class WeeklyStory {
  WeeklyStory({
    required this.id,
    required this.title,
    required this.body,
    this.verseReference,
    this.audioUrl,
    this.imageUrl,
    required this.weekStartDate,
  });

  final String id;
  final String title;
  final String body;
  final String? verseReference;
  final String? audioUrl;
  final String? imageUrl;
  final DateTime weekStartDate;

  factory WeeklyStory.fromJson(Map<String, dynamic> json) {
    return WeeklyStory(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      verseReference: json['verse_reference'] as String?,
      audioUrl: json['audio_url'] as String?,
      imageUrl: json['image_url'] as String?,
      weekStartDate: DateTime.parse(json['week_start_date'] as String),
    );
  }
}
