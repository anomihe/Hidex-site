import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/ads/ads_service.dart';
import 'core/auth/auth_providers.dart';
import 'core/billing/revenuecat_service.dart';
import 'core/notifications/fcm_service.dart';
import 'core/router/app_router.dart';
import 'core/supabase/supabase_init.dart';
import 'core/theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');
  await SupabaseInit.init();

  // Firebase requires platform config files (google-services.json /
  // GoogleService-Info.plist, generated via `flutterfire configure`)
  // that aren't part of this scaffold. Guard the boot so the rest of
  // the app still runs before that's wired up — push notifications
  // just won't register until it is.
  var firebaseReady = false;
  try {
    await Firebase.initializeApp();
    firebaseReady = true;
  } catch (_) {
    debugPrint('Firebase not configured yet — skipping FCM registration. Run `flutterfire configure`.');
  }

  await AdsService.init();
  await RevenueCatService.init();

  runApp(ProviderScope(child: BibleApp(firebaseReady: firebaseReady)));
}

class BibleApp extends ConsumerStatefulWidget {
  const BibleApp({super.key, required this.firebaseReady});

  final bool firebaseReady;

  @override
  ConsumerState<BibleApp> createState() => _BibleAppState();
}

class _BibleAppState extends ConsumerState<BibleApp> {
  @override
  void initState() {
    super.initState();
    ref.listenManual(currentUserProvider, (previous, next) {
      if (previous == null && next != null) {
        _onSignedIn(next.id);
      } else if (previous != null && next == null) {
        RevenueCatService.logOut();
      }
    });
    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null) _onSignedIn(currentUser.id);
  }

  Future<void> _onSignedIn(String userId) async {
    await RevenueCatService.identify(userId);
    if (widget.firebaseReady) {
      await fcmService.registerDevice();
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Bible App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      routerConfig: router,
    );
  }
}
