class Profile {
  Profile({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.email,
  });

  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? email;

  factory Profile.fromJson(Map<String, dynamic> json, {String? email}) {
    return Profile(
      id: json['id'] as String,
      displayName: json['display_name'] as String,
      avatarUrl: json['avatar_url'] as String?,
      email: email,
    );
  }
}
