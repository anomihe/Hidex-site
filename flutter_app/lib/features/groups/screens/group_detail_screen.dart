import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/router/app_routes.dart';
import '../../live_quiz/services/live_quiz_service.dart';
import '../providers/group_detail_providers.dart';
import '../providers/groups_providers.dart';

class GroupDetailScreen extends ConsumerWidget {
  const GroupDetailScreen({super.key, required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groupAsync = ref.watch(groupByIdProvider(groupId));
    final quizzesAsync = ref.watch(groupQuizzesProvider(groupId));
    final huntsAsync = ref.watch(groupHuntsProvider(groupId));
    final membersAsync = ref.watch(groupMembersProvider(groupId));

    return Scaffold(
      appBar: AppBar(
        title: groupAsync.when(
          data: (g) => Text(g.name),
          loading: () => const Text('Loading...'),
          error: (_, __) => const Text('Group'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_alarm),
            tooltip: 'Schedule a live quiz',
            onPressed: () => _showCreateQuizSheet(context, ref, groupId),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(groupQuizzesProvider(groupId));
          ref.invalidate(groupHuntsProvider(groupId));
          ref.invalidate(groupMembersProvider(groupId));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            groupAsync.maybeWhen(
              data: (group) => Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Invite code', style: TextStyle(fontSize: 12)),
                            Text(group.inviteCode,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2)),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: group.inviteCode));
                          ScaffoldMessenger.of(context)
                              .showSnackBar(const SnackBar(content: Text('Invite code copied')));
                        },
                      ),
                    ],
                  ),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            _SectionHeader(
              title: 'Live quizzes',
              trailing: TextButton(
                onPressed: () => _showCreateQuizSheet(context, ref, groupId),
                child: const Text('Schedule'),
              ),
            ),
            quizzesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Could not load quizzes: $e'),
              data: (quizzes) {
                if (quizzes.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No quizzes scheduled yet.'),
                  );
                }
                return Column(
                  children: quizzes
                      .map((quiz) => Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: _StatusDot(status: quiz.status),
                              title: Text(quiz.title),
                              subtitle: Text(_quizSubtitle(quiz.status, quiz.startsAt)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push(AppRoutes.liveQuizPath(groupId, quiz.id)),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            const _SectionHeader(title: 'Treasure hunts'),
            huntsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Could not load hunts: $e'),
              data: (hunts) {
                if (hunts.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('No treasure hunts yet.'),
                  );
                }
                return Column(
                  children: hunts
                      .map((hunt) => Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(Icons.explore_outlined,
                                  color: hunt.status == 'active' ? Colors.green : null),
                              title: Text(hunt.title),
                              subtitle: Text('Ends ${timeago.format(hunt.endsAt, allowFromNow: true)}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push(AppRoutes.treasureHuntPath(groupId, hunt.id)),
                            ),
                          ))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            const _SectionHeader(title: 'Members'),
            membersAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Could not load members: $e'),
              data: (members) => Column(
                children: members
                    .map((m) => ListTile(
                          leading: CircleAvatar(child: Text((m.displayName ?? '?').substring(0, 1).toUpperCase())),
                          title: Text(m.displayName ?? 'Member'),
                          trailing: Text(m.role, style: Theme.of(context).textTheme.bodySmall),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _quizSubtitle(String status, DateTime startsAt) {
    switch (status) {
      case 'join_open':
        return 'Join window open — starts ${timeago.format(startsAt, allowFromNow: true)}';
      case 'live':
        return 'Live now';
      case 'closed':
        return 'Closed';
      default:
        return 'Starts ${timeago.format(startsAt, allowFromNow: true)}';
    }
  }

  void _showCreateQuizSheet(BuildContext context, WidgetRef ref, String groupId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CreateQuizSheet(groupId: groupId),
    ).then((created) {
      if (created == true) {
        ref.invalidate(groupQuizzesProvider(groupId));
      }
    });
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'live' => Colors.red,
      'join_open' => Colors.orange,
      'closed' => Colors.grey,
      _ => Colors.blueGrey,
    };
    return CircleAvatar(radius: 6, backgroundColor: color);
  }
}

class _CreateQuizSheet extends ConsumerStatefulWidget {
  const _CreateQuizSheet({required this.groupId});

  final String groupId;

  @override
  ConsumerState<_CreateQuizSheet> createState() => _CreateQuizSheetState();
}

class _CreateQuizSheetState extends ConsumerState<_CreateQuizSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  DateTime _startsAt = DateTime.now().add(const Duration(minutes: 10));
  int _joinWindowMinutes = 2;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickStartTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startsAt,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_startsAt));
    if (time == null) return;
    setState(() {
      _startsAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      await liveQuizService.createQuiz(
        groupId: widget.groupId,
        title: _titleController.text.trim(),
        startsAt: _startsAt,
        joinWindowSeconds: _joinWindowMinutes * 60,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      setState(() => _error = 'Could not schedule quiz: $e');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Schedule a live quiz', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Quiz title'),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Starts at'),
              subtitle: Text('${_startsAt.toLocal()}'.split('.').first),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickStartTime,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Join window'),
                DropdownButton<int>(
                  value: _joinWindowMinutes,
                  items: const [1, 2, 5, 10]
                      .map((m) => DropdownMenuItem(value: m, child: Text('$m min')))
                      .toList(),
                  onChanged: (v) => setState(() => _joinWindowMinutes = v ?? 2),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add questions afterwards from the Supabase dashboard '
                  '(quiz_questions table) — question authoring UI is not built yet.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ),
            if (_error != null) Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Schedule quiz'),
            ),
          ],
        ),
      ),
    );
  }
}
