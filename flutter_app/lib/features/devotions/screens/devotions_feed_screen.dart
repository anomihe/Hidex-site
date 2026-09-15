import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../../core/router/app_routes.dart';
import '../providers/devotions_providers.dart';

class DevotionsFeedScreen extends ConsumerWidget {
  const DevotionsFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(devotionsFeedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Devotions')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(devotionsFeedProvider),
        child: feedAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Could not load devotions: $e')),
          data: (devotions) {
            if (devotions.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(child: Text('No devotions published yet.')),
                ],
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: devotions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final devotion = devotions[index];
                return Card(
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: InkWell(
                    onTap: () => context.push(AppRoutes.devotionDetailPath(devotion.id)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (devotion.imageUrl != null)
                          CachedNetworkImage(
                            imageUrl: devotion.imageUrl!,
                            height: 160,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => const SizedBox.shrink(),
                          ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                timeago.format(devotion.publishedAt),
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              const SizedBox(height: 4),
                              Text(devotion.title,
                                  style:
                                      Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                              if (devotion.verseReference != null) ...[
                                const SizedBox(height: 6),
                                Text(devotion.verseReference!,
                                    style: TextStyle(
                                        color: Theme.of(context).colorScheme.primary,
                                        fontStyle: FontStyle.italic)),
                              ],
                              const SizedBox(height: 8),
                              Text(
                                devotion.body,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              if (devotion.author != null) ...[
                                const SizedBox(height: 10),
                                Text('— ${devotion.author}', style: Theme.of(context).textTheme.bodySmall),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
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
