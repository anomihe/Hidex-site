import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../groups/providers/groups_providers.dart';
import '../models/quiz.dart';
import '../models/quiz_timeline.dart';
import '../providers/live_quiz_providers.dart';
import '../services/live_quiz_service.dart';
import '../widgets/countdown_display.dart';
import '../widgets/leaderboard_list.dart';
import '../widgets/participant_list.dart';

class LiveQuizScreen extends ConsumerStatefulWidget {
  const LiveQuizScreen({super.key, required this.groupId, required this.quizId});

  final String groupId;
  final String quizId;

  @override
  ConsumerState<LiveQuizScreen> createState() => _LiveQuizScreenState();
}

class _LiveQuizScreenState extends ConsumerState<LiveQuizScreen> {
  bool _isJoining = false;
  String? _joinError;
  final _answeredQuestionIds = <String>{};

  Future<void> _join() async {
    setState(() {
      _isJoining = true;
      _joinError = null;
    });
    try {
      await liveQuizService.joinQuiz(widget.quizId);
    } catch (e) {
      setState(() => _joinError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isJoining = false);
    }
  }

  Future<void> _answer(QuizQuestion question, int optionIndex, DateTime questionShownAt) async {
    setState(() => _answeredQuestionIds.add(question.id));
    try {
      final result = await liveQuizService.submitAnswer(
        questionId: question.id,
        selectedOption: optionIndex,
        responseMs: DateTime.now().difference(questionShownAt).inMilliseconds,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.isCorrect ? 'Correct! +${result.pointsAwarded} pts' : 'Not quite.'),
          backgroundColor: result.isCorrect ? Colors.green : Colors.redAccent,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not submit answer: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final quizAsync = ref.watch(quizStreamProvider(widget.quizId));
    final questionsAsync = ref.watch(quizQuestionsProvider(widget.quizId));
    final participantsAsync = ref.watch(quizParticipantsStreamProvider(widget.quizId));
    final membersAsync = ref.watch(groupMembersProvider(widget.groupId));
    final myId = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      appBar: AppBar(title: quizAsync.value != null ? Text(quizAsync.value!.title) : const Text('Live quiz')),
      body: quizAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load quiz: $e')),
        data: (quiz) {
          // Enrich raw participant rows (user_id, score) with display
          // names from the group roster.
          final nameByUserId = <String, String>{
            for (final m in membersAsync.value ?? []) m.userId: m.displayName ?? 'Member',
          };
          final participants = (participantsAsync.value ?? [])
              .map((p) => QuizParticipant(
                    userId: p.userId,
                    score: p.score,
                    joinedAt: p.joinedAt,
                    displayName: nameByUserId[p.userId],
                  ))
              .toList();
          final iHaveJoined = participants.any((p) => p.userId == myId);

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(quizQuestionsProvider(widget.quizId));
              ref.invalidate(groupMembersProvider(widget.groupId));
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                switch (quiz.status) {
                  'scheduled' => _ScheduledSection(quiz: quiz),
                  'join_open' => _JoinOpenSection(
                      quiz: quiz,
                      hasJoined: iHaveJoined,
                      isJoining: _isJoining,
                      joinError: _joinError,
                      onJoin: _join,
                      participants: participants,
                    ),
                  'live' => questionsAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Text('Could not load questions: $e'),
                      data: (questions) => _LiveSection(
                        quiz: quiz,
                        questions: questions,
                        hasJoined: iHaveJoined,
                        answeredQuestionIds: _answeredQuestionIds,
                        onAnswer: _answer,
                        onQuestionShown: (id) {},
                      ),
                    ),
                  _ => const _ClosedSection(),
                },
                const SizedBox(height: 28),
                Text('Leaderboard', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                LeaderboardList(participants: participants),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ScheduledSection extends StatelessWidget {
  const _ScheduledSection({required this.quiz});
  final Quiz quiz;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      icon: Icons.schedule,
      title: 'Not open yet',
      child: CountdownDisplay(
        target: quiz.joinOpensAt,
        builder: (context, remaining) => Text(
          'Join window opens in ${formatDuration(remaining)}',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
      ),
    );
  }
}

class _JoinOpenSection extends StatelessWidget {
  const _JoinOpenSection({
    required this.quiz,
    required this.hasJoined,
    required this.isJoining,
    required this.joinError,
    required this.onJoin,
    required this.participants,
  });

  final Quiz quiz;
  final bool hasJoined;
  final bool isJoining;
  final String? joinError;
  final VoidCallback onJoin;
  final List<QuizParticipant> participants;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      icon: Icons.timer_outlined,
      title: hasJoined ? "You're in — get ready" : 'Join window is open',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CountdownDisplay(
            target: quiz.startsAt,
            builder: (context, remaining) => Text(
              'Starts in ${formatDuration(remaining)}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          const SizedBox(height: 16),
          if (!hasJoined) ...[
            FilledButton(
              onPressed: isJoining ? null : onJoin,
              child: isJoining
                  ? const SizedBox(
                      height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Join quiz'),
            ),
            if (joinError != null) ...[
              const SizedBox(height: 8),
              Text(joinError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
          ] else
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 20),
                SizedBox(width: 8),
                Text("You've joined this quiz"),
              ],
            ),
          const SizedBox(height: 20),
          Text('Who\'s joined (${participants.length})',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          ParticipantList(participants: participants),
        ],
      ),
    );
  }
}

class _LiveSection extends ConsumerStatefulWidget {
  const _LiveSection({
    required this.quiz,
    required this.questions,
    required this.hasJoined,
    required this.answeredQuestionIds,
    required this.onAnswer,
    required this.onQuestionShown,
  });

  final Quiz quiz;
  final List<QuizQuestion> questions;
  final bool hasJoined;
  final Set<String> answeredQuestionIds;
  final Future<void> Function(QuizQuestion, int, DateTime) onAnswer;
  final void Function(String) onQuestionShown;

  @override
  ConsumerState<_LiveSection> createState() => _LiveSectionState();
}

class _LiveSectionState extends ConsumerState<_LiveSection> {
  int? _selectedOption;
  String? _selectedForQuestionId;
  DateTime _questionShownAt = DateTime.now();

  @override
  Widget build(BuildContext context) {
    if (!widget.hasJoined) {
      return const _InfoCard(
        icon: Icons.lock_clock,
        title: 'Quiz is live',
        child: Text("You didn't join before the window closed, but you can still watch the leaderboard."),
      );
    }

    final timeline = QuizTimeline(widget.quiz, widget.questions);
    final now = DateTime.now();
    final question = timeline.currentQuestionAt(now);

    if (question == null) {
      return const _InfoCard(
        icon: Icons.hourglass_bottom,
        title: 'Between questions...',
        child: Text('Hang tight, the next question is coming up.'),
      );
    }

    if (_selectedForQuestionId != question.id) {
      _selectedOption = null;
      _selectedForQuestionId = question.id;
      _questionShownAt = now;
      WidgetsBinding.instance.addPostFrameCallback((_) => widget.onQuestionShown(question.id));
    }

    final alreadyAnswered = widget.answeredQuestionIds.contains(question.id);

    return _InfoCard(
      icon: Icons.quiz_outlined,
      title: 'Question ${question.position}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CountdownDisplay(
            target: widget.quiz.startsAt.add(
              Duration(seconds: widget.questions.take(question.position).fold(0, (s, q) => s + q.timeLimitSeconds)),
            ),
            builder: (context, remaining) => LinearProgressIndicator(
              value: question.timeLimitSeconds == 0
                  ? 0
                  : (remaining.inSeconds / question.timeLimitSeconds).clamp(0, 1),
            ),
          ),
          const SizedBox(height: 12),
          Text(question.question, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          for (var i = 0; i < question.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  backgroundColor: _selectedOption == i
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                ),
                onPressed: alreadyAnswered
                    ? null
                    : () {
                        setState(() => _selectedOption = i);
                        widget.onAnswer(question, i, _questionShownAt);
                      },
                child: Text(question.options[i]),
              ),
            ),
          if (alreadyAnswered)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Answer submitted — waiting for the next question.', style: TextStyle(color: Colors.grey)),
            ),
        ],
      ),
    );
  }
}

class _ClosedSection extends StatelessWidget {
  const _ClosedSection();

  @override
  Widget build(BuildContext context) {
    return const _InfoCard(
      icon: Icons.flag_outlined,
      title: 'Quiz has ended',
      child: Text('Final results are on the leaderboard below.'),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
