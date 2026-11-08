import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utilities/formatters.dart';
import '../../shared/models/app_category.dart';
import '../../shared/models/photo_record.dart';
import '../../shared/providers/library_provider.dart';
import '../../shared/widgets/library_activity_card.dart';
import '../../shared/widgets/permission_gate.dart';
import '../../shared/widgets/photo_thumbnail.dart';
import '../../shared/widgets/section_header.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LibraryState library = ref.watch(libraryProvider);
    final LibraryController controller = ref.read(libraryProvider.notifier);

    if (!library.isInitialized || !library.hasAccess) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _HomeHeader(
                onSettings: () => context.push('/settings'),
              ),
              Expanded(
                child: library.isLoading
                    ? const _HomeSkeleton()
                    : const PermissionGate(),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => controller.refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 36),
            children: <Widget>[
              _HomeHeader(
                onSettings: () => context.push('/settings'),
                library: library,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                child: _SearchBar(onTap: () => context.push('/search')),
              ),
              if (library.isLimited)
                _LimitedBanner(onManage: controller.manageLimitedAccess),
              const LibraryActivityCard(),
              const SizedBox(height: 8),
              _StorageCard(library: library),
              const SectionHeader(
                title: 'Quick access',
                padding: EdgeInsets.fromLTRB(20, 26, 20, 12),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: <Widget>[
                    _QuickAction(
                      icon: Icons.auto_awesome_rounded,
                      label: 'AI Scan',
                      color: AppColors.primary,
                      onTap: () => context.push('/scan'),
                    ),
                    const SizedBox(width: 10),
                    _QuickAction(
                      icon: Icons.content_copy_rounded,
                      label: 'Duplicates',
                      color: AppColors.primary,
                      onTap: () => context.push('/duplicates'),
                    ),
                    const SizedBox(width: 10),
                    _QuickAction(
                      icon: Icons.grid_view_rounded,
                      label: 'Categories',
                      color: AppColors.primary,
                      onTap: () => context.go('/categories'),
                    ),
                    const SizedBox(width: 10),
                    _QuickAction(
                      icon: Icons.favorite_rounded,
                      label: 'Favorites',
                      color: AppColors.primary,
                      onTap: () => context.go('/favorites'),
                    ),
                  ],
                ),
              ),
              SectionHeader(
                title: 'Recent photos',
                actionLabel: library.photos.isEmpty ? null : 'View all',
                onAction: () => context.go('/gallery'),
              ),
              if (library.photos.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: <Widget>[
                        const Icon(
                          Icons.photo_library_outlined,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No photos found yet. New photos will appear here automatically.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  height: 124,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: library.photos.length > 10 ? 10 : library.photos.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 10),
                    itemBuilder: (BuildContext context, int index) {
                      final AssetEntity asset = library.photos[index];
                      return _RecentThumb(
                        asset: asset,
                        onTap: () => context.push('/photo/${asset.id}'),
                      );
                    },
                  ),
                ),
              if (library.recentlyOrganized().isNotEmpty) ...<Widget>[
                SectionHeader(
                  title: 'Recently organized',
                  subtitle: 'Identified automatically on this device',
                  actionLabel: 'Categories',
                  onAction: () => context.go('/categories'),
                ),
                SizedBox(
                  height: 154,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: library.recentlyOrganized(limit: 10).length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (BuildContext context, int index) {
                      final AssetEntity asset =
                          library.recentlyOrganized(limit: 10)[index];
                      final PhotoRecord? record = library.recordFor(asset.id);
                      return _OrganizedThumb(
                        asset: asset,
                        record: record,
                        onTap: () => context.push('/photo/${asset.id}'),
                      );
                    },
                  ),
                ),
              ],
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 14,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Your photos never leave this device.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Last gallery check ${formatRelative(library.lastScanAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.onSettings, this.library});

  final VoidCallback onSettings;
  final LibraryState? library;

  @override
  Widget build(BuildContext context) {
    final LibraryState? lib = library;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Image.asset('assets/images/app_logo.png', width: 36, height: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'J-Pix',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              IconButton(
                onPressed: onSettings,
                tooltip: 'Settings',
                icon: const Icon(Icons.settings_outlined, size: 22),
              ),
            ],
          ),
          if (lib != null) ...<Widget>[
            const SizedBox(height: 18),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: <Widget>[
                  _Stat(value: formatCount(lib.totalPhotos), label: 'Photos'),
                  const SizedBox(width: 10),
                  _Stat(
                    value: formatCount(lib.analyzedCount),
                    label: 'Organized',
                  ),
                  const SizedBox(width: 10),
                  _Stat(
                    value: formatCount(lib.favoriteIds.length),
                    label: 'Favorites',
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: AppColors.softShadow,
      ),
      child: Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(
            children: <Widget>[
              const Icon(
                Icons.search_rounded,
                size: 21,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Search photos, places, objects…',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                ),
              ),
              const Icon(
                Icons.tune_rounded,
                size: 19,
                color: AppColors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    ));
  }
}

class _LimitedBanner extends StatelessWidget {
  const _LimitedBanner({required this.onManage});

  final Future<void> Function() onManage;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.visibility_outlined,
            size: 20,
            color: AppColors.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Only selected photos are visible. Add more to organize your full library.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
          TextButton(
            onPressed: () => onManage(),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.warning,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
            child: const Text('Manage'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: <Widget>[
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 2),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _StorageCard extends StatelessWidget {
  const _StorageCard({required this.library});

  final LibraryState library;

  @override
  Widget build(BuildContext context) {
    final double used = library.storageInfo?.usedFraction ?? 0;
    final int total = library.storageInfo?.totalBytes ?? 0;
    final int free = library.storageInfo?.freeBytes ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 70,
            height: 70,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Positioned.fill(
                  child: CircularProgressIndicator(
                    value: total > 0 ? used : 0.0,
                    strokeWidth: 7,
                    backgroundColor: AppColors.primaryFaint,
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      total > 0 ? '${(used * 100).round()}%' : '—',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      'used',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 9,
                            color: AppColors.textTertiary,
                          ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Device storage',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                _StorageRow(
                  label: 'Photos',
                  value: formatFileSize(library.totalBytes),
                ),
                _StorageRow(
                  label: 'Free space',
                  value: total > 0 ? formatStorageGB(free) : 'Not available',
                ),
                _StorageRow(
                  label: 'Device',
                  value: total > 0 ? formatStorageGB(total) : 'Not available',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StorageRow extends StatelessWidget {
  const _StorageRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: AppColors.card,
        elevation: 0,
        shadowColor: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
            child: Column(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, size: 21, color: color),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentThumb extends StatelessWidget {
  const _RecentThumb({required this.asset, required this.onTap});

  final AssetEntity asset;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 100,
        height: 124,
        child: PhotoThumbnail(
          asset: asset,
          size: 500,
          fit: BoxFit.cover,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}

class _OrganizedThumb extends StatelessWidget {
  const _OrganizedThumb({
    required this.asset,
    required this.record,
    required this.onTap,
  });

  final AssetEntity asset;
  final PhotoRecord? record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppCategory? category = record?.category;
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 124,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: PhotoThumbnail(
                      asset: asset,
                      size: 500,
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  if (category != null)
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.52),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(category.icon, size: 11, color: Colors.white),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                record?.subcategory ?? category.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Jakarta',
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Text(
              record?.primaryLabel ?? 'Analyzing…',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Quiet placeholder shown for a moment while the library opens.
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  Widget _box(double height) {
    return Container(
      height: height,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F5),
        borderRadius: BorderRadius.circular(18),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 4),
      children: <Widget>[
        _box(52),
        _box(150),
        _box(96),
        _box(96),
        _box(96),
      ],
    );
  }
}
