import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/preview_player.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';

const _source = MusicSource(
  id: 'youtube',
  subtitle: 'Kho nhạc & Video\nkhổng lồ',
  accentColor: AppColors.red,
  logoStyle: MusicSourceLogoStyle.youtube,
);

Future<ProviderContainer> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(FakeLocalStorageService()),
      musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SongBrowserPage(source: _source),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Double taps the picture at [fraction] of its width.
Future<void> _doubleTapAt(WidgetTester tester, double fraction) async {
  final rect = tester.getRect(find.byType(PreviewPlayer));
  // The picture occupies the upper part of the player; tap well above the
  // transport strip so the gesture lands on the video, not a control.
  final point = Offset(
    rect.left + rect.width * fraction,
    rect.top + rect.height * 0.3,
  );
  await tester.tapAt(point);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(point);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('double_tap_centre_enters_fullscreen', (tester) async {
    final container = await _pump(tester);

    await _doubleTapAt(tester, 0.5);

    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.fullscreen);
  });

  testWidgets('double_tap_centre_again_exits_to_the_originating_mode', (
    tester,
  ) async {
    final container = await _pump(tester);

    await _doubleTapAt(tester, 0.5);
    await _doubleTapAt(tester, 0.5);

    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.normal);
  });

  testWidgets('double_tap_no_longer_toggles_wide_mode', (tester) async {
    // Deliberate behaviour change: wide is reachable from its own button only.
    final container = await _pump(tester);

    await _doubleTapAt(tester, 0.5);

    expect(container.read(nowPlayingProvider).mode, isNot(PlayerViewMode.wide));
  });

  testWidgets('double_tap_left_and_right_do_not_change_the_mode', (
    tester,
  ) async {
    // Seeking with nothing playing is a no-op inside the controller, so the
    // observable contract here is that the layout is left alone.
    final container = await _pump(tester);

    await _doubleTapAt(tester, 0.15);
    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.normal);

    await _doubleTapAt(tester, 0.85);
    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.normal);
  });
}
