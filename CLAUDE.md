# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## AI Role

Act as a senior Flutter engineer delivering production Android apps. Build UI with a feature-first architecture, a reusable design system, and code that is easy to extend, test, refactor, and maintain. Prefer long-term clarity over short-term speed.

## Target Platform

Android first, must support Android 10 (API 29) and above. All UI must behave correctly on common Android phone/TV sizes, handle small and large screens gracefully, and avoid layout overflow — landscape is the primary karaoke layout, since focus/D-pad navigation (remote control) is a first-class interaction, not just touch.

## Commands

- `flutter pub get` — install dependencies
- `flutter run` — run locally
- `flutter analyze` — lint and static checks (must be clean before considering work done)
- `flutter test` — run all unit/widget tests
- `flutter test test/widget_test.dart` — run a single test file
- `flutter build apk` — produce an Android build
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

## State Management

Riverpod is the default for new work (`flutter_riverpod`). If a feature already uses BLoC, stay consistent within that feature rather than mixing patterns in the same flow. Keep business logic in controllers/providers, not widgets — widgets read state, render state, and forward user actions (see `SongBrowserController` / `AppLocaleController` for the expected shape: `StateNotifier` + immutable state + intent methods).

## Design System — "Karaoke Neon"

This is the default and required visual language for every screen unless a user explicitly requests otherwise. Full rules live in `lib/core/theme/karaoke_neon_guidelines.md` — read it before touching UI. Summary:
- Dark cinematic backgrounds, never flat white surfaces; neon green/red/orange/purple/blue accents used sparingly.
- Floating dark panels with subtle borders instead of plain containers; glow reserved for focus/active/selected/primary states.
- D-pad/remote focus must be obvious (brighter border, stronger glow, or higher-contrast background) — touch and focus states must feel like one system.
- Tokens first: never hardcode colors, spacing, radius, elevation, or text styles in feature screens — reuse/extend `lib/core/theme/app_colors.dart`, `app_spacing.dart`, `app_radius.dart`, `app_text_styles.dart`, `app_glows.dart`, `app_theme.dart`. Add a new token there before repeating a raw value.
- Build shared widgets in `lib/core/shared/widgets/` before duplicating a visual pattern (cards, top nav, bottom hint bar, search shell, virtual keyboard keys, etc.) — extend existing ones like `GlowCard`, `KaraokeShell`, `AppTopNav`, `AppBottomHintBar`, `FocusableTile`, `VirtualKeyTile` rather than rebuilding.
- When editing one area, don't redesign it in isolation — match existing tokens/panel shapes/focus treatment so it still looks like the same product.

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
- Avoid temporary hacks, magic numbers, and tightly coupled widget code; structure screens for future expansion.
- If a requested UI conflicts with maintainability, choose the maintainable approach and keep the code structured so visual changes stay easy later.
