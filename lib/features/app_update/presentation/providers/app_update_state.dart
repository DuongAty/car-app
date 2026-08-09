import '../../data/models/app_release.dart';

enum AppUpdateStatus {
  /// Nothing asked for yet — the row shows the installed version and a check
  /// button. The app never checks on its own.
  idle,
  checking,
  upToDate,
  available,
  downloading,
  verifying,

  /// Calling the system installer. Transient — resolves within a blink once
  /// the intent is handed off, one way or the other.
  installing,

  /// The APK was handed to the system installer. From here the controller
  /// cannot observe what happened next: succeeding replaces this app
  /// entirely (this screen is simply gone), and cancelling leaves us with no
  /// callback to learn from. This is deliberately not modelled as a busy
  /// state — the row always offers a pressable retry that reopens the
  /// installer using the same verified file, no re-download.
  installRequested,

  /// The platform reported `STATUS_SUCCESS` for the install session. Rare to
  /// ever be seen: a successful self-update usually replaces this process
  /// before the callback lands. Shown honestly when it does arrive.
  installed,
  error,
}

enum AppUpdateError {
  none,
  network,
  download,
  checksum,

  /// The platform call that hands the APK to the system installer failed.
  /// Retryable on the same file when it is still on disk.
  install,

  /// The system installer itself rejected the package (bad signature,
  /// conflicting package, no space...). Reopening the installer on the same
  /// file would fail identically, so the only useful move is a fresh check.
  installRejected,

  /// The user dismissed the system confirmation dialog (Back/Cancel). Not a
  /// rejection: the checksum-verified file is still good, so — unlike
  /// [installRejected] — the row keeps [AppUpdateState.downloadedPath] and
  /// retries by reopening the installer on it, not by re-downloading.
  installCancelled,
  permission,
}

class AppUpdateState {
  const AppUpdateState({
    this.status = AppUpdateStatus.idle,
    this.release,
    this.progress = 0,
    this.error = AppUpdateError.none,
    this.downloadedPath,
  });

  final AppUpdateStatus status;

  /// The release on offer. Set once [status] reaches
  /// [AppUpdateStatus.available] and kept through the download so the row can
  /// keep showing what is being installed.
  final AppRelease? release;

  /// 0..1 while [status] is [AppUpdateStatus.downloading].
  final double progress;

  final AppUpdateError error;

  /// Path of the checksum-verified APK on disk, set once a download passes
  /// verification. Lets a retry from [AppUpdateStatus.installRequested] (or
  /// an [AppUpdateError.install] error) reopen the installer on the same
  /// file instead of downloading the ~145MB APK again. Cleared whenever a
  /// fresh [AppUpdateStatus.checking] run starts, since a newer release
  /// invalidates the old file.
  final String? downloadedPath;

  AppUpdateState copyWith({
    AppUpdateStatus? status,
    Object? release = _unset,
    double? progress,
    AppUpdateError? error,
    Object? downloadedPath = _unset,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      release: identical(release, _unset)
          ? this.release
          : release as AppRelease?,
      progress: progress ?? this.progress,
      error: error ?? this.error,
      downloadedPath: identical(downloadedPath, _unset)
          ? this.downloadedPath
          : downloadedPath as String?,
    );
  }
}

const _unset = Object();
