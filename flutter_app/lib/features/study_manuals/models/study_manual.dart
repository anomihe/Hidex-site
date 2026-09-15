class StudyManual {
  StudyManual({
    required this.id,
    required this.title,
    this.description,
    this.coverImageUrl,
  });

  final String id;
  final String title;
  final String? description;
  final String? coverImageUrl;

  factory StudyManual.fromJson(Map<String, dynamic> json) {
    return StudyManual(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
    );
  }
}

class StudyManualChapter {
  StudyManualChapter({
    required this.id,
    required this.manualId,
    required this.chapterNumber,
    required this.title,
    required this.content,
  });

  final String id;
  final String manualId;
  final int chapterNumber;
  final String title;
  final String content;

  factory StudyManualChapter.fromJson(Map<String, dynamic> json) {
    return StudyManualChapter(
      id: json['id'] as String,
      manualId: json['manual_id'] as String,
      chapterNumber: json['chapter_number'] as int,
      title: json['title'] as String,
      content: json['content'] as String,
    );
  }
}
