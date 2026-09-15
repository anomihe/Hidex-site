import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_routes.dart';

/// The periodic (~twice a week) in-app popup asking for support. Purely
/// local scheduling via DonationPromptService — not a push notification,
/// so it only ever appears while the app is open.
class DonationPromptDialog extends StatelessWidget {
  const DonationPromptDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.volunteer_activism),
      title: const Text('Enjoying the app?'),
      content: const Text(
        "This app is free and ad-supported. If it's been useful to you, "
        'consider a small donation to help keep it running.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop();
            context.push(AppRoutes.donate);
          },
          child: const Text('Support us'),
        ),
      ],
    );
  }
}
