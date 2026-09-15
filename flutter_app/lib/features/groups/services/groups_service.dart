import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_init.dart';
import '../models/group.dart';

class GroupsService {
  GroupsService(this._client);

  final SupabaseClient _client;

  Future<List<Group>> fetchMyGroups() async {
    final rows = await _client
        .from('group_members')
        .select('role, groups(*)')
        .eq('user_id', _client.auth.currentUser!.id)
        .order('joined_at', ascending: false);

    return (rows as List).map((row) => Group.fromJson(row as Map<String, dynamic>)).toList();
  }

  Future<Group> createGroup({required String name, String? description}) async {
    final row = await _client
        .from('groups')
        .insert({
          'name': name,
          'description': description,
          'created_by': _client.auth.currentUser!.id,
        })
        .select()
        .single();

    return Group.fromJson(row);
  }

  Future<Group> joinGroupByCode(String inviteCode) async {
    final row = await _client.rpc('join_group_by_code', params: {'p_invite_code': inviteCode});
    return Group.fromJson(row as Map<String, dynamic>);
  }

  Future<Group> fetchGroup(String groupId) async {
    final row = await _client.from('groups').select().eq('id', groupId).single();
    return Group.fromJson(row);
  }

  Future<List<GroupMember>> fetchMembers(String groupId) async {
    final rows = await _client
        .from('group_members')
        .select('user_id, role, joined_at, profiles(display_name, avatar_url)')
        .eq('group_id', groupId)
        .order('joined_at');

    return (rows as List).map((row) => GroupMember.fromJson(row as Map<String, dynamic>)).toList();
  }

  Future<void> leaveGroup(String groupId) async {
    await _client
        .from('group_members')
        .delete()
        .eq('group_id', groupId)
        .eq('user_id', _client.auth.currentUser!.id);
  }
}

final groupsService = GroupsService(supabase);
