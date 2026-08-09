# car-app

car-app is a Flutter karaoke application built for Android-first playback devices: low-cost Android TV/karaoke boxes and Android car entertainment screens. The app is optimized for landscape viewing, remote/D-pad navigation, and stable audio/video playback on constrained hardware.

This is not a generic mobile-first Flutter starter. Phones are supported for compatibility and testing, but product decisions should prioritize karaoke sessions on Android box hardware and in-car Android displays.

## Target devices

- Android 10 (API 29) and above
- Low-cost Android TV/karaoke boxes, often with 2GB RAM
- Android car head units / car entertainment screens
- Landscape-first displays controlled by remote, D-pad, touch, or mixed input
- Common Android phone sizes as a fallback, without overflow in portrait or landscape

## Product direction

- Karaoke neon visual language: dark cinematic surfaces, high-contrast text, restrained neon accents, visible focus states
- TV/car-screen usability: readable from distance, clear selection, predictable directional navigation
- Lightweight rendering: no expensive background animation, stacked blur, large glow, or unnecessary video decoding
- Vietnamese-first localization with English support

## Engineering rules

Read [AGENTS.md](/Users/macbookpro/car-app/AGENTS.md) before making implementation changes. It defines the project architecture, design-system rules, localization requirements, performance budget, and testing expectations.

For a shorter project brief, read [docs/PROJECT_CONTEXT.md](/Users/macbookpro/car-app/docs/PROJECT_CONTEXT.md).

## Architecture

The codebase uses a feature-first Flutter structure:

- `lib/core/` — theme, tokens, shared widgets, services, helpers
- `lib/features/<feature>/data/` — models, repositories, data sources
- `lib/features/<feature>/domain/` — entities and contracts when needed
- `lib/features/<feature>/presentation/` — pages, controllers/providers, widgets, states
- `lib/routes/` — app routing
- `lib/main.dart` — bootstrap only

Riverpod is the default state-management approach for new work.

## Localization

Flutter `gen-l10n` is used for app copy.

- Default locale: `vi`
- Supported locales: `vi`, `en`
- Source files: `lib/l10n/app_vi.arb`, `lib/l10n/app_en.arb`

Do not hardcode user-facing text in widgets.

## Common commands

```bash
flutter pub get
dart format .
flutter analyze
flutter test
flutter build apk --release
```

For target-device validation:

```bash
flutter build apk --release --dart-define=MUSIC_SDK_LICENSE_KEY=<key>
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

Debug mode is not representative of performance on 2GB Android boxes or low-cost car screens. Validate performance-sensitive work with a release APK.
