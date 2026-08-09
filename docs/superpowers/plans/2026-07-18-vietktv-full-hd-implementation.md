# car-app Responsive Android Display Implementation Plan

> Historical note: this plan replaces the earlier fixed Full HD canvas direction. Do not reintroduce a fixed `1920x1080` shell.

**Goal:** Make car-app responsive for Android boxes and Android car entertainment screens while preserving the karaoke neon visual language and 2GB RAM performance budget.

**Architecture:** Keep shared layout targets in `AppLayout`, but treat them as clamped maximums. `KaraokeShell` owns safe-area padding and background only; feature pages own their responsive column/grid decisions through `LayoutBuilder`.

## Global Constraints

- Android 10+.
- Android box and car-screen landscape are primary.
- Remote/D-pad focus and touch input must both work.
- Do not rename the Dart package from `viet_ktv` unless explicitly requested.
- Avoid heavy rendering effects and fixed full-screen media backgrounds.

## Task 1: Shell

- [ ] Remove any `FittedBox` fixed-canvas shell behavior.
- [ ] Fill the actual safe viewport.
- [ ] Apply bounded responsive shell padding and gaps.

## Task 2: Source selection

- [ ] Remove legacy brand wordmark from active UI.
- [ ] Replace the old welcome copy with localized “Chọn nguồn nhạc để bắt đầu”.
- [ ] Use a responsive source grid: 3 columns on wide displays, fewer columns on narrow displays.
- [ ] Keep the grid scroll-safe for low-height car screens.

## Task 3: Other feature pages

- [ ] Audit fixed side-panel widths in song browser, queue, favorites, history, and settings.
- [ ] Convert hard widths to clamped values where they can overflow.
- [ ] Collapse optional panels before shrinking primary playback/search controls.

## Task 4: Verification

- [ ] Run `dart format .`.
- [ ] Run `flutter analyze`.
- [ ] Run relevant widget tests.
- [ ] Manually verify a car-screen-like landscape size such as 1024x600 or 1280x720.
