import '../../../core/services/local_storage_service.dart';
import 'models/app_settings.dart';

class SettingsRepository {
  SettingsRepository(this._storage);

  static const _storageKey = 'app_settings_v1';

  final LocalStorageService _storage;

  Future<AppSettings> load() async =>
      AppSettings.decode(await _storage.read(_storageKey));

  Future<void> save(AppSettings settings) =>
      _storage.write(_storageKey, settings.encode());
}
