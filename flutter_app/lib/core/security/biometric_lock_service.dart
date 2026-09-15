import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Optional local app-lock. This is NOT part of account authentication
/// — the Google-backed Supabase session stays signed in regardless —
/// it's a purely local, opt-in gate (Face ID / fingerprint / device
/// passcode) so a user can require a biometric check before the app's
/// content is shown, useful on a shared device. Off by default.
class BiometricLockService {
  BiometricLockService(this._auth, this._prefs);

  static const _enabledKey = 'biometric_lock_enabled';

  final LocalAuthentication _auth;
  final Future<SharedPreferences> _prefs;

  Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      final canCheck = await _auth.canCheckBiometrics;
      return supported && canCheck;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isEnabled() async {
    final prefs = await _prefs;
    return prefs.getBool(_enabledKey) ?? false;
  }

  Future<void> setEnabled(bool enabled) async {
    final prefs = await _prefs;
    await prefs.setBool(_enabledKey, enabled);
  }

  /// Prompts for biometrics (falling back to device passcode). Returns
  /// false rather than throwing on cancel/failure/no-hardware, so
  /// callers can just show "try again" instead of handling exceptions.
  Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock the app',
        options: const AuthenticationOptions(biometricOnly: false, stickyAuth: true),
      );
    } catch (_) {
      return false;
    }
  }
}

final biometricLockService = BiometricLockService(LocalAuthentication(), SharedPreferences.getInstance());
