import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../models/treasure_hunt.dart';
import '../providers/treasure_hunts_providers.dart';
import '../services/treasure_hunts_service.dart';

class TreasureHuntScreen extends ConsumerStatefulWidget {
  const TreasureHuntScreen({super.key, required this.groupId, required this.huntId});

  final String groupId;
  final String huntId;

  @override
  ConsumerState<TreasureHuntScreen> createState() => _TreasureHuntScreenState();
}

class _TreasureHuntScreenState extends ConsumerState<TreasureHuntScreen> {
  final _answerControllers = <String, TextEditingController>{};
  final _submitting = <String>{};
  final _wrongAttempt = <String>{};

  TextEditingController _controllerFor(String taskId) =>
      _answerControllers.putIfAbsent(taskId, () => TextEditingController());

  @override
  void dispose() {
    for (final c in _answerControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit(HuntTask task) async {
    final answer = _controllerFor(task.id).text.trim();
    if (answer.isEmpty) return;

    setState(() {
      _submitting.add(task.id);
      _wrongAttempt.remove(task.id);
    });
    try {
      final result = await treasureHuntsService.submitAnswer(taskId: task.id, answer: answer);
      ref.invalidate(huntProgressProvider(widget.huntId));
      ref.invalidate(myTotalPointsProvider);
      if (!mounted) return;
      if (result.isCorrect) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Correct! +${result.pointsAwarded} pts'), backgroundColor: Colors.green),
        );
      } else {
        setState(() => _wrongAttempt.add(task.id));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not submit answer: $e')));
    } finally {
      if (mounted) setState(() => _submitting.remove(task.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final huntAsync = ref.watch(huntProvider(widget.huntId));
    final tasksAsync = ref.watch(huntTasksProvider(widget.huntId));
    final progressAsync = ref.watch(huntProgressProvider(widget.huntId));
    final pointsAsync = ref.watch(myTotalPointsProvider);

    return Scaffold(
      appBar: AppBar(
        title: huntAsync.value != null ? Text(huntAsync.value!.title) : const Text('Treasure hunt'),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Center(
              child: ActionChip(
                avatar: const Icon(Icons.stars, size: 18, color: Colors.amber),
                label: Text('${pointsAsync.value ?? 0} pts'),
                onPressed: () => context.push(AppRoutes.rewards),
              ),
            ),
          ),
        ],
      ),
      body: huntAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load hunt: $e')),
        data: (hunt) {
          if (hunt.status == 'scheduled') {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('This hunt starts ${hunt.startsAt.toLocal()}'.split('.').first),
              ),
            );
          }

          return tasksAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load tasks: $e')),
            data: (tasks) {
              final progress = progressAsync.value ?? {};
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: tasks.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final task = tasks[index];
                  final taskProgress = progress[task.id];
                  final isSolved = taskProgress?.isCorrect ?? false;
                  final isSubmitting = _submitting.contains(task.id);
                  final showWrongHint = _wrongAttempt.contains(task.id);

                  return Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 14,
                                backgroundColor: isSolved ? Colors.green : Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: isSolved
                                    ? const Icon(Icons.check, size: 16, color: Colors.white)
                                    : Text('${task.position}', style: const TextStyle(fontSize: 12)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(task.prompt, style: const TextStyle(fontWeight: FontWeight.w600)),
                              ),
                              Text('${task.points} pts', style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                          if (task.hint != null && !isSolved) ...[
                            const SizedBox(height: 8),
                            Text('Hint: ${task.hint}',
                                style: TextStyle(fontStyle: FontStyle.italic, color: Theme.of(context).colorScheme.outline)),
                          ],
                          if (!isSolved && hunt.status == 'active') ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: TextField(
                                    controller: _controllerFor(task.id),
                                    decoration: InputDecoration(
                                      hintText: 'Your answer',
                                      isDense: true,
                                      errorText: showWrongHint ? 'Not quite — try again' : null,
                                    ),
                                    onSubmitted: (_) => _submit(task),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                FilledButton(
                                  onPressed: isSubmitting ? null : () => _submit(task),
                                  child: isSubmitting
                                      ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Text('Submit'),
                                ),
                              ],
                            ),
                            if (taskProgress != null && taskProgress.attempts > 0)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text('${taskProgress.attempts} attempt(s)',
                                    style: Theme.of(context).textTheme.bodySmall),
                              ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
