import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/providers/service_providers.dart';
import '../../core/utilities/formatters.dart';
import '../../shared/models/app_category.dart';
import '../../shared/providers/library_provider.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/permission_gate.dart';
import '../../shared/widgets/photo_tile.dart';

class CategoryDetailScreen extends ConsumerStatefulWidget {
  const CategoryDetailScreen({super.key, required this.category});

  final AppCategory category;

  @override
  ConsumerState<CategoryDetailScreen> createState() =>
      _CategoryDetailScreenState();
}

class _CategoryDetailScreenState extends ConsumerState<CategoryDetailScreen> {
  String? _subcategory;
  bool _exporting = false;

  Future<void> _download(List<AssetEntity> photos) async {
    if (_exporting || photos.isEmpty) {
      return;
    }
    final String folder = _subcategory == null
        ? widget.category.label
        : '${widget.category.label}/$_subcategory';
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Download "$folder"?'),
        content: Text(
          '${photos.length} photo${photos.length == 1 ? '' : 's'} will be '
          'copied into a folder named "$folder" in Pictures/J-Pix Export on your phone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Download'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) {
      return;
    }
    setState(() {
      _exporting = true;
    });
    messenger.showSnackBar(
      SnackBar(content: Text('Saving ${photos.length} photos…')),
    );
    final int saved =
        await ref.read(photoServiceProvider).exportToFolder(photos, folder);
    if (!mounted) {
      return;
    }
    setState(() {
      _exporting = false;
    });
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          saved == 0
              ? 'Could not save the photos.'
              : 'Saved $saved photo${saved == 1 ? '' : 's'} to '
                  'Pictures/J-Pix Export/$folder',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final LibraryState library = ref.watch(libraryProvider);

    if (!library.isInitialized || !library.hasAccess) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.category.label)),
        body: const PermissionGate(compact: true),
      );
    }

    final List<AssetEntity> allPhotos =
        library.photosForCategory(widget.category);
    final Map<String, int> subcategories =
        library.subcategoryCounts(widget.category);
    final List<AssetEntity> photos = _subcategory == null
        ? allPhotos
        : allPhotos
            .where(
              (AssetEntity asset) =>
                  library.recordFor(asset.id)?.subcategory == _subcategory,
            )
            .toList(growable: false);
    final Color tint = widget.category.tint;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.label),
        actions: <Widget>[
          IconButton(
            onPressed: _exporting ? null : () => _download(photos),
            icon: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download_rounded),
            tooltip: 'Download as folder',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(libraryProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: <Widget>[
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppColors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        alignment: Alignment.center,
                        child: Icon(
                          widget.category.icon,
                          size: 26,
                          color: tint,
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              widget.category.description,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              allPhotos.length == 1
                                  ? '1 organized photo'
                                  : '${formatCount(allPhotos.length)} organized photos',
                              style:
                                  Theme.of(context).textTheme.labelMedium?.copyWith(
                                        color: tint,
                                        fontWeight: FontWeight.w600,
                                      ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (subcategories.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 46,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: <Widget>[
                      _SubcategoryChip(
                        label: 'All',
                        count: allPhotos.length,
                        selected: _subcategory == null,
                        onTap: () {
                          setState(() {
                            _subcategory = null;
                          });
                        },
                      ),
                      for (final MapEntry<String, int> entry
                          in subcategories.entries)
                        _SubcategoryChip(
                          label: entry.key,
                          count: entry.value,
                          selected: _subcategory == entry.key,
                          onTap: () {
                            setState(() {
                              _subcategory = entry.key;
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
            if (allPhotos.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: widget.category.icon,
                  title: 'No ${widget.category.label.toLowerCase()} yet',
                  message:
                      'Photos identified as ${widget.category.label.toLowerCase()} '
                      'will appear here. AI analysis happens privately on this device.',
                  actionLabel: library.pendingCount > 0
                      ? 'Organize now'
                      : 'Open AI Scan',
                  onAction: () {
                    if (library.pendingCount > 0) {
                      ref.read(libraryProvider.notifier).analyzePending(
                            force: true,
                          );
                    } else {
                      context.push('/scan');
                    }
                  },
                ),
              )
            else if (photos.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  compact: true,
                  icon: Icons.filter_alt_off_outlined,
                  title: 'No photos in this group',
                  message: 'Try another subcategory or view all photos.',
                  actionLabel: 'Show all',
                  onAction: () {
                    setState(() {
                      _subcategory = null;
                    });
                  },
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                sliver: SliverGrid(
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 4,
                    mainAxisSpacing: 4,
                    childAspectRatio: 1,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      final AssetEntity asset = photos[index];
                      return PhotoGridTile(
                        asset: asset,
                        record: library.recordFor(asset.id),
                        favorite: library.favoriteIds.contains(asset.id),
                        onTap: () => context.push('/photo/${asset.id}'),
                      );
                    },
                    childCount: photos.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SubcategoryChip extends StatelessWidget {
  const _SubcategoryChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : AppColors.card,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Text(
            '$label  $count',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color:
                      selected ? AppColors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}
