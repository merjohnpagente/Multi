import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:photo_manager/photo_manager.dart';

import '../constants/app_constants.dart';
import 'database_service.dart';
import 'photo_service.dart';

class DuplicateGroup {
  const DuplicateGroup({
    required this.kind,
    required this.signature,
    required this.assetIds,
    required this.totalSize,
    this.id,
    this.createdAt,
  });

  final int? id;
  final String kind;
  final String signature;
  final List<String> assetIds;
  final int totalSize;
  final DateTime? createdAt;

  int get photoCount => assetIds.length;
  int get wastedBytes => totalSize - (totalSize ~/ photoCount == 0 ? 0 : 0);

  int get potentialSavings {
    if (assetIds.isEmpty) {
      return 0;
    }
    final int average = totalSize ~/ assetIds.length;
    return totalSize - average;
  }
}

class DuplicateScanResult {
  const DuplicateScanResult({
    required this.scanId,
    required this.exact,
    required this.similar,
    required this.scanned,
    required this.skipped,
  });

  final String scanId;
  final List<DuplicateGroup> exact;
  final List<DuplicateGroup> similar;
  final int scanned;
  final int skipped;

  int get groupCount => exact.length + similar.length;
  int get duplicatePhotoCount =>
      exact.fold<int>(0, (int sum, DuplicateGroup group) => sum + group.assetIds.length) +
      similar.fold<int>(0, (int sum, DuplicateGroup group) => sum + group.assetIds.length);
}

class DuplicateService {
  DuplicateService._();

  static final DuplicateService instance = DuplicateService._();

  final PhotoService _photo = PhotoService();
  final DatabaseService _db = DatabaseService.instance;

  Future<DuplicateScanResult> scan({
    required List<AssetEntity> assets,
    required int hammingThreshold,
    void Function(int done, int total)? onProgress,
  }) async {
    final List<_HashedAsset> hashed = <_HashedAsset>[];
    int skipped = 0;
    int done = 0;
    final int total = assets.length;

    for (final AssetEntity asset in assets) {
      if (kDebugMode) {
        // Keep scanning responsive on large galleries.
      }
      final File? file = await _photo.originFile(asset);
      if (file == null) {
        skipped++;
        done++;
        onProgress?.call(done, total);
        continue;
      }
      final int size = await _photo.fileSize(asset);
      String sha256Digest;
      try {
        final Digest digest = await sha256.bind(file.openRead()).first;
        sha256Digest = digest.toString();
      } catch (_) {
        skipped++;
        done++;
        onProgress?.call(done, total);
        continue;
      }

      int? dhash;
      try {
        final Uint8List? thumbnail = await _photo.thumbnail(
          asset,
          size: 256,
        );
        if (thumbnail != null && thumbnail.isNotEmpty) {
          final img.Image? decoded = img.decodeImage(thumbnail);
          if (decoded != null) {
            final img.Image resized = img.copyResize(
              decoded,
              width: 9,
              height: 8,
              interpolation: img.Interpolation.average,
            );
            final img.Image gray = img.grayscale(resized);
            int hash = 0;
            int bit = 0;
            for (int y = 0; y < 8; y++) {
              for (int x = 0; x < 8; x++) {
                final int left =
                    gray.getPixel(x, y).r.toInt().clamp(0, 255);
                final int right =
                    gray.getPixel(x + 1, y).r.toInt().clamp(0, 255);
                if (left < right) {
                  hash |= 1 << bit;
                }
                bit++;
              }
            }
            dhash = hash;
          }
        }
      } catch (_) {
        dhash = null;
      }

      hashed.add(
        _HashedAsset(
          asset: asset,
          sha256: sha256Digest,
          dhash: dhash,
          fileSize: size,
        ),
      );
      done++;
      onProgress?.call(done, total);
    }

    final DateTime now = DateTime.now();
    final String scanId = now.microsecondsSinceEpoch.toString();

    final List<DuplicateGroup> exactGroups = _exactGroups(hashed, now);
    final List<DuplicateGroup> similarGroups =
        _similarGroups(hashed, hammingThreshold, now);

    final List<Map<String, Object?>> databaseGroups =
        <Map<String, Object?>>[];
    for (final DuplicateGroup group in exactGroups) {
      databaseGroups.add(_toMap(scanId, 'exact', group, now));
    }
    for (final DuplicateGroup group in similarGroups) {
      databaseGroups.add(_toMap(scanId, 'similar', group, now));
    }
    await _db.saveDuplicateGroups(
      scanId: scanId,
      groups: databaseGroups,
    );

    return DuplicateScanResult(
      scanId: scanId,
      exact: exactGroups,
      similar: similarGroups,
      scanned: hashed.length,
      skipped: skipped,
    );
  }

  Future<List<DuplicateGroup>> latestGroups() async {
    final List<Map<String, Object?>> rows =
        await _db.latestDuplicateGroups();
    return rows.map(_fromMap).toList(growable: false);
  }

  Future<void> clear() => _db.clearDuplicateGroups();

  List<DuplicateGroup> _exactGroups(
    List<_HashedAsset> hashed,
    DateTime now,
  ) {
    final Map<String, List<_HashedAsset>> buckets =
        <String, List<_HashedAsset>>{};
    for (final _HashedAsset item in hashed) {
      buckets
          .putIfAbsent(item.sha256, () => <_HashedAsset>[])
          .add(item);
    }
    final List<DuplicateGroup> groups = <DuplicateGroup>[];
    for (final MapEntry<String, List<_HashedAsset>> entry
        in buckets.entries) {
      if (entry.value.length < 2) {
        continue;
      }
      groups.add(
        DuplicateGroup(
          kind: 'exact',
          signature: entry.key,
          assetIds: entry.value
              .map((_HashedAsset item) => item.asset.id)
              .toList(growable: false),
          totalSize: entry.value.fold<int>(
            0,
            (int sum, _HashedAsset item) => sum + item.fileSize,
          ),
          createdAt: now,
        ),
      );
    }
    groups.sort(
      (DuplicateGroup a, DuplicateGroup b) =>
          b.totalSize.compareTo(a.totalSize),
    );
    return groups;
  }

  List<DuplicateGroup> _similarGroups(
    List<_HashedAsset> hashed,
    int threshold,
    DateTime now,
  ) {
    final List<_HashedAsset> candidates = hashed
        .where((_HashedAsset item) => item.dhash != null)
        .toList(growable: false);
    if (candidates.length < 2) {
      return const <DuplicateGroup>[];
    }

    final _UnionFind union = _UnionFind(candidates.length);
    final Map<String, List<int>> buckets = <String, List<int>>{};
    for (int i = 0; i < candidates.length; i++) {
      final int hash = candidates[i].dhash!;
      for (int band = 0; band < 16; band++) {
        final int key = (hash >> (band * 4)) & 0x0F;
        buckets
            .putIfAbsent('$band:$key', () => <int>[])
            .add(i);
      }
    }
    final Set<String> compared = <String>{};
    for (final List<int> bucket in buckets.values) {
      for (int a = 0; a < bucket.length; a++) {
        for (int b = a + 1; b < bucket.length; b++) {
          final int i = bucket[a];
          final int j = bucket[b];
          if (i == j) {
            continue;
          }
          final String pairKey = i < j ? '$i:$j' : '$j:$i';
          if (!compared.add(pairKey)) {
            continue;
          }
          if (_hamming(candidates[i].dhash!, candidates[j].dhash!) <=
              threshold) {
            union.union(i, j);
          }
        }
      }
    }

    final Map<int, List<_HashedAsset>> groupsByRoot =
        <int, List<_HashedAsset>>{};
    for (int i = 0; i < candidates.length; i++) {
      groupsByRoot
          .putIfAbsent(union.find(i), () => <_HashedAsset>[])
          .add(candidates[i]);
    }

    final List<DuplicateGroup> groups = <DuplicateGroup>[];
    for (final MapEntry<int, List<_HashedAsset>> entry
        in groupsByRoot.entries) {
      if (entry.value.length < 2) {
        continue;
      }
      final int hash = entry.value.first.dhash!;
      groups.add(
        DuplicateGroup(
          kind: 'similar',
          signature: hash.toRadixString(16).padLeft(16, '0'),
          assetIds: entry.value
              .map((_HashedAsset item) => item.asset.id)
              .toList(growable: false),
          totalSize: entry.value.fold<int>(
            0,
            (int sum, _HashedAsset item) => sum + item.fileSize,
          ),
          createdAt: now,
        ),
      );
    }
    groups.sort(
      (DuplicateGroup a, DuplicateGroup b) =>
          b.totalSize.compareTo(a.totalSize),
    );
    return groups;
  }

  Map<String, Object?> _toMap(
    String scanId,
    String kind,
    DuplicateGroup group,
    DateTime now,
  ) {
    return <String, Object?>{
      'scan_id': scanId,
      'kind': kind,
      'signature': group.signature,
      'asset_ids': group.assetIds.join(','),
      'total_size': group.totalSize,
      'photo_count': group.assetIds.length,
      'created_at': now.millisecondsSinceEpoch,
    };
  }

  DuplicateGroup _fromMap(Map<String, Object?> map) {
    final String rawIds = map['asset_ids'] as String? ?? '';
    final List<String> ids = rawIds
        .split(',')
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .toList(growable: false);
    final int created = (map['created_at'] as num?)?.toInt() ?? 0;
    return DuplicateGroup(
      id: (map['id'] as num?)?.toInt(),
      kind: map['kind'] as String? ?? 'exact',
      signature: map['signature'] as String? ?? '',
      assetIds: ids,
      totalSize: (map['total_size'] as num?)?.toInt() ?? 0,
      createdAt: created == 0
          ? null
          : DateTime.fromMillisecondsSinceEpoch(created),
    );
  }

  int _hamming(int a, int b) {
    int value = a ^ b;
    int count = 0;
    while (value != 0) {
      count += value & 1;
      value >>= 1;
    }
    return count;
  }
}

class _HashedAsset {
  const _HashedAsset({
    required this.asset,
    required this.sha256,
    required this.dhash,
    required this.fileSize,
  });

  final AssetEntity asset;
  final String sha256;
  final int? dhash;
  final int fileSize;
}

class _UnionFind {
  _UnionFind(this.size) : _parent = List<int>.generate(size, (int i) => i);

  final int size;
  final List<int> _parent;

  int find(int value) {
    int root = value;
    while (_parent[root] != root) {
      root = _parent[root];
    }
    while (_parent[value] != root) {
      final int next = _parent[value];
      _parent[value] = root;
      value = next;
    }
    return root;
  }

  void union(int a, int b) {
    final int rootA = find(a);
    final int rootB = find(b);
    if (rootA != rootB) {
      _parent[rootA] = rootB;
    }
  }
}
