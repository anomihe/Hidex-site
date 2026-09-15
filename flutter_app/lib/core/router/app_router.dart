import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/screens/auth_screen.dart';
import '../../features/devotions/screens/devotion_detail_screen.dart';
import '../../features/devotions/screens/devotions_feed_screen.dart';
import '../../features/groups/screens/create_group_screen.dart';
import '../../features/groups/screens/group_detail_screen.dart';
import '../../features/groups/screens/group_list_screen.dart';
import '../../features/live_quiz/screens/live_quiz_screen.dart';
import '../../features/reading_plans/screens/reading_plan_detail_screen.dart';
import '../../features/reading_plans/screens/reading_plans_screen.dart';
import '../../features/study_manuals/screens/study_manual_viewer_screen.dart';
import '../../features/study_manuals/screens/study_manuals_screen.dart';
import '../../features/treasure_hunts/screens/rewards_screen.dart';
import '../../features/treasure_hunts/screens/treasure_hunt_screen.dart';
import '../../shared/widgets/home_shell.dart';
import '../auth/auth_providers.dart';
import 'app_routes.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.groups,
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final isSignedIn = ref.read(isSignedInProvider);
      final isAuthRoute = state.matchedLocation == AppRoutes.auth;

      if (!isSignedIn && !isAuthRoute) return AppRoutes.auth;
      if (isSignedIn && isAuthRoute) return AppRoutes.groups;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.auth, builder: (context, state) => const AuthScreen()),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => HomeShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.groups, builder: (context, state) => const GroupListScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.readingPlans, builder: (context, state) => const ReadingPlansScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.devotions, builder: (context, state) => const DevotionsFeedScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: AppRoutes.studyManuals, builder: (context, state) => const StudyManualsScreen()),
          ]),
        ],
      ),

      GoRoute(
        path: AppRoutes.createGroup,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const CreateGroupScreen(),
      ),
      GoRoute(
        path: AppRoutes.groupDetail,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => GroupDetailScreen(groupId: state.pathParameters['groupId']!),
      ),
      GoRoute(
        path: AppRoutes.liveQuiz,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => LiveQuizScreen(
          groupId: state.pathParameters['groupId']!,
          quizId: state.pathParameters['quizId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.treasureHunt,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => TreasureHuntScreen(
          groupId: state.pathParameters['groupId']!,
          huntId: state.pathParameters['huntId']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.readingPlanDetail,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => ReadingPlanDetailScreen(planId: state.pathParameters['planId']!),
      ),
      GoRoute(
        path: AppRoutes.devotionDetail,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => DevotionDetailScreen(devotionId: state.pathParameters['devotionId']!),
      ),
      GoRoute(
        path: AppRoutes.studyManualViewer,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => StudyManualViewerScreen(manualId: state.pathParameters['manualId']!),
      ),
      GoRoute(
        path: AppRoutes.rewards,
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const RewardsScreen(),
      ),
    ],
  );
});

/// Bridges Riverpod's authStateProvider stream into a Listenable so
/// GoRouter re-evaluates `redirect` whenever auth state changes.
class _AuthListenable extends ChangeNotifier {
  _AuthListenable(this._ref) {
    _subscription = _ref.listen(authStateProvider, (_, __) => notifyListeners());
  }

  final Ref _ref;
  late final ProviderSubscription _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
