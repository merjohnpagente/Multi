import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/services/ai_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utilities/formatters.dart';
import '../../core/utilities/slug_utils.dart';
import '../../shared/models/ai_models.dart';
import '../../shared/models/app_category.dart';
import '../../shared/models/photo_metadata.dart';
import '../../shared/models/photo_record.dart';
import '../../shared/providers/library_provider.dart';
import '../../shared/providers/service_providers.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/photo_thumbnail.dart';

class PhotoDetailsScreen extends ConsumerStatefulWidget {
  const PhotoDetailsScreen({super.key, required this.assetId});

  final String assetId;

  @override
  ConsumerState<PhotoDetailsScreen> createState() =>
      _PhotoDetailsScreenState();
}

class _PhotoDetailsScreenState extends ConsumerState<PhotoDetailsScreen> {
  AssetEntity? _asset;
  Future<PhotoMetadata>? _metadataFuture;
  bool _loading = true;
  bool _analyzing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final AssetEntity? asset = await ref
        .read(photoServiceProvider)
        .assetById(widget.assetId);
    if (!mounted) {
      return;
    }
    setState(() {
      _asset = asset;
      _loading = false;
      _metadataFuture =
          asset == null ? null : ref.read(metadataServiceProvider).load(asset);
    });
  }

  Future<void> _toggleFavorite() async {
    await ref.read(libraryProvider.notifier).toggleFavorite(widget.assetId);
  }

  Future<void> _analyze(AssetEntity asset) async {
    if (_analyzing) {
      return;
    }
    setState(() {
      _analyzing = true;
    });
    try {
      final AiIdentification? result =
          await ref.read(libraryProvider.notifier).analyzeAsset(asset);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result == null
                ? 'This photo could not be analyzed.'
                : 'Identified as ${result.primaryLabel}',
          ),
        ),
      );
    } on AiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AI analysis failed. Try again.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _analyzing = false;
        });
      }
    }
  }

  Future<void> _delete(AssetEntity asset) async {
    final bool confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete this photo?'),
              content: const Text(
                'This removes the photo from your device. '
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
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final int deleted = await ref
        .read(libraryProvider.notifier)
        .deleteAssets(<AssetEntity>[asset]);
    if (!mounted) {
      return;
    }
    if (deleted > 0) {
      context.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Photo deleted')),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('No photo was deleted')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final LibraryState library = ref.watch(libraryProvider);
    final PhotoRecord? record = library.recordFor(widget.assetId);
    final bool favorite = library.favoriteIds.contains(widget.assetId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo details'),
        actions: <Widget>[
          IconButton(
            onPressed: _toggleFavorite,
            icon: Icon(
              favorite
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              color: favorite ? AppColors.danger : AppColors.textPrimary,
            ),
            tooltip: favorite ? 'Remove from favorites' : 'Add to favorites',
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _asset == null
              ? EmptyState(
                  icon: Icons.broken_image_outlined,
                  title: 'Photo unavailable',
                  message:
                      'This photo may have been moved or deleted from the device.',
                  actionLabel: 'Check gallery',
                  onAction: () {
                    ref.read(libraryProvider.notifier).refresh();
                    context.go('/gallery');
                  },
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 36),
                  children: <Widget>[
                    Hero(
                      tag: 'photo-${widget.assetId}',
                      child: AspectRatio(
                        aspectRatio: 4 / 3,
                        child: PhotoThumbnail(
                          asset: _asset!,
                          size: 1600,
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: _ActionButton(
                            icon: favorite
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            label: favorite ? 'Favorited' : 'Favorite',
                            color: AppColors.danger,
                            onTap: _toggleFavorite,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.auto_awesome_rounded,
                            label: _analyzing ? 'Analyzing…' : 'Identify',
                            color: AppColors.primary,
                            onTap: _analyzing
                                ? null
                                : () => _analyze(_asset!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _ActionButton(
                            icon: Icons.delete_outline_rounded,
                            label: 'Delete',
                            color: AppColors.danger,
                            onTap: () => _delete(_asset!),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _AiSection(
                      record: record,
                      analyzing: _analyzing,
                      onAnalyze: () => _analyze(_asset!),
                    ),
                    const SizedBox(height: 18),
                    _InfoCard(
                      title: 'Details',
                      rows: _detailRows(record),
                    ),
                    const SizedBox(height: 18),
                    FutureBuilder<PhotoMetadata>(
                      future: _metadataFuture,
                      builder: (
                        BuildContext context,
                        AsyncSnapshot<PhotoMetadata> snapshot,
                      ) {
                        final PhotoMetadata? metadata = snapshot.data;
                        final Map<String, dynamic> exif =
                            metadata?.exif ?? const <String, dynamic>{};
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const _LoadingCard();
                        }
                        return _InfoCard(
                          title: 'Camera & EXIF',
                          rows: <_InfoRow>[
                            _InfoRow(
                              'Camera',
                              metadata?.cameraLabel ??
                                  record?.cameraModel ??
                                  'Not available',
                            ),
                            if (exif['lensModel'] != null)
                              _InfoRow(
                                'Lens',
                                exif['lensModel'].toString(),
                              ),
                            if (exif['exposureTime'] != null)
                              _InfoRow(
                                'Exposure',
                                exif['exposureTime'].toString(),
                              ),
                            if (exif['fNumber'] != null)
                              _InfoRow('Aperture', exif['fNumber'].toString()),
                            if (exif['iso'] != null)
                              _InfoRow('ISO', exif['iso'].toString()),
                            if (exif['focalLength'] != null)
                              _InfoRow(
                                'Focal length',
                                exif['focalLength'].toString(),
                              ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 18),
                    _InfoCard(
                      title: 'Location',
                      rows: <_InfoRow>[
                        _InfoRow(
                          'Coordinates',
                          formatCoordinates(
                            record?.latitude ?? _asset!.latitude,
                            record?.longitude ?? _asset!.longitude,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: <Widget>[
                        const Icon(
                          Icons.lock_outline_rounded,
                          size: 15,
                          color: AppColors.textTertiary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Metadata and AI labels are read and stored locally.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
    );
  }

  List<_InfoRow> _detailRows(PhotoRecord? record) {
    final AssetEntity asset = _asset!;
    return <_InfoRow>[
      _InfoRow('File name', record?.title ?? asset.title ?? 'Photo'),
      _InfoRow(
        'Date',
        formatDateTime(record?.createDate ?? asset.createDateTime),
      ),
      _InfoRow(
        'Dimensions',
        '${asset.width} × ${asset.height}',
      ),
      _InfoRow(
        'File size',
        record != null && record.fileSize > 0
            ? formatFileSize(record.fileSize)
            : 'Calculating…',
      ),
      _InfoRow(
        'Format',
        normalizedExtension(
          record?.title ?? asset.title ?? 'photo',
          asset.mimeType,
        ).toUpperCase(),
      ),
      if (record?.analyzedAt != null)
        _InfoRow(
          'AI analyzed',
          formatRelative(record!.analyzedAt),
        ),
    ];
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Column(
            children: <Widget>[
              Icon(icon, size: 20, color: onTap == null ? AppColors.textTertiary : color),
              const SizedBox(height: 5),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontSize: 10.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiSection extends StatelessWidget {
  const _AiSection({
    required this.record,
    required this.analyzing,
    required this.onAnalyze,
  });

  final PhotoRecord? record;
  final bool analyzing;
  final VoidCallback onAnalyze;

  @override
  Widget build(BuildContext context) {
    if (record == null || !record!.isAnalyzed) {
      return _InfoCard(
        title: 'AI organizer',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'This photo has not been identified yet. Run the offline AI to '
              'add a category and searchable labels.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: analyzing ? null : onAnalyze,
                icon: analyzing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(analyzing ? 'Identifying…' : 'Identify on device'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final PhotoRecord analyzed = record!;
    final AppCategory category = analyzed.category;
    final Color tint = category.tint;
    return _InfoCard(
      title: 'AI labels',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tint.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                alignment: Alignment.center,
                child: Icon(category.icon, color: tint, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      analyzed.primaryLabel ?? 'Unidentified',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${category.label} · ${analyzed.subcategory ?? 'Other'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                formatPercent(analyzed.confidence ?? 0),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: tint,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          if (analyzed.labels.isNotEmpty) ...<Widget>[
            const SizedBox(height: 16),
            for (final LabelScore label in analyzed.labels.take(4))
              Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        humanizeLabel(label.label),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textPrimary,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      formatPercent(label.confidence),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                            color: AppColors.textTertiary,
                          ),
                    ),
                  ],
                ),
              ),
          ],
          if (analyzed.isLowConfidence) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              'Low confidence. Treat this label as a suggestion.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.title,
    this.rows,
    this.child,
  });

  final String title;
  final List<_InfoRow>? rows;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 12),
          if (child != null) child!,
          if (rows != null)
            for (int index = 0; index < rows!.length; index++) ...<Widget>[
              _InfoLine(row: rows![index]),
              if (index != rows!.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Divider(height: 1),
                ),
            ],
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.row});

  final _InfoRow row;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 108,
          child: Text(
            row.label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Expanded(
          child: Text(
            row.value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow {
  const _InfoRow(this.label, this.value);

  final String label;
  final String value;
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 110,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
