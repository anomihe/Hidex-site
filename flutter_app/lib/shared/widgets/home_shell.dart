import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/donation/donation_prompt_service.dart';
import '../../features/donation/widgets/donation_prompt_dialog.dart';

/// Bottom-nav shell for the app's five top-level tabs. Detail screens
/// (group detail, live quiz, devotion detail, etc.) are pushed as
/// top-level routes on top of this shell rather than nested inside it,
/// so they get a full-screen back button instead of living inside a tab.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowDonationPrompt());
  }

  Future<void> _maybeShowDonationPrompt() async {
    final shouldShow = await donationPromptService.shouldShow();
    if (!shouldShow || !mounted) return;
    await donationPromptService.markShown();
    if (!mounted) return;
    showDialog<void>(context: context, builder: (_) => const DonationPromptDialog());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.navigationShell.currentIndex,
        onDestinationSelected: (index) => widget.navigationShell.goBranch(
          index,
          initialLocation: index == widget.navigationShell.currentIndex,
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.groups_outlined), selectedIcon: Icon(Icons.groups), label: 'Groups'),
          NavigationDestination(
              icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Reading'),
          NavigationDestination(
              icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Devotions'),
          NavigationDestination(
              icon: Icon(Icons.auto_stories_outlined), selectedIcon: Icon(Icons.auto_stories), label: 'Manuals'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
