import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/shared/widgets/focusable_tile.dart';
import 'package:viet_ktv/features/app_update/data/models/app_release.dart';
import 'package:viet_ktv/features/app_update/presentation/providers/app_update_controller.dart';
import 'package:viet_ktv/features/app_update/presentation/providers/app_update_state.dart';
import 'package:viet_ktv/features/app_update/presentation/widgets/update_section.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import '../../support/fake_apk_downloader.dart';
import '../../support/fake_app_update_repository.dart';
import '../../support/fake_app_update_system.dart';

/// `appUpdateControllerProvider` is typed
/// `StateNotifierProvider<AppUpdateController, AppUpdateState>`, so an
/// override must produce an [AppUpdateController] — a bare StateNotifier will
/// not compile. Subclass it with fakes and seed the state directly.
class _StubController extends AppUpdateController {
  _StubController(
    AppUpdateState initial, {
    required FakeAppUpdateRepository repository,
    required FakeApkDownloader downloader,
    required FakeAppUpdateSystem system,
  }) : super(repository: repository, downloader: downloader, system: system) {
    state = initial;
  }
}

Future<void> _pump(
  WidgetTester tester,
  AppUpdateState state, {
  FakeAppUpdateRepository? repository,
  FakeApkDownloader? downloader,
  FakeAppUpdateSystem? system,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appUpdateControllerProvider.overrideWith(
          (ref) => _StubController(
            state,
            repository: repository ?? FakeAppUpdateRepository(),
            downloader: downloader ?? FakeApkDownloader(),
            system: system ?? FakeAppUpdateSystem(),
          ),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: UpdateSection()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('idle_shows_the_check_button', (tester) async {
    await _pump(tester, const AppUpdateState());

    expect(find.text('Kiểm tra cập nhật'), findsOneWidget);
  });

  testWidgets('up_to_date_says_there_is_no_new_version', (tester) async {
    await _pump(tester, const AppUpdateState(status: AppUpdateStatus.upToDate));

    expect(find.text('Không có bản cập nhật mới'), findsOneWidget);
  });

  testWidgets('available_shows_the_version_notes_and_update_button', (
    tester,
  ) async {
    await _pump(
      tester,
      const AppUpdateState(
        status: AppUpdateStatus.available,
        release: AppRelease(
          versionCode: 7,
          versionName: '1.2.0',
          apkUrl: 'https://example.invalid/a.apk',
          sha256: 'aa',
          notes: 'Sửa lỗi phát nhạc nền',
        ),
      ),
    );

    expect(find.text('Có bản mới 1.2.0'), findsOneWidget);
    expect(find.text('Sửa lỗi phát nhạc nền'), findsOneWidget);
    expect(find.text('Cập nhật'), findsOneWidget);
  });

  testWidgets('a_checksum_error_explains_itself_and_offers_a_retry', (
    tester,
  ) async {
    await _pump(
      tester,
      const AppUpdateState(
        status: AppUpdateStatus.error,
        error: AppUpdateError.checksum,
      ),
    );

    expect(
      find.text('Tệp tải về bị hỏng. Đã xoá, vui lòng thử lại.'),
      findsOneWidget,
    );
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('a_permission_error_offers_the_settings_shortcut', (
    tester,
  ) async {
    await _pump(
      tester,
      const AppUpdateState(
        status: AppUpdateStatus.error,
        error: AppUpdateError.permission,
      ),
    );

    expect(find.text('Mở cài đặt'), findsOneWidget);
  });

  testWidgets('downloading_with_no_progress_yet_shows_an_indeterminate_label_'
      'instead_of_a_stuck_zero_percent', (tester) async {
    await _pump(
      tester,
      const AppUpdateState(status: AppUpdateStatus.downloading),
    );

    expect(find.text('Đang tải...'), findsOneWidget);
    expect(find.text('Đang tải 0%'), findsNothing);
  });

  testWidgets(
    'install_requested_is_never_a_dead_end_it_always_offers_a_pressable_'
    'reinstall_action',
    (tester) async {
      // The bug this guards against: once the APK is handed to the system
      // installer, the controller cannot observe what happened next. Before
      // this fix that state was treated as busy forever — a spinner with no
      // button the user could press if they cancelled the system installer.
      await _pump(
        tester,
        const AppUpdateState(
          status: AppUpdateStatus.installRequested,
          downloadedPath: '/tmp/updates/youcar-7.apk',
        ),
      );

      // Honest copy: we know the installer was opened, not that it finished.
      expect(find.text('Đã mở trình cài đặt'), findsOneWidget);
      // No spinner — a real, pressable action.
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Cài đặt lại'), findsOneWidget);
    },
  );

  testWidgets(
    'an_install_error_after_a_verified_download_also_offers_reinstall_'
    'not_a_generic_retry_that_implies_downloading_again',
    (tester) async {
      await _pump(
        tester,
        const AppUpdateState(
          status: AppUpdateStatus.error,
          error: AppUpdateError.install,
          downloadedPath: '/tmp/updates/youcar-7.apk',
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Cài đặt lại'), findsOneWidget);
    },
  );

  testWidgets(
    'the_action_button_renders_a_visibly_stronger_border_when_focused_than_'
    'when_it_is_not',
    (tester) async {
      // Pins the D-pad/remote focus fix: a bare FilledButton only gets
      // Material's faint default focus tint, which is effectively invisible
      // from across a car dashboard or living room. The button must render
      // a clearly different (brighter) border once it holds real focus, so
      // a later change cannot silently flatten that back down.
      await _pump(tester, const AppUpdateState());

      final buttonFinder = find.byType(FocusableTile);
      expect(buttonFinder, findsOneWidget);
      final containerFinder = find
          .descendant(of: buttonFinder, matching: find.byType(Container))
          .first;

      BoxDecoration decorationOf() =>
          tester.widget<Container>(containerFinder).decoration as BoxDecoration;

      final unfocused = decorationOf();
      expect(unfocused.border, isA<Border>());

      // Advance focus via Tab, the way a real remote/keyboard would — not a
      // direct `requestFocus`, which could land even if traversal could not
      // actually reach the button.
      var landed = false;
      for (var press = 0; press < 20 && !landed; press++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        landed = decorationOf() != unfocused;
      }

      final focused = decorationOf();
      expect(landed, isTrue, reason: 'focus must be able to reach the button');
      expect(focused.border, isNot(equals(unfocused.border)));
      // Focused must have a real glow too, per the karaoke neon guideline
      // (brighter border AND/OR stronger glow — this button uses both).
      expect(focused.boxShadow, isNot(equals(unfocused.boxShadow)));
      expect(focused.boxShadow, isNotEmpty);
    },
  );

  testWidgets('pressing_the_settings_shortcut_leaves_the_row_usable_instead_of_'
      'stranding_it_on_the_same_button', (tester) async {
    // C2: every device starts without "install unknown apps", so the first
    // press of Update on every device lands here. The row offers exactly
    // one button; if pressing it leaves the state unchanged, the user can
    // grant the permission and still never reach the update again without
    // killing the app.
    final system = FakeAppUpdateSystem(canInstall: false);
    await _pump(
      tester,
      const AppUpdateState(
        status: AppUpdateStatus.error,
        error: AppUpdateError.permission,
        release: AppRelease(
          versionCode: 7,
          versionName: '1.2.0',
          apkUrl: 'https://example.invalid/a.apk',
          sha256: 'aa',
          notes: '',
        ),
      ),
      system: system,
    );

    await tester.tap(find.text('Mở cài đặt'));
    await tester.pumpAndSettle();

    expect(system.permissionScreenOpened, 1);
    expect(find.text('Mở cài đặt'), findsNothing);
    expect(find.text('Có bản mới 1.2.0'), findsOneWidget);
    expect(find.text('Cập nhật'), findsOneWidget);
  });

  testWidgets(
    'a_cancelled_install_offers_reinstall_and_reuses_the_verified_file_'
    'instead_of_a_fresh_download',
    (tester) async {
      // F1: dismissing the system confirmation dialog is not a rejection.
      // The row must keep the downloaded file and word the copy as a
      // cancellation, not "the system rejected this update".
      final system = FakeAppUpdateSystem();
      final downloader = FakeApkDownloader();
      await _pump(
        tester,
        const AppUpdateState(
          status: AppUpdateStatus.error,
          error: AppUpdateError.installCancelled,
          downloadedPath: '/tmp/updates/youcar-7.apk',
        ),
        system: system,
        downloader: downloader,
      );

      expect(
        find.text('Bạn đã huỷ cài đặt. Nhấn để cài lại tệp đã tải.'),
        findsOneWidget,
      );
      expect(find.text('Cài đặt lại'), findsOneWidget);
      expect(
        find.text(
          'Hệ thống đã từ chối bản cập nhật này. Hãy kiểm tra lại bản mới.',
        ),
        findsNothing,
      );

      await tester.tap(find.text('Cài đặt lại'));
      await tester.pumpAndSettle();

      expect(system.installApkCallCount, 1);
      expect(system.installedPath, '/tmp/updates/youcar-7.apk');
      expect(downloader.callCount, 0);
    },
  );

  testWidgets(
    'a_rejected_package_offers_a_fresh_check_rather_than_reinstalling_the_'
    'same_doomed_file',
    (tester) async {
      // I2/C1: the system installer refused this APK (bad signature, package
      // conflict). Reopening it on the same file fails identically forever.
      final repository = FakeAppUpdateRepository();
      await _pump(
        tester,
        const AppUpdateState(
          status: AppUpdateStatus.error,
          error: AppUpdateError.installRejected,
        ),
        repository: repository,
      );

      expect(
        find.text(
          'Hệ thống đã từ chối bản cập nhật này. Hãy kiểm tra lại bản mới.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cài đặt lại'), findsNothing);

      await tester.tap(find.text('Kiểm tra cập nhật'));
      await tester.pumpAndSettle();

      // The press really re-checked the backend.
      expect(repository.callCount, 1);
    },
  );

  testWidgets('a_confirmed_install_says_so_only_once_the_platform_reports_it', (
    tester,
  ) async {
    await _pump(
      tester,
      const AppUpdateState(status: AppUpdateStatus.installed),
    );

    expect(find.text('Đã cập nhật xong'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Kiểm tra cập nhật'), findsOneWidget);
  });
}
