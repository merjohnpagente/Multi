import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/ai_service.dart';
import '../../core/services/settings_service.dart';
import 'service_providers.dart';

final AsyncNotifierProvider<SettingsController, AppSettings> settingsProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() async {
    final AppSettings settings =
        await ref.watch(settingsServiceProvider).load();
    ref.read(aiServiceProvider).onlineApiKey = settings.geminiApiKey;
    return settings;
  }

  AppSettings get current => state.valueOrNull ?? AppSettings.defaults;

  Future<void> apply(AppSettings settings) async {
    state = AsyncData<AppSettings>(settings);
    final AiService ai = ref.read(aiServiceProvider);
    ai.onlineApiKey = settings.geminiApiKey;
    ai.resetOnlineCooldown();
    await ref.read(settingsServiceProvider).save(settings);
  }

  Future<void> setConfidenceThreshold(double value) =>
      apply(current.copyWith(confidenceThreshold: value));

  Future<void> setAutoAnalyze(bool value) =>
      apply(current.copyWith(autoAnalyze: value));

  Future<void> setSessionLimit(int value) =>
      apply(current.copyWith(sessionLimit: value));

  Future<void> setGalleryColumns(int value) =>
      apply(current.copyWith(galleryColumns: value));

  Future<void> setNewestFirst(bool value) =>
      apply(current.copyWith(newestFirst: value));

  Future<void> setAllowMetadata(bool value) =>
      apply(current.copyWith(allowMetadata: value));

  Future<void> setScanReminders(bool value) =>
      apply(current.copyWith(scanReminders: value));

  Future<void> setDuplicateReminders(bool value) =>
      apply(current.copyWith(duplicateReminders: value));

  Future<void> setGeminiApiKey(String value) =>
      apply(current.copyWith(geminiApiKey: value.trim()));
}

