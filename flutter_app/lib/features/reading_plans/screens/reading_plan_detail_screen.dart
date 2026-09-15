import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/reading_plans_providers.dart';
import '../services/reading_plans_service.dart';

class ReadingPlanDetailScreen extends ConsumerStatefulWidget {
  const ReadingPlanDetailScreen({super.key, required this.planId});

  final String planId;

  @override
  ConsumerState<ReadingPlanDetailScreen> createState() => _ReadingPlanDetailScreenState();
}

class _ReadingPlanDetailScreenState extends ConsumerState<ReadingPlanDetailScreen> {
  bool _isEnrolling = false;
  final _completingDays = <int>{};

  Future<void> _enroll() async {
    setState(() => _isEnrolling = true);
    try {
      await readingPlansService.enroll(widget.planId);
      ref.invalidate(myEnrollmentProvider(widget.planId));
    } finally {
      if (mounted) setState(() => _isEnrolling = false);
    }
  }

  Future<void> _completeDay(String enrollmentId, int dayNumber) async {
    setState(() => _completingDays.add(dayNumber));
    try {
      await readingPlansService.completeDay(enrollmentId: enrollmentId, dayNumber: dayNumber);
      ref.invalidate(completedDaysProvider(enrollmentId));
      ref.invalidate(myStreakProvider);
    } finally {
      if (mounted) setState(() => _completingDays.remove(dayNumber));
    }
  }

  @override
  Widget build(BuildContext context) {
    final daysAsync = ref.watch(planDaysProvider(widget.planId));
    final enrollmentAsync = ref.watch(myEnrollmentProvider(widget.planId));

    return Scaffold(
      appBar: AppBar(title: const Text('Reading plan')),
      body: daysAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load plan: $e')),
        data: (days) {
          return enrollmentAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Could not load enrollment: $e')),
            data: (enrollment) {
              if (enrollment == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.menu_book_outlined, size: 48),
                        const SizedBox(height: 16),
                        Text('${days.length} days of readings', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _isEnrolling ? null : _enroll,
                          child: _isEnrolling
                              ? const SizedBox(
                                  height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Start this plan'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              final completedAsync = ref.watch(completedDaysProvider(enrollment.id));
              return completedAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Could not load progress: $e')),
                data: (completed) => ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: days.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final day = days[index];
                    final isComplete = completed.contains(day.dayNumber);
                    final isCompleting = _completingDays.contains(day.dayNumber);
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ExpansionTile(
                        leading: CircleAvatar(
                          backgroundColor: isComplete
                              ? Colors.green
                              : Theme.of(context).colorScheme.surfaceContainerHighest,
                          child: isComplete
                              ? const Icon(Icons.check, color: Colors.white, size: 18)
                              : Text('${day.dayNumber}'),
                        ),
                        title: Text(day.reference, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('Day ${day.dayNumber}'),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (day.readingText != null) Text(day.readingText!),
                                if (day.reflection != null) ...[
                                  const SizedBox(height: 12),
                                  Text('Reflection', style: Theme.of(context).textTheme.labelLarge),
                                  Text(day.reflection!),
                                ],
                                const SizedBox(height: 12),
                                if (!isComplete)
                                  OutlinedButton.icon(
                                    onPressed:
                                        isCompleting ? null : () => _completeDay(enrollment.id, day.dayNumber),
                                    icon: isCompleting
                                        ? const SizedBox(
                                            height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                        : const Icon(Icons.check),
                                    label: const Text('Mark as read'),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
