# Single Tap To Play/Pause Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A single tap on the video picture toggles play/pause, except in
fullscreen where a tap on hidden controls only reveals them.

**Architecture:** The reveal runs on pointer-down and the tap resolves ~300ms
later, so `onTap` can never observe the pre-reveal visibility. An inner
`Listener` captures it first — Flutter dispatches pointer events from the
innermost hit-test entry outward, so a `Listener` below the overlay's own
`Listener` sees the down event before `reveal()` runs.

**Tech Stack:** Flutter, Riverpod (`StateNotifier`).

**Spec:** `docs/superpowers/specs/2026-08-08-single-tap-play-pause-design.md`

## Global Constraints

- **Do not run any git write command.** No `git add`, `git commit`, `git push`,
  `git stash`, `git checkout`, `git restore`, `git clean`. The user manages git
  themselves. This overrides the usual per-task commit step; the task ends at
  "tests pass".
- **Do not run `dart format .`** — it reformats the whole repo, including the
  user's unrelated uncommitted work. Format only the files you touch, naming
  each explicitly.
- `flutter analyze` must report "No issues found!" and the full suite must stay
  green. 220 tests pass before this plan starts.
- Android 10 (API 29) minimum. Primary targets: 2GB RAM Android TV/karaoke boxes
  and car head units. Landscape primary; D-pad, remote, and touch all
  first-class.
- No continuous or per-frame animation. One-shot transitions are fine.
- Isolate frequent rebuilds in small leaf widgets — never rebuild the video
  subtree on a repeating state change.
- Tokens first: no hardcoded colors, spacing, radius, or text styles.
- Test names are snake_case behavioural names.
- Do not change the double-tap zones, the seek step, the auto-hide delay, or the
  transport buttons.

---

### Task 1: Single tap toggles play/pause, with the fullscreen exception

**Files:**
- Modify: `lib/features/song_browser/presentation/widgets/preview_player.dart`
- Test: `test/features/playback/single_tap_test.dart`

**Interfaces:**
- Consumes: `NowPlayingController.togglePlayPause()` (existing, already a no-op
  when nothing is playing); `PlayerViewMode`; the existing
  `_FullscreenControlsOverlayState` and its `_overlayKey`.
- Produces: `bool get isControlsVisible` on `_FullscreenControlsOverlayState`.

- [ ] **Step 1: Write the failing test**

Create `test/features/playback/single_tap_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/core/theme/app_icons.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/preview_player.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import '../../support/fake_audio_track_player.dart';
import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';

const _source = MusicSource(
  id: 'youtube',
  subtitle: 'Kho nhạc & Video\nkhổng lồ',
  accentColor: AppColors.red,
  logoStyle: MusicSourceLogoStyle.youtube,
);

const _song = SongItem(
  id: 'track-1',
  title: 'Test Song',
  subtitle: 'SoundCloud',
  duration: '00:30',
  thumbnailSeed: 1,
  badge: null,
);

/// Pumps the browser page with a live audio player so play/pause has something
/// to act on. SoundCloud takes the just_audio path, which the fake stands in
/// for — the YouTube path needs a real video decoder.
Future<({ProviderContainer container, FakeAudioTrackPlayer player})> _pump(
  WidgetTester tester,
) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final player = FakeAudioTrackPlayer();
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(FakeLocalStorageService()),
      musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
      audioTrackPlayerFactoryProvider.overrideWithValue(() => player),
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

  await container
      .read(nowPlayingProvider.notifier)
      .play(_song, MusicSourceLogoStyle.soundcloud);
  await tester.pumpAndSettle();
  expect(
    container.read(nowPlayingProvider).audioPlayer,
    isNotNull,
    reason: 'setup must leave a live player, or play/pause has nothing to do',
  );

  return (container: container, player: player);
}

/// Taps the picture once. The extra pump past the double-tap window is what
/// lets onTap win the arena — without it the tap is still pending.
Future<void> _tapPicture(WidgetTester tester) async {
  final rect = tester.getRect(find.byType(PreviewPlayer));
  await tester.tapAt(
    Offset(rect.left + rect.width * 0.5, rect.top + rect.height * 0.3),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();
}

Future<void> _doubleTapPicture(WidgetTester tester, double fraction) async {
  final rect = tester.getRect(find.byType(PreviewPlayer));
  final point = Offset(
    rect.left + rect.width * fraction,
    rect.top + rect.height * 0.3,
  );
  await tester.tapAt(point);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(point);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tap_toggles_playback_in_normal_mode', (tester) async {
    final harness = await _pump(tester);
    final pausesBefore = harness.player.pauseCallCount;

    await _tapPicture(tester);

    expect(harness.player.pauseCallCount, pausesBefore + 1);
  });

  testWidgets('tap_toggles_playback_in_wide_mode', (tester) async {
    final harness = await _pump(tester);
    harness.container.read(nowPlayingProvider.notifier).toggleWide();
    await tester.pumpAndSettle();
    final pausesBefore = harness.player.pauseCallCount;

    await _tapPicture(tester);

    expect(harness.player.pauseCallCount, pausesBefore + 1);
  });

  testWidgets('tap_on_hidden_controls_only_reveals_them', (tester) async {
    // Glancing at the progress bar must not stop the song. This is the
    // behaviour the pointer-down capture exists for.
    final harness = await _pump(tester);
    harness.container.read(nowPlayingProvider.notifier).enterFullscreen();
    await tester.pumpAndSettle();
    await tester.pump(kControlsAutoHideDelay + const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.fullscreenExit), findsNothing);
    final pausesBefore = harness.player.pauseCallCount;

    await _tapPicture(tester);

    expect(find.byIcon(AppIcons.fullscreenExit), findsOneWidget);
    expect(
      harness.player.pauseCallCount,
      pausesBefore,
      reason: 'the reveal tap must not touch playback',
    );
  });

  testWidgets('tap_with_controls_already_visible_toggles_playback', (
    tester,
  ) async {
    final harness = await _pump(tester);
    harness.container.read(nowPlayingProvider.notifier).enterFullscreen();
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.fullscreenExit), findsOneWidget);
    final pausesBefore = harness.player.pauseCallCount;

    await _tapPicture(tester);

    expect(harness.player.pauseCallCount, pausesBefore + 1);
  });

  testWidgets('double_tap_does_not_also_toggle_playback', (tester) async {
    final harness = await _pump(tester);
    final pausesBefore = harness.player.pauseCallCount;
    final playsBefore = harness.player.playCallCount;

    await _doubleTapPicture(tester, 0.5);

    expect(
      harness.container.read(nowPlayingProvider).mode,
      PlayerViewMode.fullscreen,
    );
    expect(harness.player.pauseCallCount, pausesBefore);
    expect(harness.player.playCallCount, playsBefore);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/playback/single_tap_test.dart`
Expected: FAIL on `tap_toggles_playback_in_normal_mode` — `pauseCallCount` is
unchanged, because no `onTap` is wired yet.

- [ ] **Step 3: Expose the overlay's visibility**

In `_FullscreenControlsOverlayState` (around `preview_player.dart:414`), add next
to the existing `_visible` field:

```dart
  /// Read at pointer-down by [_PreviewPlayerState], before [reveal] runs.
  bool get isControlsVisible => _visible;
```

- [ ] **Step 4: Capture the visibility at pointer-down**

Add a field to `_PreviewPlayerState`, next to `_doubleTapPosition`:

```dart
  /// Whether the fullscreen controls were on screen when the finger landed.
  ///
  /// Captured here rather than read in onTap because the overlay's own
  /// Listener calls reveal() on pointer-down, ~300ms before the tap is
  /// recognised — by then the controls are always visible and the
  /// tap-only-reveals rule could never fire. Defaults to true so that
  /// normal/wide, which have no overlay at all, simply toggle playback.
  bool _controlsVisibleAtTapDown = true;
```

- [ ] **Step 5: Wire the tap**

Replace the `video` local. It currently reads:

```dart
    final Widget video = LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTapDown: (details) => _doubleTapPosition = details.localPosition,
        onDoubleTap: () => _handleDoubleTap(
          constraints.maxWidth,
          notifier,
          mode,
          playerLive: displayReady || hasAudioPlayer,
        ),
        child: picture,
      ),
    );
```

with:

```dart
    final Widget video = LayoutBuilder(
      builder: (context, constraints) => Listener(
        // Inner to the overlay's own Listener, and Flutter dispatches pointer
        // events from the innermost hit-test entry outward, so this records the
        // pre-reveal state before reveal() can change it.
        onPointerDown: (_) => _controlsVisibleAtTapDown =
            _overlayKey.currentState?.isControlsVisible ?? true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _handleTap(notifier),
          onDoubleTapDown: (details) =>
              _doubleTapPosition = details.localPosition,
          onDoubleTap: () => _handleDoubleTap(
            constraints.maxWidth,
            notifier,
            mode,
            playerLive: displayReady || hasAudioPlayer,
          ),
          child: picture,
        ),
      ),
    );
```

- [ ] **Step 6: Add the tap handler**

Add to `_PreviewPlayerState`, next to `_handleDoubleTap`:

```dart
  void _handleTap(NowPlayingController notifier) {
    if (!_controlsVisibleAtTapDown) {
      // The tap's only job was waking the controls. Toggling playback here
      // would stop the song every time the user glanced at the progress bar.
      return;
    }
    // Safe with nothing playing: togglePlayPause already returns early when
    // there is no player.
    notifier.togglePlayPause();
  }
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `flutter test test/features/playback/single_tap_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 8: Verify nothing regressed**

Run: `flutter test`, then
`dart format lib/features/song_browser/presentation/widgets/preview_player.dart test/features/playback/single_tap_test.dart`,
then `flutter analyze`
Expected: 225 tests pass (220 + 5); "No issues found!"

Two existing suites share this surface and must stay green:
`test/features/playback/double_tap_gesture_test.dart` and
`test/features/playback/fullscreen_controls_test.dart`. If either fails, the new
`onTap` is stealing an event the double-tap or reveal path needs — fix the wiring
rather than loosening those tests, and report what happened.

- [ ] **Step 9: Verify on real hardware**

Debug mode is not representative on these devices, and the ~300ms tap delay can
only be judged by feel.

```bash
flutter build apk --release --dart-define=MUSIC_SDK_LICENSE_KEY=<key>
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

On the device, with a song playing:
1. Tap the video in normal mode — playback pauses; tap again — it resumes.
2. Enter fullscreen, wait for the controls to fade, tap once — the controls come
   back and the song keeps playing.
3. Tap again while they are up — playback pauses.
4. Double-tap left/right/centre — the zone actions still work and playback state
   is untouched by the centre one.
5. Judge whether the ~300ms delay before a pause feels acceptable.

---

## Self-Review

**Spec coverage.** Behaviour (tap toggles, strip unaffected because the
`GestureDetector` wraps only the picture) → Steps 5-6; fullscreen exception →
Steps 3-4 and 6; the ordering trap and its resolution → Steps 3-5, with the
reason in the code comments; the ~300ms delay → recorded in the spec as inherent,
accounted for in the test helper's 400ms pump and in Step 9's on-device check;
testing list → all five spec bullets map to the five tests, with "a tap with
nothing playing changes nothing" covered by `togglePlayPause`'s existing guard
plus the harness's explicit assertion that a player IS live (so the positive
tests cannot pass vacuously).

**Type consistency.** `isControlsVisible` is defined in Step 3 and consumed in
Step 5. `_controlsVisibleAtTapDown` is defined in Step 4, written in Step 5, read
in Step 6. `_handleTap(NowPlayingController)` is referenced in Step 5 and defined
in Step 6. `_handleDoubleTap`'s existing signature — including
`playerLive:` — is carried through Step 5 unchanged.

**Known risks.** Two things cannot be settled from source. The inner-`Listener`
ordering relies on Flutter dispatching pointer events from the innermost
hit-test entry outward; if `tap_on_hidden_controls_only_reveals_them` fails
because the capture already saw `true`, the ordering assumption is wrong — move
the capture into `GestureDetector.onTapDown` instead and re-check, rather than
weakening the test. And the 400ms pump in `_tapPicture` assumes the double-tap
window is shorter than that; if `onTap` still has not fired, raise the pump
rather than removing `onDoubleTap`.
