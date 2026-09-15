import 'package:flutter/material.dart';

import '../models/quiz.dart';

class ParticipantList extends StatelessWidget {
  const ParticipantList({super.key, required this.participants});

  final List<QuizParticipant> participants;

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text('Waiting for people to join...'),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: participants
          .map(
            (p) => Chip(
              avatar: CircleAvatar(child: Text((p.displayName ?? '?').substring(0, 1).toUpperCase())),
              label: Text(p.displayName ?? 'Participant'),
            ),
          )
          .toList(),
    );
  }
}
