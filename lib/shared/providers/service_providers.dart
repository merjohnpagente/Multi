import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/ai_service.dart';
import '../../core/services/database_service.dart';
import '../../core/services/metadata_service.dart';
import '../../core/services/photo_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/services/storage_service.dart';
import '../../core/services/duplicate_service.dart';

final Provider<DatabaseService> databaseProvider =
    Provider<DatabaseService>((Ref ref) => DatabaseService.instance);

final Provider<PhotoService> photoServiceProvider =
    Provider<PhotoService>((Ref ref) => PhotoService());

final Provider<MetadataService> metadataServiceProvider =
    Provider<MetadataService>(
  (Ref ref) => MetadataService(ref.watch(photoServiceProvider)),
);

final Provider<AiService> aiServiceProvider = Provider<AiService>((Ref ref) {
  final AiService service = AiService();
  service.onlineApiKey = dotenv.maybeGet('GEMINI_API_KEY');
  ref.onDispose(service.dispose);
  return service;
});

final Provider<SettingsService> settingsServiceProvider =
    Provider<SettingsService>(
  (Ref ref) => SettingsService(ref.watch(databaseProvider)),
);

final Provider<StorageService> storageServiceProvider =
    Provider<StorageService>((Ref ref) => StorageService());


final Provider<DuplicateService> duplicateServiceProvider =
    Provider<DuplicateService>((Ref ref) => DuplicateService.instance);
