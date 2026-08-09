import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/shared/widgets/liquid_glass.dart';
import 'package:viet_ktv/core/shared/widgets/surface_scope.dart';
import 'package:viet_ktv/core/shared/widgets/panel_frame.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/features/history/presentation/pages/history_page.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/native_song_search_field.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/preview_player.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/search_results_panel.dart';
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

int _chipSurfaces(WidgetTester tester) => tester
    .widgetList<LiquidGlass>(find.byType(LiquidGlass))
    .where((glass) => glass.detail == LiquidGlassDetail.simple)
    .length;

Future<ProviderContainer> _pump(WidgetTester tester, Widget home) async {
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
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('normal_mode_has_one_panel_surface_for_the_content', (
    tester,
  ) async {
    // Counting LiquidGlass(detail: full) is the wrong proxy: the floating
    // status chips over the video also default to `full`, so the count no
    // longer says "one panel". Assert the structural fact directly instead —
    // exactly one ContentSlab, with the search field, the results panel and
    // the player all inside it. That is precisely "the islands became one".
    await _pump(tester, const SongBrowserPage(source: _source));

    expect(find.byType(ContentSlab), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ContentSlab),
        matching: find.byType(NativeSongSearchField),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ContentSlab),
        matching: find.byType(SearchResultsPanel),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ContentSlab),
        matching: find.byType(PreviewPlayer),
      ),
      findsOneWidget,
    );
  });

  testWidgets('normal_mode_draws_a_vertical_hairline_between_the_columns', (
    tester,
  ) async {
    await _pump(tester, const SongBrowserPage(source: _source));

    final vertical = tester
        .widgetList<SurfaceDivider>(find.byType(SurfaceDivider))
        .where((divider) => divider.axis == Axis.vertical);
    expect(vertical.length, 1);
  });

  testWidgets('wide_mode_drops_the_vertical_hairline_with_the_column', (
    tester,
  ) async {
    // It must collapse with the column, not linger down the player's edge.
    final container = await _pump(
      tester,
      const SongBrowserPage(source: _source),
    );

    container.read(nowPlayingProvider.notifier).toggleWide();
    await tester.pumpAndSettle();

    final vertical = tester
        .widgetList<SurfaceDivider>(find.byType(SurfaceDivider))
        .where((divider) => divider.axis == Axis.vertical);
    expect(vertical, isEmpty);
  });

  testWidgets('fullscreen_builds_no_slab_around_the_player', (tester) async {
    // Continues the existing fullscreen contract: a slab here would restore
    // the rounded frame that fullscreen exists to remove. Assert the
    // structural fact directly rather than counting LiquidGlass surfaces —
    // the floating status chips over the video also count as `full` and are
    // not part of this contract.
    final container = await _pump(
      tester,
      const SongBrowserPage(source: _source),
    );

    container.read(nowPlayingProvider.notifier).enterFullscreen();
    await tester.pumpAndSettle();

    expect(find.byType(ContentSlab), findsNothing);
  });

  testWidgets('small_chips_keep_their_own_surfaces', (tester) async {
    // Guards against a future change absorbing per-item chips into the slab.
    await _pump(tester, const SongBrowserPage(source: _source));

    expect(_chipSurfaces(tester), greaterThan(0));
  });

  testWidgets('an_unconverted_screen_still_frames_its_panels', (tester) async {
    // Proves SurfaceScope does not leak past the browser. HistoryPage is
    // favorites' structural twin and, unlike favorites, is still on the old
    // floating-panel look — it stands in for "any screen never converted".
    //
    // `_panelSurfaces(tester) > 1` alone is not a tight enough check here:
    // the shell's own chrome (top nav, bottom hint bar) already contributes
    // several full-detail LiquidGlass surfaces regardless of whether the
    // content area was converted, so that count would stay >1 even for a
    // converted screen. Assert the actual mechanism instead — PanelFrame
    // still paints its own surface because it never finds a SurfaceScope
    // above it. This goes red the moment HistoryPage is converted, since
    // conversion is exactly what makes PanelFrame render bare.
    await _pump(tester, const HistoryPage());

    final panelFrameSurfaces = tester
        .widgetList<LiquidGlass>(
          find.descendant(
            of: find.byType(PanelFrame),
            matching: find.byType(LiquidGlass),
          ),
        )
        .where((glass) => glass.detail == LiquidGlassDetail.full);
    expect(panelFrameSurfaces, isNotEmpty);
  });
}
