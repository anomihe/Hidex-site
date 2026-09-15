import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/reading_plan.dart';
import '../services/reading_plans_service.dart';

final readingPlansProvider = FutureProvider.autoDispose<List<ReadingPlan>>((ref) {
  return readingPlansService.fetchPlans();
});

final myStreakProvider = FutureProvider.autoDispose<UserStreak>((ref) {
  return readingPlansService.fetchStreak();
});

final planDaysProvider = FutureProvider.autoDispose.family<List<ReadingPlanDay>, String>((ref, planId) {
  return readingPlansService.fetchDays(planId);
});

final myEnrollmentProvider =
    FutureProvider.autoDispose.family<ReadingPlanEnrollment?, String>((ref, planId) {
  return readingPlansService.fetchMyEnrollment(planId);
});

final completedDaysProvider = FutureProvider.autoDispose.family<Set<int>, String>((ref, enrollmentId) {
  return readingPlansService.fetchCompletedDays(enrollmentId);
});
