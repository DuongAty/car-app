import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/services/app_system_service.dart';
import 'package:viet_ktv/features/app_update/data/models/app_release.dart';
import 'package:viet_ktv/features/app_update/presentation/providers/app_update_controller.dart';
import 'package:viet_ktv/features/app_update/presentation/providers/app_update_state.dart';

import '../../support/fake_apk_downloader.dart';
import '../../support/fake_app_update_repository.dart';
import '../../support/fake_app_update_system.dart';

const _release = AppRelease(
  versionCode: 7,
  versionName: '1.2.0',
  apkUrl: 'https://example.invalid/wetube.apk',
  sha256: 'goodhash',
  notes: 'Sửa lỗi',
);

AppUpdateController build({
  FakeAppUpdateRepository? repository,
  FakeApkDownloader? downloader,
  FakeAppUpdateSystem? system,
}) {
  return AppUpdateController(
    repository: repository ?? FakeAppUpdateRepository(),
    downloader: downloader ?? FakeApkDownloader(),
    system: system ?? FakeAppUpdateSystem(),
  );
}

void main() {
  test('starts_idle', () {
    expect(build().state.status, AppUpdateStatus.idle);
  });

  test('a_higher_remote_version_code_offers_the_update', () async {
    final controller = build(
      repository: FakeAppUpdateRepository(release: _release),
      system: FakeAppUpdateSystem(versionCode: 1),
    );

    await controller.check();

    expect(controller.state.status, AppUpdateStatus.available);
    expect(controller.state.release?.versionName, '1.2.0');
  });

  test('an_equal_version_code_reads_as_up_to_date', () async {
    final controller = build(
      repository: FakeAppUpdateRepository(release: _release),
      system: FakeAppUpdateSystem(versionCode: 7),
    );

    await controller.check();

    expect(controller.state.status, AppUpdateStatus.upToDate);
  });

  test('a_lower_version_code_never_offers_a_downgrade', () async {
    final controller = build(
      repository: FakeAppUpdateRepository(release: _release),
      system: FakeAppUpdateSystem(versionCode: 9),
    );

    await controller.check();

    expect(controller.state.status, AppUpdateStatus.upToDate);
  });

  test('no_published_release_is_up_to_date_not_an_error', () async {
    final controller = build(repository: FakeAppUpdateRepository());

    await controller.check();

    expect(controller.state.status, AppUpdateStatus.upToDate);
  });

  test('an_unreachable_backend_is_a_retryable_network_error', () async {
    final controller = build(
      repository: FakeAppUpdateRepository(error: Exception('offline')),
    );

    await controller.check();

    expect(controller.state.status, AppUpdateStatus.error);
    expect(controller.state.error, AppUpdateError.network);
  });

  test('a_matching_checksum_installs_the_downloaded_file', () async {
    final system = FakeAppUpdateSystem(versionCode: 1);
    final controller = build(
      repository: FakeAppUpdateRepository(release: _release),
      downloader: FakeApkDownloader(digest: 'goodhash'),
      system: system,
    );

    await controller.check();
    await controller.downloadAndInstall();

    expect(system.installedPath, '/tmp/updates/wetube-7.apk');
    expect(controller.state.status, AppUpdateStatus.installRequested);
    // The row must always offer a pressable action from here — not busy.
    expect(controller.state.error, AppUpdateError.none);
  });

  test('a_mismatched_checksum_errors_and_never_calls_install', () async {
    // The guard that matters most: a corrupted 145MB download must not reach
    // the system installer, where it fails with a parse error that tells the
    // user nothing.
    final system = FakeAppUpdateSystem(versionCode: 1);
    final controller = build(
      repository: FakeAppUpdateRepository(release: _release),
      downloader: FakeApkDownloader(digest: 'tampered'),
      system: system,
    );

    await controller.check();
    await controller.downloadAndInstall();

    expect(controller.state.status, AppUpdateStatus.error);
    expect(controller.state.error, AppUpdateError.checksum);
    expect(system.installedPath, isNull);
    // Left on disk, a bad file would be installed by the next attempt.
    expect(system.deletedPaths, ['/tmp/updates/wetube-7.apk']);
  });

  test('a_failed_download_is_a_retryable_error_and_does_not_install', () async {
    final system = FakeAppUpdateSystem(versionCode: 1);
    final controller = build(
      repository: FakeAppUpdateRepository(release: _release),
      downloader: FakeApkDownloader(error: Exception('connection reset')),
      system: system,
    );

    await controller.check();
    await controller.downloadAndInstall();

    expect(controller.state.error, AppUpdateError.download);
    expect(system.installedPath, isNull);
  });

  test('missing_install_permission_prompts_instead_of_downloading', () async {
    final system = FakeAppUpdateSystem(versionCode: 1, canInstall: false);
    final downloader = FakeApkDownloader(digest: 'goodhash');
    final controller = build(
      repository: FakeAppUpdateRepository(release: _release),
      downloader: downloader,
      system: system,
    );

    await controller.check();
    await controller.downloadAndInstall();

    expect(controller.state.error, AppUpdateError.permission);
    expect(downloader.lastUrl, isNull);
    expect(system.installedPath, isNull);
  });

  test(
    'a_second_check_while_one_is_in_flight_does_not_call_the_backend_again',
    () async {
      final gate = Completer<void>();
      final repository = FakeAppUpdateRepository(release: _release, gate: gate);
      final controller = build(repository: repository);

      final first = controller.check();
      final second = controller.check();

      gate.complete();
      await first;
      await second;

      expect(repository.callCount, 1);
    },
  );

  test(
    'a_second_download_while_one_is_in_flight_does_not_start_a_second_download',
    () async {
      final gate = Completer<void>();
      final system = FakeAppUpdateSystem(versionCode: 1);
      final downloader = FakeApkDownloader(digest: 'goodhash', gate: gate);
      final controller = build(
        repository: FakeAppUpdateRepository(release: _release),
        downloader: downloader,
        system: system,
      );

      await controller.check();

      final first = controller.downloadAndInstall();
      final second = controller.downloadAndInstall();

      gate.complete();
      await first;
      await second;

      expect(downloader.callCount, 1);
    },
  );

  test('opening_the_permission_screen_reaches_the_platform', () async {
    final system = FakeAppUpdateSystem();
    final controller = build(system: system);

    await controller.openPermissionSettings();

    expect(system.permissionScreenOpened, 1);
  });

  test('reopening_the_installer_after_hand_off_reuses_the_verified_file_'
      'instead_of_downloading_again', () async {
    final system = FakeAppUpdateSystem(versionCode: 1);
    final downloader = FakeApkDownloader(digest: 'goodhash');
    final controller = build(
      repository: FakeAppUpdateRepository(release: _release),
      downloader: downloader,
      system: system,
    );

    await controller.check();
    await controller.downloadAndInstall();
    expect(controller.state.status, AppUpdateStatus.installRequested);
    expect(downloader.callCount, 1);

    await controller.reopenInstaller();

    // The installer was reopened on the same path...
    expect(system.installApkCallCount, 2);
    expect(system.installedPath, '/tmp/updates/wetube-7.apk');
    // ...and no second download happened for it.
    expect(downloader.callCount, 1);
    expect(controller.state.status, AppUpdateStatus.installRequested);
  });

  test('a_failure_reopening_the_installer_is_a_retryable_install_error_that_'
      'keeps_the_verified_file', () async {
    final system = FakeAppUpdateSystem(
      versionCode: 1,
      installApkError: Exception('installer not found'),
    );
    final downloader = FakeApkDownloader(digest: 'goodhash');
    final controller = build(
      repository: FakeAppUpdateRepository(release: _release),
      downloader: downloader,
      system: system,
    );

    await controller.check();
    await controller.downloadAndInstall();

    expect(controller.state.status, AppUpdateStatus.error);
    expect(controller.state.error, AppUpdateError.install);
    // The file stays put — a later retry must still be able to reuse it.
    expect(controller.state.downloadedPath, '/tmp/updates/wetube-7.apk');

    await controller.reopenInstaller();

    expect(system.installApkCallCount, 2);
    expect(downloader.callCount, 1);
    expect(controller.state.status, AppUpdateStatus.error);
    expect(controller.state.error, AppUpdateError.install);
  });

  test(
    'two_rapid_reopen_presses_only_call_the_platform_installer_once',
    () async {
      final system = FakeAppUpdateSystem(versionCode: 1);
      final downloader = FakeApkDownloader(digest: 'goodhash');
      final controller = build(
        repository: FakeAppUpdateRepository(release: _release),
        downloader: downloader,
        system: system,
      );

      await controller.check();
      // Let the initial hand-off finish (its own gate-free call) so state
      // reaches installRequested before we drive the reopen races.
      await controller.downloadAndInstall();
      expect(controller.state.status, AppUpdateStatus.installRequested);

      final gate = Completer<void>();
      system.installApkGate = gate;

      final first = controller.reopenInstaller();
      final second = controller.reopenInstaller();

      gate.complete();
      await first;
      await second;

      // 1 from the initial hand-off + 1 from the (only) reopen that got in.
      expect(system.installApkCallCount, 2);
    },
  );

  test(
    'losing_the_downloaded_path_falls_back_to_a_full_redownload_on_reopen',
    () async {
      // Defensive path: if state ever reaches installRequested (or the
      // install error) without a downloadedPath — e.g. after a hot restart
      // that rebuilt state some other way — reopenInstaller must not throw
      // or no-op forever; it must still get the user unstuck.
      final system = FakeAppUpdateSystem(versionCode: 1);
      final downloader = FakeApkDownloader(digest: 'goodhash');
      final controller = build(
        repository: FakeAppUpdateRepository(release: _release),
        downloader: downloader,
        system: system,
      );

      await controller.check();
      expect(controller.state.downloadedPath, isNull);

      await controller.reopenInstaller();

      expect(downloader.callCount, 1);
      expect(system.installApkCallCount, 1);
      expect(controller.state.status, AppUpdateStatus.installRequested);
    },
  );

  test(
    'a_platform_install_success_is_reported_honestly_instead_of_guessed',
    () async {
      // C1: commit() only fires a status callback; the row used to claim the
      // installer had been opened and never learn anything else. Now the
      // platform outcome drives the state.
      final system = FakeAppUpdateSystem(versionCode: 1);
      final controller = build(
        repository: FakeAppUpdateRepository(release: _release),
        downloader: FakeApkDownloader(digest: 'goodhash'),
        system: system,
      );

      await controller.check();
      await controller.downloadAndInstall();
      expect(controller.state.status, AppUpdateStatus.installRequested);

      system.emitInstallStatus(AppInstallOutcome.success);
      await pumpEventQueue();

      expect(controller.state.status, AppUpdateStatus.installed);
      expect(controller.state.error, AppUpdateError.none);
      // Nothing left to reinstall from.
      expect(controller.state.downloadedPath, isNull);
    },
  );

  test(
    'a_platform_install_rejection_drops_the_file_and_routes_back_to_check',
    () async {
      final system = FakeAppUpdateSystem(versionCode: 1);
      final controller = build(
        repository: FakeAppUpdateRepository(release: _release),
        downloader: FakeApkDownloader(digest: 'goodhash'),
        system: system,
      );

      await controller.check();
      await controller.downloadAndInstall();

      system.emitInstallStatus(AppInstallOutcome.failed);
      await pumpEventQueue();

      expect(controller.state.status, AppUpdateStatus.error);
      expect(controller.state.error, AppUpdateError.installRejected);
      // The system rejected this exact file; reopening the installer on it
      // would fail identically, so it must not be retried.
      expect(controller.state.downloadedPath, isNull);
    },
  );

  test('a_platform_cancellation_keeps_the_verified_file_and_offers_reinstall_'
      'instead_of_a_full_redownload', () async {
    // F1: STATUS_FAILURE_ABORTED (Back/Cancel on the system confirmation
    // dialog) must not be treated the same as a genuine rejection — the
    // checksum-verified 145MB file is still good.
    final system = FakeAppUpdateSystem(versionCode: 1);
    final downloader = FakeApkDownloader(digest: 'goodhash');
    final controller = build(
      repository: FakeAppUpdateRepository(release: _release),
      downloader: downloader,
      system: system,
    );

    await controller.check();
    await controller.downloadAndInstall();
    expect(controller.state.status, AppUpdateStatus.installRequested);

    system.emitInstallStatus(AppInstallOutcome.cancelled);
    await pumpEventQueue();

    expect(controller.state.status, AppUpdateStatus.error);
    expect(controller.state.error, AppUpdateError.installCancelled);
    // The file must survive — a mis-tap must never force a re-download.
    expect(controller.state.downloadedPath, '/tmp/updates/wetube-7.apk');
    expect(system.deletedPaths, isEmpty);

    // Pressing again reopens the installer on the same file, no re-download.
    await controller.reopenInstaller();

    expect(downloader.callCount, 1);
    expect(system.installApkCallCount, 2);
    expect(controller.state.status, AppUpdateStatus.installRequested);
  });

  test('a_fast_failure_outcome_that_lands_before_the_hand_off_await_resolves_'
      'is_not_overwritten_by_installRequested', () async {
    // F2: the receiver's outcome callback and `_handOff`'s own await of
    // `installApk` are delivered from different threads, so their order is
    // not deterministic. A fast STATUS_FAILURE_STORAGE-style outcome must
    // survive even if it lands before `installApk` itself resolves.
    final gate = Completer<void>();
    final system = FakeAppUpdateSystem(versionCode: 1, installApkGate: gate);
    final controller = build(
      repository: FakeAppUpdateRepository(release: _release),
      downloader: FakeApkDownloader(digest: 'goodhash'),
      system: system,
    );

    await controller.check();
    final install = controller.downloadAndInstall();
    // Flush the microtasks between here and `installApk`'s gate (canInstall
    // check, cache dir lookup, the fake download, checksum verification) so
    // execution actually parks inside `_handOff`'s gated `installApk` call.
    await pumpEventQueue();
    // downloadAndInstall is still suspended inside `installApk` (the gate),
    // so state is `installing` right now — exactly the window in which the
    // real receiver callback can race ahead of the method channel result.
    expect(controller.state.status, AppUpdateStatus.installing);

    system.emitInstallStatus(AppInstallOutcome.failed);
    await pumpEventQueue();

    expect(controller.state.status, AppUpdateStatus.error);
    expect(controller.state.error, AppUpdateError.installRejected);

    // Now let the hand-off's own await finish successfully — its stale
    // "installer opened" write must not clobber the failure that already
    // landed.
    gate.complete();
    await install;

    expect(controller.state.status, AppUpdateStatus.error);
    expect(controller.state.error, AppUpdateError.installRejected);
  });

  test('a_successful_install_deletes_the_cached_apk_so_it_does_not_sit_in_'
      'cache_forever', () async {
    // F3: nothing can ever reuse this file again once the platform reports
    // STATUS_SUCCESS, so it must not linger in cache/updates.
    final system = FakeAppUpdateSystem(versionCode: 1);
    final controller = build(
      repository: FakeAppUpdateRepository(release: _release),
      downloader: FakeApkDownloader(digest: 'goodhash'),
      system: system,
    );

    await controller.check();
    await controller.downloadAndInstall();

    system.emitInstallStatus(AppInstallOutcome.success);
    await pumpEventQueue();

    expect(controller.state.status, AppUpdateStatus.installed);
    expect(system.deletedPaths, ['/tmp/updates/wetube-7.apk']);
  });

  test('a_platform_install_rejection_deletes_the_cached_apk_since_it_can_never_'
      'be_reused', () async {
    // F3: a terminal failure (bad signature, conflict, incompatible...)
    // also frees the cache — only cancellation (F1) keeps the file.
    final system = FakeAppUpdateSystem(versionCode: 1);
    final controller = build(
      repository: FakeAppUpdateRepository(release: _release),
      downloader: FakeApkDownloader(digest: 'goodhash'),
      system: system,
    );

    await controller.check();
    await controller.downloadAndInstall();

    system.emitInstallStatus(AppInstallOutcome.failed);
    await pumpEventQueue();

    expect(controller.state.status, AppUpdateStatus.error);
    expect(controller.state.error, AppUpdateError.installRejected);
    expect(system.deletedPaths, ['/tmp/updates/wetube-7.apk']);
  });

  test('the_pending_user_action_outcome_leaves_the_row_where_it_is', () async {
    final system = FakeAppUpdateSystem(versionCode: 1);
    final controller = build(
      repository: FakeAppUpdateRepository(release: _release),
      downloader: FakeApkDownloader(digest: 'goodhash'),
      system: system,
    );

    await controller.check();
    await controller.downloadAndInstall();

    system.emitInstallStatus(AppInstallOutcome.pendingUserAction);

    expect(controller.state.status, AppUpdateStatus.installRequested);
    expect(controller.state.downloadedPath, '/tmp/updates/wetube-7.apk');
  });

  test('granting_the_install_permission_is_not_a_dead_end', () async {
    // C2: openPermissionSettings used to leave state in error/permission
    // forever. The row offers exactly one button there, so after granting the
    // permission the user could never reach the update again.
    final system = FakeAppUpdateSystem(versionCode: 1, canInstall: false);
    final controller = build(
      repository: FakeAppUpdateRepository(release: _release),
      system: system,
    );

    await controller.check();
    await controller.downloadAndInstall();
    expect(controller.state.error, AppUpdateError.permission);

    await controller.openPermissionSettings();

    expect(system.permissionScreenOpened, 1);
    expect(controller.state.status, AppUpdateStatus.available);
    expect(controller.state.error, AppUpdateError.none);
    expect(controller.state.release, isNotNull);
  });

  test(
    'granting_the_permission_with_no_release_in_hand_returns_to_idle',
    () async {
      final system = FakeAppUpdateSystem(canInstall: false);
      final controller = build(system: system);
      controller.state = const AppUpdateState(
        status: AppUpdateStatus.error,
        error: AppUpdateError.permission,
      );

      await controller.openPermissionSettings();

      expect(controller.state.status, AppUpdateStatus.idle);
      expect(controller.state.error, AppUpdateError.none);
    },
  );

  test(
    'a_missing_cached_apk_drops_the_path_so_the_retry_redownloads',
    () async {
      // I2: Android can evict the cache dir between download and install.
      // Retrying installApk on that same vanished path can never succeed, so
      // the path must be cleared rather than retried forever.
      final system = FakeAppUpdateSystem(
        versionCode: 1,
        installApkError: PlatformException(
          code: 'install_file_missing',
          message: 'No file at /tmp/updates/wetube-7.apk.',
        ),
      );
      final downloader = FakeApkDownloader(digest: 'goodhash');
      final controller = build(
        repository: FakeAppUpdateRepository(release: _release),
        downloader: downloader,
        system: system,
      );

      await controller.check();
      await controller.downloadAndInstall();

      expect(controller.state.error, AppUpdateError.install);
      expect(controller.state.downloadedPath, isNull);

      // And the retry is a real re-download, not the same doomed path again.
      system.installApkError = null;
      await controller.reopenInstaller();

      expect(downloader.callCount, 2);
      expect(controller.state.status, AppUpdateStatus.installRequested);
    },
  );

  test('progress_only_reaches_the_ui_when_the_whole_percent_changes', () async {
    // I3: AppUpdateState has no ==, so every emission rebuilds UpdateSection.
    // A 145MB download produces thousands of HTTP chunks; only 100 of them
    // can possibly change what the row displays.
    final steps = <double>[for (var i = 0; i <= 1000; i++) i / 1000];
    final downloader = FakeApkDownloader(
      digest: 'goodhash',
      progressSequence: steps,
    );
    final controller = build(
      repository: FakeAppUpdateRepository(release: _release),
      downloader: downloader,
      system: FakeAppUpdateSystem(versionCode: 1),
    );

    await controller.check();

    final downloadingEmissions = <double>[];
    controller.addListener((state) {
      if (state.status == AppUpdateStatus.downloading) {
        downloadingEmissions.add(state.progress);
      }
    }, fireImmediately: false);

    await controller.downloadAndInstall();

    // One entry for entering the downloading state at 0, then exactly one per
    // whole percent from 1 to 100 — not one per chunk.
    expect(downloadingEmissions.length, 101);
    expect(downloadingEmissions.map((p) => (p * 100).round()).toList(), [
      0,
      for (var percent = 1; percent <= 100; percent++) percent,
    ]);
  });
}
