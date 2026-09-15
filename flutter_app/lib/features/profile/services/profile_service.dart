import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_init.dart';
import '../models/profile.dart';

class ProfileService {
  ProfileService(this._client);

  final SupabaseClient _client;

  Future<Profile> fetchMyProfile() async {
    final userId = _client.auth.currentUser!.id;
    final row = await _client.from('profiles').select().eq('id', userId).single();
    return Profile.fromJson(row, email: _client.auth.currentUser?.email);
  }

  Future<void> updateDisplayName(String displayName) async {
    final userId = _client.auth.currentUser!.id;
    await _client.from('profiles').update({'display_name': displayName}).eq('id', userId);
  }

  /// Uploads a new avatar image and points `profiles.avatar_url` at it.
  /// Always writes to the same path per user (`<userId>/avatar.<ext>`)
  /// with `upsert: true`, so old avatars don't pile up in storage.
  Future<String> uploadAvatar({required Uint8List bytes, required String fileExtension}) async {
    final userId = _client.auth.currentUser!.id;
    final path = '$userId/avatar.$fileExtension';

    await _client.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: 'image/$fileExtension',
          ),
        );

    // Cache-bust so CachedNetworkImage/Image.network don't keep showing
    // the previous avatar at the same URL.
    final publicUrl = '${_client.storage.from('avatars').getPublicUrl(path)}?t=${DateTime.now().millisecondsSinceEpoch}';

    await _client.from('profiles').update({'avatar_url': publicUrl}).eq('id', userId);
    return publicUrl;
  }
}

final profileService = ProfileService(supabase);
