import 'dart:math';

import 'app_system_service.dart';
import 'local_storage_service.dart';

/// Identifies this physical device to the license backend.
///
/// The id is a random token generated once and persisted locally (not the
/// Android device id): cheap boxes are known to ship with duplicate/blank
/// `ANDROID_ID` values, so a locally-generated token is the more reliable
/// "one key per device" anchor. Reinstalling the app resets it, which is the
/// desired behavior (a fresh install should re-request activation).
class DeviceIdentityService {
  DeviceIdentityService(this._storage, {AppSystemService? systemService})
    : _systemService = systemService ?? const AppSystemService();

  static const _deviceIdStorageKey = 'license_device_id_v1';

  final LocalStorageService _storage;
  final AppSystemService _systemService;

  String? _cachedId;

  Future<String> getOrCreateDeviceId() async {
    final cached = _cachedId;
    if (cached != null) {
      return cached;
    }

    final saved = await _storage.read(_deviceIdStorageKey);
    if (saved != null && saved.isNotEmpty) {
      _cachedId = saved;
      return saved;
    }

    final generated = _generateId();
    await _storage.write(_deviceIdStorageKey, generated);
    _cachedId = generated;
    return generated;
  }

  /// Info shown to the admin for a pending/bound device (e.g. "Xiaomi Box S",
  /// "Android 13 (API 33)"), best effort — falls back to generic values if
  /// the platform channel fails or never replies (bounded so a stuck native
  /// channel can't wedge the license submit flow forever).
  Future<DeviceSubmissionInfo> getDeviceInfo() async {
    try {
      final info = await _systemService.getSystemInfo().timeout(
        const Duration(seconds: 2),
      );
      return DeviceSubmissionInfo(
        label: info.deviceName,
        androidVersion: info.androidVersion,
      );
    } catch (_) {
      return const DeviceSubmissionInfo(
        label: 'Android',
        androidVersion: 'Android',
      );
    }
  }

  String _generateId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}

class DeviceSubmissionInfo {
  const DeviceSubmissionInfo({
    required this.label,
    required this.androidVersion,
  });

  final String label;
  final String androidVersion;
}
