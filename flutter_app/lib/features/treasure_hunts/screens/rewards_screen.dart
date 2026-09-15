import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/treasure_hunts_providers.dart';

class RewardsScreen extends ConsumerWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rewardsAsync = ref.watch(rewardsProvider);
    final pointsAsync = ref.watch(myTotalPointsProvider);
    final myPoints = pointsAsync.value ?? 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Rewards')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(rewardsProvider);
          ref.invalidate(myTotalPointsProvider);
        },
        child: rewardsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load rewards: $e')),
          data: (rewards) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars, color: Colors.amber, size: 36),
                      const SizedBox(width: 12),
                      Text('$myPoints points', style: Theme.of(context).textTheme.titleLarge),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (rewards.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: Text('No rewards configured yet.')),
                  )
                else
                  ...rewards.map((reward) {
                    final unlocked = myPoints >= reward.pointsRequired;
                    return Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: Icon(
                          unlocked ? Icons.emoji_events : Icons.lock_outline,
                          color: unlocked ? Colors.amber : null,
                        ),
                        title: Text(reward.title),
                        subtitle: Text(reward.description ?? '${reward.pointsRequired} pts required'),
                        trailing: unlocked
                            ? const Icon(Icons.check_circle, color: Colors.green)
                            : Text('${reward.pointsRequired} pts'),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}
