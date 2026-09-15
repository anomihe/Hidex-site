import 'package:flutter/material.dart';

import '../../core/security/biometric_lock_service.dart';

/// Wraps the app's content and, when the user has opted into the
/// biometric app-lock (see Profile), blocks it behind a Face ID /
/// fingerprint / passcode prompt on each cold start. Purely local — has
/// nothing to do with the Supabase/Google session, which stays signed
/// in either way.
class BiometricLockGate extends StatefulWidget {
  const BiometricLockGate({super.key, required this.child});

  final Widget child;

  @override
  State<BiometricLockGate> createState() => _BiometricLockGateState();
}

class _BiometricLockGateState extends State<BiometricLockGate> {
  bool _checked = false;
  bool _locked = false;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    _checkLock();
  }

  Future<void> _checkLock() async {
    final enabled = await biometricLockService.isEnabled();
    if (!mounted) return;
    setState(() {
      _locked = enabled;
      _checked = true;
    });
    if (enabled) _unlock();
  }

  Future<void> _unlock() async {
    if (_authenticating) return;
    setState(() => _authenticating = true);
    final success = await biometricLockService.authenticate();
    if (!mounted) return;
    setState(() {
      _authenticating = false;
      if (success) _locked = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked) return const SizedBox.shrink();
    if (!_locked) return widget.child;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.fingerprint, size: 64, color: Theme.of(context).colorScheme.primary),
                const SizedBox(height: 16),
                const Text('App locked', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                const Text('Verify to continue', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _authenticating ? null : _unlock,
                  child: _authenticating
                      ? const SizedBox(
                          height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Unlock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
