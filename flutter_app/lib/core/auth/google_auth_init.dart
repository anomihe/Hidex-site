import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Bootstraps `google_sign_in` once at app start, as required by v7 of
/// the plugin ("initialize must be called exactly once ... before any
/// other methods"). Call this from `main()` before `runApp`.
///
/// `GOOGLE_WEB_CLIENT_ID` (a Web OAuth client ID) is required — it's
/// passed as `serverClientId` so the ID token's `aud` claim matches the
/// Client ID(s) configured under Supabase Dashboard → Authentication →
/// Providers → Google. This is the same Web client ID a Firebase
/// project auto-creates when you enable Google sign-in in the Firebase
/// console (Authentication → Sign-in method → Google), so setting up
/// Firebase for FCM and setting up Google Sign-In share this value.
///
/// `GOOGLE_IOS_CLIENT_ID` is optional and only used on iOS, where it's
/// passed as `clientId`.
class GoogleAuthInit {
  GoogleAuthInit._();

  static bool _initialized = false;
  static bool get isConfigured => _initialized;

  static Future<void> init() async {
    if (kIsWeb || _initialized) return;

    final webClientId = dotenv.maybeGet('GOOGLE_WEB_CLIENT_ID');
    if (webClientId == null || webClientId.isEmpty) {
      // Not configured yet — the "Continue with Google" button will
      // show a clear error instead of crashing at startup. See
      // flutter_app/README.md for how to set this up.
      return;
    }

    final iosClientId = dotenv.maybeGet('GOOGLE_IOS_CLIENT_ID');

    await GoogleSignIn.instance.initialize(
      clientId: (!kIsWeb && Platform.isIOS && iosClientId != null && iosClientId.isNotEmpty)
          ? iosClientId
          : null,
      serverClientId: webClientId,
    );
    _initialized = true;
  }
}
