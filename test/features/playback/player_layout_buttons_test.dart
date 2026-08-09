import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/shared/widgets/liquid_glass.dart';
import 'package:viet_ktv/core/shared/widgets/surface_scope.dart';
import 'package:viet_ktv/core/theme/app_icons.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/preview_player.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/stage_backdrop.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
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

/// The glass rim framing the player's picture.
///
/// Anchored on the picture rather than counted under [PreviewPlayer]: every
/// transport button is itself a `LiquidGlass`, but none of them is an
/// *ancestor* of the picture, so only the panel chrome matches here.
Finder _surfaceGlass() => find.ancestor(
  of: find.byType(StageBackdrop),
  matching: find.descendant(
    of: find.byType(PreviewPlayer),
    matching: find.byType(LiquidGlass),
  ),
);

/// The rounded clip framing the player's picture.
Finder _surfaceClip() => find.ancestor(
  of: find.byType(StageBackdrop),
  matching: find.descendant(
    of: find.byType(PreviewPlayer),
    matching: find.byType(ClipRRect),
  ),
);

void main() {
  testWidgets('shows_both_layout_buttons', (tester) async {
    await _pump(tester);

    expect(find.byIcon(AppIcons.panelClose), findsOneWidget);
    expect(find.byIcon(AppIcons.fullscreen), findsOneWidget);
  });

  testWidgets('wide_button_switches_to_wide_mode', (tester) async {
    final container = await _pump(tester);

    await tester.tap(find.byIcon(AppIcons.panelClose));
    await tester.pumpAndSettle();

    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.wide);
    expect(find.byIcon(AppIcons.panelOpen), findsOneWidget);
  });

  testWidgets('fullscreen_button_switches_to_fullscreen_mode', (tester) async {
    final container = await _pump(tester);

    await tester.tap(find.byIcon(AppIcons.fullscreen));
    await tester.pumpAndSettle();

    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.fullscreen);
  });

  testWidgets('fullscreen_hides_the_top_and_bottom_bars', (tester) async {
    await _pump(tester);
    expect(find.text('TRANG CHỦ'), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.fullscreen));
    await tester.pumpAndSettle();

    expect(find.text('TRANG CHỦ'), findsNothing);
  });

  testWidgets('fullscreen_player_fills_the_whole_viewport', (tester) async {
    // The feature's whole promise. Previously the shell kept its padding and
    // the player kept its glass rim in fullscreen, so pressing the button just
    // grew a framed panel — a band of background stayed down every side.
    await _pump(tester);

    await tester.tap(find.byIcon(AppIcons.fullscreen));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(find.byType(PreviewPlayer)),
      const Rect.fromLTRB(0, 0, 1920, 1080),
    );
  });

  testWidgets('fullscreen_drops_the_panel_chrome_entirely', (tester) async {
    // The measured rect above cannot see this half of it: `LiquidGlass` adds
    // no outer margin, so re-wrapping the fullscreen surface in the rim and
    // the rounded clip leaves the rect at the full viewport while the picture
    // is quietly clipped and rimmed again. Assert on the widgets themselves.
    await _pump(tester);

    await tester.tap(find.byIcon(AppIcons.fullscreen));
    await tester.pumpAndSettle();

    expect(_surfaceGlass(), findsNothing);
    expect(_surfaceClip(), findsNothing);
  });

  testWidgets('normal_and_wide_frame_the_player_with_the_slab', (tester) async {
    // The song browser's content now sits inside one ContentSlab, which
    // paints the surface for the search field, the results panel and the
    // player together — the player no longer paints its own rim and rounded
    // clip (see `preview_player.dart`'s `SurfaceScope.of(context)` check). So
    // what separates the player from the rest of the page in the two
    // windowed modes is being a descendant of that shared slab, not chrome of
    // its own. A rect comparison cannot pin this down — the player is inset
    // in `normal` whether or not it is framed — so this asserts the slab
    // ancestry is really there.
    await _pump(tester);

    expect(
      find.ancestor(
        of: find.byType(PreviewPlayer),
        matching: find.byType(ContentSlab),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(AppIcons.panelClose));
    await tester.pumpAndSettle();

    expect(
      find.ancestor(
        of: find.byType(PreviewPlayer),
        matching: find.byType(ContentSlab),
      ),
      findsOneWidget,
    );

    // Fullscreen deliberately builds no slab (see
    // `fullscreen_builds_no_slab_around_the_player` in seamless_surface_test)
    // — back out to normal, then confirm entering fullscreen drops the
    // ancestry this test otherwise pins.
    await tester.tap(find.byIcon(AppIcons.panelOpen));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(AppIcons.fullscreen));
    await tester.pumpAndSettle();

    expect(
      find.ancestor(
        of: find.byType(PreviewPlayer),
        matching: find.byType(ContentSlab),
      ),
      findsNothing,
    );
  });

  testWidgets('normal_and_wide_stay_inset_from_the_viewport', (tester) async {
    // The inset only goes away in fullscreen; the other two modes sit inside
    // the shell next to the rest of the UI and keep their padding.
    await _pump(tester);
    final viewport = tester.getRect(find.byType(MaterialApp));

    expect(tester.getRect(find.byType(PreviewPlayer)), isNot(viewport));

    await tester.tap(find.byIcon(AppIcons.panelClose));
    await tester.pumpAndSettle();

    expect(tester.getRect(find.byType(PreviewPlayer)), isNot(viewport));
  });

  testWidgets('wide_mode_keeps_the_chrome_visible', (tester) async {
    // Wide only collapses the left column; the nav and hint bar stay.
    await _pump(tester);

    await tester.tap(find.byIcon(AppIcons.panelClose));
    await tester.pumpAndSettle();

    expect(find.text('TRANG CHỦ'), findsOneWidget);
  });

  testWidgets('fullscreen_toggle_keeps_the_same_preview_player_state', (
    tester,
  ) async {
    // The slab wraps and unwraps PreviewPlayer's ancestry on every
    // fullscreen toggle (see `normal_and_wide_frame_the_player_with_the_slab`
    // above and `SongBrowserPage._previewPlayerKey`). Without a stable
    // GlobalKey, Flutter cannot tell that the widget on both sides of the
    // toggle is "the same" player, tears down its State, and any deferred
    // logic keyed off `didUpdateWidget` (e.g. focusing the play/pause
    // button on entering fullscreen) never runs again. Pin the identity
    // directly instead of inferring it from a side effect.
    //
    // Exiting fullscreen is driven through the provider rather than a
    // button tap: fullscreen hides the top bar (which holds the fullscreen
    // toggle), so there is no visible exit button to tap here.
    final container = await _pump(tester);

    final beforeState = tester.state(find.byType(PreviewPlayer));

    await tester.tap(find.byIcon(AppIcons.fullscreen));
    await tester.pumpAndSettle();

    final duringFullscreenState = tester.state(find.byType(PreviewPlayer));
    expect(identical(beforeState, duringFullscreenState), isTrue);

    container.read(nowPlayingProvider.notifier).exitFullscreen();
    await tester.pumpAndSettle();

    final afterState = tester.state(find.byType(PreviewPlayer));
    expect(identical(beforeState, afterState), isTrue);
  });
}
