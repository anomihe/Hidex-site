import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';
import '../providers/groups_providers.dart';

class GroupListScreen extends ConsumerWidget {
  const GroupListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupsAsync = ref.watch(myGroupsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Create or join a group',
            onPressed: () => context.push(AppRoutes.createGroup),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myGroupsProvider),
        child: groupsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Center(child: Text('Could not load groups: $error')),
            ],
          ),
          data: (groups) {
            if (groups.isEmpty) {
              return ListView(
                children: [
                  const SizedBox(height: 80),
                  Icon(Icons.groups_outlined, size: 56, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  const Text(
                    'No groups yet.\nCreate one or join with an invite code.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: FilledButton.icon(
                      onPressed: () => context.push(AppRoutes.createGroup),
                      icon: const Icon(Icons.add),
                      label: const Text('Create or join a group'),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final group = groups[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                      child: Text(group.name.isNotEmpty ? group.name[0].toUpperCase() : '?'),
                    ),
                    title: Text(group.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(group.description?.isNotEmpty == true
                        ? group.description!
                        : 'Invite code: ${group.inviteCode}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.groupDetailPath(group.id)),
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
