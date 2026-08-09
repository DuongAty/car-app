import '../../../core/services/local_storage_service.dart';

/// The last server-confirmed status worth remembering across restarts and
/// network blips. Only ever set from a real server response, never guessed.
enum LicenseCachedStatus {
  active,
  pending,
  locked,
  expired;

  static LicenseCachedStatus? tryParse(String? raw) => switch (raw) {
    'active' => LicenseCachedStatus.active,
    'pending' => LicenseCachedStatus.pending,
    'locked' => LicenseCachedStatus.locked,
    'expired' => LicenseCachedStatus.expired,
    _ => null,
  };
}

/// Persists the license key this device is bound to (or waiting on), plus the
/// last status the server confirmed. Karaoke boxes lose network often; the
/// cached status is what lets a previously-activated box keep working through
/// a network blip instead of re-locking on every splash screen.
class LicenseLocalStore {
  LicenseLocalStore(this._storage);

  static const _keyCodeStorageKey = 'license_key_code_v1';
  static const _lastGoodStatusStorageKey = 'license_last_good_status_v1';

  final LocalStorageService _storage;

  Future<String?> readKeyCode() async {
    final saved = await _storage.read(_keyCodeStorageKey);
    return (saved == null || saved.isEmpty) ? null : saved;
  }

  Future<LicenseCachedStatus?> readLastGoodStatus() async {
    return LicenseCachedStatus.tryParse(
      await _storage.read(_lastGoodStatusStorageKey),
    );
  }

  Future<void> save({
    required String keyCode,
    required LicenseCachedStatus status,
  }) async {
    await _storage.write(_keyCodeStorageKey, keyCode);
    await _storage.write(_lastGoodStatusStorageKey, status.name);
  }

  /// Forgets the bound key, e.g. after the server reports the key is now
  /// locked/reassigned/unknown — the device must go back to the input screen.
  Future<void> clear() async {
    await _storage.write(_keyCodeStorageKey, '');
    await _storage.write(_lastGoodStatusStorageKey, '');
  }
}
