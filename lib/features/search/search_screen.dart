import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utilities/slug_utils.dart';
import '../../shared/models/ai_models.dart';
import '../../shared/models/photo_record.dart';
import '../../shared/providers/library_provider.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/permission_gate.dart';
import '../../shared/widgets/photo_tile.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _setQuery(String value) {
    setState(() {
      _query = value.trim();
    });
  }

  @override
  Widget build(BuildContext context) {
    final LibraryState library = ref.watch(libraryProvider);

    if (!library.isInitialized || !library.hasAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Search')),
        body: const PermissionGate(compact: true),
      );
    }

    final List<AssetEntity> results = _search(library);
    final List<String> suggestions = _suggestions(library);

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 48,
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
        ),
        titleSpacing: 0,
        title: Container(
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(14),
          ),
          child: TextField(
            controller: _controller,
            focusNode: _focus,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onChanged: _setQuery,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textPrimary,
                ),
            decoration: InputDecoration(
              hintText: 'Search photos, objects, places…',
              filled: false,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: _controller.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        _controller.clear();
                        _setQuery('');
                        _focus.requestFocus();
                      },
                      icon: const Icon(Icons.close_rounded, size: 18),
                      tooltip: 'Clear',
                    ),
            ),
          ),
        ),
        actions: <Widget>[
          const SizedBox(width: 14),
        ],
      ),
      body: _query.isEmpty
          ? _SearchStart(
              suggestions: suggestions,
              onSuggestion: (String value) {
                _controller.text = value;
                _controller.selection = TextSelection.collapsed(
                  offset: value.length,
                );
                _setQuery(value);
              },
              totalPhotos: library.totalPhotos,
            )
          : results.isEmpty
              ? const EmptyState(
                  icon: Icons.search_off_rounded,
                  title: 'No matches',
                  message:
                      'Try a simpler word, an object, an animal, a place or a '
                      'category such as Food or Plants.',
                )
              : CustomScrollView(
                  slivers: <Widget>[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
                        child: Text(
                          '${results.length} ${results.length == 1 ? 'result' : 'results'} for “$_query”',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
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
                            final AssetEntity asset = results[index];
                            return PhotoGridTile(
                              asset: asset,
                              record: library.recordFor(asset.id),
                              favorite:
                                  library.favoriteIds.contains(asset.id),
                              onTap: () => context.push('/photo/${asset.id}'),
                            );
                          },
                          childCount: results.length,
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  List<AssetEntity> _search(LibraryState library) {
    if (_query.isEmpty) {
      return const <AssetEntity>[];
    }
    final String needle = _query.toLowerCase();
    return library.photos.where((AssetEntity asset) {
      final PhotoRecord? record = library.recordFor(asset.id);
      if (record == null) {
        return false;
      }
      if (record.title.toLowerCase().contains(needle) ||
          (record.primaryLabel?.toLowerCase().contains(needle) ?? false) ||
          (record.subcategory?.toLowerCase().contains(needle) ?? false) ||
          record.category.label.toLowerCase().contains(needle) ||
          record.category.description.toLowerCase().contains(needle)) {
        return true;
      }
      for (final LabelScore label in record.labels) {
        if (label.label.toLowerCase().contains(needle) ||
            humanizeLabel(label.label).toLowerCase().contains(needle)) {
          return true;
        }
      }
      return false;
    }).toList(growable: false);
  }

  List<String> _suggestions(LibraryState library) {
    final Map<String, int> counts = <String, int>{};
    for (final PhotoRecord record in library.records.values) {
      final String? label = record.primaryLabel;
      if (label == null || label.isEmpty || record.category.name == 'other') {
        continue;
      }
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final List<MapEntry<String, int>> sorted = counts.entries.toList()
      ..sort(
        (MapEntry<String, int> a, MapEntry<String, int> b) =>
            b.value.compareTo(a.value),
      );
    return sorted.take(8).map((MapEntry<String, int> e) => e.key).toList();
  }
}

class _SearchStart extends StatelessWidget {
  const _SearchStart({
    required this.suggestions,
    required this.onSuggestion,
    required this.totalPhotos,
  });

  final List<String> suggestions;
  final ValueChanged<String> onSuggestion;
  final int totalPhotos;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
      children: <Widget>[
        Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(
            color: AppColors.primaryFaint,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.travel_explore_rounded,
            color: AppColors.primary,
            size: 27,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Search what is inside your photos',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          '$totalPhotos photos, all labels generated on this device. '
          'Search for objects, animals, food, plants and more.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        if (suggestions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 28),
          Text(
            'Popular in your library',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((String suggestion) {
              return ActionChip(
                onPressed: () => onSuggestion(suggestion),
                backgroundColor: AppColors.card,
                side: BorderSide.none,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                label: Text(
                  humanizeLabel(suggestion),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.textPrimary,
                      ),
                ),
              );
            }).toList(),
          ),
        ],
        const SizedBox(height: 30),
        Row(
          children: <Widget>[
            const Icon(
              Icons.shield_outlined,
              size: 15,
              color: AppColors.textTertiary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Search is powered by the offline AI labels stored on your phone.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
