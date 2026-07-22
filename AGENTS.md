# Repository Guidelines

## AI Role
Act as a senior Flutter engineer with 10+ years of experience delivering production Android apps. Build UI with a feature-first architecture, a reusable design system, and code that is easy to extend, test, refactor, and maintain. Prefer long-term clarity over short-term speed.

## Target Platform
This project targets Android first and must support at least Android 10 (API 29) and above. All UI must behave correctly on common Android phone sizes, handle small and large screens gracefully, and avoid layout overflow in portrait mode.

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

When changing only one area of the UI, do not redesign it in isolation. Extend the existing karaoke neon design system in `lib/core/theme/` and `lib/core/shared/widgets/` so the new work still looks like part of the same product.

## Responsive UI Requirements
Every screen must be responsive. Use `LayoutBuilder`, `MediaQuery`, flexible widgets, constraints, and scroll-safe layouts where appropriate. Avoid fixed widths and heights unless strictly necessary. Support narrow Android phones first, then scale up cleanly for larger devices. If a screen contains dense content, structure it so it still works on smaller Android 10 devices without clipping or overflow.

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
- `flutter build apk` to create an Android build

Do not consider work complete if analysis errors or obvious widget test regressions remain.

## Testing Expectations
Use `flutter_test` for widget and unit tests. Add tests for reusable components, view states, and important user interactions. Name tests by behavior, such as `shows_loading_indicator` or `submits_valid_form`. For responsive screens, verify that the layout remains usable with smaller viewport sizes.

## Delivery Rules For AI
When implementing UI, always:
- explain where new files should live
- create shared components before repeating UI blocks
- keep feature boundaries clear
- preserve consistency with the existing pattern inside each feature
- preserve the karaoke neon visual language unless the user explicitly overrides it
- avoid temporary hacks, magic numbers, and tightly coupled widget code
- make screens ready for future expansion

If a requested UI conflicts with maintainability, choose the maintainable approach and structure the code so visual changes remain easy later.
