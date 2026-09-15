import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../live_quiz/models/quiz.dart';
import '../../live_quiz/services/live_quiz_service.dart';
import '../../treasure_hunts/models/treasure_hunt.dart';
import '../../treasure_hunts/services/treasure_hunts_service.dart';
import '../models/group.dart';
import '../services/groups_service.dart';

final groupByIdProvider = FutureProvider.autoDispose.family<Group, String>((ref, groupId) {
  return groupsService.fetchGroup(groupId);
});

final groupQuizzesProvider = FutureProvider.autoDispose.family<List<Quiz>, String>((ref, groupId) {
  return liveQuizService.fetchQuizzesForGroup(groupId);
});

final groupHuntsProvider = FutureProvider.autoDispose.family<List<TreasureHunt>, String>((ref, groupId) {
  return treasureHuntsService.fetchHunts(groupId);
});
