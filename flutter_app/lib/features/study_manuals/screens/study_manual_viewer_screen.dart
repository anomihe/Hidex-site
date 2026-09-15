import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/study_manuals_providers.dart';
import '../services/study_manuals_service.dart';

class StudyManualViewerScreen extends ConsumerStatefulWidget {
  const StudyManualViewerScreen({super.key, required this.manualId});

  final String manualId;

  @override
  ConsumerState<StudyManualViewerScreen> createState() => _StudyManualViewerScreenState();
}

class _StudyManualViewerScreenState extends ConsumerState<StudyManualViewerScreen> {
  int _chapterIndex = 0;
  bool _isMarking = false;

  Future<void> _markComplete(String chapterId) async {
    setState(() => _isMarking = true);
    try {
      await studyManualsService.markChapterComplete(chapterId);
      ref.invalidate(manualCompletedChaptersProvider(widget.manualId));
    } finally {
      if (mounted) setState(() => _isMarking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chaptersAsync = ref.watch(manualChaptersProvider(widget.manualId));
    final completedAsync = ref.watch(manualCompletedChaptersProvider(widget.manualId));

    return Scaffold(
      appBar: AppBar(title: const Text('Study manual')),
      body: chaptersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load chapters: $e')),
        data: (chapters) {
          if (chapters.isEmpty) {
            return const Center(child: Text('This manual has no chapters yet.'));
          }
          final index = _chapterIndex.clamp(0, chapters.length - 1);
          final chapter = chapters[index];
          final completed = completedAsync.value ?? {};
          final isComplete = completed.contains(chapter.id);

          return Column(
            children: [
              SizedBox(
                height: 56,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: chapters.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final c = chapters[i];
                    final selected = i == index;
                    final done = completed.contains(c.id);
                    return ChoiceChip(
                      label: Text('${c.chapterNumber}'),
                      selected: selected,
                      avatar: done ? const Icon(Icons.check, size: 16) : null,
                      onSelected: (_) => setState(() => _chapterIndex = i),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    Text('Chapter ${chapter.chapterNumber}', style: Theme.of(context).textTheme.labelLarge),
                    const SizedBox(height: 4),
                    Text(chapter.title, style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 16),
                    Text(chapter.content, style: Theme.of(context).textTheme.bodyLarge),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        if (index > 0)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() => _chapterIndex = index - 1),
                              child: const Text('Previous'),
                            ),
                          ),
                        if (index > 0) const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: isComplete || _isMarking ? null : () => _markComplete(chapter.id),
                            icon: Icon(isComplete ? Icons.check_circle : Icons.check_circle_outline),
                            label: Text(isComplete ? 'Completed' : 'Mark complete'),
                          ),
                        ),
                        if (index < chapters.length - 1) const SizedBox(width: 12),
                        if (index < chapters.length - 1)
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => setState(() => _chapterIndex = index + 1),
                              child: const Text('Next'),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
