import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../providers/library_provider.dart';

class LibraryActivityCard extends ConsumerWidget {
  const LibraryActivityCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LibraryState library = ref.watch(libraryProvider);
    final LibraryController controller = ref.read(libraryProvider.notifier);

    final bool busy = library.isAnalyzing || library.isIndexing;
    final bool hasPending = library.pendingCount > 0;
    if (!busy && !hasPending && library.error == null) {
      return const SizedBox.shrink();
    }

    final double? progress = library.isAnalyzing
        ? (library.sessionTotal == 0
            ? null
            : library.sessionProcessed / library.sessionTotal)
        : null;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryFaint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.white,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(
                        Icons.auto_awesome_rounded,
                        size: 19,
                        color: AppColors.primary,
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      library.isAnalyzing
                          ? 'Organizing on device'
                          : library.autoScanCancelled
                              ? 'AI scan paused'
                              : hasPending
                                  ? 'Photos waiting to be organized'
                                  : 'Library ready',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      library.isAnalyzing
                          ? '${library.sessionProcessed} of ${library.sessionTotal} checked this session'
                          : library.error ??
                              (hasPending
                                  ? '${library.pendingCount} photos can be identified privately on this phone.'
                                  : 'All photos have an AI label.'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (library.isAnalyzing)
                TextButton(
                  onPressed: controller.pauseAnalysis,
                  child: const Text('Pause'),
                )
              else if (hasPending)
                TextButton(
                  onPressed: () => controller.analyzePending(force: true),
                  child: Text(library.autoScanCancelled ? 'Resume' : 'Start'),
                ),
            ],
          ),
          if (library.isAnalyzing) ...<Widget>[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: AppColors.white,
              ),
            ),
          ],
          if (library.error != null && hasPending) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              library.error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.danger,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
