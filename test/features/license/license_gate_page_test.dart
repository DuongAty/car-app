import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/features/license/data/models/license_rpc_result.dart';
import 'package:viet_ktv/features/license/presentation/pages/license_gate_page.dart';
import 'package:viet_ktv/features/license/presentation/providers/license_controller.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import '../../support/fake_license_repository.dart';
import '../../support/fake_local_storage_service.dart';

const _systemChannel = MethodChannel('viet_ktv/system');

Future<void> _pumpGate(
  WidgetTester tester, {
  required FakeLicenseRepository repository,
  FakeLocalStorageService? storage,
  VoidCallback? onUnlocked,
}) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  // getDeviceLabel() reads this channel when a key is submitted; without a
  // handler an unimplemented platform channel hangs forever in flutter_test
  // rather than throwing, which would wedge submitKey() mid-flight.
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    _systemChannel,
    (call) async => <String, Object?>{
      'deviceName': 'Test Device',
      'androidVersion': 'Android 13 (API 33)',
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      _systemChannel,
      null,
    ),
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(
          storage ?? FakeLocalStorageService(),
        ),
        licenseRepositoryProvider.overrideWithValue(repository),
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
        home: LicenseGatePage(onUnlocked: onUnlocked ?? () {}),
      ),
    ),
  );
  await _settle(tester);
}

/// A few bounded pumps rather than `pumpAndSettle`: the pending/checking
/// screens show an indeterminate `CircularProgressIndicator`, whose repeating
/// animation never settles and would hang `pumpAndSettle` forever.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 20));
  }
}

/// Enters [key] through the device-native text field.
Future<void> _type(WidgetTester tester, String key) async {
  await tester.enterText(
    find.byKey(const ValueKey('licenseUserNameField')),
    'Nguyen Van A',
  );
  await tester.enterText(
    find.byKey(const ValueKey('licenseNativeKeyField')),
    key,
  );
  await tester.pump();
}

void main() {
  testWidgets('shows_native_key_input_when_no_key_saved', (tester) async {
    await _pumpGate(tester, repository: FakeLicenseRepository());

    expect(find.text('Nhập mã bản quyền'), findsOneWidget);
    expect(find.text('KÍCH HOẠT'), findsOneWidget);
    expect(find.byKey(const ValueKey('licenseNativeKeyField')), findsOneWidget);
  });

  testWidgets('typing_a_key_and_submitting_shows_pending_screen', (
    tester,
  ) async {
    final repository = FakeLicenseRepository(
      requestResult: LicenseRpcResult.pending,
    );
    await _pumpGate(tester, repository: repository);

    await _type(tester, 'ABC123');
    await tester.tap(find.text('KÍCH HOẠT'));
    await _settle(tester);

    expect(repository.lastRequestedKey, 'ABC123');
    expect(repository.lastRequestedUserName, 'Nguyen Van A');
    expect(find.text('Đang chờ quản lý duyệt'), findsOneWidget);
    expect(find.text('ABC123'), findsOneWidget);
  });

  testWidgets('requires a user name before submitting a key', (tester) async {
    final repository = FakeLicenseRepository();
    await _pumpGate(tester, repository: repository);

    await tester.enterText(
      find.byKey(const ValueKey('licenseNativeKeyField')),
      'ABC123',
    );
    await tester.tap(find.text('KÍCH HOẠT'));
    await _settle(tester);

    expect(
      find.text('Nhập tên người dùng trước khi kích hoạt.'),
      findsOneWidget,
    );
    expect(repository.lastRequestedKey, isNull);
  });

  testWidgets('submitting_a_locked_key_shows_locked_screen', (tester) async {
    final repository = FakeLicenseRepository(
      requestResult: LicenseRpcResult.locked,
    );
    await _pumpGate(tester, repository: repository);

    await _type(tester, 'LOCKED1');
    await tester.tap(find.text('KÍCH HOẠT'));
    await _settle(tester);

    expect(find.text('Key đã bị khoá'), findsOneWidget);
    expect(find.text('Kiểm tra lại'), findsOneWidget);
    expect(find.text('Nhập key khác'), findsOneWidget);
  });

  testWidgets('submitting_an_expired_key_shows_expired_screen', (tester) async {
    final repository = FakeLicenseRepository(
      requestResult: LicenseRpcResult.expired,
    );
    await _pumpGate(tester, repository: repository);

    await _type(tester, 'OLDKEY1');
    await tester.tap(find.text('KÍCH HOẠT'));
    await _settle(tester);

    expect(find.text('Key đã hết hạn'), findsOneWidget);
    expect(find.text('Kiểm tra lại'), findsOneWidget);
    expect(find.text('Nhập key khác'), findsOneWidget);
  });

  testWidgets('submitting_an_unknown_key_shows_inline_error', (tester) async {
    final repository = FakeLicenseRepository(
      requestResult: LicenseRpcResult.notFound,
    );
    await _pumpGate(tester, repository: repository);

    await _type(tester, 'GHOST1');
    await tester.tap(find.text('KÍCH HOẠT'));
    await _settle(tester);

    expect(find.text('Key không tồn tại'), findsOneWidget);
    // Still on the input screen, not stuck on a full-screen error.
    expect(find.text('Nhập mã bản quyền'), findsOneWidget);
  });

  testWidgets('a_previously_activated_device_unlocks_automatically', (
    tester,
  ) async {
    var unlocked = false;
    final storage = FakeLocalStorageService()
      ..store['license_key_code_v1'] = 'SAVED-KEY';
    final repository = FakeLicenseRepository(
      checkResult: LicenseRpcResult.activeSelf,
    );

    await _pumpGate(
      tester,
      repository: repository,
      storage: storage,
      onUnlocked: () => unlocked = true,
    );

    expect(repository.lastCheckedKey, 'SAVED-KEY');
    expect(unlocked, isTrue);
  });

  testWidgets('change_key_button_on_pending_screen_returns_to_input', (
    tester,
  ) async {
    final repository = FakeLicenseRepository(
      requestResult: LicenseRpcResult.pending,
    );
    await _pumpGate(tester, repository: repository);

    await _type(tester, 'ABC123');
    await tester.tap(find.text('KÍCH HOẠT'));
    await _settle(tester);
    expect(find.text('Đang chờ quản lý duyệt'), findsOneWidget);

    await tester.tap(find.text('Nhập key khác'));
    await _settle(tester);

    expect(find.text('Nhập mã bản quyền'), findsOneWidget);
  });

  testWidgets('system back cannot leave the license gate', (tester) async {
    await _pumpGate(tester, repository: FakeLicenseRepository());

    await tester.binding.handlePopRoute();
    await _settle(tester);

    expect(find.text('Nhập mã bản quyền'), findsOneWidget);
  });
}
