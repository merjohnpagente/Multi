import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/utilities/formatters.dart';
import '../../shared/providers/library_provider.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/permission_gate.dart';
import '../../shared/widgets/photo_tile.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final LibraryState library = ref.watch(libraryProvider);

    if (!library.isInitialized || !library.hasAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('Favorites')),
        body: const PermissionGate(),
      );
    }

    final List<AssetEntity> favorites = library.favoritePhotos;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        actions: <Widget>[
          if (favorites.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 20),
              child: Center(
                child: Text(
                  '${formatCount(favorites.length)} ${favorites.length == 1 ? 'photo' : 'photos'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(libraryProvider.notifier).refresh(),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            if (favorites.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.favorite_border_rounded,
                  title: 'No favorites yet',
                  message:
                      'Tap the heart on any photo to keep it close. '
                      'Favorites stay on this device.',
                  actionLabel: 'Browse gallery',
                  onAction: () => context.go('/gallery'),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
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
                      final AssetEntity asset = favorites[index];
                      return PhotoGridTile(
                        asset: asset,
                        record: library.recordFor(asset.id),
                        favorite: true,
                        onTap: () => context.push('/photo/${asset.id}'),
                      );
                    },
                    childCount: favorites.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
