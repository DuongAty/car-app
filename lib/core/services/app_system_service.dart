import 'package:flutter/services.dart';

class AppSystemInfo {
  const AppSystemInfo({
    required this.networkStatus,
    required this.deviceName,
    required this.androidVersion,
    required this.appVersion,
    required this.appVersionCode,
    required this.storageSummary,
  });

  factory AppSystemInfo.fromMap(Map<Object?, Object?> map) {
    return AppSystemInfo(
      networkStatus: map['networkStatus'] as String? ?? 'Unknown',
      deviceName: map['deviceName'] as String? ?? 'Android',
      androidVersion: map['androidVersion'] as String? ?? 'Android',
      appVersion: map['appVersion'] as String? ?? '1.0.0',
      // 0, not 1: an unknown installed version must read as older than any
      // published release, so the user is never silently told they are current.
      appVersionCode: map['appVersionCode'] as int? ?? 0,
      storageSummary: map['storageSummary'] as String? ?? '--',
    );
  }

  final String networkStatus;
  final String deviceName;
  final String androidVersion;
  final String appVersion;
  final int appVersionCode;
  final String storageSummary;
}

/// What the platform's `PackageInstaller` session reported.
///
/// [pendingUserAction] means the system confirmation screen was opened — the
/// only outcome the old code could (wrongly) assume; [success], [cancelled]
/// and [failed] are the real results, and they arrive later, if at all: a
/// successful self-update replaces this process, so the callback may never be
/// delivered.
///
/// [cancelled] is `STATUS_FAILURE_ABORTED` — the user dismissed the system
/// confirmation dialog (Back/Cancel). It is deliberately not folded into
/// [failed]: the package itself was never rejected, so the checksum-verified
/// file is still good and must not be treated the same as a genuine failure.
enum AppInstallOutcome { pendingUserAction, success, cancelled, failed }

class AppInstallStatus {
  const AppInstallStatus({required this.outcome, this.status, this.message});

  factory AppInstallStatus.fromMap(Map<Object?, Object?> map) {
    return AppInstallStatus(
      outcome: switch (map['outcome']) {
        'pendingUserAction' => AppInstallOutcome.pendingUserAction,
        'success' => AppInstallOutcome.success,
        'cancelled' => AppInstallOutcome.cancelled,
        // Anything unrecognised is treated as a failure rather than silently
        // read as success — never claim an install that did not happen.
        _ => AppInstallOutcome.failed,
      },
      status: map['status'] as int?,
      message: map['message'] as String?,
    );
  }

  final AppInstallOutcome outcome;

  /// Raw `PackageInstaller.EXTRA_STATUS`, for logging/diagnosis only.
  final int? status;
  final String? message;
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

  /// Directory the APK is downloaded into. Owned by the platform side, which
  /// has to reopen the same file to install it.
  Future<String> getUpdateCacheDir() async {
    final path = await _channel.invokeMethod<String>('getUpdateCacheDir');
    return path ?? '';
  }

  /// Android 8+ requires a per-app grant before this app may install another.
  /// A platform failure reads as "not allowed" so the caller routes the user
  /// to the settings screen rather than attempting an install that will fail.
  Future<bool> canInstallPackages() async {
    try {
      final allowed = await _channel.invokeMethod<bool>('canInstallPackages');
      return allowed ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openInstallPermissionSettings() =>
      _channel.invokeMethod<void>('openInstallPermissionSettings');

  Future<void> installApk(String path) => _channel.invokeMethod<void>(
    'installApk',
    <String, Object?>{'path': path},
  );

  /// Listens for `PackageInstaller` session outcomes pushed from the platform.
  ///
  /// Entirely optional: with no listener registered the platform message is
  /// dropped, and a malformed or unknown payload is ignored rather than
  /// thrown, so nothing here can take the app down. Pass null to unregister.
  void setInstallStatusListener(
    void Function(AppInstallStatus status)? listener,
  ) {
    if (listener == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'onInstallStatus') {
        return null;
      }
      final arguments = call.arguments;
      if (arguments is Map) {
        listener(AppInstallStatus.fromMap(arguments.cast<Object?, Object?>()));
      }
      return null;
    });
  }
}
