import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/duplicate_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utilities/formatters.dart';
import '../../shared/providers/library_provider.dart';
import '../../shared/providers/service_providers.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/permission_gate.dart';
import '../../shared/widgets/photo_thumbnail.dart';

class DuplicateFinderScreen extends ConsumerStatefulWidget {
  const DuplicateFinderScreen({super.key});

  @override
  ConsumerState<DuplicateFinderScreen> createState() =>
      _DuplicateFinderScreenState();
}

class _DuplicateFinderScreenState
    extends ConsumerState<DuplicateFinderScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  bool _scanning = false;
  double _progress = 0;
  int _done = 0;
  int _total = 0;
  DuplicateScanResult? _result;
  List<DuplicateGroup> _loadedGroups = const <DuplicateGroup>[];
  String? _error;
  final Set<String> _selected = <String>{};
  bool _deleting = false;

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    try {
      final List<DuplicateGroup> groups =
          await ref.read(duplicateServiceProvider).latestGroups();
      if (!mounted) {
        return;
      }
      setState(() {
        _loadedGroups = groups;
      });
    } catch (_) {
      // Ignore stale saved scans.
    }
  }

  Future<void> _scan() async {
    if (_scanning) {
      return;
    }
    final LibraryState library = ref.read(libraryProvider);
    if (!library.hasAccess || library.photos.isEmpty) {
      setState(() {
        _error = 'Add gallery access and photos before scanning for duplicates.';
      });
      return;
    }
    setState(() {
      _scanning = true;
      _progress = 0;
      _done = 0;
      _total = library.photos.length;
      _error = null;
      _selected.clear();
    });
    try {
      final DuplicateScanResult result = await ref
          .read(duplicateServiceProvider)
          .scan(
            assets: library.photos,
            hammingThreshold: 8,
            onProgress: (int done, int total) {
              if (!mounted) {
                return;
              }
              setState(() {
                _done = done;
                _total = total;
                _progress = total <= 0 ? 0 : done / total;
              });
            },
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _result = result;
        _loadedGroups = <DuplicateGroup>[...result.exact, ...result.similar];
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'The duplicate scan could not finish. Try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _scanning = false;
        });
      }
    }
  }

  List<DuplicateGroup> get _groups {
    if (_result != null) {
      return _result!.exact + _result!.similar;
    }
    return _loadedGroups;
  }

  List<DuplicateGroup> _groupsForTab(int index) {
    final List<DuplicateGroup> groups = _groups;
    if (index == 0) {
      return groups.where((DuplicateGroup g) => g.kind == 'exact').toList();
    }
    return groups.where((DuplicateGroup g) => g.kind == 'similar').toList();
  }

  Map<String, AssetEntity> _assetMap(LibraryState library) {
    return <String, AssetEntity>{
      for (final AssetEntity asset in library.photos) asset.id: asset,
    };
  }

  Future<void> _deleteSelected() async {
    if (_selected.isEmpty || _deleting) {
      return;
    }
    final LibraryState library = ref.read(libraryProvider);
    final Map<String, AssetEntity> byId = _assetMap(library);
    final List<AssetEntity> assets = _selected
        .map((String id) => byId[id])
        .whereType<AssetEntity>()
        .toList(growable: false);
    if (assets.isEmpty) {
      _selected.clear();
      setState(() {});
      return;
    }
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text(
                'Delete ${assets.length} ${assets.length == 1 ? 'duplicate' : 'duplicates'}?',
              ),
              content: Text(
                'The selected photos will be removed from your device. '
                'Keep at least one copy in each group if you want to preserve it. '
                'This action cannot be undone in Photo Organizer.',
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;
    if (!confirmed || !mounted) {
      return;
    }
    setState(() {
      _deleting = true;
    });
    final int deleted =
        await ref.read(libraryProvider.notifier).deleteAssets(assets);
    if (!mounted) {
      return;
    }
    setState(() {
      _deleting = false;
      _selected.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          deleted > 0
              ? 'Deleted $deleted ${deleted == 1 ? 'photo' : 'photos'}'
              : 'No photos were deleted',
        ),
      ),
    );
    await ref.read(libraryProvider.notifier).refresh();
    await _loadSaved();
  }

  @override
  Widget build(BuildContext context) {
    final LibraryState library = ref.watch(libraryProvider);

    if (!library.isInitialized || !library.hasAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Duplicate finder')),
        body: const PermissionGate(),
      );
    }

    final Map<String, AssetEntity> byId = _assetMap(library);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Duplicate finder'),
        actions: <Widget>[
          IconButton(
            onPressed: _scanning ? null : _scan,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Scan duplicates',
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
            child: _ScanSummary(
              scanning: _scanning,
              progress: _progress,
              done: _done,
              total: _total,
              result: _result,
              groupCount: _groups.length,
              onScan: _scan,
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.dangerSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textPrimary,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          TabBar(
            controller: _tabs,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: const <Tab>[
              Tab(text: 'Exact'),
              Tab(text: 'Similar'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: <Widget>[
                _GroupList(
                  groups: _groupsForTab(0),
                  byId: byId,
                  selected: _selected,
                  onToggle: (String id) {
                    setState(() {
                      if (_selected.contains(id)) {
                        _selected.remove(id);
                      } else {
                        _selected.add(id);
                      }
                    });
                  },
                  emptyTitle: 'No exact duplicates found',
                  emptyMessage:
                      'Run a scan to find identical photos by file hash.',
                ),
                _GroupList(
                  groups: _groupsForTab(1),
                  byId: byId,
                  selected: _selected,
                  onToggle: (String id) {
                    setState(() {
                      if (_selected.contains(id)) {
                        _selected.remove(id);
                      } else {
                        _selected.add(id);
                      }
                    });
                  },
                  emptyTitle: 'No similar photos found',
                  emptyMessage:
                      'Perceptual hashing can find resized or lightly edited duplicates.',
                ),
              ],
            ),
          ),
          if (_selected.isNotEmpty)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  border: Border(top: BorderSide(color: AppColors.border)),
                ),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        '${_selected.length} selected for deletion',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _deleting ? null : _deleteSelected,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        minimumSize: const Size(0, 44),
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                      ),
                      icon: _deleting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.white,
                              ),
                            )
                          : const Icon(Icons.delete_outline_rounded, size: 18),
                      label: const Text('Delete'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ScanSummary extends StatelessWidget {
  const _ScanSummary({
    required this.scanning,
    required this.progress,
    required this.done,
    required this.total,
    required this.result,
    required this.groupCount,
    required this.onScan,
  });

  final bool scanning;
  final double progress;
  final int done;
  final int total;
  final DuplicateScanResult? result;
  final int groupCount;
  final VoidCallback onScan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryFaint,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.content_copy_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      scanning ? 'Scanning for duplicates' : 'Duplicate scan',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      scanning
                          ? '$done of $total photos checked'
                          : result == null
                              ? 'No scan yet. Tap scan to find duplicates.'
                              : '${result!.scanned} photos checked, '
                                  '${result!.skipped} skipped, '
                                  '$groupCount groups found.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: scanning ? null : onScan,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 40),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                child: Text(scanning ? 'Running…' : 'Scan'),
              ),
            ],
          ),
          if (scanning) ...<Widget>[
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
        ],
      ),
    );
  }
}

class _GroupList extends StatelessWidget {
  const _GroupList({
    required this.groups,
    required this.byId,
    required this.selected,
    required this.onToggle,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final List<DuplicateGroup> groups;
  final Map<String, AssetEntity> byId;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    if (groups.isEmpty) {
      return EmptyState(
        icon: Icons.content_copy_outlined,
        title: emptyTitle,
        message: emptyMessage,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: groups.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (BuildContext context, int index) {
        final DuplicateGroup group = groups[index];
        final List<AssetEntity> assets = group.assetIds
            .map((String id) => byId[id])
            .whereType<AssetEntity>()
            .toList(growable: false);
        return _DuplicateGroupCard(
          group: group,
          assets: assets,
          selected: selected,
          onToggle: onToggle,
        );
      },
    );
  }
}

class _DuplicateGroupCard extends StatelessWidget {
  const _DuplicateGroupCard({
    required this.group,
    required this.assets,
    required this.selected,
    required this.onToggle,
  });

  final DuplicateGroup group;
  final List<AssetEntity> assets;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: (group.kind == 'exact'
                          ? AppColors.primary
                          : const Color(0xFF8B5CF6))
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  group.kind == 'exact' ? 'Exact' : 'Similar',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: group.kind == 'exact'
                            ? AppColors.primary
                            : const Color(0xFF8B5CF6),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${assets.length} photos',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              Text(
                formatFileSize(group.totalSize),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            group.kind == 'exact'
                ? 'Identical file hash'
                : 'Visual similarity within ${AppConstants.duplicateHammingThreshold} bits',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: assets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (BuildContext context, int index) {
                final AssetEntity asset = assets[index];
                final bool isSelected = selected.contains(asset.id);
                return SizedBox(
                  width: 92,
                  child: Column(
                    children: <Widget>[
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            PhotoThumbnail(
                              asset: asset,
                              size: 320,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            Positioned.fill(
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () => onToggle(asset.id),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 150),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected
                                            ? AppColors.danger
                                            : Colors.transparent,
                                        width: 2.5,
                                      ),
                                      color: isSelected
                                          ? AppColors.danger.withValues(alpha: 0.12)
                                          : Colors.transparent,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: GestureDetector(
                                onTap: () => onToggle(asset.id),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? AppColors.danger
                                        : Colors.black38,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: isSelected
                                      ? const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Photo',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize: 10,
                            ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
