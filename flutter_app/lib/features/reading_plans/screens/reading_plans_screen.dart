import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../providers/reading_plans_providers.dart';

class ReadingPlansScreen extends ConsumerWidget {
  const ReadingPlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(readingPlansProvider);
    final streakAsync = ref.watch(myStreakProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reading plans')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(readingPlansProvider);
          ref.invalidate(myStreakProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            streakAsync.maybeWhen(
              data: (streak) => _StreakBanner(streak: streak),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 20),
            plansAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Could not load reading plans: $e'),
              data: (plans) {
                if (plans.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('No reading plans yet.')),
                  );
                }
                return Column(
                  children: plans
                      .map((plan) => Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              leading: const Icon(Icons.menu_book),
                              title: Text(plan.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text('${plan.durationDays} days'
                                  '${plan.description != null ? ' · ${plan.description}' : ''}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push(AppRoutes.readingPlanDetailPath(plan.id)),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakBanner extends StatelessWidget {
  const _StreakBanner({required this.streak});

  final dynamic streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          Theme.of(context).colorScheme.primary,
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
        ]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 40),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${streak.currentStreak} day${streak.currentStreak == 1 ? '' : 's'} streak',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Longest: ${streak.longestStreak} days',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
