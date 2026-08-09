import 'package:flutter/services.dart';

class AppSystemInfo {
  const AppSystemInfo({
    required this.networkStatus,
    required this.deviceName,
    required this.androidVersion,
    required this.appVersion,
    required this.storageSummary,
  });

  factory AppSystemInfo.fromMap(Map<Object?, Object?> map) {
    return AppSystemInfo(
      networkStatus: map['networkStatus'] as String? ?? 'Unknown',
      deviceName: map['deviceName'] as String? ?? 'Android',
      androidVersion: map['androidVersion'] as String? ?? 'Android',
      appVersion: map['appVersion'] as String? ?? '1.0.0',
      storageSummary: map['storageSummary'] as String? ?? '--',
    );
  }

  final String networkStatus;
  final String deviceName;
  final String androidVersion;
  final String appVersion;
  final String storageSummary;
}

class AppSystemService {
  const AppSystemService({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('viet_ktv/system');

  final MethodChannel _channel;

  Future<AppSystemInfo> getSystemInfo() async {
    final result = await _channel.invokeMapMethod<Object?, Object?>(
      'getSystemInfo',
    );
    return AppSystemInfo.fromMap(result ?? const {});
  }

  Future<void> restartApp() => _channel.invokeMethod<void>('restartApp');

  Future<void> shutdownDevice() =>
      _channel.invokeMethod<void>('shutdownDevice');

  /// Android 13+ hides the media notification without this. A denial is not
  /// fatal — the foreground service still keeps playback alive.
  Future<bool> requestNotificationPermission() async {
    try {
      final granted = await _channel.invokeMethod<bool>(
        'requestNotificationPermission',
      );
      return granted ?? false;
    } catch (_) {
      return false;
    }
  }
}
