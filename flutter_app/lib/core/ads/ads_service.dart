import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob bootstrap. `ADMOB_APP_ID_*` in `.env` default to Google's test
/// app IDs (see `.env.example`) so the SDK initializes safely in dev —
/// swap them for your real AdMob app IDs (and update the native
/// AndroidManifest.xml / Info.plist entries, which must match) before
/// shipping.
///
/// This only initializes the SDK. Ad units themselves (banner,
/// interstitial, rewarded) aren't wired into any screen yet — add
/// `AdWidget`s where you want them once you have real ad unit IDs.
class AdsService {
  AdsService._();

  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;
    await MobileAds.instance.initialize();
    _initialized = true;
  }

  static String? get appIdAndroid => dotenv.maybeGet('ADMOB_APP_ID_ANDROID');
  static String? get appIdIos => dotenv.maybeGet('ADMOB_APP_ID_IOS');
}
