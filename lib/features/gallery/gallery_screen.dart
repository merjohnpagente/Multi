import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utilities/formatters.dart';
import '../../shared/models/photo_record.dart';
import '../../shared/providers/library_provider.dart';
import '../../shared/providers/settings_provider.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/permission_gate.dart';
import '../../shared/widgets/photo_tile.dart';

enum GalleryFilter {
  all('All'),
  date('Date'),
  camera('Camera'),
  location('Location');

  const GalleryFilter(this.label);

  final String label;
}

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  GalleryFilter _filter = GalleryFilter.all;
  bool _selecting = false;
  bool _deleting = false;
  bool _newestFirst = true;
  Set<String> _selected = <String>{};

  @override
  void initState() {
    super.initState();
    _newestFirst =
        ref.read(settingsProvider).valueOrNull?.newestFirst ?? true;
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
        if (_selected.isEmpty) {
          _selecting = false;
        }
      } else {
        _selected.add(id);
        _selecting = true;
      }
    });
  }

  void _startSelection(String id) {
    setState(() {
      _selecting = true;
      _selected = <String>{id};
    });
  }

  void _closeSelection() {
    setState(() {
      _selecting = false;
      _selected = <String>{};
    });
  }

  void _selectAll(List<AssetEntity> assets) {
    setState(() {
      _selected = assets.map((AssetEntity asset) => asset.id).toSet();
      _selecting = _selected.isNotEmpty;
    });
  }

  Future<void> _favoriteSelected(LibraryState library) async {
    if (_selected.isEmpty) {
      return;
    }
    final bool allFavorites = _selected.every(
      (String id) => library.favoriteIds.contains(id),
    );
    final LibraryController controller = ref.read(libraryProvider.notifier);
    final List<String> ids = List<String>.of(_selected);
    for (final String id in ids) {
      final bool current = library.favoriteIds.contains(id);
      if (current == allFavorites) {
        await controller.toggleFavorite(id);
      }
    }
    if (!mounted) {
      return;
    }
    _closeSelection();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          allFavorites
              ? 'Removed ${ids.length} photos from Favorites'
              : 'Added ${ids.length} photos to Favorites',
        ),
      ),
    );
  }

  Future<void> _deleteSelected(LibraryState library) async {
    if (_selected.isEmpty || _deleting) {
      return;
    }
    final List<AssetEntity> assets = library.photos
        .where((AssetEntity asset) => _selected.contains(asset.id))
        .toList(growable: false);
    if (assets.isEmpty) {
      _closeSelection();
      return;
    }
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Delete ${assets.length} ${assets.length == 1 ? 'photo' : 'photos'}?'),
              content: const Text(
                'This removes the selected photos from your device. '
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
      _selecting = false;
      _selected = <String>{};
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
  }

  Future<void> _addPhotos() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose photos'),
                subtitle: const Text('Pick one or more from your phone'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.gallery),
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take a photo'),
                onTap: () =>
                    Navigator.of(sheetContext).pop(ImageSource.camera),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
    if (source == null || !mounted) {
      return;
    }
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> files = <XFile>[];
      if (source == ImageSource.camera) {
        final PermissionStatus status = await Permission.camera.request();
        if (!status.isGranted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Camera access is needed.')),
          );
          return;
        }
        final XFile? shot = await picker.pickImage(source: source);
        if (shot != null) {
          files.add(shot);
        }
      } else {
        files.addAll(await picker.pickMultiImage());
      }
      if (files.isEmpty) {
        return;
      }
      final List<MapEntry<String, Uint8List>> items =
          <MapEntry<String, Uint8List>>[];
      for (final XFile file in files) {
        items.add(MapEntry<String, Uint8List>(
          file.name,
          await file.readAsBytes(),
        ));
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            ref.read(libraryProvider.notifier).onlineAiEnabled
                ? 'Identifying with online AI and saving into folders…'
                : 'Identifying and saving into folders…',
          ),
        ),
      );
      final LibraryController controller = ref.read(libraryProvider.notifier);
      final int saved = await controller.importPhotos(items);
      final String? importError = controller.lastImportError;
      final String? onlineError = controller.lastOnlineError;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(
            saved == 0
                ? 'Could not add the photos. ${importError ?? ''}'.trim()
                : onlineError != null
                    ? '$saved added using offline AI. Online AI: $onlineError'
                    : '$saved ${saved == 1 ? 'photo' : 'photos'} added and '
                        'sorted into folders (${controller.lastImportOnlineCount > 0 ? 'online AI: ${controller.lastImportOnlineCount}' : 'offline AI'}).',
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not add the photos.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final LibraryState library = ref.watch(libraryProvider);
    final int columns =
        ref.watch(settingsProvider).valueOrNull?.galleryColumns ?? 3;

    if (!library.isInitialized || !library.hasAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gallery')),
        body: const PermissionGate(),
      );
    }

    final List<AssetEntity> photos = _sortedPhotos(library);

    return Scaffold(
      appBar: _selecting
          ? AppBar(
              leading: IconButton(
                onPressed: _deleting ? null : _closeSelection,
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Cancel selection',
              ),
              title: Text('${_selected.length} selected'),
              actions: <Widget>[
                IconButton(
                  onPressed: _deleting ? null : () => _selectAll(photos),
                  icon: const Icon(Icons.select_all_rounded),
                  tooltip: 'Select all',
                ),
                IconButton(
                  onPressed:
                      _deleting ? null : () => _favoriteSelected(library),
                  icon: const Icon(Icons.favorite_border_rounded),
                  tooltip: 'Favorite',
                ),
                IconButton(
                  onPressed: _deleting ? null : () => _deleteSelected(library),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.danger,
                  ),
                  tooltip: 'Delete',
                ),
              ],
            )
          : AppBar(
              title: const Text('Gallery'),
              actions: <Widget>[
                IconButton(
                  onPressed: _addPhotos,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  tooltip: 'Add photos',
                ),
                IconButton(
                  onPressed: () => context.push('/search'),
                  icon: const Icon(Icons.search_rounded),
                  tooltip: 'Search',
                ),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _newestFirst = !_newestFirst;
                    });
                  },
                  icon: Icon(
                    _newestFirst
                        ? Icons.arrow_downward_rounded
                        : Icons.arrow_upward_rounded,
                  ),
                  tooltip: _newestFirst ? 'Newest first' : 'Oldest first',
                ),
              ],
            ),
      body: photos.isEmpty && !library.isRefreshing
          ? EmptyState(
              icon: Icons.photo_library_outlined,
              title: 'No photos yet',
              message:
                  'Photos on this device will appear here automatically. '
                  'Pull down to check again.',
              actionLabel: 'Check gallery',
              onAction: () => ref.read(libraryProvider.notifier).refresh(),
            )
          : Column(
              children: <Widget>[
                if (library.isRefreshing)
                  const LinearProgressIndicator(minHeight: 2),
                _FilterBar(
                  filter: _filter,
                  count: photos.length,
                  onChanged: (GalleryFilter filter) {
                    setState(() {
                      _filter = filter;
                    });
                  },
                ),
                if (library.isLimited)
                  _LimitedNote(
                    onManage:
                        ref.read(libraryProvider.notifier).manageLimitedAccess,
                  ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () =>
                        ref.read(libraryProvider.notifier).refresh(),
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      slivers: _buildSlivers(context, library, photos, columns),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  List<AssetEntity> _sortedPhotos(LibraryState library) {
    final List<AssetEntity> photos = List<AssetEntity>.of(library.photos);
    photos.sort((AssetEntity a, AssetEntity b) {
      final int result = a.createDateTime.compareTo(b.createDateTime);
      return _newestFirst ? -result : result;
    });
    return photos;
  }

  List<Widget> _buildSlivers(
    BuildContext context,
    LibraryState library,
    List<AssetEntity> photos,
    int columns,
  ) {
    if (_filter == GalleryFilter.all) {
      return <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          sliver: _grid(photos, columns, library),
        ),
      ];
    }

    final Map<String, List<AssetEntity>> groups = _groupPhotos(photos, library);
    final List<Widget> slivers = <Widget>[];
    for (final MapEntry<String, List<AssetEntity>> group in groups.entries) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    group.key,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  '${group.value.length}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      );
      slivers.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 2),
          sliver: _grid(group.value, columns, library),
        ),
      );
    }
    slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));
    return slivers;
  }

  Widget _grid(
    List<AssetEntity> photos,
    int columns,
    LibraryState library,
  ) {
    return SliverGrid(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
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
            selected: _selected.contains(asset.id),
            selecting: _selecting,
            favorite: library.favoriteIds.contains(asset.id),
            heroEnabled: !_selecting,
            onTap: () {
              if (_selecting) {
                _toggleSelection(asset.id);
              } else {
                context.push('/photo/${asset.id}');
              }
            },
            onLongPress: () => _startSelection(asset.id),
          );
        },
        childCount: photos.length,
      ),
    );
  }

  Map<String, List<AssetEntity>> _groupPhotos(
    List<AssetEntity> photos,
    LibraryState library,
  ) {
    final Map<String, List<AssetEntity>> groups =
        <String, List<AssetEntity>>{};
    for (final AssetEntity asset in photos) {
      final PhotoRecord? record = library.recordFor(asset.id);
      String key;
      switch (_filter) {
        case GalleryFilter.date:
          key = formatMonthYear(asset.createDateTime);
          break;
        case GalleryFilter.camera:
          final String make = record?.cameraMake?.trim() ?? '';
          final String model = record?.cameraModel?.trim() ?? '';
          key = model.isNotEmpty
              ? model
              : make.isNotEmpty
                  ? make
                  : 'Camera information pending';
          break;
        case GalleryFilter.location:
          key = record?.hasLocation == true
              ? 'With location'
              : 'No location';
          break;
        case GalleryFilter.all:
          key = 'All photos';
          break;
      }
      groups.putIfAbsent(key, () => <AssetEntity>[]).add(asset);
    }
    return groups;
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.count,
    required this.onChanged,
  });

  final GalleryFilter filter;
  final int count;
  final ValueChanged<GalleryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 58,
      child: Row(
        children: <Widget>[
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: GalleryFilter.values.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (BuildContext context, int index) {
                final GalleryFilter item = GalleryFilter.values[index];
                final bool selected = item == filter;
                return Center(
                  child: GestureDetector(
                    onTap: () => onChanged(item),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 15,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.primary
                            : AppColors.card,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        item.label,
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: selected
                                  ? AppColors.white
                                  : AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 20),
            child: Text(
              '$count ${count == 1 ? 'photo' : 'photos'}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _LimitedNote extends StatelessWidget {
  const _LimitedNote({required this.onManage});

  final Future<void> Function() onManage;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.visibility_outlined,
            size: 17,
            color: AppColors.warning,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing selected photos only',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
            ),
          ),
          GestureDetector(
            onTap: () => onManage(),
            child: Text(
              'Manage',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
