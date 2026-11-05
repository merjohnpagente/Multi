import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

import '../constants/app_constants.dart';

typedef AssetProgress = void Function(int loaded, int total);

class PhotoService {
  PhotoService();

  static const PermissionRequestOption _permissionOption = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.image,
      mediaLocation: true,
    ),
  );

  final LinkedHashMap<String, Uint8List> _thumbnailCache =
      LinkedHashMap<String, Uint8List>();
  final Map<String, Future<Uint8List?>> _thumbnailRequests =
      <String, Future<Uint8List?>>{};
  static const int _thumbnailCacheLimit = 320;

  PermissionState _permission = PermissionState.notDetermined;
  PermissionState get permission => _permission;
  bool get hasAccess => _permission.hasAccess;

  Future<PermissionState> requestPermission() async {
    final PermissionState permission =
        await PhotoManager.requestPermissionExtend(
      requestOption: _permissionOption,
    );
    _permission = permission;
    return permission;
  }

  Future<PermissionState> currentPermission() async {
    try {
      final PermissionState permission = await PhotoManager.getPermissionState(
        requestOption: _permissionOption,
      );
      _permission = permission;
      return permission;
    } catch (_) {
      return _permission;
    }
  }

  Future<void> openSettings() => PhotoManager.openSetting();

  Future<void> presentLimitedPicker() =>
      PhotoManager.presentLimited(type: RequestType.image);

  Future<List<AssetEntity>> loadImageAssets({
    AssetProgress? onProgress,
  }) async {
    final List<AssetPathEntity> paths = await PhotoManager.getAssetPathList(
      onlyAll: true,
      type: RequestType.image,
      filterOption: FilterOptionGroup(
        orders: <OrderOption>[
          OrderOption(type: OrderOptionType.createDate, asc: false),
        ],
      ),
    );
    if (paths.isEmpty) {
      return const <AssetEntity>[];
    }
    final AssetPathEntity all = paths.first;
    int total = 0;
    try {
      total = await all.assetCountAsync;
    } catch (_) {
      total = 0;
    }

    final List<AssetEntity> assets = <AssetEntity>[];
    int page = 0;
    while (true) {
      final List<AssetEntity> batch = await all.getAssetListPaged(
        page: page,
        size: AppConstants.pageSize,
      );
      if (batch.isEmpty) {
        break;
      }
      assets.addAll(batch);
      onProgress?.call(assets.length, total);
      if (batch.length < AppConstants.pageSize) {
        break;
      }
      page++;
    }
    // Exported folders are copies for the user; keep them out of the library.
    return assets
        .where((AssetEntity a) =>
            !(a.relativePath ?? '').contains(exportRoot))
        .toList(growable: false);
  }

  static const String exportRoot = 'J-Pix Export';

  /// Copies photos into Pictures/J-Pix Export/<folder>. Returns saved count.
  Future<int> exportToFolder(
    List<AssetEntity> assets,
    String folder, {
    void Function(int done, int total)? onProgress,
  }) async {
    int saved = 0;
    int done = 0;
    for (final AssetEntity asset in assets) {
      try {
        final Uint8List? bytes = await asset.originBytes;
        if (bytes != null && bytes.isNotEmpty) {
          String name = (asset.title ?? '').trim();
          if (name.isEmpty) {
            name = '${asset.id}.jpg';
          }
          final AssetEntity? entity = await PhotoManager.editor.saveImage(
            bytes,
            filename: name,
            title: name,
            relativePath: 'Pictures/$exportRoot/$folder',
          );
          if (entity != null) {
            saved++;
          }
        }
      } catch (_) {
        // Skip photos that cannot be read.
      }
      done++;
      onProgress?.call(done, assets.length);
    }
    return saved;
  }

  Future<AssetEntity?> assetById(String id) async {
    try {
      return await AssetEntity.fromId(id);
    } catch (_) {
      return null;
    }
  }

  Future<List<AssetEntity>> assetsByIds(List<String> ids) async {
    final List<AssetEntity> assets = <AssetEntity>[];
    for (final String id in ids) {
      final AssetEntity? asset = await assetById(id);
      if (asset != null) {
        assets.add(asset);
      }
    }
    return assets;
  }

  Future<Uint8List?> thumbnail(
    AssetEntity asset, {
    int size = AppConstants.thumbnailSize,
  }) {
    final String key = '${asset.id}:$size';
    final Uint8List? cached = _thumbnailCache.remove(key);
    if (cached != null) {
      _thumbnailCache[key] = cached;
      return Future<Uint8List?>.value(cached);
    }
    final Future<Uint8List?>? pending = _thumbnailRequests[key];
    if (pending != null) {
      return pending;
    }
    final Future<Uint8List?> request = asset
        .thumbnailDataWithSize(ThumbnailSize.square(size), quality: 80)
        .then((Uint8List? data) {
      if (data != null && data.isNotEmpty) {
        _thumbnailCache[key] = data;
        if (_thumbnailCache.length > _thumbnailCacheLimit) {
          _thumbnailCache.remove(_thumbnailCache.keys.first);
        }
      }
      _thumbnailRequests.remove(key);
      return data;
    }).catchError((Object error, StackTrace stack) {
      _thumbnailRequests.remove(key);
      if (kDebugMode) {
        debugPrint('Thumbnail failed for ${asset.id}: $error');
      }
      return null;
    });
    _thumbnailRequests[key] = request;
    return request;
  }

  Future<Uint8List?> thumbnailForId(
    String assetId, {
    int size = AppConstants.thumbnailSize,
  }) async {
    final AssetEntity? asset = await assetById(assetId);
    if (asset == null) {
      return null;
    }
    return thumbnail(asset, size: size);
  }

  Future<File?> originFile(AssetEntity asset) async {
    try {
      return await asset.originFile ?? await asset.file;
    } catch (_) {
      return null;
    }
  }

  Future<File?> displayFile(AssetEntity asset) async {
    try {
      return await asset.file;
    } catch (_) {
      return null;
    }
  }

  Future<int> fileSize(AssetEntity asset) async {
    try {
      final int size = await asset.fileSize;
      return size;
    } catch (_) {
      final File? file = await originFile(asset);
      if (file == null) {
        return 0;
      }
      try {
        return await file.length();
      } catch (_) {
        return 0;
      }
    }
  }

  Future<List<String>> deleteAssets(List<AssetEntity> assets) async {
    if (assets.isEmpty) {
      return const <String>[];
    }
    try {
      final List<String> ids =
          assets.map((AssetEntity asset) => asset.id).toList();
      return await PhotoManager.editor.deleteWithIds(ids);
    } catch (_) {
      return const <String>[];
    }
  }

  Future<List<String>> deleteAssetIds(List<String> ids) async {
    if (ids.isEmpty) {
      return const <String>[];
    }
    try {
      return await PhotoManager.editor.deleteWithIds(ids);
    } catch (_) {
      return const <String>[];
    }
  }

  Future<AssetEntity?> saveImageBytes(Uint8List bytes, String filename) async {
    try {
      return await PhotoManager.editor.saveImage(
        bytes,
        filename: filename,
        title: filename,
        relativePath: 'Pictures/J-Pix',
      );
    } catch (_) {
      return null;
    }
  }

  void clearThumbnailCache() {
    _thumbnailCache.clear();
    _thumbnailRequests.clear();
  }
}
