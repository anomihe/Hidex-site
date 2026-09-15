class Devotion {
  Devotion({
    required this.id,
    required this.title,
    required this.body,
    this.verseReference,
    this.verseText,
    this.author,
    this.imageUrl,
    required this.publishedAt,
    this.likedByMe = false,
  });

  final String id;
  final String title;
  final String body;
  final String? verseReference;
  final String? verseText;
  final String? author;
  final String? imageUrl;
  final DateTime publishedAt;
  final bool likedByMe;

  factory Devotion.fromJson(Map<String, dynamic> json, {bool likedByMe = false}) {
    return Devotion(
      id: json['id'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      verseReference: json['verse_reference'] as String?,
      verseText: json['verse_text'] as String?,
      author: json['author'] as String?,
      imageUrl: json['image_url'] as String?,
      publishedAt: DateTime.parse(json['published_at'] as String),
      likedByMe: likedByMe,
    );
  }
}
