import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/core/theme/app_icons.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
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

/// Simulates the Android system back gesture/button.
Future<void> _pressBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('back_exits_fullscreen_instead_of_popping', (tester) async {
    final container = await _pump(tester);
    await tester.tap(find.byIcon(AppIcons.fullscreen));
    await tester.pumpAndSettle();

    await _pressBack(tester);

    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.normal);
    expect(find.byType(SongBrowserPage), findsOneWidget);
  });

  testWidgets('back_from_fullscreen_entered_from_wide_returns_to_wide', (
    tester,
  ) async {
    final container = await _pump(tester);
    await tester.tap(find.byIcon(AppIcons.panelClose));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(AppIcons.fullscreen));
    await tester.pumpAndSettle();

    await _pressBack(tester);

    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.wide);
  });

  testWidgets('exit_button_restores_the_chrome', (tester) async {
    await _pump(tester);
    await tester.tap(find.byIcon(AppIcons.fullscreen));
    await tester.pumpAndSettle();
    expect(find.text('TRANG CHỦ'), findsNothing);

    await tester.tap(find.byIcon(AppIcons.fullscreenExit));
    await tester.pumpAndSettle();

    expect(find.text('TRANG CHỦ'), findsOneWidget);
  });
}
