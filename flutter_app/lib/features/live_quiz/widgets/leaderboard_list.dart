import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/quiz.dart';

class LeaderboardList extends StatelessWidget {
  const LeaderboardList({super.key, required this.participants});

  final List<QuizParticipant> participants;

  @override
  Widget build(BuildContext context) {
    final sorted = [...participants]..sort((a, b) => b.score.compareTo(a.score));
    final myId = Supabase.instance.client.auth.currentUser?.id;

    if (sorted.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('No one has joined yet.'),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < sorted.length; i++)
          _LeaderboardRow(
            rank: i + 1,
            participant: sorted[i],
            isMe: sorted[i].userId == myId,
          ),
      ],
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.rank, required this.participant, required this.isMe});

  final int rank;
  final QuizParticipant participant;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final medalColors = {1: Colors.amber, 2: Colors.blueGrey, 3: Colors.brown};

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isMe ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '#$rank',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: medalColors[rank],
              ),
            ),
          ),
          Expanded(
            child: Text(
              participant.displayName ?? 'Participant',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal),
            ),
          ),
          Text('${participant.score} pts', style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
