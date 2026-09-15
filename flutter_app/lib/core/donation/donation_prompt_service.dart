import 'package:shared_preferences/shared_preferences.dart';

/// Decides when to show the periodic "support this app" prompt —
/// roughly twice a week, tracked purely on-device (no server schedule
/// needed). Call [shouldShow] once per app open/home screen build; if
/// it returns true, show the dialog and then call [markShown].
class DonationPromptService {
  DonationPromptService(this._prefs);

  static const _lastShownKey = 'donation_prompt_last_shown_at';
  static const minInterval = Duration(days: 3);

  final Future<SharedPreferences> _prefs;

  Future<bool> shouldShow() async {
    final prefs = await _prefs;
    final lastShownMillis = prefs.getInt(_lastShownKey);
    if (lastShownMillis == null) {
      // Don't prompt on someone's very first open — let them use the
      // app a little first.
      await markShown();
      return false;
    }
    final lastShown = DateTime.fromMillisecondsSinceEpoch(lastShownMillis);
    return DateTime.now().difference(lastShown) >= minInterval;
  }

  Future<void> markShown() async {
    final prefs = await _prefs;
    await prefs.setInt(_lastShownKey, DateTime.now().millisecondsSinceEpoch);
  }
}

final donationPromptService = DonationPromptService(SharedPreferences.getInstance());
