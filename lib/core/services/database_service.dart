import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../shared/models/ai_models.dart';
import '../../shared/models/app_category.dart';
import '../../shared/models/photo_record.dart';
import '../constants/app_constants.dart';

class DatabaseService {
  DatabaseService._();

  static final DatabaseService instance = DatabaseService._();

  Database? _database;
  Future<Database>? _opening;

  Future<Database> get database {
    final Database? existing = _database;
    if (existing != null) {
      return Future<Database>.value(existing);
    }
    return _opening ??= _open();
  }

  Future<Database> _open() async {
    final String base = await getDatabasesPath();
    final String path = p.join(base, AppConstants.databaseName);
    final Database db = await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onConfigure: (Database db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
    _database = db;
    return db;
  }

  Future<void> initialize() async {
    await database;
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE photos (
        asset_id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        width INTEGER NOT NULL DEFAULT 0,
        height INTEGER NOT NULL DEFAULT 0,
        mime_type TEXT,
        file_size INTEGER NOT NULL DEFAULT 0,
        create_date INTEGER NOT NULL,
        modified_date INTEGER NOT NULL,
        latitude REAL,
        longitude REAL,
        category TEXT NOT NULL DEFAULT 'other',
        primary_label TEXT,
        subcategory TEXT,
        confidence REAL,
        labels_json TEXT,
        analyzed_at INTEGER,
        organized_at INTEGER,
        camera_make TEXT,
        camera_model TEXT,
        analysis_version INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_photos_category ON photos(category)',
    );
    await db.execute(
      'CREATE INDEX idx_photos_create_date ON photos(create_date)',
    );
    await db.execute(
      'CREATE INDEX idx_photos_analyzed_at ON photos(analyzed_at)',
    );
    await db.execute('''
      CREATE TABLE favorites (
        asset_id TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE ai_results (
        key TEXT PRIMARY KEY,
        asset_id TEXT,
        file_path TEXT,
        primary_label TEXT NOT NULL,
        category TEXT NOT NULL,
        subcategory TEXT NOT NULL,
        confidence REAL NOT NULL,
        description TEXT NOT NULL,
        suggested_filename TEXT NOT NULL,
        labels_json TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE duplicate_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scan_id TEXT NOT NULL,
        kind TEXT NOT NULL,
        signature TEXT NOT NULL,
        asset_ids TEXT NOT NULL,
        total_size INTEGER NOT NULL DEFAULT 0,
        photo_count INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_duplicate_scan ON duplicate_groups(scan_id)',
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Version 1 is the initial schema. Future migrations belong here.
  }

  Future<List<PhotoRecord>> allPhotos() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'photos',
      orderBy: 'create_date DESC',
    );
    return rows.map(PhotoRecord.fromMap).toList(growable: false);
  }

  Future<PhotoRecord?> photoById(String assetId) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'photos',
      where: 'asset_id = ?',
      whereArgs: <Object?>[assetId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return PhotoRecord.fromMap(rows.first);
  }

  Future<int> photoCount() async {
    final Database db = await database;
    final List<Map<String, Object?>> result =
        await db.rawQuery('SELECT COUNT(*) AS count FROM photos');
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  Future<Map<AppCategory, int>> categoryCounts() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT category, COUNT(*) AS count FROM photos '
      'WHERE analyzed_at IS NOT NULL GROUP BY category',
    );
    final Map<AppCategory, int> result = <AppCategory, int>{
      for (final AppCategory category in AppCategory.values) category: 0,
    };
    for (final Map<String, Object?> row in rows) {
      final AppCategory category = AppCategory.parse(row['category'] as String?);
      result[category] = (row['count'] as num?)?.toInt() ?? 0;
    }
    return result;
  }

  Future<int> analyzedCount() async {
    final Database db = await database;
    final List<Map<String, Object?>> result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM photos WHERE analyzed_at IS NOT NULL',
    );
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  Future<int> pendingAnalysisCount() async {
    final Database db = await database;
    final List<Map<String, Object?>> result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM photos '
      'WHERE analyzed_at IS NULL '
      'OR analysis_version < ? '
      'OR analyzed_at < modified_date',
      <Object?>[AppConstants.currentAnalysisVersion],
    );
    return (result.first['count'] as num?)?.toInt() ?? 0;
  }

  Future<List<PhotoRecord>> pendingAnalysis({required int limit}) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'photos',
      where: 'analyzed_at IS NULL '
          'OR analysis_version < ? '
          'OR analyzed_at < modified_date',
      whereArgs: <Object?>[AppConstants.currentAnalysisVersion],
      orderBy: 'create_date DESC',
      limit: limit,
    );
    return rows.map(PhotoRecord.fromMap).toList(growable: false);
  }

  Future<void> syncPhotoRecords(
    List<PhotoRecord> incoming, {
    required bool pruneMissing,
  }) async {
    final Database db = await database;
    final List<PhotoRecord> existing = await allPhotos();
    final Map<String, PhotoRecord> existingById = <String, PhotoRecord>{
      for (final PhotoRecord record in existing) record.assetId: record,
    };

    await db.transaction((Transaction txn) async {
      for (final PhotoRecord record in incoming) {
        final PhotoRecord? old = existingById[record.assetId];
        if (old == null) {
          await txn.insert(
            'photos',
            record.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          continue;
        }

        final bool changed =
            old.modifiedDate.millisecondsSinceEpoch !=
                record.modifiedDate.millisecondsSinceEpoch;
        final Map<String, Object?> values = record.toMap();
        if (changed) {
          values['analyzed_at'] = null;
          values['category'] = AppCategory.other.name;
          values['primary_label'] = null;
          values['subcategory'] = null;
          values['confidence'] = null;
          values['labels_json'] = null;
          values['analysis_version'] = 0;
        } else {
          values['analyzed_at'] =
              old.analyzedAt?.millisecondsSinceEpoch;
          values['category'] = old.category.name;
          values['primary_label'] = old.primaryLabel;
          values['subcategory'] = old.subcategory;
          values['confidence'] = old.confidence;
          values['labels_json'] = old.labelsJson;
          values['analysis_version'] = old.analysisVersion;
          values['camera_make'] = old.cameraMake;
          values['camera_model'] = old.cameraModel;
          values['organized_at'] = old.organizedAt?.millisecondsSinceEpoch;
        }
        values['asset_id'] = old.assetId;
        await txn.update(
          'photos',
          values,
          where: 'asset_id = ?',
          whereArgs: <Object?>[old.assetId],
        );
      }

      if (pruneMissing) {
        final Set<String> incomingIds = incoming
            .map((PhotoRecord record) => record.assetId)
            .toSet();
        final List<String> stale = existingById.keys
            .where((String id) => !incomingIds.contains(id))
            .toList(growable: false);
        for (int start = 0; start < stale.length; start += 400) {
          final int end = start + 400 < stale.length ? start + 400 : stale.length;
          final List<String> chunk = stale.sublist(start, end);
          final String placeholders =
              List<String>.filled(chunk.length, '?').join(',');
          await txn.delete(
            'photos',
            where: 'asset_id IN ($placeholders)',
            whereArgs: chunk,
          );
          await txn.delete(
            'favorites',
            where: 'asset_id IN ($placeholders)',
            whereArgs: chunk,
          );
        }
      }
    });
  }

  Future<void> saveAnalysis({
    required String assetId,
    required AiIdentification identification,
    required AiResultRecord result,
    String? cameraMake,
    String? cameraModel,
  }) async {
    final Database db = await database;
    final int now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((Transaction txn) async {
      await txn.update(
        'photos',
        <String, Object?>{
          'category': identification.category.name,
          'primary_label': identification.primaryLabel,
          'subcategory': identification.subcategory,
          'confidence': identification.confidence,
          'labels_json': LabelScore.toJson(identification.labels),
          'analyzed_at': now,
          'organized_at': now,
          'analysis_version': AppConstants.currentAnalysisVersion,
          if (cameraMake != null) 'camera_make': cameraMake,
          if (cameraModel != null) 'camera_model': cameraModel,
        },
        where: 'asset_id = ?',
        whereArgs: <Object?>[assetId],
      );
      await txn.insert(
        'ai_results',
        result.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> updateCameraMetadata(
    String assetId, {
    String? make,
    String? model,
  }) async {
    if ((make == null || make.isEmpty) && (model == null || model.isEmpty)) {
      return;
    }
    final Database db = await database;
    await db.update(
      'photos',
      <String, Object?>{
        if (make != null && make.isNotEmpty) 'camera_make': make,
        if (model != null && model.isNotEmpty) 'camera_model': model,
      },
      where: 'asset_id = ?',
      whereArgs: <Object?>[assetId],
    );
  }

  Future<void> updateFileSizes(Map<String, int> sizes) async {
    if (sizes.isEmpty) {
      return;
    }
    final Database db = await database;
    await db.transaction((Transaction txn) async {
      for (final MapEntry<String, int> entry in sizes.entries) {
        await txn.update(
          'photos',
          <String, Object?>{'file_size': entry.value},
          where: 'asset_id = ?',
          whereArgs: <Object?>[entry.key],
        );
      }
    });
  }

  Future<void> saveAiResult(AiResultRecord result) async {
    final Database db = await database;
    await db.insert(
      'ai_results',
      result.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<AiResultRecord?> aiResultForAsset(String assetId) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'ai_results',
      where: 'asset_id = ?',
      whereArgs: <Object?>[assetId],
      orderBy: 'created_at DESC',
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return AiResultRecord.fromMap(rows.first);
  }

  Future<List<PhotoRecord>> recentlyAnalyzed({int limit = 12}) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'photos',
      where: 'analyzed_at IS NOT NULL',
      orderBy: 'analyzed_at DESC',
      limit: limit,
    );
    return rows.map(PhotoRecord.fromMap).toList(growable: false);
  }

  Future<Set<String>> favoriteIds() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows =
        await db.query('favorites', orderBy: 'created_at DESC');
    return rows
        .map((Map<String, Object?> row) => row['asset_id'] as String?)
        .whereType<String>()
        .toSet();
  }

  Future<List<String>> orderedFavoriteIds() async {
    final Database db = await database;
    final List<Map<String, Object?>> rows =
        await db.query('favorites', orderBy: 'created_at DESC');
    return rows
        .map((Map<String, Object?> row) => row['asset_id'] as String?)
        .whereType<String>()
        .toList(growable: false);
  }

  Future<bool> isFavorite(String assetId) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'favorites',
      where: 'asset_id = ?',
      whereArgs: <Object?>[assetId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<bool> toggleFavorite(String assetId) async {
    final Database db = await database;
    final bool current = await isFavorite(assetId);
    if (current) {
      await db.delete(
        'favorites',
        where: 'asset_id = ?',
        whereArgs: <Object?>[assetId],
      );
      return false;
    }
    await db.insert(
      'favorites',
      <String, Object?>{
        'asset_id': assetId,
        'created_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    return true;
  }

  Future<void> removeFavorite(String assetId) async {
    final Database db = await database;
    await db.delete(
      'favorites',
      where: 'asset_id = ?',
      whereArgs: <Object?>[assetId],
    );
  }

  Future<void> deletePhotoRecords(List<String> assetIds) async {
    if (assetIds.isEmpty) {
      return;
    }
    final Database db = await database;
    await db.transaction((Transaction txn) async {
      for (int start = 0; start < assetIds.length; start += 400) {
        final int end = start + 400 < assetIds.length ? start + 400 : assetIds.length;
        final List<String> chunk = assetIds.sublist(start, end);
        final String placeholders =
            List<String>.filled(chunk.length, '?').join(',');
        await txn.delete(
          'photos',
          where: 'asset_id IN ($placeholders)',
          whereArgs: chunk,
        );
        await txn.delete(
          'favorites',
          where: 'asset_id IN ($placeholders)',
          whereArgs: chunk,
        );
        await txn.delete(
          'ai_results',
          where: 'asset_id IN ($placeholders)',
          whereArgs: chunk,
        );
      }
    });
  }

  Future<void> saveDuplicateGroups({
    required String scanId,
    required List<Map<String, Object?>> groups,
  }) async {
    final Database db = await database;
    await db.transaction((Transaction txn) async {
      await txn.delete(
        'duplicate_groups',
        where: 'scan_id != ?',
        whereArgs: <Object?>[scanId],
      );
      await txn.delete(
        'duplicate_groups',
        where: 'scan_id = ?',
        whereArgs: <Object?>[scanId],
      );
      for (final Map<String, Object?> group in groups) {
        await txn.insert('duplicate_groups', group);
      }
    });
  }

  Future<List<Map<String, Object?>>> latestDuplicateGroups() async {
    final Database db = await database;
    final List<Map<String, Object?>> scans = await db.rawQuery(
      'SELECT scan_id, MAX(created_at) AS created_at '
      'FROM duplicate_groups GROUP BY scan_id '
      'ORDER BY created_at DESC LIMIT 1',
    );
    if (scans.isEmpty) {
      return const <Map<String, Object?>>[];
    }
    final String scanId = scans.first['scan_id'] as String;
    return db.query(
      'duplicate_groups',
      where: 'scan_id = ?',
      whereArgs: <Object?>[scanId],
      orderBy: 'total_size DESC',
    );
  }

  Future<void> clearDuplicateGroups() async {
    final Database db = await database;
    await db.delete('duplicate_groups');
  }

  Future<void> clearAiData() async {
    final Database db = await database;
    await db.transaction((Transaction txn) async {
      await txn.delete('ai_results');
      await txn.update(
        'photos',
        <String, Object?>{
          'category': AppCategory.other.name,
          'primary_label': null,
          'subcategory': null,
          'confidence': null,
          'labels_json': null,
          'analyzed_at': null,
          'organized_at': null,
          'analysis_version': 0,
        },
      );
    });
  }

  Future<String?> getSetting(String key) async {
    final Database db = await database;
    final List<Map<String, Object?>> rows = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: <Object?>[key],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String value) async {
    final Database db = await database;
    await db.insert(
      'settings',
      <String, Object?>{'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
    _opening = null;
  }
}
