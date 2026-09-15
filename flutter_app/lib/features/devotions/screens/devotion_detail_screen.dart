import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/bible/bible_providers.dart';
import '../providers/devotions_providers.dart';
import '../services/devotions_service.dart';

class DevotionDetailScreen extends ConsumerStatefulWidget {
  const DevotionDetailScreen({super.key, required this.devotionId});

  final String devotionId;

  @override
  ConsumerState<DevotionDetailScreen> createState() => _DevotionDetailScreenState();
}

class _DevotionDetailScreenState extends ConsumerState<DevotionDetailScreen> {
  bool _pendingLikeToggle = false;

  Future<void> _toggleLike(bool currentlyLiked) async {
    setState(() => _pendingLikeToggle = true);
    try {
      await devotionsService.toggleLike(widget.devotionId, currentlyLiked);
      ref.invalidate(devotionDetailProvider(widget.devotionId));
    } finally {
      if (mounted) setState(() => _pendingLikeToggle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final devotionAsync = ref.watch(devotionDetailProvider(widget.devotionId));

    return Scaffold(
      appBar: AppBar(),
      body: devotionAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load devotion: $e')),
        data: (devotion) => ListView(
          children: [
            if (devotion.imageUrl != null)
              CachedNetworkImage(
                imageUrl: devotion.imageUrl!,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(timeago.format(devotion.publishedAt), style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 8),
                  Text(devotion.title, style: Theme.of(context).textTheme.headlineSmall),
                  if (devotion.verseReference != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _VerseText(reference: devotion.verseReference!, fallbackText: devotion.verseText),
                          const SizedBox(height: 6),
                          Text(devotion.verseReference!, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(devotion.body, style: Theme.of(context).textTheme.bodyLarge),
                  if (devotion.author != null) ...[
                    const SizedBox(height: 16),
                    Text('— ${devotion.author}', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _pendingLikeToggle ? null : () => _toggleLike(devotion.likedByMe),
                    icon: Icon(
                      devotion.likedByMe ? Icons.favorite : Icons.favorite_border,
                      color: devotion.likedByMe ? Colors.redAccent : null,
                    ),
                    label: Text(devotion.likedByMe ? 'Liked' : 'Like'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows admin-entered verse text if present; otherwise fetches it live
/// from the Bible API for [reference].
class _VerseText extends ConsumerWidget {
  const _VerseText({required this.reference, required this.fallbackText});

  final String reference;
  final String? fallbackText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (fallbackText != null && fallbackText!.isNotEmpty) {
      return Text(fallbackText!, style: const TextStyle(fontStyle: FontStyle.italic));
    }

    final passageAsync = ref.watch(biblePassageProvider(reference));
    return passageAsync.when(
      loading: () => const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
      error: (e, _) => const SizedBox.shrink(),
      data: (passage) => Text(passage.text, style: const TextStyle(fontStyle: FontStyle.italic)),
    );
  }
}
