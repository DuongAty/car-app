import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/services/app_system_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('viet_ktv/system');
  final calls = <MethodCall>[];

  void handle(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return handler(call);
        });
  }

  setUp(calls.clear);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('system_info_exposes_the_numeric_version_code', () async {
    handle(
      (_) async => <Object?, Object?>{
        'networkStatus': 'WiFi',
        'deviceName': 'Test Box',
        'androidVersion': 'Android 13 (API 33)',
        'appVersion': '1.2.0',
        'appVersionCode': 7,
        'storageSummary': '1.0GB / 8.0GB',
      },
    );

    final info = await const AppSystemService().getSystemInfo();

    expect(info.appVersionCode, 7);
    expect(info.appVersion, '1.2.0');
  });

  test(
    'missing_version_code_falls_back_to_zero_so_any_release_is_newer',
    () async {
      handle((_) async => <Object?, Object?>{'appVersion': '1.2.0'});

      final info = await const AppSystemService().getSystemInfo();

      expect(info.appVersionCode, 0);
    },
  );

  test('install_apk_passes_the_path_to_the_platform', () async {
    handle((_) async => null);

    await const AppSystemService().installApk('/data/cache/update.apk');

    expect(calls.single.method, 'installApk');
    expect(calls.single.arguments, <String, Object?>{
      'path': '/data/cache/update.apk',
    });
  });

  test('can_install_packages_reports_false_when_the_platform_errors', () async {
    handle((_) async => throw PlatformException(code: 'boom'));

    expect(await const AppSystemService().canInstallPackages(), isFalse);
  });
}
