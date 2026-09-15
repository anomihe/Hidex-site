import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/auth/auth_providers.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/security/biometric_lock_service.dart';
import '../providers/profile_providers.dart';
import '../services/profile_service.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _uploadingAvatar = false;
  bool _signingOut = false;

  Future<void> _changeAvatar() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 640,
      maxHeight: 640,
      imageQuality: 85,
    );
    if (picked == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      final bytes = await picked.readAsBytes();
      final extension = picked.path.split('.').last.toLowerCase();
      await profileService.uploadAvatar(
        bytes: bytes,
        fileExtension: extension == 'png' ? 'png' : 'jpg',
      );
      ref.invalidate(myProfileProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update photo: $e')));
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _editDisplayName(String currentName) async {
    final controller = TextEditingController(text: currentName);
    final newName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit name'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (newName == null || newName.isEmpty || newName == currentName) return;

    try {
      await profileService.updateDisplayName(newName);
      ref.invalidate(myProfileProvider);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update name: $e')));
    }
  }

  Future<void> _toggleBiometricLock(bool enable) async {
    if (enable) {
      final verified = await biometricLockService.authenticate();
      if (!verified) return;
    }
    await biometricLockService.setEnabled(enable);
    ref.invalidate(biometricEnabledProvider);
  }

  Future<void> _signOut() async {
    setState(() => _signingOut = true);
    try {
      await ref.read(authServiceProvider).signOut();
      // Navigation to /auth happens automatically via the router's
      // redirect, which watches authStateProvider.
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(myProfileProvider);
    final biometricAvailableAsync = ref.watch(biometricAvailableProvider);
    final biometricEnabledAsync = ref.watch(biometricEnabledProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load profile: $e')),
        data: (profile) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 48,
                    backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                    child: profile.avatarUrl == null
                        ? Text(
                            profile.displayName.isNotEmpty ? profile.displayName[0].toUpperCase() : '?',
                            style: const TextStyle(fontSize: 32),
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: InkWell(
                      onTap: _uploadingAvatar ? null : _changeAvatar,
                      borderRadius: BorderRadius.circular(20),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: _uploadingAvatar
                            ? const SizedBox(
                                height: 14,
                                width: 14,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () => _editDisplayName(profile.displayName),
                icon: Text(profile.displayName, style: Theme.of(context).textTheme.titleLarge),
                label: const Icon(Icons.edit, size: 16),
              ),
            ),
            if (profile.email != null)
              Center(
                child: Text(profile.email!, style: Theme.of(context).textTheme.bodyMedium),
              ),
            const SizedBox(height: 32),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: biometricAvailableAsync.when(
                loading: () => const ListTile(title: Text('Checking biometrics...')),
                error: (_, __) => const SizedBox.shrink(),
                data: (available) {
                  if (!available) return const SizedBox.shrink();
                  final enabled = biometricEnabledAsync.value ?? false;
                  return SwitchListTile(
                    secondary: const Icon(Icons.fingerprint),
                    title: const Text('Biometric app lock'),
                    subtitle: const Text('Require Face ID / fingerprint to open the app'),
                    value: enabled,
                    onChanged: _toggleBiometricLock,
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.volunteer_activism),
                title: const Text('Support this app'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(AppRoutes.donate),
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _signingOut ? null : _signOut,
              icon: _signingOut
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
