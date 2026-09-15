import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_init.dart';

/// Thin wrapper around Supabase Auth. Screens should depend on this,
/// not on `Supabase.instance.client.auth` directly, so auth behaviour
/// (e.g. profile bootstrapping) stays in one place.
class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  User? get currentUser => _client.auth.currentUser;

  bool get isSignedIn => currentUser != null;

  /// Emits on every auth state change (sign in, sign out, token refresh).
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  Future<void> sendPasswordResetEmail(String email) {
    return _client.auth.resetPasswordForEmail(email);
  }
}

final authService = AuthService(supabase);
