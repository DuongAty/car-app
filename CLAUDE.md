# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## AI Role

Act as a senior Flutter engineer delivering production Android apps. Build UI with a feature-first architecture, a reusable design system, and code that is easy to extend, test, refactor, and maintain. Prefer long-term clarity over short-term speed.

## Target Platform

Android first, must support Android 8.0 (API 26) and above. The primary deployment targets are low-cost Android TV/karaoke boxes with 2GB RAM and Android car head units / in-car entertainment screens. All UI must behave correctly on Android box displays, Android car screens, and common Android phone sizes, handle small and large screens gracefully, and avoid layout overflow — landscape is the primary karaoke layout, since focus/D-pad navigation, remote/control buttons, touch, and mixed input are first-class interactions.

Do not treat this repository as a generic mobile-first Flutter app. Phones are supported for compatibility and testing, but product and performance decisions should prioritize karaoke sessions on Android box hardware and Android car screens.

## 2GB RAM Box And Car-Screen Performance Rules

Smooth playback on a 2GB RAM Android TV/karaoke box or low-cost Android car screen is a baseline requirement. Optimize directly for that hardware by default; do not add a separate "weak device mode" unless the user explicitly asks for one. Preserve the existing workflow and karaoke neon look while using the lightest implementation that works.

Rendering rules:
- Avoid continuous background animation, animated particles, animated gradients, bokeh/orb effects, large blur passes, and high-radius shadows.
- Keep focus/button animations short and subtle. Avoid animation inside long lists, grids, search results, queue rows, favorites, or history rows.
- Prefer static gradients, crisp borders, simple custom paint, and low-radius glow over `BackdropFilter`, large `MaskFilter.blur`, shader-heavy effects, or per-frame painting.
- Never use `BackdropFilter` for stacked glass surfaces. Android TV boxes and car head units cannot afford full-screen texture reads per panel.
- Reuse `LiquidGlass`/design tokens, but keep `LiquidGlassDetail.simple` for small or repeated elements.

Media and image rules:
- Decode network and asset thumbnails at display size using `cacheWidth`, `cacheHeight`, and low `filterQuality`.
- Keep Flutter's global `ImageCache` bounded for box RAM limits. Do not increase it without measuring.
- Keep visualizer/background videos optional and off by default. If disabled, do not create or initialize their `VideoPlayerController`.
- Visualizer assets should be MP4/H.264, 720p or lower, 24fps, no audio track, around 900kbps unless measured otherwise.
- Do not bundle old/raw/generated media folders once optimized replacements are in use.

List and state rules:
- Use lazy builders for scrollable content: `ListView.builder`, `ListView.separated`, `ListView.custom`, and `GridView.builder`.
- Keep offscreen cache extent small and prefer `ClampingScrollPhysics` for TV/box-first lists.
- Do not build whole dynamic queues/lists/grids with `children: [...]` if the collection can grow.
- Throttle playback progress UI updates; do not rebuild large UI trees on every audio/video tick when second-level accuracy is enough.

Verification rules:
- `flutter run` debug mode is not representative for performance on 2GB boxes or low-cost Android car screens.
- Test performance-sensitive changes using a release APK on the target Android box, Android car screen, emulator, or BlueStacks:

```bash
flutter build apk --release --dart-define=MUSIC_SDK_LICENSE_KEY=<key>
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Performance Optimization Playbook (applied patterns + gotchas)

These patterns are already applied across the codebase. Follow them when adding features and copy them when optimizing further; do not undo them.

### Rebuild scoping (Riverpod)
- Watch the narrowest slice with `.select`. Never `ref.watch(wholeProvider)` at a page root when only part of the state is rendered — wrap each panel in its own `Consumer` that selects just its slice (see `song_browser_page.dart`, `settings_page.dart`, `source_selection_page.dart`).
- Isolate the ~1s playback tick in tiny leaf `ConsumerWidget`s so it never rebuilds a large subtree (see `preview_player.dart` `_ProgressSection`/`_PlayPauseButton`, `rail_mini_player.dart` `_RailProgressTrack`).
- Watch per-row state (favorite membership, queue selection) inside the row via `.select`, not by threading it from a panel that watches the whole list (see `core/shared/widgets/favorite_toggle.dart`, `selected_queue_panel.dart`).
- GOTCHA: `songBrowserProvider` is `autoDispose.family` and depends on `nowPlayingProvider.notifier`, so it is recreated when playback state rebuilds (e.g. a settings change). Widgets that hold its controller across events must use `ref.watch(provider.notifier)` (NOT `ref.read`), or their callbacks can call a disposed controller.
- GOTCHA: a provider that owns expensive native resources (video/audio decoders) must NOT `ref.watch` a volatile setting in its create body to seed a value — that makes the provider a dependency of the setting, so changing it (e.g. dragging the volume slider) DISPOSES and recreates the provider, tearing down the live decoder and stopping playback. Seed with `ref.read` and apply ongoing changes in place via `ref.listen` (see `nowPlayingProvider` seeding `musicVolume`/`visualizerEnabled`/`videoQuality`).

### Painting cost
- Wrap focus/selection-independent heavy paints in `RepaintBoundary` so focus tweens don't re-rasterize them: thumbnails (`song_thumbnail.dart`), the `LiquidGlass` edge painter, the browse-grid image (`category_grid_panel.dart`), `VideoPlayer`, and the static shell background (`karaoke_shell.dart`).
- Prefer an instant focus highlight (`Container`) over `AnimatedContainer` for anything in a list — a tweened blurred `BoxShadow` re-blurs every frame while scrolling.
- App-wide: overscroll stretch is suppressed (`_NoOverscrollScrollBehavior` in `app.dart`) and `CollapsibleAxis` defaults to `Duration.zero` (instant). Page/route changes use a light opacity-only fade — `_FadePageTransitionsBuilder` in `app_theme.dart` picks the fade, `_FadePageRoute` in `app_router.dart` sets the 220ms duration (`AppMotion.route`). Fade is used (not slide/zoom) because it doesn't relayout the screen; keep it fade-only and short.
- Keep `MaskFilter.blur` and `BoxShadow.blurRadius` small (≤16). A wide gaussian re-rasterized per frame is the single costliest thing on this GPU.

### Caching & network (avoid redundant slow calls)
- Recommendations: stale-while-revalidate, persisted (`RecommendationsCacheRepository`). They fill the results column whenever `SearchState` is `SearchIdle` (`SuggestionsPanel`), so the column is never an empty "type something" placeholder; a submitted search swaps in `SearchResultsPanel`.
- Category/artist/typed search results: in-session `SearchResultsCache` + in-flight/duplicate-query dedupe in `SongBrowserController._runSearch`.
- Playable links: 90s in-memory TTL cache in `NowPlayingController`, evicted on playback failure (links expire) — kills re-resolves on repeat-one/previous/repeat-all.
- Native SDK init is deferred: `main()` fires `ensureMusicSdkInitialized()` without awaiting; `MusicSdkSongRepository` awaits it before its first call.
- RULE: a cache consumed by an `autoDispose` provider must itself live in a NON-autoDispose provider so it survives leaving/returning to the page.

### Memory
- Cap unbounded session-lived lists: the playback back-stack is capped (`QueuePlaybackController._maxHistory = 50`); history persistence caps at 100. Add a cap to any new always-growing list.

### Testing gotchas (or tests hang/fail)
- Any test that pumps `SongBrowserPage` (or otherwise builds `songBrowserProvider`) must override `localStorageServiceProvider` with `FakeLocalStorageService` — including inline `ProviderScope`s a single test builds itself. Otherwise the recommendations spinner never settles and `pumpAndSettle` times out.
- Do NOT cache a module-global `Future` that app code awaits; a single cached `Future` awaited across `flutter_test` zones hangs. Return a fresh `Future.value()` in the no-op/test path (see `ensureMusicSdkInitialized`).
- Do NOT assert playback via `FakeMusicSdkPlatform.lastPlayableLinkTrackId` when a replay can be served from the link cache — read the real state instead: `ProviderScope.containerOf(...).read(nowPlayingProvider).playback`.

### Known remaining wins (not yet done)
- Build/APK (Tier 3): enable R8 + resource shrinking (`isMinifyEnabled`/`isShrinkResources`; keep-rules already exist in `proguard-rules.pro`), drop the `x86_64` ABI (or `--split-per-abi` for `arm64-v8a`), remove the unused `cupertino_icons` dependency, and delete the two unused `assets/browse/*_artist.jpg` images. Together ~145MB → ~95–100MB. Re-test search/playback after enabling R8 (MusicSDK is reflection-heavy).

## Commands

- `flutter pub get` — install dependencies
- `flutter run` — run locally
- `flutter analyze` — lint and static checks (must be clean before considering work done)
- `flutter test` — run all unit/widget tests
- `flutter test test/widget_test.dart` — run a single test file
- `flutter build apk --release` — produce a performance-representative Android build
- `dart format .` — format before finishing any change
- Regenerate localizations (after editing `.arb` files) by running `flutter gen-l10n` or simply `flutter pub get` / `flutter run`, since `l10n.yaml` has `generate: true` wired through `pubspec.yaml`

## Architecture

Feature-first structure inside `lib/`:
- `lib/core/` — theme/tokens, shared widgets, providers, models, constants, helpers used across features
- `lib/features/<feature>/data/` — models, mock data sources, repositories
- `lib/features/<feature>/domain/` — entities/business contracts (only when a feature needs one)
- `lib/features/<feature>/presentation/` — pages, providers/controllers, widgets
- `lib/routes/` — `AppRouter` with a single `onGenerateRoute` switch keyed by named routes (see `lib/routes/app_router.dart`); pass typed arguments via `RouteSettings.arguments` (e.g. `SongBrowserPage` receives a `MusicSource`)
- `lib/main.dart` — bootstrap only (`ProviderScope` + `runApp`), all app config lives in `lib/app.dart`

Current features: `song_browser` (search/filter songs, virtual keyboard input, queue selection) and `source_selection` (choose a music source). Each feature's presentation layer follows the same shape: a `StateNotifierProvider` (often `.autoDispose.family` when scoped to route arguments like `MusicSource`) driving an immutable state class with `copyWith`, consumed by a `ConsumerWidget`/`ConsumerStatefulWidget` page.

Do not place unrelated screens, widgets, and logic in one file. Keep each feature isolated and easy to navigate.

## App Shell And Navigation

Chrome is one left navigation rail, never a top bar or a bottom bar. The screen
on a car head unit and a landscape karaoke box is short and wide, so anything
stacked above or below the body comes straight out of the video stage's height;
a rail costs width, which is the dimension there is spare of.

- `KaraokeShell` takes `navRail` + `body` and lays them out in a Row. Passing
  `chromeVisible: false` (fullscreen playback) drops the rail from the tree
  entirely — not `Offstage`, which would still cost layout.
- Every page passes the same `MainNavRail`
  (`lib/features/navigation/presentation/widgets/`), which owns the brand mark,
  the destinations, the language switch, and the compact now-playing block.
  Pages name their active destination with a `NavDestination` id, never an
  index.
- Neither the rail nor `ContentSlab` paints an edge: no rim, no dividers, no
  lift shadow (`LiquidGlassDetail.none`). The content area is the screen, not a
  panel floating on it. Framed `LiquidGlass` stays for things that really are
  discrete objects — the player's status chips, focus plates, cards.
- The rail paints no surface of its own at all.
  A single hairline `AppLayout.navRailInset` (10) is the ONLY margin on screen
  when the rail is up: all four shell edges plus the gap between the rail and
  the body. The rail itself has no local inset — there is deliberately no
  second value to keep in sync. Change that one token, not the individual
  paddings. Its
  width (`AppLayout.navRailWidth`, 104) is sized to the longest destination
  label measured on device (EN "CATEGORIES", ~73 logical px), not rounded up:
  it is capped even on a 1920 display, because extra width there belongs to the
  stage. `RailMiniPlayer`'s transport row is in a `FittedBox` for the same
  reason — it is wider than the narrowest rail and must scale, not overflow. Only its
  active/focused destination draws a plate. Do not give it a background back:
  every pixel it does not need belongs to the stage.
- The rail's volume control (`VolumeRailEntry`) is the speaker icon plus the
  level, at the foot of the rail above the VI/EN chip; activating it floats a
  vertical slider popup directly above the icon via `OverlayPortal` +
  `LayerLink`. An overlay, never an inline expansion — opening it must not
  shift the destinations under the user's finger. It lives in the footer, NOT
  in `AppNavRail.items` — a `NavRailItem` is rebuilt from `MainNavRail`, and
  watching `volumeProvider` up there would rebuild all eight destinations on
  every volume step, including the hardware keys.
- The track uses a raw `Listener`, not `onVerticalDragUpdate`: the rail's
  `SingleChildScrollView` is a vertical-drag competitor and wins the gesture
  arena, so a drag recognizer here only ever sees the initial touch. Widget
  tests do not catch this — it has to be dragged on a device.
- It writes through `SettingsController.setMasterVolume`, not straight to
  `volumeProvider`, so the level is persisted and Settings → Âm thanh shows the
  same number. It binds left/right, never up/down: up/down traverse the rail,
  and swallowing them would trap focus with no way back to the destinations.
- Below the 1366x768 landscape floor `KaraokeShell` scales the UI down, but the
  canvas takes the DISPLAY's aspect ratio, never a fixed 1366x768. Fitting a
  fixed canvas into a differently-shaped display (a 1280x720 head unit) left
  black bars down both sides that read as the rail floating off the edge.
- `AppNavRail` (`lib/core/shared/widgets/`) is the presentation half: it knows
  nothing about routes or providers. Add destinations through `MainNavRail`.
- A page that handles a destination in place rather than by navigating passes an
  override (`onSearchSelected`, `onCategoriesSelected`, `onQueueSelected`) —
  the song browser switches tabs instead of pushing a route.
- There is no bottom hint legend any more. Anything a hint used to reach must be
  a rail destination or live inside the page it belongs to.

## State Management

Riverpod is the default for new work (`flutter_riverpod`). If a feature already uses BLoC, stay consistent within that feature rather than mixing patterns in the same flow. Keep business logic in controllers/providers, not widgets — widgets read state, render state, and forward user actions (see `SongBrowserController` / `AppLocaleController` for the expected shape: `StateNotifier` + immutable state + intent methods).

## Design System — "Karaoke Neon"

This is the default and required visual language for every screen unless a user explicitly requests otherwise. Full rules live in `lib/core/theme/karaoke_neon_guidelines.md` — read it before touching UI. Summary:
- Dark cinematic backgrounds, never flat white surfaces; neon green/red/orange/purple/blue accents used sparingly.
- Floating dark panels with subtle borders instead of plain containers; glow reserved for focus/active/selected/primary states.
- D-pad/remote focus must be obvious (brighter border, stronger glow, or higher-contrast background) — touch and focus states must feel like one system.
- Implement the neon look with lightweight effects suitable for 2GB RAM boxes. Prefer crisp rims and restrained glow over blur-heavy decoration, animated particles, or moving backgrounds.
- Tokens first: never hardcode colors, spacing, radius, elevation, or text styles in feature screens — reuse/extend `lib/core/theme/app_colors.dart`, `app_spacing.dart`, `app_radius.dart`, `app_text_styles.dart`, `app_glows.dart`, `app_theme.dart`. Add a new token there before repeating a raw value.
- Build shared widgets in `lib/core/shared/widgets/` before duplicating a visual pattern (cards, navigation rail, search shell, virtual keyboard keys, etc.) — extend existing ones like `GlowCard`, `KaraokeShell`, `AppNavRail`, `LiquidGlass`, `FocusableTile`, `VirtualKeyTile` rather than rebuilding.
- When editing one area, don't redesign it in isolation — match existing tokens/panel shapes/focus treatment so it still looks like the same product.
- Keep text, controls, and focus affordances readable on Android boxes and car screens viewed from a distance. Do not optimize visual density only for hand-held phones.

## Localization

Uses Flutter `gen-l10n`. Default locale `vi`, supported locales `vi` and `en`.
- Source of truth: `lib/l10n/app_vi.arb` (template) and `lib/l10n/app_en.arb` — add new keys to both.
- All user-facing text (labels, placeholders, titles, button/dialog/hint text) must be localized — no hardcoded UI copy once a key should exist.
- Vietnamese copy needs correct accents and natural phrasing; English copy should stay close in meaning to the Vietnamese source.
- Localized mock data shown in UI should use localized factories/labels, not embedded non-localized copy.
- The `VI/EN` toggle (`appLocaleProvider` / `AppLocaleController` in `lib/core/providers/locale_provider.dart`) must switch locale app-wide — don't let a screen toggle local visual state instead of the shared locale provider.

## Coding Conventions

2-space indentation; run `dart format .` before finishing. `UpperCamelCase` classes, `lowerCamelCase` variables/methods, `snake_case.dart` files. Keep widgets small and composable — extract child widgets or move logic into providers/controllers once a widget mixes layout and logic heavily or grows too large (e.g. avoid growing files like the existing ~1000-line `song_browser_page.dart` further; split it if you touch it substantially). Prefer `const` constructors where possible.

## Testing

Use `flutter_test` for widget and unit tests. Add tests for reusable components, view states, and important user interactions. Name tests by behavior (e.g. `shows_loading_indicator`, `submits_valid_form`). For responsive screens, verify layout stays usable at smaller viewport sizes. Don't consider work complete if `flutter analyze` errors or obvious widget test regressions remain.

## Delivery Expectations For AI

- State where new files should live before creating them.
- Create shared components before repeating UI blocks.
- Keep feature boundaries clear; preserve the existing pattern inside each feature you touch.
- Preserve the karaoke neon visual language unless explicitly overridden.
- Prioritize Android box / Android car-screen karaoke usage over generic phone-first behavior.
- Avoid temporary hacks, magic numbers, and tightly coupled widget code; structure screens for future expansion.
- Preserve the 2GB RAM box performance budget: avoid new heavy effects, keep assets light, use lazy lists/grids, constrain image decode size, and avoid unnecessary rebuilds.
- If a requested UI conflicts with maintainability, choose the maintainable approach and keep the code structured so visual changes stay easy later.
