# VietKTV I18n Design

## Summary
Add real Flutter internationalization to VietKTV using `gen-l10n`, with Vietnamese as the default locale and English as the secondary locale.

The existing `VI/EN` toggle must change the app locale globally instead of only toggling local UI state. New UI copy must be added through the localization files rather than hardcoded directly in widgets or mock data.

## Goals
- Make `vi` the default locale for the app
- Add a real `vi/en` localization pipeline using `arb` files
- Ensure Vietnamese strings include proper accents
- Ensure English strings stay close in meaning to the Vietnamese source text
- Make future AI edits automatically follow the same i18n workflow

## Non-Goals
- No machine-translation workflow
- No support for locales beyond `vi` and `en` in this phase
- No migration of song titles into translated variants unless they are UI copy

## Architecture
- Use Flutter `gen-l10n`
- Add `lib/l10n/app_vi.arb` and `lib/l10n/app_en.arb`
- Add a global Riverpod locale provider with default `Locale('vi')`
- Wire `MaterialApp.locale`, `supportedLocales`, and localization delegates in `app.dart`
- Replace hardcoded UI copy in the current home screen, song browser screen, shared widgets, and UI-facing mock data factories

## Content Rules
- Vietnamese copy must use correct accents and readable wording
- English copy must preserve meaning closely, not paraphrase loosely
- UI strings must not be hardcoded in widgets once a localized equivalent exists
- New prompt-driven UI changes must add strings to the `arb` files and consume them through generated localizations

## Files Expected To Change
- `pubspec.yaml`
- `l10n.yaml`
- `lib/l10n/app_vi.arb`
- `lib/l10n/app_en.arb`
- `lib/app.dart`
- `lib/core/providers/locale_provider.dart`
- `lib/core/shared/widgets/language_toggle.dart`
- `lib/features/source_selection/...`
- `lib/features/song_browser/...`
- `AGENTS.md`
- `test/widget_test.dart`

## Acceptance Criteria
- App launches in Vietnamese by default
- Tapping the `VI/EN` control changes locale app-wide
- Current UI text on the two main screens comes from generated localizations
- Vietnamese strings show proper accents
- English strings are accurate translations
- `AGENTS.md` explicitly instructs AI to add future UI strings through `lib/l10n/*.arb`
- `flutter analyze` passes
- `flutter test` passes
