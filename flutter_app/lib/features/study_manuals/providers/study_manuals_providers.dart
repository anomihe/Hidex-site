import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/study_manual.dart';
import '../services/study_manuals_service.dart';

final studyManualsProvider = FutureProvider.autoDispose<List<StudyManual>>((ref) {
  return studyManualsService.fetchManuals();
});

final manualChaptersProvider = FutureProvider.autoDispose.family<List<StudyManualChapter>, String>((ref, manualId) {
  return studyManualsService.fetchChapters(manualId);
});

final manualCompletedChaptersProvider = FutureProvider.autoDispose.family<Set<String>, String>((ref, manualId) {
  return studyManualsService.fetchCompletedChapterIds(manualId);
});
