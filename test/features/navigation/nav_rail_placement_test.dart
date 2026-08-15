import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/shared/widgets/app_nav_rail.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/features/navigation/presentation/widgets/main_nav_rail.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/preview_player.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';
import 'package:viet_ktv/features/source_selection/presentation/pages/source_selection_page.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';

const _source = MusicSource(
  id: 'youtube',
  subtitle: 'Kho nhạc & Video\nkhổng lồ',
  accentColor: AppColors.red,
  logoStyle: MusicSourceLogoStyle.youtube,
);

const _viewportSize = Size(1920, 1080);

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = _viewportSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(
          FakeLocalStorageService(),
        ),
        musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
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
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('rail_is_pinned_to_the_left_edge_on_every_page', (tester) async {
    for (final home in [
      const SourceSelectionPage(),
      const SongBrowserPage(source: _source),
    ]) {
      await _pump(tester, home);

      final rail = tester.getRect(find.byType(AppNavRail));
      expect(
        rail.left,
        lessThan(_viewportSize.width * 0.05),
        reason: 'rail should hug the left edge on ${home.runtimeType}',
      );
      expect(
        rail.height,
        greaterThan(_viewportSize.height * 0.85),
        reason: 'rail should run the full height on ${home.runtimeType}',
      );
    }
  });

  testWidgets('rail_does_not_move_between_pages', (tester) async {
    await _pump(tester, const SourceSelectionPage());
    final pickerRail = tester.getRect(find.byType(AppNavRail));

    await _pump(tester, const SongBrowserPage(source: _source));
    final browserRail = tester.getRect(find.byType(AppNavRail));

    expect(browserRail, pickerRail);
  });

  testWidgets('rail_leaves_the_player_the_full_screen_height', (tester) async {
    // The reason navigation moved to the left in the first place: nothing is
    // stacked above or below the stage any more, so on a car screen the video
    // gets every vertical pixel the shell padding does not.
    await _pump(tester, const SongBrowserPage(source: _source));

    final player = tester.getRect(find.byType(PreviewPlayer));
    expect(player.height, greaterThan(_viewportSize.height * 0.9));
  });

  testWidgets('rail_shows_every_destination', (tester) async {
    await _pump(tester, const SongBrowserPage(source: _source));

    final rail = find.byType(MainNavRail);
    for (final label in const [
      'TRANG CHỦ',
      'TÌM BÀI',
      'DANH MỤC',
      'ĐÃ CHỌN',
      'Yêu thích',
      'KẾT NỐI ĐT',
      'CÀI ĐẶT',
      'THOÁT',
    ]) {
      expect(
        find.descendant(of: rail, matching: find.text(label)),
        findsOneWidget,
        reason: 'missing rail destination "$label"',
      );
    }
  });
}
