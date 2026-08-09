import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/core/theme/app_icons.dart';
import 'package:viet_ktv/features/history/presentation/pages/history_page.dart';
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

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1920, 1080);
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
        home: const SongBrowserPage(source: _source),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _enterFullscreen(WidgetTester tester) async {
  await tester.tap(find.byIcon(AppIcons.fullscreen));
  await tester.pumpAndSettle();
}

/// The icon of the single transport button currently holding focus, or null
/// when focus sits on a scope rather than on one button.
IconData? _focusedIcon(WidgetTester tester) {
  final focusedContext = primaryFocus?.context;
  if (focusedContext == null) {
    return null;
  }
  final icons = find.descendant(
    of: find.byElementPredicate((e) => identical(e, focusedContext)),
    matching: find.byType(Icon),
  );
  if (icons.evaluate().length != 1) {
    return null;
  }
  return tester.widget<Icon>(icons).icon;
}

/// The player wrapper's own focus node — the one that owns the remote
/// shortcuts and sits above every transport button.
FocusNode _playerWrapperNode(WidgetTester tester) => tester
    .widgetList<Focus>(find.byType(Focus, skipOffstage: false))
    .map((focus) => focus.focusNode)
    .whereType<FocusNode>()
    .firstWhere((node) => node.debugLabel == 'previewPlayer');

void main() {
  testWidgets('controls_are_visible_on_entering_fullscreen', (tester) async {
    await _pump(tester);
    await _enterFullscreen(tester);

    expect(find.byIcon(AppIcons.fullscreenExit), findsOneWidget);
  });

  testWidgets('controls_hide_after_the_delay_in_fullscreen', (tester) async {
    await _pump(tester);
    await _enterFullscreen(tester);

    await tester.pump(kControlsAutoHideDelay + const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byIcon(AppIcons.fullscreenExit), findsNothing);
  });

  testWidgets('tapping_reveals_hidden_controls', (tester) async {
    await _pump(tester);
    await _enterFullscreen(tester);
    await tester.pump(kControlsAutoHideDelay + const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.tapAt(tester.getCenter(find.byType(PreviewPlayer)));
    await tester.pumpAndSettle();

    expect(find.byIcon(AppIcons.fullscreenExit), findsOneWidget);
  });

  testWidgets('a_key_press_reveals_hidden_controls', (tester) async {
    // Remote users have no touchscreen; a D-pad press must bring the exit
    // button back or they are stranded in fullscreen.
    await _pump(tester);
    await _enterFullscreen(tester);
    await tester.pump(kControlsAutoHideDelay + const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    expect(find.byIcon(AppIcons.fullscreenExit), findsOneWidget);
  });

  testWidgets('controls_never_auto_hide_outside_fullscreen', (tester) async {
    await _pump(tester);

    await tester.pump(kControlsAutoHideDelay + const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byIcon(AppIcons.fullscreen), findsOneWidget);
  });

  testWidgets('disposing_while_fullscreen_cancels_the_timer', (tester) async {
    await _pump(tester);
    await _enterFullscreen(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    // Deliberately less than the auto-hide delay: a timer that was not
    // cancelled in dispose() is still pending at teardown, and the test
    // binding fails the test for it. Pumping past the delay instead would
    // let the timer fire and complete, leaving nothing to detect.
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });

  testWidgets('two_mounted_players_can_enter_fullscreen', (tester) async {
    // `mode` lives in the app-wide nowPlayingProvider and pushed routes keep
    // their state, so entering fullscreen builds the overlay on both the
    // visible page and the one underneath at the same time.
    await _pump(tester);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    unawaited(
      navigator.push(
        MaterialPageRoute<void>(builder: (_) => const HistoryPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byType(PreviewPlayer, skipOffstage: false),
      findsNWidgets(2),
      reason: 'both players must stay mounted for this to be a real repro',
    );

    await _enterFullscreen(tester);

    expect(tester.takeException(), isNull);
    expect(find.byIcon(AppIcons.fullscreenExit), findsOneWidget);
  });

  testWidgets('touching_the_transport_strip_restarts_the_hide_timer', (
    tester,
  ) async {
    // A touch user tapping a control just before the auto-hide must not watch
    // the strip fade out from under their finger.
    await _pump(tester);
    await _enterFullscreen(tester);

    await tester.pump(kControlsAutoHideDelay - const Duration(seconds: 1));
    await tester.tap(find.byIcon(AppIcons.repeatOne));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.byIcon(AppIcons.fullscreenExit), findsOneWidget);
  });

  testWidgets('revealing_the_controls_restores_focus_to_play_pause', (
    tester,
  ) async {
    // Hiding the controls drops whatever held focus. Without a restore, the
    // remote user reveals the strip but has nothing focused to act on.
    //
    // The target is deliberately play/pause, not the exit-fullscreen button:
    // FocusableTile's ActivateIntent claims Enter, so if the exit button held
    // focus after a reveal, the next Enter would exit fullscreen instead of
    // toggling playback — Enter has always meant play/pause on this player.
    await _pump(tester);
    await _enterFullscreen(tester);
    await tester.pump(kControlsAutoHideDelay + const Duration(seconds: 1));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();

    final focusedContext = primaryFocus?.context;
    expect(focusedContext, isNotNull);
    // Deliberately not "the play/pause icon is somewhere below the focused
    // node": when focus sits on the enclosing modal scope that is trivially
    // true, since the whole page is below it. Requiring the focused subtree
    // to hold exactly one icon pins focus to a single transport button.
    final iconsBelowFocus = find.descendant(
      of: find.byElementPredicate((e) => identical(e, focusedContext)),
      matching: find.byType(Icon),
    );
    expect(
      iconsBelowFocus,
      findsOneWidget,
      reason: 'focus should sit on a single transport control, not a scope',
    );
    expect(tester.widget<Icon>(iconsBelowFocus).icon, AppIcons.play);
  });

  testWidgets('entering_fullscreen_moves_focus_onto_the_player', (
    tester,
  ) async {
    // The player's key handler only sees events on the focus chain. If focus
    // stays on the enclosing route scope after entering fullscreen, the first
    // remote press is swallowed above the player.
    //
    // Focus lands on the play/pause button rather than on the player wrapper:
    // the wrapper's rect is the whole viewport, and directional traversal only
    // keeps candidates whose centre lies past the focused rect's matching
    // edge, so from the wrapper every control — all inside that rect — is
    // filtered out in all four directions and the D-pad goes nowhere. The
    // wrapper stays on the focus chain above the button either way, so its key
    // handler still sees every press.
    await _pump(tester);
    await _enterFullscreen(tester);

    expect(_focusedIcon(tester), AppIcons.play);
    expect(_playerWrapperNode(tester).hasFocus, isTrue);
  });

  testWidgets('d_pad_reaches_the_exit_button_straight_after_entering', (
    tester,
  ) async {
    // Deliberately no auto-hide wait: this is the state the user is actually
    // in the instant they press the fullscreen button, controls up and never
    // yet hidden. While focus started on the full-viewport player wrapper,
    // no arrow key moved it at all, so the exit button was undiscoverable by
    // remote — and every press re-revealed the controls, so the auto-hide (and
    // with it the reveal path that restores focus to a button) never fired.
    await _pump(tester);
    await _enterFullscreen(tester);

    final start = primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(
      primaryFocus,
      isNot(same(start)),
      reason: 'the very first arrow press must move focus somewhere',
    );

    var reached = _focusedIcon(tester) == AppIcons.fullscreenExit;
    for (var press = 0; press < 8 && !reached; press++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      reached = _focusedIcon(tester) == AppIcons.fullscreenExit;
    }

    expect(
      reached,
      isTrue,
      reason: 'exit-fullscreen must be reachable by arrowing right',
    );
  });

  testWidgets('arrow_right_can_traverse_from_play_pause_to_the_exit_button', (
    tester,
  ) async {
    // The remote user's only way out of fullscreen is the exit button, and the
    // transport row puts it right of play/pause. While the player wrapper
    // claimed every arrowRight as "next song" — even ones bubbling up from a
    // focused button — focus could never move right, so nothing past
    // play/pause was reachable with a D-pad.
    await _pump(tester);
    await _enterFullscreen(tester);
    await tester.pump(kControlsAutoHideDelay + const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // A reveal puts focus on play/pause, the remote user's starting point.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(_focusedIcon(tester), AppIcons.play);

    var reached = false;
    for (var press = 0; press < 8 && !reached; press++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pumpAndSettle();
      reached = _focusedIcon(tester) == AppIcons.fullscreenExit;
    }

    expect(
      reached,
      isTrue,
      reason: 'exit-fullscreen must be reachable by arrowing right',
    );
  });

  testWidgets(
    'enter_after_a_reveal_toggles_play_pause_and_does_not_exit_fullscreen',
    (tester) async {
      // The bug this guards against: if reveal() focused the exit-fullscreen
      // button, the next Enter would be claimed by FocusableTile's
      // ActivateIntent and exit fullscreen instead of pausing playback — a
      // karaoke singer pressing Enter to pause would be thrown out of
      // fullscreen entirely.
      await _pump(tester);
      await _enterFullscreen(tester);
      await tester.pump(kControlsAutoHideDelay + const Duration(seconds: 1));
      await tester.pumpAndSettle();

      // Reveal the hidden controls, same as a remote user pressing any key.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(SongBrowserPage));
      final mode = ProviderScope.containerOf(
        context,
      ).read(nowPlayingProvider).mode;
      expect(mode, PlayerViewMode.fullscreen);
    },
  );
}
