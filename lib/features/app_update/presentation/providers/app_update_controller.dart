import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_system_service.dart';
import '../../data/apk_downloader.dart';
import '../../data/app_update_repository.dart';
import 'app_update_state.dart';

/// The slice of the platform the updater needs, named separately so tests can
/// fake five small methods instead of the whole [AppSystemService].
abstract interface class AppUpdateSystem {
  Future<int> installedVersionCode();
  Future<String> updateCacheDir();
  Future<bool> canInstallPackages();
  Future<void> openInstallPermissionSettings();
  Future<void> installApk(String path);

  /// Removes a downloaded APK. Called when its checksum does not match, so a
  /// corrupt file cannot be picked up by the next attempt.
  Future<void> deleteFile(String path);

  /// Registers [listener] for the platform's install-session outcome, or
  /// clears it when null. Optional on purpose — the outcome may never arrive
  /// (a successful self-update replaces the process first), so nothing may
  /// depend on it.
  void setInstallStatusListener(
    void Function(AppInstallStatus status)? listener,
  );
}

class PlatformAppUpdateSystem implements AppUpdateSystem {
  const PlatformAppUpdateSystem({AppSystemService? service})
    : _service = service ?? const AppSystemService();

  final AppSystemService _service;

  @override
  Future<int> installedVersionCode() async =>
      (await _service.getSystemInfo()).appVersionCode;

  @override
  Future<String> updateCacheDir() => _service.getUpdateCacheDir();

  @override
  Future<bool> canInstallPackages() => _service.canInstallPackages();

  @override
  Future<void> openInstallPermissionSettings() =>
      _service.openInstallPermissionSettings();

  @override
  Future<void> installApk(String path) => _service.installApk(path);

  @override
  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }

  @override
  void setInstallStatusListener(
    void Function(AppInstallStatus status)? listener,
  ) => _service.setInstallStatusListener(listener);
}

class AppUpdateController extends StateNotifier<AppUpdateState> {
  AppUpdateController({
    required this.repository,
    required this.downloader,
    required this.system,
  }) : super(const AppUpdateState()) {
    // Optional by contract: the platform may never report an outcome (a
    // successful self-update replaces this process first), and nothing here
    // waits on it — it only corrects the row when it does arrive.
    system.setInstallStatusListener(_onInstallStatus);
  }

  @override
  void dispose() {
    system.setInstallStatusListener(null);
    super.dispose();
  }

  final AppUpdateRepository repository;
  final ApkDownloader downloader;
  final AppUpdateSystem system;

  /// Statuses in which a run is already in flight. [AppUpdateStatus.installing]
  /// counts as busy too — it is the brief synchronous window around handing
  /// the file to the system installer. [AppUpdateStatus.installRequested] is
  /// deliberately NOT busy: once the installer has been opened, this
  /// controller is no longer blocked on anything observable, so the row must
  /// stay pressable.
  static const _busyStatuses = {
    AppUpdateStatus.checking,
    AppUpdateStatus.downloading,
    AppUpdateStatus.verifying,
    AppUpdateStatus.installing,
  };

  bool get _isBusy => _busyStatuses.contains(state.status);

  Future<void> check() async {
    if (_isBusy) {
      return;
    }
    state = state.copyWith(
      status: AppUpdateStatus.checking,
      error: AppUpdateError.none,
      release: null,
      downloadedPath: null,
    );
    try {
      final release = await repository.latestRelease();
      final installed = await system.installedVersionCode();
      if (release == null || release.versionCode <= installed) {
        // No row published, or the server is not ahead of us. Both are
        // "up to date"; neither is an error, and neither may downgrade.
        state = state.copyWith(status: AppUpdateStatus.upToDate);
        return;
      }
      state = state.copyWith(
        status: AppUpdateStatus.available,
        release: release,
      );
    } catch (_) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        error: AppUpdateError.network,
      );
    }
  }

  Future<void> downloadAndInstall() async {
    if (_isBusy) {
      return;
    }
    final release = state.release;
    if (release == null) {
      return;
    }

    // Claim the busy state synchronously, before the first `await` below —
    // otherwise a second call arriving during that first suspension would
    // see the same pre-download status and slip past the guard too.
    state = state.copyWith(
      status: AppUpdateStatus.downloading,
      progress: 0,
      error: AppUpdateError.none,
    );

    if (!await system.canInstallPackages()) {
      // Downloading 145MB the user cannot install wastes their data.
      state = state.copyWith(
        status: AppUpdateStatus.error,
        error: AppUpdateError.permission,
      );
      return;
    }

    final String path;
    final String digest;
    // The row renders a whole percent, and `AppUpdateState` has no `==`, so
    // emitting per HTTP chunk would rebuild `UpdateSection` thousands of
    // times a second for minutes on a 2GB box. Starts at 0 because the state
    // above already reports 0%.
    var lastPercent = 0;
    try {
      final dir = await system.updateCacheDir();
      path = '$dir/wetube-${release.versionCode}.apk';
      digest = await downloader.download(
        url: release.apkUrl,
        destinationPath: path,
        onProgress: (progress) {
          final percent = (progress * 100).round();
          if (percent == lastPercent) {
            return;
          }
          lastPercent = percent;
          state = state.copyWith(progress: progress);
        },
      );
    } catch (_) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        error: AppUpdateError.download,
      );
      return;
    }

    state = state.copyWith(status: AppUpdateStatus.verifying);
    if (digest.toLowerCase() != release.sha256.toLowerCase()) {
      // A truncated download reaching the system installer fails with a parse
      // error that tells the user nothing. Stop here — and delete the file,
      // or the next attempt would pick the same bad bytes back up.
      await system.deleteFile(path);
      state = state.copyWith(
        status: AppUpdateStatus.error,
        error: AppUpdateError.checksum,
      );
      return;
    }

    // The file is verified from here on, so a retry never needs to
    // re-download it — only reopen the installer on this same path.
    state = state.copyWith(
      status: AppUpdateStatus.installing,
      downloadedPath: path,
    );
    await _handOff(path);
  }

  /// Reopens the system installer without re-downloading, using the
  /// checksum-verified file already on disk. This is the only escape from
  /// [AppUpdateStatus.installRequested] (and from an [AppUpdateError.install]
  /// error) — see the type doc on [AppUpdateStatus.installRequested] for why
  /// there is nothing else to wait on.
  Future<void> reopenInstaller() async {
    if (_isBusy) {
      return;
    }
    final path = state.downloadedPath;
    if (path == null) {
      // No verified file on disk to reuse (e.g. state was reset, or the
      // cached APK was evicted). Re-download when we still know what to
      // fetch; otherwise the only way forward is a fresh check.
      if (state.release == null) {
        await check();
      } else {
        await downloadAndInstall();
      }
      return;
    }

    // Claim the busy state synchronously, before the first `await`, for the
    // same reentrancy reason as `downloadAndInstall`.
    state = state.copyWith(
      status: AppUpdateStatus.installing,
      error: AppUpdateError.none,
    );
    await _handOff(path);
  }

  /// Hands [path] to the platform installer and records the outcome.
  ///
  /// Success here only means the install session was accepted — whether
  /// anything is actually installed arrives later through
  /// [_onInstallStatus], if at all.
  Future<void> _handOff(String path) async {
    try {
      await system.installApk(path);
      // The receiver's outcome callback lands from a different thread than
      // this await's completion, so the order between them is not
      // deterministic (F2). A fast failure/cancellation can already have
      // moved the state past `installing` by the time this resolves — never
      // clobber it with "installer opened".
      if (state.status == AppUpdateStatus.installing) {
        state = state.copyWith(status: AppUpdateStatus.installRequested);
      }
    } on PlatformException catch (error) {
      if (state.status == AppUpdateStatus.installing) {
        _failInstall(reusableFile: error.code != _fileMissingCode);
      }
    } catch (_) {
      if (state.status == AppUpdateStatus.installing) {
        _failInstall(reusableFile: true);
      }
    }
  }

  /// [reusableFile] false means retrying on the same path can never work
  /// (Android evicted the cached APK), so the path is dropped and the next
  /// press re-downloads instead of pressing the same doomed button forever.
  void _failInstall({required bool reusableFile}) {
    state = state.copyWith(
      status: AppUpdateStatus.error,
      error: AppUpdateError.install,
      downloadedPath: reusableFile ? state.downloadedPath : null,
    );
  }

  Future<void> _onInstallStatus(AppInstallStatus status) async {
    switch (status.outcome) {
      case AppInstallOutcome.pendingUserAction:
        // The system confirmation screen is up; the row already says so.
        break;
      case AppInstallOutcome.success:
        // Nothing can reuse this file again — free the ~145MB it holds in
        // cache/updates now rather than leaving it there forever (F3).
        await _deleteCachedApk();
        state = state.copyWith(
          status: AppUpdateStatus.installed,
          error: AppUpdateError.none,
          downloadedPath: null,
        );
      case AppInstallOutcome.cancelled:
        // The user dismissed the confirmation dialog — not a rejection of
        // the file. Keep downloadedPath so pressing again reopens the
        // installer on the same verified APK instead of re-downloading
        // 145MB (F1). Do not delete the cache: it is still needed.
        state = state.copyWith(
          status: AppUpdateStatus.error,
          error: AppUpdateError.installCancelled,
        );
      case AppInstallOutcome.failed:
        // The installer rejected this exact package. Reopening it on the
        // same file would fail identically, so the file goes (F3) and the
        // row routes back to a fresh check.
        await _deleteCachedApk();
        state = state.copyWith(
          status: AppUpdateStatus.error,
          error: AppUpdateError.installRejected,
          downloadedPath: null,
        );
    }
  }

  /// Deletes the checksum-verified APK once it can no longer be needed —
  /// after a successful install or a terminal failure. Never called for a
  /// cancellation (F1) or while the confirmation dialog is still up: both
  /// still need this exact file.
  Future<void> _deleteCachedApk() async {
    final path = state.downloadedPath;
    if (path != null) {
      await system.deleteFile(path);
    }
  }

  /// Opens the system "install unknown apps" screen and leaves the row in a
  /// state the user can act on when they come back.
  ///
  /// Android gives no callback for that return trip, and this provider is
  /// root-scoped so leaving Settings never resets it. Staying in
  /// `error/permission` would strand the row on a single button that only
  /// reopens the same system screen. Dropping back to the release on offer
  /// costs nothing: the next press re-checks the permission anyway.
  Future<void> openPermissionSettings() async {
    await system.openInstallPermissionSettings();
    if (state.error != AppUpdateError.permission) {
      return;
    }
    state = state.copyWith(
      status: state.release != null
          ? AppUpdateStatus.available
          : AppUpdateStatus.idle,
      error: AppUpdateError.none,
    );
  }

  /// Platform error code for an APK that is no longer on disk.
  static const _fileMissingCode = 'install_file_missing';
}

final appUpdateControllerProvider =
    StateNotifierProvider<AppUpdateController, AppUpdateState>(
      (ref) => AppUpdateController(
        repository: const SupabaseAppUpdateRepository(),
        downloader: const HttpApkDownloader(),
        system: const PlatformAppUpdateSystem(),
      ),
    );
