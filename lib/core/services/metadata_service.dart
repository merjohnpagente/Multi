import 'dart:io';

import 'package:exif/exif.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../shared/models/photo_metadata.dart';
import '../utilities/formatters.dart';
import 'photo_service.dart';

class MetadataService {
  MetadataService(this._photoService);

  final PhotoService _photoService;

  Future<PhotoMetadata> load(AssetEntity asset) async {
    final String title = await _safeTitle(asset);
    final File? file = await _photoService.originFile(asset);
    final int fileSize = await _photoService.fileSize(asset);

    Map<String, IfdTag> tags = const <String, IfdTag>{};
    if (file != null) {
      try {
        tags = await readExifFromFile(file);
      } catch (_) {
        tags = const <String, IfdTag>{};
      }
    }

    DateTime? takenAt;
    final IfdTag? dateTag =
        tags['EXIF DateTimeOriginal'] ?? tags['Image DateTime'];
    if (dateTag != null) {
      takenAt = _parseExifDate(dateTag.printable);
    }
    takenAt ??= asset.createDateTime;

    final String? make = _tagValue(tags['Image Make']);
    final String? model = _tagValue(tags['Image Model']);

    final Map<String, dynamic> exif = <String, dynamic>{
      if (tags['EXIF ExposureTime'] != null)
        'exposureTime': tags['EXIF ExposureTime']!.printable,
      if (tags['EXIF FNumber'] != null)
        'fNumber': tags['EXIF FNumber']!.printable,
      if (tags['EXIF ISOSpeedRatings'] != null)
        'iso': tags['EXIF ISOSpeedRatings']!.printable,
      if (tags['EXIF FocalLength'] != null)
        'focalLength': tags['EXIF FocalLength']!.printable,
      if (tags['EXIF LensModel'] != null)
        'lensModel': tags['EXIF LensModel']!.printable,
    };

    final double? latitude = asset.latitude;
    final double? longitude = asset.longitude;

    return PhotoMetadata(
      title: title,
      fileSize: fileSize,
      width: asset.width,
      height: asset.height,
      format: normalizedExtension(title, asset.mimeType).toUpperCase(),
      takenAt: takenAt,
      cameraMake: make,
      cameraModel: model,
      latitude: latitude,
      longitude: longitude,
      exif: exif,
    );
  }

  Future<CameraMetadata?> readCameraOnly(AssetEntity asset) async {
    final File? file = await _photoService.originFile(asset);
    if (file == null) {
      return null;
    }
    try {
      final Map<String, IfdTag> tags = await readExifFromFile(file);
      final String? make = _tagValue(tags['Image Make']);
      final String? model = _tagValue(tags['Image Model']);
      if ((make == null || make.isEmpty) && (model == null || model.isEmpty)) {
        return null;
      }
      return CameraMetadata(make: make, model: model);
    } catch (_) {
      return null;
    }
  }

  Future<String> _safeTitle(AssetEntity asset) async {
    try {
      final String title = await asset.titleAsync;
      if (title.trim().isNotEmpty) {
        return title;
      }
    } catch (_) {
      // Fall back to the synchronous title.
    }
    return asset.title ?? 'Untitled';
  }

  String? _tagValue(IfdTag? tag) {
    if (tag == null) {
      return null;
    }
    final String value = tag.printable.trim();
    return value.isEmpty ? null : value;
  }

  DateTime? _parseExifDate(String input) {
    final String value = input.trim();
    final Match? match =
        RegExp(r'^(\d{4})[:\-](\d{2})[:\-](\d{2})[ T](\d{2}):(\d{2}):(\d{2})')
            .firstMatch(value);
    if (match == null) {
      return null;
    }
    try {
      return DateTime(
        int.parse(match.group(1)!),
        int.parse(match.group(2)!),
        int.parse(match.group(3)!),
        int.parse(match.group(4)!),
        int.parse(match.group(5)!),
        int.parse(match.group(6)!),
      );
    } catch (_) {
      return null;
    }
  }
}

class CameraMetadata {
  const CameraMetadata({this.make, this.model});

  final String? make;
  final String? model;
}
