# car-app Responsive Android Display Design

## Summary

car-app must adapt to Android box displays and Android car entertainment screens instead of depending on one fixed Full HD canvas. Large 16:9 screens remain the main visual target, but the runtime layout must derive sizes from the actual viewport and stay usable on smaller or unusual car-head-unit resolutions.

## Goals

- Fill the available Android display without `FittedBox`-scaling one hardcoded canvas.
- Keep the karaoke neon visual language intact.
- Make source selection, song browsing, queue, history, favorites, and settings scroll-safe.
- Preserve obvious remote/D-pad focus while also supporting touch screens.
- Avoid render overflow on low-height landscape car screens.

## Non-Goals

- No package rename; the Dart package can remain `viet_ktv`.
- No redesign of the music-source cards or karaoke neon identity.
- No phone-first redesign. Phones are fallback targets, not the primary product.

## Core Decision

Use constraint-based responsive layout:

- `KaraokeShell` fills the safe area and applies bounded responsive padding.
- `AppLayout` constants are large-screen targets, not absolute device pixels.
- Individual screens choose columns, panel widths, card counts, and scroll behavior from their `LayoutBuilder` constraints.
- Fixed dimensions are allowed only as clamped upper/lower bounds for readability and focus targets.

## Responsive Strategy

Landscape Android box / car screen:

- Prefer multi-column layouts when width and height allow.
- Collapse optional side panels first on narrower displays.
- Keep playback/search controls reachable without overflow.

Small or low-height displays:

- Use lazy scrollable layouts where content cannot fit.
- Keep focusable controls large enough for D-pad/touch use.
- Reduce gaps and padding before shrinking text below readable sizes.

Portrait fallback:

- Must not overflow.
- Can stack content vertically and scroll.
- Does not need a separate visual identity.

## Files Expected To Change

- `lib/core/shared/widgets/karaoke_shell.dart`
- `lib/core/theme/app_layout.dart`
- `lib/features/source_selection/presentation/pages/source_selection_page.dart`
- Other feature pages when they still assume fixed large-screen panel widths

## Acceptance Criteria

- No active docs require a fixed `1920x1080` app canvas.
- Source selection does not show legacy brand logo/copy and adapts to available width.
- Home headline reads “Chọn nguồn nhạc để bắt đầu” in Vietnamese.
- `flutter analyze` passes.
- Relevant widget tests pass.
