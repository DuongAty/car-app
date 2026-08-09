# Repository Guidelines

## AI Role
Act as a senior Flutter engineer with 10+ years of experience delivering production Android apps. Build UI with a feature-first architecture, a reusable design system, and code that is easy to extend, test, refactor, and maintain. Prefer long-term clarity over short-term speed.

## Target Platform
This project targets Android first and must support at least Android 10 (API 29) and above. The primary deployment targets are low-cost Android TV/karaoke boxes with 2GB RAM and Android car head units / in-car entertainment screens. Assume landscape use, remote/D-pad navigation, touch input, and mixed input depending on the device. All UI must behave correctly on Android box displays, Android car screens, common Android phone sizes, small and large screens, and avoid layout overflow in portrait or landscape.

Do not treat this repository as a generic mobile-first Flutter app. Phones are supported for compatibility and testing, but product and performance decisions should prioritize karaoke sessions on Android box hardware and Android car screens.

## Performance Budget For 2GB RAM Boxes And Car Screens
Treat smooth playback on a 2GB RAM Android box or low-cost Android car screen as a default requirement, not an optional mode. When implementing or reviewing any feature, preserve the existing workflow and visual identity while choosing the lightest implementation that still looks professional.

- Do not add continuous background animation, animated particles, animated gradients, bokeh/orb effects, large blur passes, or high-radius shadows unless the user explicitly asks and there is a clear performance justification.
- Keep focus and button animations short, subtle, and bounded. Avoid animations inside long lists, grids, queue rows, search results, or any widget that can appear many times.
- Prefer static painted decoration, simple gradients, crisp borders, and low-radius glow over `BackdropFilter`, heavy `MaskFilter.blur`, large `BoxShadow.blurRadius`, shader-heavy effects, or per-frame custom painting.
- Avoid `BackdropFilter` entirely for app surfaces. It is too expensive for stacked glass panels on Android TV boxes and car head units.
- Decode images at display size using `cacheWidth`, `cacheHeight`, and low `filterQuality` for thumbnails, category cards, browse artwork, search results, favorites, history, and queue rows.
- Keep Flutter's global `ImageCache` bounded for box RAM limits. Do not raise cache size without measuring and explaining why.
- Use lazy builders for scrollable collections (`ListView.builder`, `ListView.separated`, `ListView.custom`, `GridView.builder`) and keep offscreen cache extent small. Do not build a whole queue/list/grid with a `children: [...]` list when it can grow.
- Use `ClampingScrollPhysics` for TV/box-first lists unless bounce behavior is explicitly required.
- Throttle playback progress UI updates. Do not rebuild large UI trees on every video/audio tick when labels and progress only need second-level accuracy.
- Keep video decode count minimal. For audio-only sources, visualizer/background video must be optional and off by default for box deployments. If a visualizer is disabled, do not create or initialize its `VideoPlayerController` in the background.
- Keep visualizer assets lightweight: MP4/H.264, 720p or lower, 24fps, no audio track, bitrate near 900kbps unless there is a measured reason to increase it. Do not bundle raw 1080p/4K visualizer assets.
- Keep APK assets tight. Only folders listed in `pubspec.yaml` should be intended for runtime. Remove or exclude old/generated media folders once replacements are in use.
- Test performance-sensitive changes in `--release` builds, not only `flutter run` debug mode. Debug mode is not representative on 2GB boxes or low-cost Android car screens.

## Performance Optimization Playbook (applied patterns + gotchas)
These patterns are already applied across the codebase. Follow them for new work and copy them when optimizing further; do not undo them.

Rebuild scoping (Riverpod):
- Watch the narrowest slice with `.select`. Never `ref.watch(wholeProvider)` at a page root when only part of the state is rendered — wrap each panel in its own `Consumer` that selects just its slice (`song_browser_page.dart`, `settings_page.dart`, `source_selection_page.dart`).
- Isolate the ~1s playback tick in tiny leaf `ConsumerWidget`s so it never rebuilds a large subtree (`preview_player.dart`, `bottom_mini_player.dart`).
- Watch per-row state (favorite membership, queue selection) inside the row via `.select`, not threaded from a panel that watches the whole list (`core/shared/widgets/favorite_toggle.dart`, `selected_queue_panel.dart`).
- GOTCHA: `songBrowserProvider` is `autoDispose.family` and depends on `nowPlayingProvider.notifier`, so it is recreated when playback state rebuilds. Widgets holding its controller across events must use `ref.watch(provider.notifier)` (NOT `ref.read`) so callbacks never hit a disposed controller.
- GOTCHA: a provider owning native decoders (video/audio) must NOT `ref.watch` a volatile setting in its create body — that recreates the provider (and tears down the decoder, stopping playback) whenever the setting changes, e.g. a volume-slider drag. Seed with `ref.read`, apply ongoing changes via `ref.listen` in place (`nowPlayingProvider`). Also: skeleton/loading widgets must be STATIC (no `AnimationController.repeat()` shimmer) — `NeonSkeletonList` is static on purpose.

Painting cost:
- Wrap focus/selection-independent heavy paints in `RepaintBoundary` (thumbnails, `LiquidGlass` edge, browse-grid image, `VideoPlayer`, shell background) so focus tweens don't re-rasterize them.
- Prefer an instant focus highlight (`Container`) over `AnimatedContainer` for list rows — a tweened blurred `BoxShadow` re-blurs every frame while scrolling.
- App-wide: overscroll stretch suppressed (`app.dart` `scrollBehavior`); `CollapsibleAxis` defaults to `Duration.zero` (instant). Page/route changes use a light opacity-only fade at 220ms (`_FadePageTransitionsBuilder` in `app_theme.dart` + `_FadePageRoute` in `app_router.dart`, `AppMotion.route`) — fade only (no slide/zoom, no relayout); keep it short.
- Keep `MaskFilter.blur` / `BoxShadow.blurRadius` ≤ 16; a wide gaussian re-rasterized per frame is the costliest thing on this GPU.

Caching & network:
- Recommendations: persisted stale-while-revalidate (`RecommendationsCacheRepository`). Category/artist/search: in-session `SearchResultsCache` + duplicate/in-flight dedupe. Playable links: 90s in-memory TTL cache in `NowPlayingController`, evicted on failure.
- Native SDK init is deferred: `main()` fires `ensureMusicSdkInitialized()` without awaiting; the repository awaits it before its first call.
- RULE: a cache consumed by an `autoDispose` provider must live in a NON-autoDispose provider so it survives re-navigation.

Memory: cap unbounded session-lived lists (playback back-stack capped at 50; history capped at 100). Cap any new always-growing list.

Testing gotchas (or tests hang/fail):
- Any test that pumps `SongBrowserPage` (or builds `songBrowserProvider`) must override `localStorageServiceProvider` with `FakeLocalStorageService`, including inline `ProviderScope`s — otherwise the recommendations spinner never settles and `pumpAndSettle` times out.
- Do NOT cache a module-global `Future` that app code awaits; awaited across `flutter_test` zones it hangs. Return a fresh `Future.value()` in the no-op/test path (see `ensureMusicSdkInitialized`).
- Do NOT assert playback via `FakeMusicSdkPlatform.lastPlayableLinkTrackId` when a replay can be cache-served; read `ProviderScope.containerOf(...).read(nowPlayingProvider).playback` instead.

Known remaining wins (not yet done): Build/APK (Tier 3) — enable R8 + resource shrinking (`isMinifyEnabled`/`isShrinkResources`; keep-rules already in `proguard-rules.pro`), drop the `x86_64` ABI (or `--split-per-abi` for `arm64-v8a`), remove the unused `cupertino_icons` dependency, delete the two unused `assets/browse/*_artist.jpg` images. Together ~145MB → ~95–100MB; re-test search/playback after R8 (MusicSDK is reflection-heavy).

## Required Architecture
Use a feature-first structure inside `lib/`:
- `lib/core/` for theme, tokens, shared widgets, constants, helpers, error handling, and common services
- `lib/features/<feature>/data/` for models, repositories, and data sources
- `lib/features/<feature>/domain/` for entities and business contracts when needed
- `lib/features/<feature>/presentation/` for pages, controllers, providers, widgets, and states
- `lib/routes/` for app routing
- `lib/main.dart` only for bootstrap and app-level configuration

Do not place unrelated screens, widgets, and logic in one file. Keep each feature isolated and easy to navigate.

## State Management Standard
Prefer `Riverpod` as the default state management solution for new work. If a feature already uses `BLoC`, keep it consistent and continue with `BLoC` in that feature instead of mixing patterns inside the same flow. Keep business logic out of widgets. Widgets should read state, render state, and forward user actions.

## Design System Rules
Always build and use shared UI primitives before duplicating visual patterns. Define and reuse:
- color tokens
- text styles
- spacing scale
- radius scale
- elevation/shadow rules
- button, input, card, app bar, dialog, and empty-state components

Put shared design tokens and common widgets in `lib/core/`. Do not hardcode colors, font sizes, spacing, border radius, or shadows directly in feature screens unless there is a strong one-off reason.

## Localization Rules
This repository uses Flutter `gen-l10n` for app copy. Treat localization as mandatory for all user-facing UI text.

- Default locale is `vi`
- Supported locales are `vi` and `en`
- Add new UI strings to `lib/l10n/app_vi.arb` and `lib/l10n/app_en.arb`
- Do not hardcode user-facing labels, placeholders, panel titles, button text, dialog text, or hint text directly in widgets once a localized key should exist
- Vietnamese copy must include proper accents and read naturally
- English copy must stay close in meaning to the Vietnamese source text
- When updating mock data that is shown in UI, prefer localized factories or localized labels instead of embedding non-localized UI copy
- When editing screens, ensure the `VI/EN` toggle continues to switch locale app-wide rather than toggling local visual state only

## Default Visual Language
The default UI style for this repository is `karaoke neon`. Unless a user explicitly asks for a different visual direction, all new screens and all future UI edits must continue this same style:
- dark cinematic background
- neon green, red, orange, purple, and blue accents
- glowing borders and highlighted focus states
- bold, high-contrast typography
- floating dark panels instead of flat white surfaces

When changing only one area of the UI, do not redesign it in isolation. Extend the existing karaoke neon design system in `lib/core/theme/` and `lib/core/shared/widgets/` so the new work still looks like part of the same product. Karaoke neon must be implemented with lightweight effects suitable for 2GB RAM boxes: crisp rims, restrained glow, and static decoration are preferred over blur-heavy or animated decoration.

## Responsive UI Requirements
Every screen must be responsive. Use `LayoutBuilder`, `MediaQuery`, flexible widgets, constraints, and scroll-safe layouts where appropriate. Avoid fixed widths and heights unless strictly necessary. Design the primary experience for landscape Android box and Android car screens, then make sure narrow Android phones and portrait fallback layouts remain usable without clipping or overflow. If a screen contains dense content, structure it so it still works on smaller Android 10 devices.

## Coding Conventions
Use 2-space indentation and run `dart format .` before finishing. Use:
- `UpperCamelCase` for classes
- `lowerCamelCase` for variables and methods
- `snake_case.dart` for file names

Keep widgets small and composable. If a widget exceeds a reasonable size or mixes layout and logic heavily, extract child widgets or move logic into providers/controllers. Prefer const constructors where possible.

## Build, Analyze, and Test Commands
Use:
- `flutter pub get` to install dependencies
- `flutter run` to run locally
- `flutter analyze` to enforce lint and static checks
- `flutter test` to run unit and widget tests
- `flutter build apk --release` to create a performance-representative Android build

Do not consider work complete if analysis errors or obvious widget test regressions remain.

For box/car-screen performance validation, install a release APK on the target Android box, Android car screen, or emulator:

```bash
flutter build apk --release --dart-define=MUSIC_SDK_LICENSE_KEY=<key>
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## Testing Expectations
Use `flutter_test` for widget and unit tests. Add tests for reusable components, view states, and important user interactions. Name tests by behavior, such as `shows_loading_indicator` or `submits_valid_form`. For responsive screens, verify that the layout remains usable with smaller viewport sizes.

## Delivery Rules For AI
When implementing UI, always:
- explain where new files should live
- create shared components before repeating UI blocks
- keep feature boundaries clear
- preserve consistency with the existing pattern inside each feature
- preserve the karaoke neon visual language unless the user explicitly overrides it
- prioritize Android box / Android car-screen karaoke usage over generic phone-first behavior
- avoid temporary hacks, magic numbers, and tightly coupled widget code
- make screens ready for future expansion
- preserve the 2GB RAM box performance budget: avoid new heavy effects, keep media assets light, use lazy lists/grids, constrain image decode size, and avoid unnecessary rebuilds

If a requested UI conflicts with maintainability, choose the maintainable approach and structure the code so visual changes remain easy later.
