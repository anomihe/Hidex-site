import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_init.dart';
import 'google_auth_init.dart';

/// Thin wrapper around Supabase Auth. Sign-in is Google-only for now:
/// google_sign_in gets a Google ID token natively, which is then
/// exchanged for a Supabase session via `signInWithIdToken`. Screens
/// should depend on this, not on `Supabase.instance.client.auth` or
/// `GoogleSignIn` directly, so that exchange stays in one place.
class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  bool get isSignedIn => currentUser != null;

  /// Emits on every auth state change (sign in, sign out, token refresh).
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<AuthResponse> signInWithGoogle() async {
    if (!GoogleAuthInit.isConfigured) {
      throw StateError(
        'Google sign-in is not configured. Set GOOGLE_WEB_CLIENT_ID in '
        'flutter_app/.env — see flutter_app/README.md for how to get it '
        'from your Firebase/Google Cloud project.',
      );
    }

    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;

    if (idToken == null) {
      throw StateError('Google did not return an ID token — try signing in again.');
    }

    return _client.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );
  }

  Future<void> signOut() async {
    await Future.wait([
      _client.auth.signOut(),
      if (GoogleAuthInit.isConfigured) GoogleSignIn.instance.signOut(),
    ]);
  }
}

final authService = AuthService(supabase);
