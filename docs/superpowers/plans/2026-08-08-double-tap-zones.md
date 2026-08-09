# Double-Tap Zones Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Split the video's double-tap gesture into three horizontal zones — seek
back on the left, toggle fullscreen in the middle, seek forward on the right —
with a brief on-screen badge confirming each seek.

**Architecture:** Zone classification is a pure function of `dx` and width, so it
is tested without widgets. The gesture captures its position in
`onDoubleTapDown` and acts in `onDoubleTap`. The seek badge is a small stateful
leaf reached by a per-instance `GlobalKey`, matching how the fullscreen controls
overlay is already driven.

**Tech Stack:** Flutter, Riverpod (`StateNotifier`), `material_symbols_icons`.

**Spec:** `docs/superpowers/specs/2026-08-08-double-tap-zones-design.md`

## Global Constraints

- **Do not run any git write command.** No `git add`, `git commit`, `git push`,
  `git stash`, `git checkout`, `git restore`, `git clean`. The user manages git
  themselves. This overrides the usual per-task commit step; every task ends at
  "tests pass".
- **Do not run `dart format .`** — it reformats the whole repo, including the
  user's unrelated uncommitted work. Format only the files you touch, naming
  each explicitly.
- `flutter analyze` must report "No issues found!" and the full suite must stay
  green. 203 tests pass before this plan starts.
- Android 10 (API 29) minimum. Primary targets: 2GB RAM Android TV/karaoke boxes
  and car head units. Landscape primary; D-pad, remote, and touch all
  first-class.
- **No continuous or per-frame animation.** One-shot transitions on a state
  change are fine.
- Isolate frequent rebuilds in small leaf widgets — never rebuild the video
  subtree on a repeating state change.
- Watch the narrowest slice with `.select`; never `ref.watch` a whole provider at
  a page root.
- **Tokens first**: no hardcoded colors, spacing, radius, or text styles in
  feature widgets. Reuse `lib/core/theme/*`.
- Test names are snake_case behavioural names.
- Seek step stays 10s — reuse `NowPlayingController.seekBackward()` /
  `seekForward()`; do not reimplement seeking.

---

### Task 1: Zone classification and gesture wiring

Delivers the working gesture with no feedback badge yet. That is deliberate —
the badge is separable and reviewable on its own.

**Files:**
- Create: `lib/features/song_browser/presentation/widgets/double_tap_zone.dart`
- Modify: `lib/features/song_browser/presentation/widgets/preview_player.dart`
- Test: `test/features/song_browser/double_tap_zone_test.dart`
- Test: `test/features/playback/double_tap_gesture_test.dart`

**Interfaces:**
- Consumes: `PlayerViewMode`, `NowPlayingController.seekBackward()`,
  `seekForward()`, `enterFullscreen()`, `exitFullscreen()` — all existing.
- Produces:
  - `enum DoubleTapZone { seekBackward, toggleFullscreen, seekForward }`
  - `DoubleTapZone doubleTapZoneFor(double dx, double width)`

- [ ] **Step 1: Write the failing pure-function test**

Create `test/features/song_browser/double_tap_zone_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/double_tap_zone.dart';

void main() {
  test('left_third_seeks_backward', () {
    expect(doubleTapZoneFor(20, 100), DoubleTapZone.seekBackward);
  });

  test('middle_toggles_fullscreen', () {
    expect(doubleTapZoneFor(50, 100), DoubleTapZone.toggleFullscreen);
  });

  test('right_third_seeks_forward', () {
    expect(doubleTapZoneFor(80, 100), DoubleTapZone.seekForward);
  });

  test('boundaries_belong_to_the_middle_zone', () {
    // Exactly 30% and 70% are centre, so a mis-hit near the edge does nothing
    // rather than jumping the song 10 seconds.
    expect(doubleTapZoneFor(30, 100), DoubleTapZone.toggleFullscreen);
    expect(doubleTapZoneFor(70, 100), DoubleTapZone.toggleFullscreen);
  });

  test('just_outside_the_boundaries_seeks', () {
    expect(doubleTapZoneFor(29.9, 100), DoubleTapZone.seekBackward);
    expect(doubleTapZoneFor(70.1, 100), DoubleTapZone.seekForward);
  });

  test('scales_with_width_rather_than_using_fixed_pixels', () {
    expect(doubleTapZoneFor(400, 1920), DoubleTapZone.seekBackward);
    expect(doubleTapZoneFor(960, 1920), DoubleTapZone.toggleFullscreen);
    expect(doubleTapZoneFor(1500, 1920), DoubleTapZone.seekForward);
  });

  test('degenerate_width_falls_back_to_the_middle_zone', () {
    // A zero or negative width would make the fraction undefined; the safe
    // fallback is the non-destructive action.
    expect(doubleTapZoneFor(0, 0), DoubleTapZone.toggleFullscreen);
    expect(doubleTapZoneFor(10, -5), DoubleTapZone.toggleFullscreen);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/song_browser/double_tap_zone_test.dart`
Expected: FAIL — "Target of URI doesn't exist: '.../double_tap_zone.dart'".

- [ ] **Step 3: Write the pure function**

Create `lib/features/song_browser/presentation/widgets/double_tap_zone.dart`:

```dart
/// Which action a double tap on the video picture triggers, chosen by where
/// along the picture's width the tap landed.
enum DoubleTapZone { seekBackward, toggleFullscreen, seekForward }

/// Fraction of the picture's width given to each outer (seek) zone.
///
/// 30/40/30 rather than a YouTube-style 40/20/40: the centre has to be hit
/// reliably on a head unit in a moving car, and a mis-hit there does not merely
/// do nothing — it jumps the song 10 seconds.
const double _seekZoneFraction = 0.3;

/// Classifies a double tap. [dx] is the horizontal offset within the picture.
///
/// The boundaries themselves belong to the centre zone, so an edge mis-hit
/// toggles fullscreen rather than seeking.
DoubleTapZone doubleTapZoneFor(double dx, double width) {
  if (width <= 0) {
    return DoubleTapZone.toggleFullscreen;
  }
  final fraction = dx / width;
  if (fraction < _seekZoneFraction) {
    return DoubleTapZone.seekBackward;
  }
  if (fraction > 1 - _seekZoneFraction) {
    return DoubleTapZone.seekForward;
  }
  return DoubleTapZone.toggleFullscreen;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/song_browser/double_tap_zone_test.dart`
Expected: PASS, 7 tests.

- [ ] **Step 5: Write the failing gesture test**

Create `test/features/playback/double_tap_gesture_test.dart`:

```dart
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

    expect(
      container.read(nowPlayingProvider).mode,
      PlayerViewMode.fullscreen,
    );
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

    expect(
      container.read(nowPlayingProvider).mode,
      isNot(PlayerViewMode.wide),
    );
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
```

- [ ] **Step 6: Run the gesture test to verify it fails**

Run: `flutter test test/features/playback/double_tap_gesture_test.dart`
Expected: FAIL on `double_tap_centre_enters_fullscreen` — the mode is
`PlayerViewMode.wide`, because the current gesture still calls `toggleWide`.

- [ ] **Step 7: Wire the zones into the gesture**

In `preview_player.dart`, add the import:

```dart
import 'double_tap_zone.dart';
```

Add a field to `_PreviewPlayerState` (no `setState` — it is read-only bookkeeping
between the two gesture callbacks, and changing it must not rebuild anything):

```dart
  /// Captured in onDoubleTapDown because onDoubleTap carries no position.
  Offset? _doubleTapPosition;
```

Replace the `video` local. It currently reads:

```dart
    final Widget video = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onDoubleTap: notifier.toggleWide,
      child: picture,
    );
```

with:

```dart
    final Widget video = LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTapDown: (details) => _doubleTapPosition = details.localPosition,
        onDoubleTap: () => _handleDoubleTap(constraints.maxWidth, notifier, mode),
        child: picture,
      ),
    );
```

Add the handler method to `_PreviewPlayerState`:

```dart
  void _handleDoubleTap(
    double width,
    NowPlayingController notifier,
    PlayerViewMode mode,
  ) {
    final dx = _doubleTapPosition?.dx;
    if (dx == null) {
      return;
    }
    switch (doubleTapZoneFor(dx, width)) {
      case DoubleTapZone.seekBackward:
        notifier.seekBackward();
      case DoubleTapZone.seekForward:
        notifier.seekForward();
      case DoubleTapZone.toggleFullscreen:
        if (mode == PlayerViewMode.fullscreen) {
          notifier.exitFullscreen();
        } else {
          notifier.enterFullscreen();
        }
    }
  }
```

Update the comment above `picture` — it currently says "Only the picture toggles
on double tap", which is now wrong. Say that the picture carries the three
double-tap zones and that the transport strip is excluded so double-tapping a
control cannot resize the screen out from under the user.

- [ ] **Step 8: Run both test files to verify they pass**

Run: `flutter test test/features/song_browser/double_tap_zone_test.dart test/features/playback/double_tap_gesture_test.dart`
Expected: PASS, 11 tests.

- [ ] **Step 9: Verify nothing regressed**

Run: `flutter test`, then
`dart format lib/features/song_browser/presentation/widgets/double_tap_zone.dart lib/features/song_browser/presentation/widgets/preview_player.dart test/features/song_browser/double_tap_zone_test.dart test/features/playback/double_tap_gesture_test.dart`,
then `flutter analyze`
Expected: 214 tests pass (203 + 11); "No issues found!"

Note: an existing test may assert the old `normal ↔ wide` double-tap. If one
fails, it is asserting behaviour this plan deliberately removes — update it to
the new contract rather than reverting the change, and say so in your report.

---

### Task 2: Seek feedback badge

**Files:**
- Modify: `lib/features/song_browser/presentation/widgets/preview_player.dart`
- Test: `test/features/playback/seek_badge_test.dart`

**Interfaces:**
- Consumes: `DoubleTapZone`, `doubleTapZoneFor` (Task 1).
- Produces: `const Duration kSeekBadgeDuration = Duration(milliseconds: 600);`
  exported from `preview_player.dart`, and a private `_SeekFeedbackBadge` leaf
  whose state exposes `void show({required bool forward})`.

- [ ] **Step 1: Write the failing test**

Create `test/features/playback/seek_badge_test.dart`:

```dart
import 'package:flutter/material.dart';
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

Future<void> _doubleTapAt(WidgetTester tester, double fraction) async {
  final rect = tester.getRect(find.byType(PreviewPlayer));
  final point = Offset(
    rect.left + rect.width * fraction,
    rect.top + rect.height * 0.3,
  );
  await tester.tapAt(point);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(point);
  await tester.pump();
}

void main() {
  testWidgets('seeking_forward_shows_the_forward_badge', (tester) async {
    await _pump(tester);

    await _doubleTapAt(tester, 0.85);

    expect(find.text('10s'), findsOneWidget);
    expect(find.byIcon(AppIcons.fastForward), findsWidgets);
  });

  testWidgets('seeking_backward_shows_the_backward_badge', (tester) async {
    await _pump(tester);

    await _doubleTapAt(tester, 0.15);

    expect(find.text('10s'), findsOneWidget);
    expect(find.byIcon(AppIcons.rewind), findsWidgets);
  });

  testWidgets('the_badge_disappears_after_the_hold', (tester) async {
    await _pump(tester);
    await _doubleTapAt(tester, 0.85);
    expect(find.text('10s'), findsOneWidget);

    await tester.pump(kSeekBadgeDuration + const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('10s'), findsNothing);
  });

  testWidgets('the_centre_zone_shows_no_badge', (tester) async {
    // Entering fullscreen is its own evidence; a badge there would be noise.
    await _pump(tester);

    await _doubleTapAt(tester, 0.5);

    expect(find.text('10s'), findsNothing);
  });

  testWidgets('disposing_while_the_badge_is_up_does_not_throw', (tester) async {
    await _pump(tester);
    await _doubleTapAt(tester, 0.85);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 100));

    expect(tester.takeException(), isNull);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/playback/seek_badge_test.dart`
Expected: FAIL — "Undefined name 'kSeekBadgeDuration'".

- [ ] **Step 3: Add the duration constant**

At the top of `preview_player.dart`, next to `kControlsAutoHideDelay`:

```dart
/// How long the seek confirmation badge stays up after a double-tap seek.
const Duration kSeekBadgeDuration = Duration(milliseconds: 600);
```

- [ ] **Step 4: Build the badge leaf**

Add to `preview_player.dart`:

```dart
/// Brief confirmation that a double-tap seek happened, and in which direction.
///
/// A karaoke video runs continuously, so a 10-second jump is not always
/// obvious — and in fullscreen with the controls auto-hidden, the progress bar
/// that would otherwise show it is off screen.
///
/// Its own leaf so showing and hiding it never rebuilds the video subtree.
class _SeekFeedbackBadge extends StatefulWidget {
  const _SeekFeedbackBadge({super.key});

  @override
  State<_SeekFeedbackBadge> createState() => _SeekFeedbackBadgeState();
}

class _SeekFeedbackBadgeState extends State<_SeekFeedbackBadge> {
  bool _visible = false;
  bool _forward = true;
  Timer? _hideTimer;

  @override
  void dispose() {
    // Without this a fired timer calls setState after unmount.
    _hideTimer?.cancel();
    super.dispose();
  }

  void show({required bool forward}) {
    setState(() {
      _visible = true;
      _forward = forward;
    });
    _hideTimer?.cancel();
    _hideTimer = Timer(kSeekBadgeDuration, () {
      if (mounted) {
        setState(() => _visible = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: _forward ? Alignment.centerRight : Alignment.centerLeft,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
          // A one-shot fade on a state change, not a running animation.
          child: AnimatedOpacity(
            opacity: _visible ? 1 : 0,
            duration: AppMotion.control,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.background.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(AppRadius.pill),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _forward ? AppIcons.fastForward : AppIcons.rewind,
                    color: AppColors.textPrimary,
                    size: AppSpacing.lg,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text('10s', style: AppTextStyles.label),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

Check the exact token names against `lib/core/theme/` before using them —
`AppSpacing.xl`, `AppSpacing.lg`, `AppSpacing.xs`, `AppColors.textPrimary`, and
`AppMotion.control` must exist. If any does not, use the nearest existing token
rather than inventing a literal, and note the substitution in your report.

- [ ] **Step 5: Mount the badge and drive it**

Add a key field to `_PreviewPlayerState`, alongside the existing overlay key:

```dart
  final GlobalKey<_SeekFeedbackBadgeState> _seekBadgeKey = GlobalKey();
```

Add the badge as the last child of the `picture` `Stack`, so it paints above the
video and the status overlay:

```dart
        _SeekFeedbackBadge(key: _seekBadgeKey),
```

In `_handleDoubleTap`, show it on each seek branch:

```dart
      case DoubleTapZone.seekBackward:
        notifier.seekBackward();
        _seekBadgeKey.currentState?.show(forward: false);
      case DoubleTapZone.seekForward:
        notifier.seekForward();
        _seekBadgeKey.currentState?.show(forward: true);
```

Leave the `toggleFullscreen` branch without a badge.

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/playback/seek_badge_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 7: Verify nothing regressed**

Run: `flutter test`, then
`dart format lib/features/song_browser/presentation/widgets/preview_player.dart test/features/playback/seek_badge_test.dart`,
then `flutter analyze`
Expected: 219 tests pass (214 + 5); "No issues found!"

- [ ] **Step 8: Verify on real hardware**

Debug mode is not representative on these devices, and gesture feel cannot be
judged from tests.

```bash
flutter build apk --release --dart-define=MUSIC_SDK_LICENSE_KEY=<key>
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

On the device, with a song playing, check:
1. Double-tap the middle of the video enters fullscreen; again exits to where
   you started.
2. Double-tap the right third jumps forward 10s and shows the badge; the left
   third jumps back.
3. The 30/40/30 split feels right — you can hit the centre without accidentally
   seeking, and reach the seek zones without stretching.
4. 600ms is long enough to notice the badge but not long enough to annoy.
5. In fullscreen with the controls hidden, a seek still shows the badge.
6. Playback does not stutter on any of these transitions.

---

## Self-Review

**Spec coverage.** Zones table → Task 1 Steps 1-4; gesture wiring
(`onDoubleTapDown` then `onDoubleTap`) → Task 1 Step 7; behaviour across modes
and the removal of the `normal ↔ wide` double-tap → Task 1 Steps 5-7, with an
explicit test; seek feedback (600ms, direction, no badge for centre) → Task 2;
interaction with the existing `Listener` reveal → unchanged by design, nothing to
implement; no-op seek with nothing playing → covered by Task 1's
`double_tap_left_and_right_do_not_change_the_mode`; testing section → both tasks
plus Task 2 Step 8 on hardware.

**Type consistency.** `DoubleTapZone` and `doubleTapZoneFor(double, double)` are
defined in Task 1 and consumed in Task 2. `kSeekBadgeDuration` and
`_SeekFeedbackBadgeState.show({required bool forward})` are defined in Task 2 and
used in its own tests and in `_handleDoubleTap`. `_handleDoubleTap` is introduced
in Task 1 Step 7 and extended in Task 2 Step 5 — the Task 2 snippet shows only
the two changed branches, and the surrounding method is unchanged.

**Known risks.** Two things cannot be settled from source. The gesture tests tap
at 30% of the player's height to hit the picture rather than the transport strip;
if the strip's proportion differs enough at 1920×1080 that this lands on a
control, adjust the fraction rather than the zone logic. And `AnimatedOpacity`
uses `AppMotion.control` (160ms) rather than `AppMotion.route` (220ms): the
badge is a control-level affordance, not a page transition. Both tokens exist;
this is a semantic choice, not a constraint.
