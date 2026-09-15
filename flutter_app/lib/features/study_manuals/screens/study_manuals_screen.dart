import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../providers/study_manuals_providers.dart';

class StudyManualsScreen extends ConsumerWidget {
  const StudyManualsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manualsAsync = ref.watch(studyManualsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Study manuals')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(studyManualsProvider),
        child: manualsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load study manuals: $e')),
          data: (manuals) {
            if (manuals.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(child: Text('No study manuals published yet.')),
                ],
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 0.72,
              ),
              itemCount: manuals.length,
              itemBuilder: (context, index) {
                final manual = manuals[index];
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => context.push(AppRoutes.studyManualViewerPath(manual.id)),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.auto_stories, size: 36, color: Theme.of(context).colorScheme.primary),
                        const Spacer(),
                        Text(manual.title,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis),
                        if (manual.description != null) ...[
                          const SizedBox(height: 4),
                          Text(manual.description!,
                              style: Theme.of(context).textTheme.bodySmall,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
