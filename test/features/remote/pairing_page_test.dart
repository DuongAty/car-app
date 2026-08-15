import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/providers/volume_provider.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/remote/data/models/pairing_result.dart';
import 'package:viet_ktv/features/remote/presentation/pages/pairing_page.dart';
import 'package:viet_ktv/features/remote/presentation/providers/pairing_controller.dart';
import 'package:viet_ktv/features/remote/presentation/providers/remote_session_provider.dart';
import 'package:viet_ktv/features/remote/presentation/widgets/pairing_qr_view.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import '../../support/fake_audio_track_player.dart';
import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';
import '../../support/fake_pairing_repository.dart';
import '../../support/fake_remote_channel.dart';
import '../../support/fake_volume_service.dart';

Future<void> _pumpPage(
  WidgetTester tester, {
  required FakePairingRepository repository,
}) async {
  await tester.binding.setSurfaceSize(const Size(1366, 768));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(
          FakeLocalStorageService(),
        ),
        musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
        audioTrackPlayerFactoryProvider.overrideWithValue(
          FakeAudioTrackPlayer.new,
        ),
        volumeServiceProvider.overrideWithValue(FakeVolumeService()),
        remoteChannelProvider.overrideWithValue(FakeRemoteChannel()),
        pairingRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(
        locale: Locale('vi'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: PairingPage(),
      ),
    ),
  );
  // The controller asks the device for its label before calling the RPC, and
  // that lookup is bounded by a 2s timeout with no platform channel in tests.
  await tester.pump();
  await tester.pump(const Duration(seconds: 3));
  await tester.pump();
}

void main() {
  testWidgets('shows_the_qr_and_the_six_digit_code', (tester) async {
    final repository = FakePairingRepository();

    await _pumpPage(tester, repository: repository);

    expect(repository.createCount, 1);
    expect(find.byType(PairingQrView), findsOneWidget);
    // Grouped 3+3 so it can be read out across a car cabin.
    expect(find.text('123 456'), findsOneWidget);
    expect(
      tester.widget<PairingQrView>(find.byType(PairingQrView)).data,
      'wektv://pair?code=123456',
    );
  });

  testWidgets('shows_a_localized_error_when_the_backend_is_unreachable', (
    tester,
  ) async {
    final repository = FakePairingRepository(
      codeResult: const PairingCodeFailure(
        PairingFailureKind.network,
        'socket',
      ),
    );

    await _pumpPage(tester, repository: repository);

    expect(find.byType(PairingQrView), findsNothing);
    expect(
      find.text('Không kết nối được máy chủ. Kiểm tra mạng rồi thử lại.'),
      findsOneWidget,
    );
  });

  testWidgets('disconnect_rotates_the_pairing_secret', (tester) async {
    final repository = FakePairingRepository();

    await _pumpPage(tester, repository: repository);
    await tester.tap(find.text('Ngắt kết nối điện thoại'));
    await tester.pump();
    await tester.pump();

    expect(repository.resetCount, 1);
    expect(find.byType(PairingQrView), findsNothing);
  });

  test('the_qr_payload_format_is_the_phone_apps_contract', () {
    expect(pairingQrPayload('987654'), 'wektv://pair?code=987654');
  });
}
