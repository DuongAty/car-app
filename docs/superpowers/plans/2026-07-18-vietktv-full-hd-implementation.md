# VietKTV Full HD Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Migrate VietKTV to a `1920x1080` design canvas so the karaoke neon UI matches the Full HD references more closely at runtime.

**Architecture:** Introduce shared Full HD layout tokens in `lib/core/theme`, make `KaraokeShell` the single `1920x1080` canvas owner, then update the source selection and song browser pages to consume those shared layout dimensions instead of mixing ad-hoc flex and hardcoded 720p-era sizes.

**Tech Stack:** Flutter, Material 3, Riverpod, flutter_test

## Global Constraints

- Act as a senior Flutter engineer with 10+ years of experience delivering production Android apps.
- This project targets Android first and must support at least Android 10 (API 29) and above.
- Use a feature-first structure inside `lib/`.
- Prefer `Riverpod` as the default state management solution for new work.
- The default UI style for this repository is `karaoke neon`.
- Every screen must be responsive, but this feature uses `1920x1080` as the primary design canvas and scales the composed surface down on smaller landscape displays.
- Use 2-space indentation and run `dart format .` before finishing.
- Do not consider work complete if analysis errors or obvious widget test regressions remain.

---

### Task 1: Add Shared Full HD Layout Tokens

**Files:**
- Create: `lib/core/theme/app_layout.dart`
- Modify: `lib/core/shared/widgets/karaoke_shell.dart`

**Interfaces:**
- Consumes: existing `AppSpacing`, `AppRadius`, and `KaraokeShell` slots
- Produces: `AppLayout` constants for shell, source selection, and song browser sizing

- [ ] Define `AppLayout` constants for the `1920x1080` canvas and shared panel sizes.
- [ ] Update `KaraokeShell` to render a fixed `1920x1080` canvas with the new shell paddings.
- [ ] Keep portrait fallback behavior intact while preventing landscape reflow.

### Task 2: Rebuild Source Selection For Full HD

**Files:**
- Modify: `lib/features/source_selection/presentation/pages/source_selection_page.dart`

**Interfaces:**
- Consumes: `AppLayout.shell*`, `AppLayout.sourceSelection*`, existing `GlowCard`, `AppTopNav`, `LanguageToggle`
- Produces: fixed-row Full HD source selection layout

- [ ] Replace the `Wrap`-based card layout with a stable three-card row for landscape.
- [ ] Resize the headline, top bar spacing, and card sizes for TV viewing distance.
- [ ] Keep portrait fallback scroll-safe.

### Task 3: Rebuild Song Browser For Full HD

**Files:**
- Modify: `lib/features/song_browser/presentation/pages/song_browser_page.dart`

**Interfaces:**
- Consumes: `AppLayout.songBrowser*`, existing keyboard open/close behavior, `SearchInputShell`, `AppBottomHintBar`
- Produces: fixed three-column Full HD browser layout with stable preview/search/keyboard heights

- [ ] Remove intermediate landscape reflow thresholds so landscape keeps the TV layout.
- [ ] Replace mixed preview/keyboard flex sizing with shared Full HD target heights.
- [ ] Keep `BACK`, tap-outside, and search focus behavior unchanged.

### Task 4: Verify Full HD Migration

**Files:**
- Modify: `test/widget_test.dart`

**Interfaces:**
- Consumes: existing widget tests
- Produces: regression coverage for Full HD render assumptions and search keyboard behavior

- [ ] Keep the source selection render test passing under the new shell.
- [ ] Keep song browser keyboard open/close tests passing at `1920x1080`.
- [ ] Run `dart format`, `flutter analyze`, and `flutter test`.
