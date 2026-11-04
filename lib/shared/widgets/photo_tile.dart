import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/models/photo_record.dart';
import 'photo_thumbnail.dart';

class PhotoGridTile extends StatelessWidget {
  const PhotoGridTile({
    super.key,
    required this.asset,
    required this.record,
    required this.onTap,
    this.onLongPress,
    this.selected = false,
    this.selecting = false,
    this.favorite = false,
    this.heroEnabled = true,
  });

  final AssetEntity asset;
  final PhotoRecord? record;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool selected;
  final bool selecting;
  final bool favorite;
  final bool heroEnabled;

  @override
  Widget build(BuildContext context) {
    final Widget image = PhotoThumbnail(
      asset: asset,
      size: 500,
      borderRadius: BorderRadius.circular(8),
    );

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          heroEnabled
              ? Hero(tag: 'photo-${asset.id}', child: image)
              : image,
          if (favorite)
            const Positioned(
              right: 6,
              top: 6,
              child: _HeartBadge(),
            ),
          if (selecting)
            Positioned(
              right: 6,
              top: 6,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.black26,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: selected
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ),
          if (selected)
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary, width: 2.5),
                    color: AppColors.primary.withOpacity(0.08),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeartBadge extends StatelessWidget {
  const _HeartBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: const BoxDecoration(
        color: Colors.black38,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.favorite_rounded,
        size: 12,
        color: Colors.white,
      ),
    );
  }
}
