import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utilities/formatters.dart';
import '../../shared/models/app_category.dart';
import '../../shared/providers/library_provider.dart';
import '../../shared/widgets/permission_gate.dart';
import '../../shared/widgets/photo_thumbnail.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LibraryState library = ref.watch(libraryProvider);

    if (!library.isInitialized || !library.hasAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Categories')),
        body: const PermissionGate(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        actions: <Widget>[
          IconButton(
            onPressed: () => context.push('/search'),
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(libraryProvider.notifier).refresh(),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 32),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
              child: _OrganizerHeader(library: library),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: AppCategory.values.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.98,
                ),
                itemBuilder: (BuildContext context, int index) {
                  final AppCategory category = AppCategory.values[index];
                  final List<AssetEntity> photos =
                      library.photosForCategory(category);
                  return _CategoryCard(
                    category: category,
                    count: library.categoryCounts[category] ?? 0,
                    cover: photos.isEmpty ? null : photos.first,
                    onTap: () =>
                        context.push('/category/${category.name}'),
                  );
                },
              ),
            ),
            const SizedBox(height: 28),
            Center(
              child: Text(
                'Categories improve privately as photos are identified on this device.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrganizerHeader extends StatelessWidget {
  const _OrganizerHeader({required this.library});

  final LibraryState library;

  @override
  Widget build(BuildContext context) {
    final int total = library.totalPhotos;
    final int organized = library.analyzedCount;
    final double progress =
        total == 0 ? 0 : (organized / total).clamp(0, 1).toDouble();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[AppColors.primaryFaint, AppColors.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primarySoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.auto_awesome_rounded,
                size: 19,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sorted on your device',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                '${formatCount(organized)}/${formatCount(total)}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppColors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            library.pendingCount > 0
                ? '${formatCount(library.pendingCount)} photos are waiting to be organized. This happens privately in the background.'
                : 'Every photo has a category. Tap one to explore.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.category,
    required this.count,
    required this.cover,
    required this.onTap,
  });

  final AppCategory category;
  final int count;
  final AssetEntity? cover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color tint = category.tint;
    return Material(
      color: tint.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: Icon(category.icon, color: tint, size: 21),
                  ),
                  const Spacer(),
                  if (cover != null)
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: PhotoThumbnail(
                        asset: cover!,
                        size: 320,
                        borderRadius: BorderRadius.circular(12),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '0',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: tint,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                category.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 3),
              Text(
                category.description,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Text(
                count == 1 ? '1 photo' : '${formatCount(count)} photos',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: tint,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
