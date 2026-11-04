import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/settings_service.dart';
import 'service_providers.dart';

final AsyncNotifierProvider<SettingsController, AppSettings> settingsProvider =
    AsyncNotifierProvider<SettingsController, AppSettings>(
  SettingsController.new,
);

class SettingsController extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() {
    return ref.watch(settingsServiceProvider).load();
  }

  AppSettings get current => state.valueOrNull ?? AppSettings.defaults;

  Future<void> update(AppSettings settings) async {
    state = AsyncData<AppSettings>(settings);
    await ref.read(settingsServiceProvider).save(settings);
  }

  Future<void> setConfidenceThreshold(double value) =>
      update(current.copyWith(confidenceThreshold: value));

  Future<void> setAutoAnalyze(bool value) =>
      update(current.copyWith(autoAnalyze: value));

  Future<void> setSessionLimit(int value) =>
      update(current.copyWith(sessionLimit: value));

  Future<void> setGalleryColumns(int value) =>
      update(current.copyWith(galleryColumns: value));

  Future<void> setNewestFirst(bool value) =>
      update(current.copyWith(newestFirst: value));

  Future<void> setAllowMetadata(bool value) =>
      update(current.copyWith(allowMetadata: value));

  Future<void> setScanReminders(bool value) =>
      update(current.copyWith(scanReminders: value));

  Future<void> setDuplicateReminders(bool value) =>
      update(current.copyWith(duplicateReminders: value));
}
