import 'package:photo_manager/photo_manager.dart';

class PhotoMetadata {
  const PhotoMetadata({
    required this.title,
    required this.fileSize,
    required this.width,
    required this.height,
    required this.format,
    required this.takenAt,
    required this.cameraMake,
    required this.cameraModel,
    required this.latitude,
    required this.longitude,
    required this.exif,
  });

  final String title;
  final int fileSize;
  final int width;
  final int height;
  final String format;
  final DateTime? takenAt;
  final String? cameraMake;
  final String? cameraModel;
  final double? latitude;
  final double? longitude;
  final Map<String, dynamic> exif;

  String? get cameraLabel {
    final List<String> parts = <String>[
      if (cameraMake != null && cameraMake!.trim().isNotEmpty) cameraMake!.trim(),
      if (cameraModel != null && cameraModel!.trim().isNotEmpty) cameraModel!.trim(),
    ];
    if (parts.isEmpty) {
      return null;
    }
    final String joined = parts.join(' ');
    return joined.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String get resolutionLabel => '$width × $height';

  String get locationLabel {
    if (latitude == null || longitude == null) {
      return 'Not available';
    }
    return '${latitude!.toStringAsFixed(5)}, ${longitude!.toStringAsFixed(5)}';
  }

  static PhotoMetadata empty(AssetEntity asset) => PhotoMetadata(
        title: asset.title ?? 'Untitled',
        fileSize: 0,
        width: asset.width,
        height: asset.height,
        format: _formatFromMime(asset.mimeType),
        takenAt: asset.createDateTime,
        cameraMake: null,
        cameraModel: null,
        latitude: asset.latitude,
        longitude: asset.longitude,
        exif: const <String, dynamic>{},
      );

  static String _formatFromMime(String? mimeType) {
    if (mimeType == null || !mimeType.contains('/')) {
      return 'IMAGE';
    }
    return mimeType.split('/').last.toUpperCase();
  }
}

class MetadataSection {
  const MetadataSection(this.title, this.rows);

  final String title;
  final List<MetadataRow> rows;
}

class MetadataRow {
  const MetadataRow(this.label, this.value);

  final String label;
  final String value;
}
