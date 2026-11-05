import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../core/constants/app_constants.dart';
import '../../core/services/ai_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/metadata_service.dart';
import '../../core/services/photo_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/utilities/formatters.dart';
import '../../shared/models/ai_models.dart';
import '../../shared/models/app_category.dart';
import '../../shared/models/photo_record.dart';
import 'service_providers.dart';
import 'settings_provider.dart';

final NotifierProvider<LibraryController, LibraryState> libraryProvider =
    NotifierProvider<LibraryController, LibraryState>(LibraryController.new);

class LibraryState {
  const LibraryState({
    required this.permission,
    required this.isInitialized,
    required this.isLoading,
    required this.isRefreshing,
    required this.isIndexing,
    required this.isAnalyzing,
    required this.autoScanCancelled,
    required this.photos,
    required this.records,
    required this.favoriteIds,
    required this.categoryCounts,
    required this.analyzedCount,
    required this.pendingCount,
    required this.sessionTotal,
    required this.sessionProcessed,
    required this.loadedAssets,
    required this.totalAssets,
    required this.totalBytes,
    required this.lastScanAt,
    required this.statusMessage,
    required this.error,
    required this.storageInfo,
  });

  factory LibraryState.initial() {
    return LibraryState(
      permission: PermissionState.notDetermined,
      isInitialized: false,
      isLoading: true,
      isRefreshing: false,
      isIndexing: false,
      isAnalyzing: false,
      autoScanCancelled: false,
      photos: const <AssetEntity>[],
      records: const <String, PhotoRecord>{},
      favoriteIds: const <String>{},
      categoryCounts: <AppCategory, int>{
        for (final AppCategory category in AppCategory.values) category: 0,
      },
      analyzedCount: 0,
      pendingCount: 0,
      sessionTotal: 0,
      sessionProcessed: 0,
      loadedAssets: 0,
      totalAssets: 0,
      totalBytes: 0,
      lastScanAt: null,
      statusMessage: null,
      error: null,
      storageInfo: null,
    );
  }

  final PermissionState permission;
  final bool isInitialized;
  final bool isLoading;
  final bool isRefreshing;
  final bool isIndexing;
  final bool isAnalyzing;
  final bool autoScanCancelled;
  final List<AssetEntity> photos;
  final Map<String, PhotoRecord> records;
  final Set<String> favoriteIds;
  final Map<AppCategory, int> categoryCounts;
  final int analyzedCount;
  final int pendingCount;
  final int sessionTotal;
  final int sessionProcessed;
  final int loadedAssets;
  final int totalAssets;
  final int totalBytes;
  final DateTime? lastScanAt;
  final String? statusMessage;
  final String? error;
  final StorageInfo? storageInfo;

  bool get hasAccess => permission.hasAccess;
  bool get isLimited => permission == PermissionState.limited;
  bool get permissionDenied =>
      permission == PermissionState.denied ||
      permission == PermissionState.restricted;
  int get totalPhotos => photos.length;

  double get analysisProgress {
    if (analyzedCount <= 0) {
      return 0;
    }
    return (analyzedCount / (analyzedCount + pendingCount))
        .clamp(0, 1)
        .toDouble();
  }

  PhotoRecord? recordFor(String assetId) => records[assetId];

  bool isFavorite(String assetId) => favoriteIds.contains(assetId);

  List<AssetEntity> photosForCategory(AppCategory category) {
    return photos
        .where(
          (AssetEntity asset) =>
              records[asset.id]?.category == category &&
              records[asset.id]?.isAnalyzed == true,
        )
        .toList(growable: false);
  }

  List<AssetEntity> photosForSubcategory(String subcategory) {
    return photos
        .where(
          (AssetEntity asset) =>
              records[asset.id]?.subcategory == subcategory &&
              records[asset.id]?.isAnalyzed == true,
        )
        .toList(growable: false);
  }

  List<AssetEntity> get favoritePhotos => photos
      .where((AssetEntity asset) => favoriteIds.contains(asset.id))
      .toList(growable: false);

  List<AssetEntity> recentlyOrganized({int limit = 10}) {
    final List<AssetEntity> organized = photos
        .where((AssetEntity asset) => records[asset.id]?.organizedAt != null)
        .toList();
    organized.sort((AssetEntity a, AssetEntity b) {
      final DateTime? left = records[a.id]?.organizedAt;
      final DateTime? right = records[b.id]?.organizedAt;
      if (left == null || right == null) {
        return 0;
      }
      return right.compareTo(left);
    });
    return organized.take(limit).toList(growable: false);
  }

  Map<String, int> subcategoryCounts(AppCategory category) {
    final Map<String, int> counts = <String, int>{};
    for (final PhotoRecord record in records.values) {
      if (record.category != category || record.subcategory == null) {
        continue;
      }
      final String key = record.subcategory!;
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final List<MapEntry<String, int>> sorted = counts.entries.toList()
      ..sort(
        (MapEntry<String, int> a, MapEntry<String, int> b) =>
            b.value.compareTo(a.value),
      );
    return <String, int>{
      for (final MapEntry<String, int> entry in sorted) entry.key: entry.value,
    };
  }

  LibraryState copyWith({
    PermissionState? permission,
    bool? isInitialized,
    bool? isLoading,
    bool? isRefreshing,
    bool? isIndexing,
    bool? isAnalyzing,
    bool? autoScanCancelled,
    List<AssetEntity>? photos,
    Map<String, PhotoRecord>? records,
    Set<String>? favoriteIds,
    Map<AppCategory, int>? categoryCounts,
    int? analyzedCount,
    int? pendingCount,
    int? sessionTotal,
    int? sessionProcessed,
    int? loadedAssets,
    int? totalAssets,
    int? totalBytes,
    DateTime? lastScanAt,
    String? statusMessage,
    bool clearStatus = false,
    String? error,
    bool clearError = false,
    StorageInfo? storageInfo,
  }) {
    return LibraryState(
      permission: permission ?? this.permission,
      isInitialized: isInitialized ?? this.isInitialized,
      isLoading: isLoading ?? this.isLoading,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isIndexing: isIndexing ?? this.isIndexing,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      autoScanCancelled: autoScanCancelled ?? this.autoScanCancelled,
      photos: photos ?? this.photos,
      records: records ?? this.records,
      favoriteIds: favoriteIds ?? this.favoriteIds,
      categoryCounts: categoryCounts ?? this.categoryCounts,
      analyzedCount: analyzedCount ?? this.analyzedCount,
      pendingCount: pendingCount ?? this.pendingCount,
      sessionTotal: sessionTotal ?? this.sessionTotal,
      sessionProcessed: sessionProcessed ?? this.sessionProcessed,
      loadedAssets: loadedAssets ?? this.loadedAssets,
      totalAssets: totalAssets ?? this.totalAssets,
      totalBytes: totalBytes ?? this.totalBytes,
      lastScanAt: lastScanAt ?? this.lastScanAt,
      statusMessage:
          clearStatus ? null : (statusMessage ?? this.statusMessage),
      error: clearError ? null : (error ?? this.error),
      storageInfo: storageInfo ?? this.storageInfo,
    );
  }
}

class LibraryController extends Notifier<LibraryState> {
  late final DatabaseService _db = ref.read(databaseProvider);
  late final PhotoService _photo = ref.read(photoServiceProvider);
  late final MetadataService _metadata = ref.read(metadataServiceProvider);
  late final AiService _ai = ref.read(aiServiceProvider);

  Timer? _changeDebounce;
  Map<String, AssetEntity> _assetsById = const <String, AssetEntity>{};
  AppSettings _settings = AppSettings.defaults;
  bool _initialized = false;
  bool _initializing = false;
  bool _refreshing = false;
  bool _analyzing = false;
  bool _backgroundRunning = false;
  bool _listeningForChanges = false;
  bool _appActive = true;
  bool _cancelAnalysis = false;
  bool _disposed = false;

  @override
  LibraryState build() {
    ref.onDispose(_dispose);
    ref.listen<AsyncValue<AppSettings>>(settingsProvider,
        (AsyncValue<AppSettings>? previous, AsyncValue<AppSettings> next) {
      final AppSettings? settings = next.valueOrNull;
      if (settings == null) {
        return;
      }
      _settings = settings;
      if (!settings.autoAnalyze && _analyzing) {
        _cancelAnalysis = true;
      } else if (settings.autoAnalyze &&
          _initialized &&
          state.hasAccess &&
          state.pendingCount > 0 &&
          !_analyzing) {
        unawaited(analyzePending());
      }
    });
    return LibraryState.initial();
  }

  void _setState(LibraryState next) {
    if (!_disposed) {
      state = next;
    }
  }

  Future<void> initialize() async {
    if (_initialized || _initializing || _disposed) {
      return;
    }
    _initializing = true;
    _setState(
      state.copyWith(isLoading: true, clearError: true, clearStatus: true),
    );
    try {
      await _db.initialize();
      final AppSettings settings = await ref.read(settingsProvider.future);
      _settings = settings;
      final StorageInfo? storage =
          await ref.read(storageServiceProvider).deviceStorage();

      final PermissionState permission = await _photo.requestPermission();
      if (!permission.hasAccess) {
        _setState(
          LibraryState.initial().copyWith(
            permission: permission,
            isInitialized: true,
            isLoading: false,
            storageInfo: storage,
            statusMessage: 'Gallery access is needed to organize your photos.',
          ),
        );
        _initialized = true;
        return;
      }

      _listenForGalleryChanges();
      final LibraryState loaded = await _loadLibrary(
        permission,
        storage: storage,
      );
      _setState(
        loaded.copyWith(
          isInitialized: true,
          isLoading: false,
          isRefreshing: false,
          lastScanAt: DateTime.now(),
          clearError: true,
        ),
      );
      _initialized = true;
      _startBackgroundWork();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Library initialization failed: $error');
      }
      _setState(
        state.copyWith(
          isInitialized: false,
          isLoading: false,
          error: 'Photo Organizer could not open your gallery. '
              'Check storage permissions and try again.',
        ),
      );
    } finally {
      _initializing = false;
    }
  }

  Future<LibraryState> _loadLibrary(
    PermissionState permission, {
    StorageInfo? storage,
  }) async {
    final List<AssetEntity> assets = await _photo.loadImageAssets(
      onProgress: (int loaded, int total) {
        _setState(
          state.copyWith(
            loadedAssets: loaded,
            totalAssets: total,
            statusMessage: 'Reading your gallery…',
          ),
        );
      },
    );

    final Map<String, AssetEntity> byId = <String, AssetEntity>{
      for (final AssetEntity asset in assets) asset.id: asset,
    };
    final List<PhotoRecord> incoming = assets
        .map(_recordFromAsset)
        .toList(growable: false);
    await _db.syncPhotoRecords(
      incoming,
      pruneMissing: permission == PermissionState.authorized,
    );

    final List<PhotoRecord> records = await _db.allPhotos();
    final Map<String, PhotoRecord> byRecord = <String, PhotoRecord>{
      for (final PhotoRecord record in records) record.assetId: record,
    };
    final Set<String> favorites = await _db.favoriteIds();
    final Map<AppCategory, int> counts = await _db.categoryCounts();
    final int analyzed = await _db.analyzedCount();
    final int pending = await _db.pendingAnalysisCount();
    final int totalBytes = records.fold<int>(
      0,
      (int sum, PhotoRecord record) => sum + record.fileSize,
    );

    _assetsById = byId;
    return state.copyWith(
      permission: permission,
      photos: assets,
      records: byRecord,
      favoriteIds: favorites,
      categoryCounts: counts,
      analyzedCount: analyzed,
      pendingCount: pending,
      loadedAssets: assets.length,
      totalAssets: assets.length,
      totalBytes: totalBytes,
      storageInfo: storage,
      statusMessage: null,
      clearStatus: true,
      error: null,
      clearError: true,
    );
  }

  PhotoRecord _recordFromAsset(AssetEntity asset) {
    final String rawTitle = asset.title?.trim() ?? '';
    return PhotoRecord(
      assetId: asset.id,
      title: rawTitle.isEmpty ? 'Photo' : rawTitle,
      width: asset.width,
      height: asset.height,
      mimeType: asset.mimeType,
      fileSize: 0,
      createDate: asset.createDateTime,
      modifiedDate: asset.modifiedDateTime,
      latitude: asset.latitude,
      longitude: asset.longitude,
      category: AppCategory.other,
      primaryLabel: null,
      subcategory: null,
      confidence: null,
      labelsJson: null,
      analyzedAt: null,
      organizedAt: null,
      cameraMake: null,
      cameraModel: null,
      analysisVersion: 0,
    );
  }

  Future<void> refresh({bool requestPermission = false}) async {
    if (!_initialized) {
      await initialize();
      return;
    }
    if (_refreshing || _disposed) {
      return;
    }
    _refreshing = true;
    _setState(
      state.copyWith(
        isRefreshing: true,
        clearError: true,
        statusMessage: 'Checking for new photos…',
      ),
    );
    try {
      final PermissionState permission = requestPermission
          ? await _photo.requestPermission()
          : await _photo.currentPermission();
      if (!permission.hasAccess) {
        _assetsById = const <String, AssetEntity>{};
        _setState(
          state.copyWith(
            permission: permission,
            photos: const <AssetEntity>[],
            records: const <String, PhotoRecord>{},
            favoriteIds: const <String>{},
            isRefreshing: false,
            statusMessage:
                'Gallery access is needed to organize your photos.',
            clearError: true,
          ),
        );
        return;
      }
      _listenForGalleryChanges();
      final LibraryState loaded = await _loadLibrary(
        permission,
        storage: state.storageInfo,
      );
      _setState(
        loaded.copyWith(
          isRefreshing: false,
          lastScanAt: DateTime.now(),
          clearStatus: true,
          clearError: true,
        ),
      );
      _startBackgroundWork();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Gallery refresh failed: $error');
      }
      _setState(
        state.copyWith(
          isRefreshing: false,
          error: 'Could not refresh your gallery. Try again.',
        ),
      );
    } finally {
      _refreshing = false;
    }
  }

  Future<void> grantAccess() async {
    final PermissionState permission = await _photo.requestPermission();
    if (!permission.hasAccess) {
      _setState(
        state.copyWith(
          permission: permission,
          isInitialized: true,
          isLoading: false,
        ),
      );
      return;
    }
    if (!_initialized) {
      _initialized = true;
      _listenForGalleryChanges();
      final LibraryState loaded = await _loadLibrary(permission);
      _setState(
        loaded.copyWith(
          isInitialized: true,
          isLoading: false,
          isRefreshing: false,
          lastScanAt: DateTime.now(),
        ),
      );
      _startBackgroundWork();
    } else {
      await refresh(requestPermission: true);
    }
  }

  Future<void> openSystemSettings() => _photo.openSettings();

  Future<void> manageLimitedAccess() async {
    await _photo.presentLimitedPicker();
    await refresh();
  }

  Future<void> retry() async {
    _initialized = false;
    await initialize();
  }

  void _listenForGalleryChanges() {
    if (_listeningForChanges || _disposed) {
      return;
    }
    _listeningForChanges = true;
    PhotoManager.addChangeCallback(_onPhotoChange);
    PhotoManager.startChangeNotify();
  }

  void _onPhotoChange(MethodCall call) {
    if (_disposed || !_initialized) {
      return;
    }
    _changeDebounce?.cancel();
    _changeDebounce = Timer(const Duration(milliseconds: 1800), () {
      unawaited(refresh());
    });
  }

  void onAppPaused() {
    _appActive = false;
  }

  void onAppResumed() {
    if (!_appActive) {
      _appActive = true;
    }
    if (!_initialized || _disposed) {
      return;
    }
    _changeDebounce?.cancel();
    _changeDebounce = Timer(const Duration(milliseconds: 700), () {
      unawaited(refresh());
    });
    if (!_analyzing &&
        state.hasAccess &&
        state.pendingCount > 0 &&
        _settings.autoAnalyze) {
      unawaited(analyzePending());
    }
  }

  void _startBackgroundWork() {
    if (_backgroundRunning || _disposed) {
      return;
    }
    unawaited(_runBackgroundWork());
  }

  Future<void> _runBackgroundWork() async {
    if (_backgroundRunning) {
      return;
    }
    _backgroundRunning = true;
    try {
      await _enrichFileSizes();
      if (_settings.autoAnalyze &&
          state.isInitialized &&
          state.hasAccess &&
          state.pendingCount > 0) {
        await analyzePending();
      }
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Background library work failed: $error');
      }
    } finally {
      _backgroundRunning = false;
    }
  }

  Future<void> _enrichFileSizes() async {
    final List<PhotoRecord> missing = state.records.values
        .where((PhotoRecord record) => record.fileSize <= 0)
        .toList(growable: false);
    if (missing.isEmpty) {
      return;
    }
    _setState(
      state.copyWith(
        isIndexing: true,
        statusMessage: 'Measuring photo library…',
      ),
    );

    final Map<String, int> pendingSizes = <String, int>{};
    int done = 0;
    final Map<String, PhotoRecord> localRecords = Map<String, PhotoRecord>.of(
      state.records,
    );
    for (final PhotoRecord record in missing) {
      if (_disposed) {
        return;
      }
      final AssetEntity? asset = _assetsById[record.assetId];
      if (asset == null) {
        continue;
      }
      final int size = await _photo.fileSize(asset);
      if (size > 0) {
        pendingSizes[record.assetId] = size;
        localRecords[record.assetId] = record.copyWith(fileSize: size);
      }
      done++;
      if (pendingSizes.length >= 30 || done == missing.length) {
        await _db.updateFileSizes(pendingSizes);
        pendingSizes.clear();
        if (_disposed) {
          return;
        }
        _setState(
          state.copyWith(
            records: Map<String, PhotoRecord>.of(localRecords),
            totalBytes: localRecords.values.fold<int>(
              0,
              (int sum, PhotoRecord item) => sum + item.fileSize,
            ),
            isIndexing: true,
            statusMessage: done < missing.length
                ? 'Measuring photo library… $done/${missing.length}'
                : 'Photo details ready',
          ),
        );
      }
    }
    _setState(
      state.copyWith(
        records: localRecords,
        isIndexing: false,
        clearStatus: true,
      ),
    );
  }

  Future<void> analyzePending({bool force = false}) async {
    if (_disposed ||
        !_initialized ||
        !state.hasAccess ||
        _analyzing) {
      return;
    }
    if (!force && !_settings.autoAnalyze) {
      return;
    }
    int pending = await _db.pendingAnalysisCount();
    if (pending == 0) {
      final Map<AppCategory, int> counts = await _db.categoryCounts();
      _setState(state.copyWith(pendingCount: 0, categoryCounts: counts));
      return;
    }
    final List<PhotoRecord> batch = await _db.pendingAnalysis(
      limit: _settings.sessionLimit,
    );
    if (batch.isEmpty) {
      return;
    }
    _cancelAnalysis = false;
    _analyzing = true;
    _setState(
      state.copyWith(
        isAnalyzing: true,
        autoScanCancelled: false,
        sessionTotal: batch.length,
        sessionProcessed: 0,
        pendingCount: pending,
        statusMessage: 'Organizing photos on device…',
        clearError: true,
      ),
    );

    int processed = 0;
    int failures = 0;
    try {
      for (final PhotoRecord record in batch) {
        if (_disposed || _cancelAnalysis || !_appActive) {
          break;
        }
        final AssetEntity? asset = _assetsById[record.assetId];
        if (asset == null) {
          failures++;
          continue;
        }
        try {
          final Uint8List? bytes = await _photo.thumbnail(
            asset,
            size: AppConstants.gridThumbnailSize,
          );
          if (bytes == null) {
            failures++;
            continue;
          }
          final AiIdentification result = await _ai.classifyBytes(
            bytes,
            confidenceThreshold: _settings.confidenceThreshold,
            extension: normalizedExtension(record.title, record.mimeType),
          );

          String? cameraMake = record.cameraMake;
          String? cameraModel = record.cameraModel;
          if (_settings.allowMetadata &&
              (cameraMake == null || cameraModel == null)) {
            final CameraMetadata? camera =
                await _metadata.readCameraOnly(asset);
            cameraMake = camera?.make ?? cameraMake;
            cameraModel = camera?.model ?? cameraModel;
          }

          final DateTime now = DateTime.now();
          final AiResultRecord stored = AiResultRecord(
            key: 'asset:${record.assetId}',
            assetId: record.assetId,
            filePath: null,
            primaryLabel: result.primaryLabel,
            category: result.category,
            subcategory: result.subcategory,
            confidence: result.confidence,
            description: result.description,
            suggestedFilename: result.suggestedFilename,
            labels: result.labels,
            createdAt: now,
          );
          await _db.saveAnalysis(
            assetId: record.assetId,
            identification: result,
            result: stored,
            cameraMake: cameraMake,
            cameraModel: cameraModel,
          );

          processed++;
          final Map<String, PhotoRecord> updatedRecords =
              Map<String, PhotoRecord>.of(state.records);
          updatedRecords[record.assetId] = record.copyWith(
            category: result.category,
            primaryLabel: result.primaryLabel,
            subcategory: result.subcategory,
            confidence: result.confidence,
            labelsJson: LabelScore.toJson(result.labels),
            analyzedAt: now,
            organizedAt: now,
            cameraMake: cameraMake,
            cameraModel: cameraModel,
            analysisVersion: AppConstants.currentAnalysisVersion,
          );
          _setState(
            state.copyWith(
              records: updatedRecords,
              sessionProcessed: processed,
              analyzedCount: state.analyzedCount + 1,
              pendingCount: (state.pendingCount - 1).clamp(0, 999999999).toInt(),
              statusMessage: 'Organizing photos on device… $processed/${batch.length}',
            ),
          );

          if (processed % 5 == 0) {
            final Map<AppCategory, int> counts = await _db.categoryCounts();
            pending = await _db.pendingAnalysisCount();
            _setState(
              state.copyWith(
                categoryCounts: counts,
                pendingCount: pending,
              ),
            );
          }
        } catch (error) {
          failures++;
          if (kDebugMode) {
            debugPrint('AI analysis failed for ${record.assetId}: $error');
          }
        }
        await Future<void>.delayed(const Duration(milliseconds: 12));
      }
    } finally {
      _analyzing = false;
      if (!_disposed) {
        final Map<AppCategory, int> counts = await _db.categoryCounts();
        final int remaining = await _db.pendingAnalysisCount();
        final int analyzed = await _db.analyzedCount();
        _setState(
          state.copyWith(
            isAnalyzing: false,
            autoScanCancelled: _cancelAnalysis && remaining > 0,
            categoryCounts: counts,
            pendingCount: remaining,
            analyzedCount: analyzed,
            sessionProcessed: processed,
            statusMessage: _statusAfterAnalysis(
              processed: processed,
              failures: failures,
              remaining: remaining,
            ),
          ),
        );
      }
    }
  }

  String _statusAfterAnalysis({
    required int processed,
    required int failures,
    required int remaining,
  }) {
    if (_cancelAnalysis && remaining > 0) {
      return 'AI scan paused. Your progress is saved.';
    }
    if (processed == 0 && remaining > 0) {
      return 'Some photos could not be analyzed. You can retry.';
    }
    if (remaining > 0) {
      return '$processed photos organized. $remaining remaining.';
    }
    if (failures > 0) {
      return 'AI scan finished. $failures photos were skipped.';
    }
    return 'All photos are organized.';
  }

  void pauseAnalysis() {
    if (_analyzing) {
      _cancelAnalysis = true;
      _setState(
        state.copyWith(
          autoScanCancelled: true,
          statusMessage: 'Pausing after this photo…',
        ),
      );
    }
  }

  Future<bool> toggleFavorite(String assetId) async {
    final bool isFavorite = await _db.toggleFavorite(assetId);
    final Set<String> favorites = Set<String>.of(state.favoriteIds);
    if (isFavorite) {
      favorites.add(assetId);
    } else {
      favorites.remove(assetId);
    }
    _setState(state.copyWith(favoriteIds: favorites));
    return isFavorite;
  }

  Future<int> deleteAssets(List<AssetEntity> assets) async {
    if (assets.isEmpty) {
      return 0;
    }
    _cancelAnalysis = true;
    final Set<String> before = state.photos
        .map((AssetEntity asset) => asset.id)
        .toSet();
    final List<String> deleted = await _photo.deleteAssets(assets);
    if (deleted.isNotEmpty) {
      await _db.deletePhotoRecords(deleted);
      _photo.clearThumbnailCache();
    }
    await refresh();
    final Set<String> after = state.photos
        .map((AssetEntity asset) => asset.id)
        .toSet();
    return before.difference(after).length;
  }

  /// Saves picked images into the device gallery (Pictures/J-Pix), then
  /// refreshes the library and organizes them automatically.
  Future<int> importPhotos(List<MapEntry<String, Uint8List>> items) async {
    int saved = 0;
    for (final MapEntry<String, Uint8List> item in items) {
      String name = item.key.trim().isEmpty ? 'photo' : item.key.trim();
      if (!RegExp(r'\.(jpe?g|png|webp|heic|heif|gif|bmp)$',
              caseSensitive: false)
          .hasMatch(name)) {
        name = '$name.jpg';
      }
      name = '${DateTime.now().millisecondsSinceEpoch}_$name';
      final AssetEntity? entity = await _photo.saveImageBytes(item.value, name);
      if (entity != null) {
        saved++;
      }
    }
    if (saved > 0) {
      _photo.clearThumbnailCache();
      await refresh();
      unawaited(analyzePending(force: true));
    }
    return saved;
  }

  Future<AiIdentification?> analyzeAsset(AssetEntity asset) async {
    final Uint8List? bytes = await _photo.thumbnail(
      asset,
      size: AppConstants.gridThumbnailSize,
    );
    if (bytes == null) {
      return null;
    }
    final AiIdentification result = await _ai.classifyBytes(
      bytes,
      confidenceThreshold: _settings.confidenceThreshold,
      thorough: true,
      extension: normalizedExtension(asset.title ?? 'photo', asset.mimeType),
    );
    final PhotoRecord? record = state.records[asset.id];
    await saveAiResult(
      identification: result,
      assetId: record == null ? null : asset.id,
      cameraMake: record?.cameraMake,
      cameraModel: record?.cameraModel,
    );
    return result;
  }

  Future<void> saveAiResult({
    required AiIdentification identification,
    String? assetId,
    String? filePath,
    String? cameraMake,
    String? cameraModel,
  }) async {
    final DateTime now = DateTime.now();
    final AiResultRecord stored = AiResultRecord(
      key: assetId != null
          ? 'asset:$assetId'
          : 'file:${filePath ?? now.microsecondsSinceEpoch}',
      assetId: assetId,
      filePath: filePath,
      primaryLabel: identification.primaryLabel,
      category: identification.category,
      subcategory: identification.subcategory,
      confidence: identification.confidence,
      description: identification.description,
      suggestedFilename: identification.suggestedFilename,
      labels: identification.labels,
      createdAt: now,
    );

    final PhotoRecord? record =
        assetId == null ? null : state.records[assetId];
    if (assetId == null || record == null) {
      await _db.saveAiResult(stored);
      return;
    }

    await _db.saveAnalysis(
      assetId: assetId,
      identification: identification,
      result: stored,
      cameraMake: cameraMake,
      cameraModel: cameraModel,
    );
    final Map<String, PhotoRecord> updated = Map<String, PhotoRecord>.of(
      state.records,
    );
    updated[assetId] = record.copyWith(
      category: identification.category,
      primaryLabel: identification.primaryLabel,
      subcategory: identification.subcategory,
      confidence: identification.confidence,
      labelsJson: LabelScore.toJson(identification.labels),
      analyzedAt: now,
      organizedAt: now,
      cameraMake: cameraMake,
      cameraModel: cameraModel,
      analysisVersion: AppConstants.currentAnalysisVersion,
    );
    final Map<AppCategory, int> counts = await _db.categoryCounts();
    final int analyzed = await _db.analyzedCount();
    final int pending = await _db.pendingAnalysisCount();
    _setState(
      state.copyWith(
        records: updated,
        categoryCounts: counts,
        analyzedCount: analyzed,
        pendingCount: pending,
      ),
    );
  }

  Future<void> clearAiResults() async {
    await _db.clearAiData();
    final List<PhotoRecord> records = await _db.allPhotos();
    final Map<String, PhotoRecord> byId = <String, PhotoRecord>{
      for (final PhotoRecord record in records) record.assetId: record,
    };
    final Map<AppCategory, int> counts = await _db.categoryCounts();
    final int analyzed = await _db.analyzedCount();
    final int pending = await _db.pendingAnalysisCount();
    _setState(
      state.copyWith(
        records: byId,
        categoryCounts: counts,
        analyzedCount: analyzed,
        pendingCount: pending,
        statusMessage: 'AI results cleared',
      ),
    );
  }

  Future<void> clearDuplicateGroups() async {
    await _db.clearDuplicateGroups();
  }

  Future<void> runMemoryCleanup() async {
    _photo.clearThumbnailCache();
  }

  void _dispose() {
    _disposed = true;
    _changeDebounce?.cancel();
    if (_listeningForChanges) {
      PhotoManager.removeChangeCallback(_onPhotoChange);
      PhotoManager.stopChangeNotify();
      _listeningForChanges = false;
    }
  }
}
