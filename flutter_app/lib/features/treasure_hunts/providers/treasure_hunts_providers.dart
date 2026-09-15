import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/treasure_hunt.dart';
import '../services/treasure_hunts_service.dart';

final huntProvider = FutureProvider.autoDispose.family<TreasureHunt, String>((ref, huntId) {
  return treasureHuntsService.fetchHunt(huntId);
});

final huntTasksProvider = FutureProvider.autoDispose.family<List<HuntTask>, String>((ref, huntId) {
  return treasureHuntsService.fetchTasks(huntId);
});

final huntProgressProvider = FutureProvider.autoDispose.family<Map<String, HuntProgress>, String>((ref, huntId) {
  return treasureHuntsService.fetchMyProgress(huntId);
});

final myTotalPointsProvider = FutureProvider.autoDispose<int>((ref) {
  return treasureHuntsService.fetchMyTotalPoints();
});

final rewardsProvider = FutureProvider.autoDispose<List<Reward>>((ref) {
  return treasureHuntsService.fetchRewards();
});
