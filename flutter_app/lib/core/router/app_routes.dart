/// Central registry of route paths/names so screens never hardcode
/// strings when navigating.
class AppRoutes {
  AppRoutes._();

  static const auth = '/auth';

  static const groups = '/groups';
  static const createGroup = '/groups/create';
  static const groupDetail = '/groups/:groupId';
  static const liveQuiz = '/groups/:groupId/quiz/:quizId';
  static const treasureHunt = '/groups/:groupId/hunts/:huntId';
  static const rewards = '/rewards';

  static const readingPlans = '/reading-plans';
  static const readingPlanDetail = '/reading-plans/:planId';

  static const devotions = '/devotions';
  static const devotionDetail = '/devotions/:devotionId';

  static const studyManuals = '/study-manuals';
  static const studyManualViewer = '/study-manuals/:manualId';

  static String groupDetailPath(String groupId) => '/groups/$groupId';
  static String liveQuizPath(String groupId, String quizId) => '/groups/$groupId/quiz/$quizId';
  static String treasureHuntPath(String groupId, String huntId) => '/groups/$groupId/hunts/$huntId';
  static String readingPlanDetailPath(String planId) => '/reading-plans/$planId';
  static String devotionDetailPath(String devotionId) => '/devotions/$devotionId';
  static String studyManualViewerPath(String manualId) => '/study-manuals/$manualId';
}
