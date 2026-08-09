# Seamless Browser Surface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the song browser's content area read as one continuous surface —
search field, results, and player inside a single slab divided by hairlines —
instead of four separate floating panels.

**Architecture:** A `SurfaceScope` inherited widget marks "an ancestor already
paints the surface"; the three shared widgets that would otherwise draw their own
`LiquidGlass` consult it and render bare. `ContentSlab` pairs the outer
`LiquidGlass` with that scope so the two can never be used apart.

**Tech Stack:** Flutter, Riverpod.

**Spec:** `docs/superpowers/specs/2026-08-08-seamless-browser-surface-design.md`

## Global Constraints

- **Do not run any git write command.** No `git add`, `git commit`, `git push`,
  `git stash`, `git checkout`, `git restore`, `git clean`. The user manages git
  themselves. Every task ends at "tests pass".
- **Do not run `dart format .`** — format only the files you touch, naming each
  explicitly.
- `flutter analyze` must report "No issues found!" and the full suite must stay
  green. 235 tests pass before this plan starts.
- **No `BackdropFilter`, no blur passes, no glassmorphism, no animated
  gradients.** Forbidden on the 2GB-RAM target. Seamlessness comes from layout
  and surface strategy only.
- Android 10 (API 29) minimum. Primary targets: 2GB RAM Android TV/karaoke boxes
  and car head units. Landscape primary; D-pad, remote and touch all
  first-class.
- **Tokens first** — no hardcoded colors, spacing, or radius. The hairline colour
  is `AppColors.panelBorderSoft` (`app_colors.dart:11`), already used for this
  purpose at `search_results_panel.dart:89`. Do not invent a new token.
- Only the song browser changes. The other six screens must render exactly as
  they do today.
- Test names are snake_case behavioural names.
- **Record every file you create or modify** in
  `.superpowers/ui-redesign-backup/README.md` under its Inventory heading, marked
  `NEW` or `MODIFIED`. The rollback script restores modified files but cannot
  delete new ones, so that list is the only record of what to remove by hand.

---

### Task 1: SurfaceScope and the three widgets that consult it

Delivers the mechanism with nothing using it yet. That is deliberate — a reviewer
can judge the seam before any layout moves.

**Files:**
- Create: `lib/core/shared/widgets/surface_scope.dart`
- Modify: `lib/features/song_browser/presentation/widgets/native_song_search_field.dart:56-61`
- Modify: `lib/features/song_browser/presentation/widgets/preview_player.dart:319-340`
- Modify: `lib/core/shared/widgets/panel_frame.dart:33-40`
- Test: `test/core/surface_scope_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `class SurfaceScope extends InheritedWidget` with
    `static bool of(BuildContext context)`.
  - `class ContentSlab extends StatelessWidget` — `ContentSlab({required Widget child})`.
  - `class SurfaceDivider extends StatelessWidget` —
    `SurfaceDivider({Axis axis = Axis.horizontal})`.

- [ ] **Step 1: Write the failing test**

Create `test/core/surface_scope_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/shared/widgets/liquid_glass.dart';
import 'package:viet_ktv/core/shared/widgets/panel_frame.dart';
import 'package:viet_ktv/core/shared/widgets/surface_scope.dart';

/// Counts panel-level surfaces only. Small repeated chips use
/// LiquidGlassDetail.simple and must not be swept up by these assertions.
int _panelSurfaces(WidgetTester tester) => tester
    .widgetList<LiquidGlass>(find.byType(LiquidGlass))
    .where((glass) => glass.detail == LiquidGlassDetail.full)
    .length;

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('scope_is_absent_by_default', (tester) async {
    late bool inScope;
    await _pump(
      tester,
      Builder(
        builder: (context) {
          inScope = SurfaceScope.of(context);
          return const SizedBox.shrink();
        },
      ),
    );

    expect(inScope, isFalse);
  });

  testWidgets('scope_is_visible_to_descendants', (tester) async {
    late bool inScope;
    await _pump(
      tester,
      SurfaceScope(
        child: Builder(
          builder: (context) {
            inScope = SurfaceScope.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(inScope, isTrue);
  });

  testWidgets('panel_frame_paints_its_own_surface_outside_a_scope', (
    tester,
  ) async {
    await _pump(tester, const PanelFrame(child: Text('BODY')));

    expect(_panelSurfaces(tester), 1);
    expect(find.text('BODY'), findsOneWidget);
  });

  testWidgets('panel_frame_renders_bare_inside_a_scope', (tester) async {
    await _pump(
      tester,
      const SurfaceScope(child: PanelFrame(child: Text('BODY'))),
    );

    expect(_panelSurfaces(tester), 0);
    expect(find.text('BODY'), findsOneWidget);
  });

  testWidgets('content_slab_paints_exactly_one_surface_for_its_children', (
    tester,
  ) async {
    // Two panels that would each paint their own surface collapse into the
    // slab's single one — this is the whole point of the pairing.
    await _pump(
      tester,
      const ContentSlab(
        child: Column(
          children: [
            PanelFrame(child: Text('ONE')),
            PanelFrame(child: Text('TWO')),
          ],
        ),
      ),
    );

    expect(_panelSurfaces(tester), 1);
    expect(find.text('ONE'), findsOneWidget);
    expect(find.text('TWO'), findsOneWidget);
  });

  testWidgets('surface_divider_is_one_pixel_on_each_axis', (tester) async {
    await _pump(
      tester,
      const Column(
        children: [
          SurfaceDivider(),
          Expanded(child: Row(children: [SurfaceDivider(axis: Axis.vertical)])),
        ],
      ),
    );

    final dividers = tester.widgetList<SurfaceDivider>(
      find.byType(SurfaceDivider),
    );
    expect(dividers.length, 2);
    expect(tester.getSize(find.byType(SurfaceDivider).first).height, 1);
    expect(tester.getSize(find.byType(SurfaceDivider).last).width, 1);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/surface_scope_test.dart`
Expected: FAIL — "Target of URI doesn't exist: '.../surface_scope.dart'".

- [ ] **Step 3: Create the scope, slab and divider**

Create `lib/core/shared/widgets/surface_scope.dart`:

```dart
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import 'liquid_glass.dart';

/// Marks a subtree as already sitting on a painted surface.
///
/// Widgets that normally draw their own [LiquidGlass] — the search field, the
/// player, [PanelFrame] — look this up and render bare when they find it, so a
/// screen reads as one continuous slab instead of a set of floating tiles.
///
/// It carries no data; its presence is the whole signal. Screens that never
/// insert one behave exactly as before.
class SurfaceScope extends InheritedWidget {
  const SurfaceScope({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SurfaceScope>() != null;

  // Nothing to compare: the widget holds no state. Adding or removing it from
  // the tree already rebuilds dependents through the normal element machinery.
  @override
  bool updateShouldNotify(SurfaceScope oldWidget) => false;
}

/// One continuous surface for a screen's content area.
///
/// Pairs the outer [LiquidGlass] with a [SurfaceScope] so the two can never be
/// used apart: a scope without a slab would strip descendants' surfaces with
/// nothing painting one in their place.
class ContentSlab extends StatelessWidget {
  const ContentSlab({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LiquidGlass(
      radius: AppRadius.md,
      opacity: 0.5,
      padding: const EdgeInsets.all(1),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.md - 1),
        child: SurfaceScope(child: child),
      ),
    );
  }
}

/// Hairline between two regions of a [ContentSlab], replacing the gap and rim
/// that separated them when each was its own panel.
class SurfaceDivider extends StatelessWidget {
  const SurfaceDivider({super.key, this.axis = Axis.horizontal});

  final Axis axis;

  @override
  Widget build(BuildContext context) {
    return axis == Axis.horizontal
        ? const SizedBox(
            height: 1,
            child: ColoredBox(color: AppColors.panelBorderSoft),
          )
        : const SizedBox(
            width: 1,
            child: ColoredBox(color: AppColors.panelBorderSoft),
          );
  }
}
```

- [ ] **Step 4: Make PanelFrame consult the scope**

In `panel_frame.dart`, the build method currently returns `LiquidGlass(radius:
AppRadius.md, padding: padding, opacity: opacity, child: Column(...))`. Extract
the `Column` into a local and branch:

```dart
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ...existing children unchanged
      ],
    );

    if (SurfaceScope.of(context)) {
      // An ancestor slab already paints the surface; keep only the padding it
      // would otherwise have supplied.
      return Padding(padding: padding, child: content);
    }

    return LiquidGlass(
      radius: AppRadius.md,
      padding: padding,
      opacity: opacity,
      child: content,
    );
```

Add `import 'surface_scope.dart';`.

- [ ] **Step 5: Make the search field consult the scope**

In `native_song_search_field.dart`, `build` currently returns
`LiquidGlass(capsule: true, opacity: 0.4, rimColor: AppColors.glassBorder,
padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md), child: TextField(...))`.

Extract the `TextField` into a local and branch:

```dart
    final Widget field = TextField(
      // ...existing arguments unchanged
    );

    if (SurfaceScope.of(context)) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: field,
      );
    }

    return LiquidGlass(
      capsule: true,
      opacity: 0.4,
      rimColor: AppColors.glassBorder,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: field,
    );
```

Add the import with the correct relative depth — this file is four levels below
`lib/`, so `import '../../../../core/shared/widgets/surface_scope.dart';`.

- [ ] **Step 6: Make the player consult the scope**

In `preview_player.dart`, the `surface` local currently picks between the
fullscreen overlay and a `LiquidGlass`-wrapped `Column`. Add a third branch for
the in-slab case:

```dart
    final Widget framedPlayer = Column(
      children: [
        Expanded(child: video),
        transportStrip,
      ],
    );

    final Widget surface = mode == PlayerViewMode.fullscreen
        ? _FullscreenControlsOverlay(
            key: _overlayKey,
            video: video,
            controls: transportStrip,
            revealFocusAnchor: _playPauseFocusAnchor,
          )
        : SurfaceScope.of(context)
        ? framedPlayer
        : LiquidGlass(
            radius: AppRadius.md,
            opacity: 0.5,
            padding: const EdgeInsets.all(1),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md - 1),
              child: framedPlayer,
            ),
          );
```

Fullscreen must stay the first branch: in that mode the player is deliberately
full-bleed with no surface at all, and a slab is never built around it.

Add `import '../../../../core/shared/widgets/surface_scope.dart';`.

- [ ] **Step 7: Run the test to verify it passes**

Run: `flutter test test/core/surface_scope_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 8: Verify nothing regressed**

Run: `flutter test`, then format the four touched files by name, then
`flutter analyze`
Expected: 241 tests pass (235 + 6); "No issues found!"

Nothing inserts a `SurfaceScope` yet, so every screen must look and test exactly
as before. If an existing test fails here, a widget is consulting the scope
incorrectly — fix the branch, do not change the test.

- [ ] **Step 9: Record the change**

Append to the Inventory in `.superpowers/ui-redesign-backup/README.md`:

```markdown
- `NEW` lib/core/shared/widgets/surface_scope.dart
- `NEW` test/core/surface_scope_test.dart
- `MODIFIED` lib/core/shared/widgets/panel_frame.dart
- `MODIFIED` lib/features/song_browser/presentation/widgets/native_song_search_field.dart
- `MODIFIED` lib/features/song_browser/presentation/widgets/preview_player.dart
```

---

### Task 2: Put the browser's content in one slab

**Files:**
- Modify: `lib/features/song_browser/presentation/pages/song_browser_page.dart:110-215,296-315`
- Test: `test/features/song_browser/seamless_surface_test.dart`

**Interfaces:**
- Consumes: `ContentSlab({required Widget child})`, `SurfaceDivider({Axis axis})`,
  `SurfaceScope.of(BuildContext)` (Task 1).
- Produces: nothing public.

- [ ] **Step 1: Write the failing test**

Create `test/features/song_browser/seamless_surface_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/shared/widgets/liquid_glass.dart';
import 'package:viet_ktv/core/shared/widgets/surface_scope.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/features/favorites/presentation/pages/favorites_page.dart';
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

/// Panel-level surfaces only. Chips use LiquidGlassDetail.simple and are not
/// part of this count.
int _panelSurfaces(WidgetTester tester) => tester
    .widgetList<LiquidGlass>(find.byType(LiquidGlass))
    .where((glass) => glass.detail == LiquidGlassDetail.full)
    .length;

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
    // The bottom hint bar stays a separate surface by design, so the expected
    // count is the slab plus that bar.
    await _pump(tester, const SongBrowserPage(source: _source));

    expect(_panelSurfaces(tester), 2);
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
    // the rounded frame that fullscreen exists to remove.
    final container = await _pump(
      tester,
      const SongBrowserPage(source: _source),
    );

    container.read(nowPlayingProvider.notifier).enterFullscreen();
    await tester.pumpAndSettle();

    expect(_panelSurfaces(tester), 0);
  });

  testWidgets('small_chips_keep_their_own_surfaces', (tester) async {
    // Guards against a future change absorbing per-item chips into the slab.
    await _pump(tester, const SongBrowserPage(source: _source));

    expect(_chipSurfaces(tester), greaterThan(0));
  });

  testWidgets('an_unconverted_screen_still_frames_its_panels', (tester) async {
    // Proves SurfaceScope does not leak past the browser.
    await _pump(tester, const FavoritesPage());

    expect(_panelSurfaces(tester), greaterThan(1));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/song_browser/seamless_surface_test.dart`
Expected: FAIL on `normal_mode_has_one_panel_surface_for_the_content` — the
count is higher, because the search field, results panel and player each still
paint their own surface.

Record the actual number the failure reports. The expected 2 is the slab plus the
bottom hint bar, which was verified to be a `full`-detail surface
(`app_bottom_hint_bar.dart:36-38`). If the real number still differs, report it
and explain why — do not change the page to force the number.

- [ ] **Step 3: Put a hairline between the search field and the results**

In `song_browser_page.dart`, `_BrowserSearchPanel.build` currently separates the
field from the results with `const SizedBox(height: AppLayout.browserSectionGap)`.
Replace that line with:

```dart
        const SurfaceDivider(),
```

Add `import '../../../../core/shared/widgets/surface_scope.dart';`.

- [ ] **Step 4: Put the search-tab layout in a slab**

In the non-category branch (around line 187), the `Row` currently holds a
`CollapsibleAxis` whose child is `Padding(padding: EdgeInsets.only(right:
columnGap), child: _BrowserSearchPanel(...))`, followed by
`Expanded(child: const PreviewPlayer())`.

Replace the gap with a hairline that lives *inside* the collapsible region, so it
collapses with the column, and wrap the whole row in a slab unless fullscreen:

```dart
                else
                  Builder(
                    builder: (context) {
                      final Widget row = Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          CollapsibleAxis(
                            axis: Axis.horizontal,
                            // +1 for the hairline that replaced the gap.
                            extent: leftPanelWidth + 1,
                            collapsed: mode != PlayerViewMode.normal,
                            alignment: Alignment.topRight,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  width: leftPanelWidth,
                                  child: _BrowserSearchPanel(
                                    source: widget.source,
                                    controller: controller,
                                  ),
                                ),
                                const SurfaceDivider(axis: Axis.vertical),
                              ],
                            ),
                          ),
                          const Expanded(child: PreviewPlayer()),
                        ],
                      );

                      // No slab in fullscreen: the player is deliberately
                      // full-bleed there, and a slab would put the rounded
                      // frame back.
                      return mode == PlayerViewMode.fullscreen
                          ? row
                          : ContentSlab(child: row);
                    },
                  ),
```

- [ ] **Step 5: Put the category-tab layout in a slab**

In the category branch (around line 127-186), the `Row` holds a fixed-width
`SizedBox` with the genre/artist grid, then `SizedBox(width: columnGap)`, then
`Expanded(child: _SearchResults(source: widget.source))`.

Replace the `SizedBox(width: columnGap)` at line 184 with:

```dart
                      const SurfaceDivider(axis: Axis.vertical),
```

and wrap that whole `Row` in `ContentSlab(child: ...)`. This branch has no
player, so there is no fullscreen case to guard.

- [ ] **Step 6: Run the test to verify it passes**

Run: `flutter test test/features/song_browser/seamless_surface_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 7: Verify nothing regressed**

Run: `flutter test`, then
`dart format lib/features/song_browser/presentation/pages/song_browser_page.dart test/features/song_browser/seamless_surface_test.dart`,
then `flutter analyze`
Expected: 247 tests pass (241 + 6); "No issues found!"

Several existing suites pump this page — `widget_test.dart`, `queue_test.dart`,
`volume_test.dart`, the player-layout and fullscreen suites. They assert on text
and icons rather than surfaces, so they should be unaffected. If one fails
because it counted widgets, report it before changing it.

- [ ] **Step 8: Record the change**

Append to the Inventory in `.superpowers/ui-redesign-backup/README.md`:

```markdown
- `NEW` test/features/song_browser/seamless_surface_test.dart
- `MODIFIED` lib/features/song_browser/presentation/pages/song_browser_page.dart
```

- [ ] **Step 9: Look at it on real hardware**

This is the only step that can judge the actual goal. Debug mode is not
representative on this hardware.

```bash
flutter build apk --release --dart-define=MUSIC_SDK_LICENSE_KEY=<key>
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Capture a screenshot of the browser in normal mode, wide mode, and the category
tab, and put the paths in your report. Do not judge the result yourself — the
user decides whether the tone step, hairline weight, and corner radius are right,
and one revision round is expected.

---

## Self-Review

**Spec coverage.** The surface model (one slab, hairlines, `panelBorderSoft`) →
Task 1 Step 3 and Task 2 Steps 3-5; the bottom hint bar staying separate → not
touched anywhere, and the expected surface count of 2 in Task 2 Step 1 encodes
it; chips keeping their own surfaces → `small_chips_keep_their_own_surfaces`; the
scope mechanism → Task 1 Steps 3-6; the three layout states → Task 2 Steps 4-5
with tests for each; the category tab → Task 2 Step 5; the testing list → all six
of the spec's bullets map to tests; verification and revision → Task 2 Step 9;
rollback → the Inventory steps in both tasks.

**Type consistency.** `SurfaceScope.of(BuildContext) → bool`, `ContentSlab({Widget
child})` and `SurfaceDivider({Axis axis})` are defined in Task 1 Step 3 and used
in Task 1 Steps 4-6 and Task 2 Steps 3-5 under those exact names.
`LiquidGlassDetail.full` is the default (`liquid_glass.dart:39`), which is what
makes the panel-versus-chip count in both test files meaningful.

**Verified rather than assumed.** `AppBottomHintBar` builds its `LiquidGlass`
without a `detail` argument (`app_bottom_hint_bar.dart:36-38`), so it defaults to
`full` — the expected panel count of 2 in normal mode (slab + hint bar) is
correct, not a guess. `FavoritesPage` takes only `super.key`, so
`const FavoritesPage()` compiles.

**Known risk.** One thing cannot be settled from source: swapping
`SizedBox(height: AppLayout.browserSectionGap)` for a 1px hairline removes
vertical spacing the layout may have depended on; if the search field ends up
visually cramped against the results, add padding inside the regions rather than
reinstating the gap, since the gap is exactly what made the panels read as
separate.
