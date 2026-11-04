import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/theme/app_colors.dart';
import '../providers/service_providers.dart';

class PhotoThumbnail extends ConsumerStatefulWidget {
  const PhotoThumbnail({
    super.key,
    required this.asset,
    this.size = 500,
    this.fit = BoxFit.cover,
    this.borderRadius = BorderRadius.zero,
  });

  final AssetEntity asset;
  final int size;
  final BoxFit fit;
  final BorderRadius borderRadius;

  @override
  ConsumerState<PhotoThumbnail> createState() => _PhotoThumbnailState();
}

class _PhotoThumbnailState extends ConsumerState<PhotoThumbnail> {
  late Future<Uint8List?> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PhotoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id ||
        oldWidget.size != widget.size) {
      _load();
    }
  }

  void _load() {
    _future = ref
        .read(photoServiceProvider)
        .thumbnail(widget.asset, size: widget.size);
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: widget.borderRadius,
      child: FutureBuilder<Uint8List?>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<Uint8List?> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Container(
              color: AppColors.card,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          final Uint8List? bytes = snapshot.data;
          if (bytes == null || bytes.isEmpty) {
            return Container(
              color: AppColors.card,
              alignment: Alignment.center,
              child: const Icon(
                Icons.broken_image_outlined,
                color: AppColors.textTertiary,
              ),
            );
          }
          return Image.memory(
            bytes,
            fit: widget.fit,
            gaplessPlayback: true,
            filterQuality: FilterQuality.low,
          );
        },
      ),
    );
  }
}
