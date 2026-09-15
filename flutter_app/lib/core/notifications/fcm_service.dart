import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../supabase/supabase_init.dart';

/// Registers this device's FCM token in `device_tokens` so the
/// `send_push` edge function has somewhere to deliver to. This only
/// handles the client-side half (registration) — the send side lives
/// in supabase/edge_functions/send_push.ts.
class FcmService {
  FcmService(this._messaging);

  final FirebaseMessaging _messaging;

  /// Call once after sign-in (a token registered before the user is
  /// authenticated can't be written to `device_tokens`, which is RLS-
  /// scoped to `user_id = auth.uid()`).
  Future<void> registerDevice() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return;
    }

    final token = await _messaging.getToken();
    if (token != null) {
      await _upsertToken(token);
    }

    // Re-sync whenever FCM rotates the token.
    _messaging.onTokenRefresh.listen(_upsertToken);
  }

  Future<void> _upsertToken(String token) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase.from('device_tokens').upsert(
      {
        'user_id': userId,
        'fcm_token': token,
        'platform': _platformName(),
      },
      onConflict: 'user_id,fcm_token',
    );
  }

  /// Best-effort cleanup on sign-out so a shared/borrowed device stops
  /// receiving another account's pushes.
  Future<void> unregisterCurrentDevice() async {
    final token = await _messaging.getToken();
    final userId = supabase.auth.currentUser?.id;
    if (token == null || userId == null) return;

    await supabase
        .from('device_tokens')
        .delete()
        .eq('user_id', userId)
        .eq('fcm_token', token);
  }

  String _platformName() {
    if (kIsWeb) return 'web';
    return Platform.isIOS ? 'ios' : 'android';
  }
}

final fcmService = FcmService(FirebaseMessaging.instance);
