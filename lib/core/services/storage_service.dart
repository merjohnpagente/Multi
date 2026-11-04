import 'package:flutter/services.dart';

class StorageInfo {
  const StorageInfo({required this.totalBytes, required this.freeBytes});

  final int totalBytes;
  final int freeBytes;

  int get usedBytes => totalBytes - freeBytes;
  double get usedFraction =>
      totalBytes <= 0 ? 0 : (usedBytes / totalBytes).clamp(0, 1).toDouble();
}

class StorageService {
  StorageService();

  static const MethodChannel _channel =
      MethodChannel('photo_organizer/storage');

  Future<StorageInfo?> deviceStorage() async {
    try {
      final Map<String, dynamic>? result =
          await _channel.invokeMapMethod<String, dynamic>('getStorageInfo');
      if (result == null) {
        return null;
      }
      final int total = (result['totalBytes'] as num?)?.toInt() ?? 0;
      final int free = (result['freeBytes'] as num?)?.toInt() ?? 0;
      if (total <= 0) {
        return null;
      }
      return StorageInfo(
        totalBytes: total,
        freeBytes: free.clamp(0, total).toInt(),
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
