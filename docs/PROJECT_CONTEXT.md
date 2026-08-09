# Project Context

car-app is an Android-first karaoke app for Android box hardware and Android car entertainment screens.

## Primary use case

The main user is running karaoke on a large or medium landscape screen:

- a low-cost Android TV/karaoke box connected to a TV
- an Android-based car head unit or car entertainment display
- a remote/D-pad, steering/control buttons, touch screen, or mixed input

Future contributors must not treat this project as a normal phone-first app. Phone layouts matter because the app should not overflow or break, but the core UX is a TV/car-screen karaoke experience.

## Device assumptions

- Android 10 / API 29 minimum
- 2GB RAM Android boxes are a baseline target
- Landscape is the primary layout
- Portrait must remain safe and usable, but does not drive the main visual design
- Remote/D-pad focus is as important as touch input
- Text and controls must remain readable from a distance

## UI direction

The visual language is karaoke neon:

- dark cinematic background
- floating dark panels
- neon green, red, orange, purple, and blue accents
- obvious focus/selected states
- bold, high-contrast typography

Keep the style lightweight. Prefer crisp borders, simple gradients, and restrained glow. Avoid heavy blur, continuous animation, animated particles, animated gradients, or video-backed decoration unless there is a specific measured reason.

## Performance baseline

Smooth playback on 2GB Android boxes is required.

- Use lazy lists and grids for growing collections
- Decode images at display size
- Keep image cache bounded
- Avoid unnecessary rebuilds from playback ticks
- Avoid creating background video controllers when visualizers are disabled
- Test performance-sensitive work in release builds

## Contributor checklist

Before changing UI or playback behavior:

- Confirm the layout works in landscape on Android box/car-screen style displays
- Confirm focus navigation is visible and predictable
- Confirm small screens do not overflow
- Keep new user-facing strings localized in Vietnamese and English
- Reuse or extend shared design-system widgets before adding one-off UI
- Run `dart format .`, `flutter analyze`, and relevant tests
