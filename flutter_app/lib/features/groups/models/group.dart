class Group {
  Group({
    required this.id,
    required this.name,
    this.description,
    required this.inviteCode,
    required this.createdBy,
    required this.createdAt,
    this.myRole,
  });

  final String id;
  final String name;
  final String? description;
  final String inviteCode;
  final String createdBy;
  final DateTime createdAt;
  final String? myRole;

  factory Group.fromJson(Map<String, dynamic> json) {
    // Supports both a plain `groups` row and the joined shape returned
    // by GroupsService.fetchMyGroups (group_members -> groups(*)).
    final groupJson = json['groups'] as Map<String, dynamic>? ?? json;
    return Group(
      id: groupJson['id'] as String,
      name: groupJson['name'] as String,
      description: groupJson['description'] as String?,
      inviteCode: groupJson['invite_code'] as String,
      createdBy: groupJson['created_by'] as String,
      createdAt: DateTime.parse(groupJson['created_at'] as String),
      myRole: json['role'] as String?,
    );
  }
}

class GroupMember {
  GroupMember({
    required this.userId,
    required this.role,
    required this.joinedAt,
    this.displayName,
    this.avatarUrl,
  });

  final String userId;
  final String role;
  final DateTime joinedAt;
  final String? displayName;
  final String? avatarUrl;

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return GroupMember(
      userId: json['user_id'] as String,
      role: json['role'] as String,
      joinedAt: DateTime.parse(json['joined_at'] as String),
      displayName: profile?['display_name'] as String?,
      avatarUrl: profile?['avatar_url'] as String?,
    );
  }
}
