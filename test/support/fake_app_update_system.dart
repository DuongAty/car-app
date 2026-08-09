import 'dart:async';

import 'package:viet_ktv/core/services/app_system_service.dart';
import 'package:viet_ktv/features/app_update/presentation/providers/app_update_controller.dart';

/// Records what the controller asked the platform to do. [installedPath] stays
/// null unless `installApk` was actually reached — that absence is what the
/// checksum test asserts on.
///
/// [installApkError] makes `installApk` throw, for exercising the
/// [AppUpdateError.install] path. [installApkGate], if set, holds `installApk`
/// open until the test completes it, so overlapping calls (e.g. two rapid
/// `reopenInstaller` presses) can be tested for real.
class FakeAppUpdateSystem implements AppUpdateSystem {
  FakeAppUpdateSystem({
    this.versionCode = 1,
    this.canInstall = true,
    this.installApkError,
    this.installApkGate,
  });

  int versionCode;
  bool canInstall;
  Object? installApkError;
  Completer<void>? installApkGate;

  String? installedPath;
  int installApkCallCount = 0;
  int permissionScreenOpened = 0;
  final List<String> deletedPaths = <String>[];

  @override
  Future<int> installedVersionCode() async => versionCode;

  @override
  Future<String> updateCacheDir() async => '/tmp/updates';

  @override
  Future<bool> canInstallPackages() async => canInstall;

  @override
  Future<void> openInstallPermissionSettings() async {
    permissionScreenOpened++;
  }

  @override
  Future<void> installApk(String path) async {
    installApkCallCount++;
    final gate = installApkGate;
    if (gate != null) {
      await gate.future;
    }
    final thrown = installApkError;
    if (thrown != null) {
      throw thrown;
    }
    installedPath = path;
  }

  @override
  Future<void> deleteFile(String path) async {
    deletedPaths.add(path);
  }

  /// The listener the controller registered, or null once it unregistered.
  /// [emitInstallStatus] pushes an outcome through it the way the platform
  /// would; calling it with no listener registered is a no-op, which is the
  /// "absence of a listener cannot crash anything" guarantee.
  void Function(AppInstallStatus status)? installStatusListener;

  @override
  void setInstallStatusListener(
    void Function(AppInstallStatus status)? listener,
  ) {
    installStatusListener = listener;
  }

  void emitInstallStatus(AppInstallOutcome outcome) {
    installStatusListener?.call(AppInstallStatus(outcome: outcome));
  }
}
