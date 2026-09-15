import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group.dart';
import '../services/groups_service.dart';

final myGroupsProvider = FutureProvider.autoDispose<List<Group>>((ref) {
  return groupsService.fetchMyGroups();
});

final groupMembersProvider = FutureProvider.autoDispose.family<List<GroupMember>, String>((ref, groupId) {
  return groupsService.fetchMembers(groupId);
});
