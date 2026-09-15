import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:url_launcher/url_launcher.dart';

class DonationScreen extends StatelessWidget {
  const DonationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final donationUrl = dotenv.maybeGet('DONATION_URL');
    final hasLink = donationUrl != null && donationUrl.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Support this app')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.volunteer_activism, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 20),
            Text(
              'This app is free to use and ad-supported.',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "If it's been a blessing to you, a donation helps cover "
              'hosting and keeps it running and improving.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 28),
            if (hasLink)
              FilledButton.icon(
                onPressed: () => launchUrl(Uri.parse(donationUrl), mode: LaunchMode.externalApplication),
                icon: const Icon(Icons.favorite),
                label: const Text('Donate'),
              )
            else
              Text(
                'Donation link coming soon.',
                style: TextStyle(color: Theme.of(context).colorScheme.outline),
              ),
          ],
        ),
      ),
    );
  }
}
