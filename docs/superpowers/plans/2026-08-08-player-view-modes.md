# Player View Modes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the player's single "expanded" state into a wide mode and a real
fullscreen mode, each with its own button, with auto-hiding controls and three
ways out of fullscreen.

**Architecture:** `NowPlayingState.isExpanded` becomes a three-value
`PlayerViewMode` enum so contradictory states are unrepresentable. `KaraokeShell`
gains the ability to drop its top and bottom bars from the widget tree. In
fullscreen the transport strip moves from being a `Column` sibling below the
video to an overlay on top of it, so auto-hiding never re-lays-out the video.

**Tech Stack:** Flutter, Riverpod (`StateNotifier`), `material_symbols_icons`,
`SystemChrome`.

**Spec:** `docs/superpowers/specs/2026-08-08-player-view-modes-design.md`

## Global Constraints

- **Do not run any git write command.** No `git add`, `git commit`, `git push`,
  `git stash`, `git checkout`, `git restore`, `git clean`. The user manages git
  themselves. This overrides the usual per-task commit step; every task ends at
  "tests pass".
- **Do not run `dart format .`** — it reformats the whole repo, including the
  user's unrelated uncommitted work. Format only the files you touch, naming
  each explicitly.
- `flutter analyze` must report "No issues found!" and the full suite must stay
  green. 165 tests pass before this plan starts.
- Android 10 (API 29) minimum. Primary targets: 2GB RAM Android TV/karaoke boxes
  and car head units. Landscape is the primary layout; D-pad, remote, and touch
  are all first-class.
- No continuous background animation. One-shot transitions are fine; per-frame
  or looping animation is not.
- Never `ref.watch` a volatile setting inside `nowPlayingProvider`'s create body
  — it disposes the live decoder. Seed with `ref.read`, apply via `ref.listen`.
- Watch the narrowest slice with `.select`; never `ref.watch` a whole provider at
  a page root.
- Tests use snake_case behavioural names. Tests that build `songBrowserProvider`
  must override `localStorageServiceProvider` with `FakeLocalStorageService`.
- Tokens first: no hardcoded colors, spacing, radius, or text styles in feature
  screens. Extend `lib/core/theme/*` instead.

---

### Task 1: PlayerViewMode enum replaces isExpanded

Mechanical but wide-reaching. Doing it first means every later task works
against the final state shape.

**Files:**
- Modify: `lib/features/playback/presentation/providers/now_playing_controller.dart`
- Modify: `lib/features/song_browser/presentation/pages/song_browser_page.dart:81-82,186`
- Modify: `lib/features/favorites/presentation/pages/favorites_page.dart:30-31,43`
- Modify: `lib/features/queue/presentation/pages/selected_queue_page.dart:24-25,37`
- Modify: `lib/features/history/presentation/pages/history_page.dart:30-31,43`
- Modify: `lib/features/song_browser/presentation/widgets/preview_player.dart:63-64,98,145-146,369,381,458`
- Test: `test/features/playback/player_view_mode_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum PlayerViewMode { normal, wide, fullscreen }` exported from
    `now_playing_controller.dart`.
  - `NowPlayingState.mode` (`PlayerViewMode`, default `PlayerViewMode.normal`),
    replacing `isExpanded`.
  - `NowPlayingController.toggleWide()`, `enterFullscreen()`, `exitFullscreen()`.

- [ ] **Step 1: Write the failing test**

Create `test/features/playback/player_view_mode_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';

import '../../support/fake_audio_track_player.dart';
import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';

ProviderContainer _container() {
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(FakeLocalStorageService()),
      musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
      audioTrackPlayerFactoryProvider.overrideWithValue(
        FakeAudioTrackPlayer.new,
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('starts_in_normal_mode', () {
    final container = _container();

    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.normal);
  });

  test('toggle_wide_switches_between_normal_and_wide', () {
    final container = _container();
    final controller = container.read(nowPlayingProvider.notifier);

    controller.toggleWide();
    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.wide);

    controller.toggleWide();
    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.normal);
  });

  test('exiting_fullscreen_returns_to_normal_when_entered_from_normal', () {
    final container = _container();
    final controller = container.read(nowPlayingProvider.notifier);

    controller.enterFullscreen();
    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.fullscreen);

    controller.exitFullscreen();
    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.normal);
  });

  test('exiting_fullscreen_returns_to_wide_when_entered_from_wide', () {
    // The user widened the player deliberately; dropping them back to the
    // narrow layout on exit would silently undo that.
    final container = _container();
    final controller = container.read(nowPlayingProvider.notifier);
    controller.toggleWide();

    controller.enterFullscreen();
    controller.exitFullscreen();

    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.wide);
  });

  test('entering_fullscreen_twice_does_not_lose_the_origin_mode', () {
    final container = _container();
    final controller = container.read(nowPlayingProvider.notifier);
    controller.toggleWide();

    controller.enterFullscreen();
    controller.enterFullscreen();
    controller.exitFullscreen();

    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.wide);
  });

  test('exiting_fullscreen_when_not_fullscreen_is_a_no_op', () {
    final container = _container();
    final controller = container.read(nowPlayingProvider.notifier);
    controller.toggleWide();

    controller.exitFullscreen();

    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.wide);
  });

  test('toggle_wide_from_fullscreen_leaves_fullscreen_for_wide', () {
    // Reaching the wide button at all means the controls are visible, so this
    // is a deliberate press and should be honoured rather than ignored.
    final container = _container();
    final controller = container.read(nowPlayingProvider.notifier);
    controller.enterFullscreen();

    controller.toggleWide();

    expect(container.read(nowPlayingProvider).mode, PlayerViewMode.wide);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/playback/player_view_mode_test.dart`
Expected: FAIL — "Undefined name 'PlayerViewMode'" and "The getter 'mode' isn't defined for the class 'NowPlayingState'".

- [ ] **Step 3: Add the enum and state field**

In `now_playing_controller.dart`, add above `sealed class PlaybackState`:

```dart
/// How much of the screen the player occupies.
///
/// A single enum rather than two booleans: "expanded and fullscreen at the same
/// time" has no defined meaning, and an enum makes it unrepresentable.
enum PlayerViewMode {
  /// Search/results column on the left, player on the right.
  normal,

  /// Left column collapsed, player full width. App chrome still visible.
  wide,

  /// Player owns the whole screen; top nav and bottom bar are gone.
  fullscreen,
}
```

Replace the `isExpanded` field declaration (line 88 in the constructor and line
102) with:

```dart
    this.mode = PlayerViewMode.normal,
```

and

```dart
  /// Theater mode: shared so a mode chosen on one screen survives navigating
  /// to another.
  final PlayerViewMode mode;
```

- [ ] **Step 4: Update every state reconstruction**

There are 11 occurrences of `isExpanded: state.isExpanded,` in this file. Replace
each with:

```dart
      mode: state.mode,
```

Run `grep -n "isExpanded" lib/features/playback/presentation/providers/now_playing_controller.dart` afterwards and confirm it returns nothing.

- [ ] **Step 5: Replace toggleExpanded with the three mode methods**

Replace the whole `toggleExpanded` method with:

```dart
  /// Remembers where fullscreen was entered from, so leaving it restores that
  /// layout instead of always dropping back to [PlayerViewMode.normal].
  PlayerViewMode _modeBeforeFullscreen = PlayerViewMode.normal;

  void toggleWide() {
    _setMode(
      state.mode == PlayerViewMode.wide
          ? PlayerViewMode.normal
          : PlayerViewMode.wide,
    );
  }

  void enterFullscreen() {
    if (state.mode == PlayerViewMode.fullscreen) {
      return;
    }
    _modeBeforeFullscreen = state.mode;
    _setMode(PlayerViewMode.fullscreen);
  }

  void exitFullscreen() {
    if (state.mode != PlayerViewMode.fullscreen) {
      return;
    }
    _setMode(_modeBeforeFullscreen);
  }

  void _setMode(PlayerViewMode mode) {
    state = NowPlayingState(
      playback: state.playback,
      activeSource: state.activeSource,
      mode: mode,
      videoController: state.videoController,
      visualizerController: state.visualizerController,
      audioPlayer: state.audioPlayer,
      audioPosition: state.audioPosition,
      audioDuration: state.audioDuration,
      audioIsPlaying: state.audioIsPlaying,
    );
  }
```

- [ ] **Step 6: Update the four consuming pages**

In each of `song_browser_page.dart`, `favorites_page.dart`,
`selected_queue_page.dart`, and `history_page.dart`, replace the selector:

```dart
    final mode = ref.watch(nowPlayingProvider.select((value) => value.mode));
```

and the collapse argument:

```dart
                      collapsed: mode != PlayerViewMode.normal,
```

Both `wide` and `fullscreen` hide the left column, so one comparison covers both.
Add the import for `PlayerViewMode` where each page does not already import
`now_playing_controller.dart`.

- [ ] **Step 7: Keep preview_player compiling**

In `preview_player.dart`, this task only keeps it building; Task 3 rewires the
buttons properly. Replace the selector at lines 63-64:

```dart
    final mode = ref.watch(nowPlayingProvider.select((s) => s.mode));
```

Replace `onDoubleTap: notifier.toggleExpanded,` with:

```dart
                  onDoubleTap: notifier.toggleWide,
```

In the `_TransportStrip` call, replace the two arguments:

```dart
                mode: mode,
                onToggleWide: notifier.toggleWide,
```

In `_TransportStrip`, replace the `isExpanded` field and constructor parameter
with `mode` / `onToggleWide`:

```dart
    required this.mode,
    required this.onToggleWide,
```

```dart
  final PlayerViewMode mode;
  final VoidCallback onToggleWide;
```

and the existing layout button becomes:

```dart
                        _TransportButton(
                          icon: mode == PlayerViewMode.normal
                              ? AppIcons.fullscreen
                              : AppIcons.fullscreenExit,
                          onPressed: onToggleWide,
                          size: buttonSize,
                        ),
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/features/playback/player_view_mode_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 9: Verify nothing regressed**

Run: `flutter test` then
`dart format lib/features/playback/presentation/providers/now_playing_controller.dart lib/features/song_browser/presentation/pages/song_browser_page.dart lib/features/favorites/presentation/pages/favorites_page.dart lib/features/queue/presentation/pages/selected_queue_page.dart lib/features/history/presentation/pages/history_page.dart lib/features/song_browser/presentation/widgets/preview_player.dart`
then `flutter analyze`
Expected: 172 tests pass (165 + 7); "No issues found!"

---

### Task 2: KaraokeShell can drop its chrome

**Files:**
- Modify: `lib/core/shared/widgets/karaoke_shell.dart:14-25,99-120,133-173`
- Test: `test/core/karaoke_shell_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: `KaraokeShell({..., bool chromeVisible = true})`. When false,
  `topBar` and `bottomBar` are absent from the widget tree.

- [ ] **Step 1: Write the failing test**

Create `test/core/karaoke_shell_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/shared/widgets/karaoke_shell.dart';

Future<void> _pump(WidgetTester tester, {required bool chromeVisible}) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: KaraokeShell(
        chromeVisible: chromeVisible,
        topBar: const Text('TOP BAR'),
        body: const Text('BODY'),
        bottomBar: const Text('BOTTOM BAR'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows_chrome_by_default', (tester) async {
    await _pump(tester, chromeVisible: true);

    expect(find.text('TOP BAR'), findsOneWidget);
    expect(find.text('BOTTOM BAR'), findsOneWidget);
    expect(find.text('BODY'), findsOneWidget);
  });

  testWidgets('removes_chrome_from_the_tree_when_hidden', (tester) async {
    // Absent, not merely invisible: an Offstage or Opacity would still cost
    // layout on a 2GB box.
    await _pump(tester, chromeVisible: false);

    expect(find.text('TOP BAR'), findsNothing);
    expect(find.text('BOTTOM BAR'), findsNothing);
    expect(find.text('BODY'), findsOneWidget);
  });

  testWidgets('body_is_taller_without_chrome', (tester) async {
    await _pump(tester, chromeVisible: true);
    final withChrome = tester.getSize(find.text('BODY'));

    await _pump(tester, chromeVisible: false);
    final withoutChrome = tester.getSize(find.text('BODY'));

    expect(withoutChrome.height, greaterThan(withChrome.height));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/karaoke_shell_test.dart`
Expected: FAIL — "No named parameter with the name 'chromeVisible'".

- [ ] **Step 3: Add the parameter**

In `karaoke_shell.dart`, add to the constructor and fields:

```dart
    this.chromeVisible = true,
```

```dart
  /// When false the top and bottom bars are not built at all, giving the body
  /// the whole shell. Used by the player's fullscreen mode.
  final bool chromeVisible;
```

- [ ] **Step 4: Thread it through both _ShellContent call sites**

`build` constructs `_ShellContent` twice — once inside the compact-landscape
`FittedBox` and once directly. Add `chromeVisible: chromeVisible,` to both.

- [ ] **Step 5: Use it in the layout**

In `_ShellContent`, add the field and constructor parameter:

```dart
    required this.chromeVisible,
```

```dart
  final bool chromeVisible;
```

and replace the `Column`'s children list with:

```dart
          child: Column(
            children: [
              if (chromeVisible) ...[
                topBar,
                SizedBox(height: bodyGap),
              ],
              Expanded(child: body),
              if (chromeVisible) ...[
                SizedBox(height: bottomGap),
                bottomBar,
              ],
            ],
          ),
```

The gaps go inside the conditionals so hiding a bar also removes the space it
occupied, rather than leaving a stranded blank strip.

- [ ] **Step 6: Run tests to verify they pass**

Run: `flutter test test/core/karaoke_shell_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 7: Verify nothing regressed**

Run: `flutter test && dart format lib/core/shared/widgets/karaoke_shell.dart && flutter analyze`
Expected: 175 tests pass; "No issues found!"

---

### Task 3: Two separate layout buttons

**Files:**
- Modify: `lib/core/theme/app_icons.dart:53-54`
- Modify: `lib/features/song_browser/presentation/widgets/preview_player.dart`
- Modify: `lib/features/song_browser/presentation/pages/song_browser_page.dart`
- Modify: `lib/features/favorites/presentation/pages/favorites_page.dart`
- Modify: `lib/features/queue/presentation/pages/selected_queue_page.dart`
- Modify: `lib/features/history/presentation/pages/history_page.dart`
- Test: `test/features/playback/player_layout_buttons_test.dart`

**Interfaces:**
- Consumes: `PlayerViewMode`, `toggleWide()`, `enterFullscreen()`,
  `exitFullscreen()` (Task 1); `KaraokeShell.chromeVisible` (Task 2).
- Produces: `AppIcons.panelClose` and `AppIcons.panelOpen`; a transport row with
  distinct wide and fullscreen buttons.

- [ ] **Step 1: Write the failing test**

Create `test/features/playback/player_layout_buttons_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/theme/app_icons.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
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

    expect(
      container.read(nowPlayingProvider).mode,
      PlayerViewMode.fullscreen,
    );
  });

  testWidgets('fullscreen_hides_the_top_and_bottom_bars', (tester) async {
    await _pump(tester);
    expect(find.text('TRANG CHỦ'), findsOneWidget);

    await tester.tap(find.byIcon(AppIcons.fullscreen));
    await tester.pumpAndSettle();

    expect(find.text('TRANG CHỦ'), findsNothing);
  });

  testWidgets('wide_mode_keeps_the_chrome_visible', (tester) async {
    // Wide only collapses the left column; the nav and hint bar stay.
    await _pump(tester);

    await tester.tap(find.byIcon(AppIcons.panelClose));
    await tester.pumpAndSettle();

    expect(find.text('TRANG CHỦ'), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/playback/player_layout_buttons_test.dart`
Expected: FAIL — "The getter 'panelClose' isn't defined for the class 'AppIcons'".

- [ ] **Step 3: Add the icons**

In `lib/core/theme/app_icons.dart`, next to the existing fullscreen pair:

```dart
  /// Collapses/expands the left search column. Named for the panel that moves,
  /// which is the one on the left.
  static const IconData panelClose = Symbols.left_panel_close_rounded;
  static const IconData panelOpen = Symbols.left_panel_open_rounded;
```

- [ ] **Step 4: Split the transport row's layout button in two**

In `preview_player.dart`, `_TransportStrip` takes an extra callback pair. Replace
its `mode` / `onToggleWide` declarations with:

```dart
    required this.mode,
    required this.onToggleWide,
    required this.onToggleFullscreen,
```

```dart
  final PlayerViewMode mode;
  final VoidCallback onToggleWide;
  final VoidCallback onToggleFullscreen;
```

Replace the single layout button added in Task 1 with two buttons:

```dart
                        _TransportButton(
                          icon: mode == PlayerViewMode.normal
                              ? AppIcons.panelClose
                              : AppIcons.panelOpen,
                          onPressed: onToggleWide,
                          size: buttonSize,
                        ),
                        SizedBox(width: gap),
                        _TransportButton(
                          icon: mode == PlayerViewMode.fullscreen
                              ? AppIcons.fullscreenExit
                              : AppIcons.fullscreen,
                          onPressed: onToggleFullscreen,
                          size: buttonSize,
                        ),
```

- [ ] **Step 5: Wire the callbacks**

In `PreviewPlayer.build`, pass both to `_TransportStrip`:

```dart
                mode: mode,
                onToggleWide: notifier.toggleWide,
                onToggleFullscreen: () => mode == PlayerViewMode.fullscreen
                    ? notifier.exitFullscreen()
                    : notifier.enterFullscreen(),
```

- [ ] **Step 6: Hide the chrome in fullscreen**

In each of the four pages, pass the new flag to `KaraokeShell`:

```dart
      chromeVisible: mode != PlayerViewMode.fullscreen,
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/features/playback/player_layout_buttons_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 8: Verify nothing regressed**

Run: `flutter test`, then format the six touched files by name, then
`flutter analyze`
Expected: 180 tests pass; "No issues found!"

---

### Task 4: Fullscreen overlays and auto-hides the controls

**Files:**
- Modify: `lib/features/song_browser/presentation/widgets/preview_player.dart`
- Test: `test/features/playback/fullscreen_controls_test.dart`

**Interfaces:**
- Consumes: `PlayerViewMode` (Task 1), the two-button transport row (Task 3).
- Produces: `_FullscreenControlsOverlay`, a private stateful leaf owning the
  visibility flag and its timer. `const Duration kControlsAutoHideDelay =
  Duration(seconds: 3);` exported from `preview_player.dart` for the test.

- [ ] **Step 1: Write the failing test**

Create `test/features/playback/fullscreen_controls_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/core/theme/app_icons.dart';
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

  testWidgets('disposing_while_fullscreen_does_not_fire_the_timer', (
    tester,
  ) async {
    await _pump(tester);
    await _enterFullscreen(tester);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(kControlsAutoHideDelay + const Duration(seconds: 1));

    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/playback/fullscreen_controls_test.dart`
Expected: FAIL — "Undefined name 'kControlsAutoHideDelay'".

- [ ] **Step 3: Add the delay constant**

At the top of `preview_player.dart`, below the imports:

```dart
/// How long the fullscreen controls stay up after the last interaction.
const Duration kControlsAutoHideDelay = Duration(seconds: 3);
```

- [ ] **Step 4: Build the overlay widget**

Add to `preview_player.dart`:

```dart
/// Owns the fullscreen controls' visibility.
///
/// Deliberately a small leaf: the flag flips every few seconds, and holding it
/// on the page would rebuild the whole tree each time, which the box
/// performance rules forbid.
class _FullscreenControlsOverlay extends StatefulWidget {
  const _FullscreenControlsOverlay({
    required this.video,
    required this.controls,
  });

  final Widget video;
  final Widget controls;

  @override
  State<_FullscreenControlsOverlay> createState() =>
      _FullscreenControlsOverlayState();
}

class _FullscreenControlsOverlayState
    extends State<_FullscreenControlsOverlay> {
  bool _visible = true;
  Timer? _hideTimer;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  @override
  void dispose() {
    // Without this a fired timer calls setState after unmount.
    _hideTimer?.cancel();
    super.dispose();
  }

  void _restartTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(kControlsAutoHideDelay, () {
      if (mounted) {
        setState(() => _visible = false);
      }
    });
  }

  void reveal() {
    if (!_visible) {
      setState(() => _visible = true);
    }
    _restartTimer();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.video,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          // A one-shot fade on a state change, not a running animation.
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            // Hidden controls must not swallow the tap that reveals them.
            child: IgnorePointer(
              ignoring: !_visible,
              child: widget.controls,
            ),
          ),
        ),
      ],
    );
  }
}
```

Add `import 'dart:async';` at the top of the file if it is not already there.

- [ ] **Step 5: Use the overlay in fullscreen only**

In `PreviewPlayer.build`, the video and `_TransportStrip` currently sit in a
`Column`. Keep that for `normal` and `wide`; in `fullscreen`, stack them instead
so hiding the strip does not resize the video:

```dart
          child: mode == PlayerViewMode.fullscreen
              ? _FullscreenControlsOverlay(
                  key: _overlayKey,
                  video: video,
                  controls: transportStrip,
                )
              : Column(
                  children: [
                    Expanded(child: video),
                    transportStrip,
                  ],
                ),
```

Extract the existing `GestureDetector`-wrapped picture into a local
`final Widget video = ...;` and the `_TransportStrip(...)` into a local
`final Widget transportStrip = ...;` above the `return`, so both branches use the
same widgets rather than duplicating them.

Declare the key on the `ConsumerWidget`'s state or as a module-level
`final GlobalKey<_FullscreenControlsOverlayState> _overlayKey = GlobalKey();`
so Task 5's key handler can call `reveal()`.

- [ ] **Step 6: Reveal on tap**

The picture's existing `GestureDetector` already has `onDoubleTap`. Add a tap
handler that reveals the controls when in fullscreen:

```dart
                  onTap: mode == PlayerViewMode.fullscreen
                      ? () => _overlayKey.currentState?.reveal()
                      : null,
```

- [ ] **Step 7: Reveal on any key**

In `_PlayerRemoteShortcuts._handleKeyEvent`, before the existing key checks, add:

```dart
    if (event is KeyDownEvent) {
      // Any remote press brings the controls back, so the exit button is always
      // one further press away.
      _overlayKey.currentState?.reveal();
    }
```

This runs before the `return KeyEventResult.ignored` fallthrough, so keys the
player does not handle still reveal the controls without being consumed.

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/features/playback/fullscreen_controls_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 9: Verify nothing regressed**

Run: `flutter test && dart format lib/features/song_browser/presentation/widgets/preview_player.dart && flutter analyze`
Expected: 186 tests pass; "No issues found!"

---

### Task 5: Back exits fullscreen, focus and system bars follow

**Files:**
- Modify: `lib/features/song_browser/presentation/widgets/preview_player.dart`
- Modify: `lib/features/song_browser/presentation/pages/song_browser_page.dart`
- Modify: `lib/features/favorites/presentation/pages/favorites_page.dart`
- Modify: `lib/features/queue/presentation/pages/selected_queue_page.dart`
- Modify: `lib/features/history/presentation/pages/history_page.dart`
- Test: `test/features/playback/fullscreen_escape_test.dart`

**Interfaces:**
- Consumes: `PlayerViewMode`, `exitFullscreen()` (Task 1); the overlay's
  `reveal()` (Task 4).
- Produces: no new public API — behaviour only.

- [ ] **Step 1: Write the failing test**

Create `test/features/playback/fullscreen_escape_test.dart`:

```dart
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/playback/fullscreen_escape_test.dart`
Expected: FAIL on `back_exits_fullscreen_instead_of_popping` — the mode stays
`PlayerViewMode.fullscreen` because nothing intercepts back.

- [ ] **Step 3: Intercept back in each page**

In each of the four pages, wrap the returned `KaraokeShell` in a `PopScope`:

```dart
    return PopScope(
      // Back must leave fullscreen rather than the screen. Without this the
      // user's only way out is a button that auto-hides.
      canPop: mode != PlayerViewMode.fullscreen,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          ref.read(nowPlayingProvider.notifier).exitFullscreen();
        }
      },
      child: KaraokeShell(
        // ...existing arguments unchanged
      ),
    );
```

`license_gate_page.dart:40` already uses `PopScope`; follow that shape.

- [ ] **Step 4: Drive the system bars and focus from the mode**

In `PreviewPlayer`, react to mode changes. Because `PreviewPlayer` is a
`ConsumerWidget`, add the listener inside `build` using `ref.listen`:

```dart
    ref.listen<PlayerViewMode>(
      nowPlayingProvider.select((s) => s.mode),
      (previous, next) {
        if (previous == next) {
          return;
        }
        if (next == PlayerViewMode.fullscreen) {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        } else {
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        }
      },
    );
```

Add `import 'package:flutter/services.dart';` if it is not already imported.

Most target head units and TV boxes have no system bars, so this is a no-op
there; it matters on phones and emulators used for testing.

- [ ] **Step 5: Give the D-pad somewhere to land**

`_PlayerRemoteShortcuts` already owns a `FocusNode` (`preview_player.dart:228`).
Entering fullscreen removes the top nav from the tree, so focus may be sitting on
a widget that no longer exists. In `_PlayerRemoteShortcutsState`, add:

```dart
  @override
  void didUpdateWidget(_PlayerRemoteShortcuts oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFullscreen && !oldWidget.isFullscreen) {
      _focusNode.requestFocus();
    }
  }
```

and pass the flag in — add `required this.isFullscreen,` plus
`final bool isFullscreen;` to `_PlayerRemoteShortcuts`, and
`isFullscreen: mode == PlayerViewMode.fullscreen,` at its call site in
`PreviewPlayer.build`.

- [ ] **Step 6: Restore the system UI on dispose**

`PreviewPlayer` is a `ConsumerWidget` with no dispose. Put the restore on
`_PlayerRemoteShortcutsState`, which is already stateful and lives exactly as
long as the player.

That class **already has a `dispose`** (`preview_player.dart:181`). Extend it —
do not write a second one, and do not drop either existing line:

```dart
  @override
  void dispose() {
    // Leaving the player while fullscreen must not strand the device in
    // immersive mode.
    if (widget.isFullscreen) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    _enterHoldTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/features/playback/fullscreen_escape_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 8: Run the full suite**

Run: `flutter test`, then format the five touched files by name, then
`flutter analyze`
Expected: 189 tests pass; "No issues found!"

- [ ] **Step 9: Verify on real hardware**

Debug mode is not representative on these devices.

```bash
flutter build apk --release --dart-define=MUSIC_SDK_LICENSE_KEY=<key>
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

On the device, check:
1. The wide button collapses the left column; nav and hint bar stay.
2. The fullscreen button fills the screen; nav and hint bar disappear.
3. Controls fade out after 3 seconds and come back on a touch and on a D-pad
   press.
4. Back exits fullscreen and does not leave the screen.
5. Entering fullscreen from wide and pressing Back returns to wide.
6. Playback never stops or stutters across any transition.

---

## Self-Review

**Spec coverage.** Every spec section maps to a task: State Model → Task 1;
Controls (two buttons, icons) → Task 3; Hiding the App Chrome → Task 2 plus
Task 3 Step 6, with `SystemChrome` in Task 5 Step 4; Auto-Hiding the Controls →
Task 4; Escaping Fullscreen → Task 4 Steps 6-7 and Task 5 Steps 3 and 5; Known
Consequence (volume hidden) → deliberately not implemented, recorded in the spec;
Testing → each task, plus Task 5 Step 9 on hardware.

**Type consistency.** `PlayerViewMode` and `NowPlayingState.mode` are defined in
Task 1 and used in Tasks 2-5 under the same names. `toggleWide()`,
`enterFullscreen()`, `exitFullscreen()` are defined in Task 1 and consumed in
Tasks 3 and 5. `chromeVisible` is defined in Task 2 and consumed in Task 3
Step 6. `AppIcons.panelClose` / `panelOpen` are defined in Task 3 and used in its
own tests and in Task 5's test. `kControlsAutoHideDelay` and the overlay's
`reveal()` are defined in Task 4 and consumed in Task 4 Steps 6-7. Task 1 Step 7
deliberately reuses the old fullscreen icons as a temporary placeholder; Task 3
Step 4 replaces that button, so the two are consistent in sequence.

**Known risks.** Two things cannot be settled from source. The `GlobalKey` used
to reach the overlay's `reveal()` (Task 4 Steps 5-7) assumes a single
`PreviewPlayer` alive at a time; that holds today because `nowPlayingProvider` is
a single shared slot and only one page renders the player, but a second
simultaneous player would produce a duplicate-key error — if that ever happens,
replace the key with an `InheritedWidget` exposing `reveal()`. And
`tester.binding.handlePopRoute()` is the closest test-level analogue to the
Android back gesture; if it does not trigger `PopScope` in this Flutter version,
send `LogicalKeyboardKey.goBack` through the focus node instead and assert the
same outcome.
