import '../constants/app_constants.dart';
import 'database_service.dart';

class AppSettings {
  const AppSettings({
    required this.confidenceThreshold,
    required this.autoAnalyze,
    required this.sessionLimit,
    required this.galleryColumns,
    required this.newestFirst,
    required this.allowMetadata,
    required this.scanReminders,
    required this.duplicateReminders,
    this.geminiApiKey = '',
  });

  final double confidenceThreshold;
  final bool autoAnalyze;
  final int sessionLimit;
  final int galleryColumns;
  final bool newestFirst;
  final bool allowMetadata;
  final bool scanReminders;
  final bool duplicateReminders;
  final String geminiApiKey;

  static const AppSettings defaults = AppSettings(
    confidenceThreshold: AppConstants.defaultConfidenceThreshold,
    autoAnalyze: true,
    sessionLimit: AppConstants.defaultSessionLimit,
    galleryColumns: AppConstants.defaultGridColumns,
    newestFirst: true,
    allowMetadata: true,
    scanReminders: true,
    duplicateReminders: true,
  );

  AppSettings copyWith({
    double? confidenceThreshold,
    bool? autoAnalyze,
    int? sessionLimit,
    int? galleryColumns,
    bool? newestFirst,
    bool? allowMetadata,
    bool? scanReminders,
    bool? duplicateReminders,
    String? geminiApiKey,
  }) {
    return AppSettings(
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      autoAnalyze: autoAnalyze ?? this.autoAnalyze,
      sessionLimit: sessionLimit ?? this.sessionLimit,
      galleryColumns: galleryColumns ?? this.galleryColumns,
      newestFirst: newestFirst ?? this.newestFirst,
      allowMetadata: allowMetadata ?? this.allowMetadata,
      scanReminders: scanReminders ?? this.scanReminders,
      duplicateReminders: duplicateReminders ?? this.duplicateReminders,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
    );
  }
}

class SettingsService {
  SettingsService(this._db);

  final DatabaseService _db;

  static const String _keyConfidence = 'ai_confidence';
  static const String _keyAutoAnalyze = 'auto_analyze';
  static const String _keySessionLimit = 'session_limit';
  static const String _keyGridColumns = 'gallery_columns';
  static const String _keyNewestFirst = 'newest_first';
  static const String _keyAllowMetadata = 'allow_metadata';
  static const String _keyScanReminders = 'scan_reminders';
  static const String _keyDuplicateReminders = 'duplicate_reminders';
  static const String _keyGeminiApiKey = 'gemini_api_key';

  Future<AppSettings> load() async {
    final String? confidence = await _db.getSetting(_keyConfidence);
    final String? autoAnalyze = await _db.getSetting(_keyAutoAnalyze);
    final String? sessionLimit = await _db.getSetting(_keySessionLimit);
    final String? gridColumns = await _db.getSetting(_keyGridColumns);
    final String? newestFirst = await _db.getSetting(_keyNewestFirst);
    final String? allowMetadata = await _db.getSetting(_keyAllowMetadata);
    final String? scanReminders = await _db.getSetting(_keyScanReminders);
    final String? duplicateReminders =
        await _db.getSetting(_keyDuplicateReminders);
    final String? geminiApiKey = await _db.getSetting(_keyGeminiApiKey);

    return AppSettings(
      confidenceThreshold: (double.tryParse(confidence ?? '') ??
              AppSettings.defaults.confidenceThreshold)
          .clamp(0.1, 0.95)
          .toDouble(),
      autoAnalyze: _parseBool(
        autoAnalyze,
        AppSettings.defaults.autoAnalyze,
      ),
      sessionLimit: (int.tryParse(sessionLimit ?? '') ??
              AppSettings.defaults.sessionLimit)
          .clamp(20, 400)
          .toInt(),
      galleryColumns: (int.tryParse(gridColumns ?? '') ??
              AppSettings.defaults.galleryColumns)
          .clamp(2, 4)
          .toInt(),
      newestFirst: _parseBool(
        newestFirst,
        AppSettings.defaults.newestFirst,
      ),
      allowMetadata: _parseBool(
        allowMetadata,
        AppSettings.defaults.allowMetadata,
      ),
      scanReminders: _parseBool(
        scanReminders,
        AppSettings.defaults.scanReminders,
      ),
      duplicateReminders: _parseBool(
        duplicateReminders,
        AppSettings.defaults.duplicateReminders,
      ),
      geminiApiKey: (geminiApiKey ?? '').trim(),
    );
  }

  Future<void> save(AppSettings settings) async {
    await _db.setSetting(_keyConfidence, settings.confidenceThreshold.toString());
    await _db.setSetting(_keyAutoAnalyze, settings.autoAnalyze.toString());
    await _db.setSetting(_keySessionLimit, settings.sessionLimit.toString());
    await _db.setSetting(_keyGridColumns, settings.galleryColumns.toString());
    await _db.setSetting(_keyNewestFirst, settings.newestFirst.toString());
    await _db.setSetting(_keyAllowMetadata, settings.allowMetadata.toString());
    await _db.setSetting(_keyScanReminders, settings.scanReminders.toString());
    await _db.setSetting(
      _keyDuplicateReminders,
      settings.duplicateReminders.toString(),
    );
    await _db.setSetting(_keyGeminiApiKey, settings.geminiApiKey.trim());
  }

  bool _parseBool(String? value, bool fallback) {
    if (value == null) {
      return fallback;
    }
    return value.toLowerCase() == 'true';
  }
}
