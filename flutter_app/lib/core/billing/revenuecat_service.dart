import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

/// RevenueCat bootstrap. Requires `REVENUECAT_API_KEY_ANDROID` /
/// `REVENUECAT_API_KEY_IOS` in `.env` — get these from the RevenueCat
/// dashboard once the app is registered there. Until those are set,
/// `init()` is a safe no-op so the rest of the app keeps working
/// without subscriptions configured.
///
/// This only initializes the SDK and exposes `currentOfferings` /
/// `isEntitled`. No paywall UI or entitlement gating is wired into any
/// screen yet.
class RevenueCatService {
  RevenueCatService._();

  static bool _initialized = false;

  static Future<void> init() async {
    if (kIsWeb || _initialized) return;

    final apiKey = Platform.isIOS
        ? dotenv.maybeGet('REVENUECAT_API_KEY_IOS')
        : dotenv.maybeGet('REVENUECAT_API_KEY_ANDROID');

    if (apiKey == null || apiKey.isEmpty) {
      return;
    }

    await Purchases.setLogLevel(LogLevel.warn);
    await Purchases.configure(PurchasesConfiguration(apiKey));
    _initialized = true;
  }

  static Future<void> identify(String userId) async {
    if (!_initialized) return;
    await Purchases.logIn(userId);
  }

  static Future<void> logOut() async {
    if (!_initialized) return;
    await Purchases.logOut();
  }

  static Future<Offerings?> currentOfferings() async {
    if (!_initialized) return null;
    return Purchases.getOfferings();
  }

  static Future<bool> isEntitled(String entitlementId) async {
    if (!_initialized) return false;
    final info = await Purchases.getCustomerInfo();
    return info.entitlements.active.containsKey(entitlementId);
  }
}
