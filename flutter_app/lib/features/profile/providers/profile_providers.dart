import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/security/biometric_lock_service.dart';
import '../models/profile.dart';
import '../services/profile_service.dart';

final myProfileProvider = FutureProvider.autoDispose<Profile>((ref) {
  return profileService.fetchMyProfile();
});

final biometricAvailableProvider = FutureProvider.autoDispose<bool>((ref) {
  return biometricLockService.isAvailable();
});

final biometricEnabledProvider = FutureProvider.autoDispose<bool>((ref) {
  return biometricLockService.isEnabled();
});
