# VietKTV I18n Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real Vietnamese/English internationalization to VietKTV with Vietnamese as the default locale and make the `VI/EN` toggle switch the whole app locale.

**Architecture:** Use Flutter `gen-l10n` with `arb` files, a global Riverpod locale provider, and localized mock-data factories for UI-facing labels. Replace hardcoded strings on the source selection and song browser screens with generated localizations and update `AGENTS.md` so future AI edits follow the same workflow.

**Tech Stack:** Flutter, Material 3, Riverpod, flutter_localizations, gen-l10n, flutter_test

## Global Constraints

- Act as a senior Flutter engineer with 10+ years of experience delivering production Android apps.
- This project targets Android first and must support at least Android 10 (API 29) and above.
- Prefer `Riverpod` as the default state management solution for new work.
- The default UI style for this repository is `karaoke neon`.
- Use 2-space indentation and run `dart format .` before finishing.
- Vietnamese is the default locale.
- Vietnamese copy must include proper accents.
- English copy must stay close in meaning to the Vietnamese source text.
- New UI strings must be added through `lib/l10n/*.arb`, not hardcoded in widgets.

---

### Task 1: Add Localization Infrastructure
- [ ] Add `flutter_localizations`, `generate: true`, and `l10n.yaml`
- [ ] Create `app_vi.arb` and `app_en.arb`
- [ ] Add a global locale provider and wire it into `app.dart`

### Task 2: Localize Shared UI And Source Selection
- [ ] Update `LanguageToggle` to use the global locale provider
- [ ] Localize source selection screen labels and UI-facing mock data
- [ ] Remove per-feature fake language state from source selection

### Task 3: Localize Song Browser
- [ ] Localize screen labels, placeholder copy, panel titles, keyboard labels, and UI-facing mock data
- [ ] Keep the existing keyboard behavior and search logic intact
- [ ] Remove per-feature fake language state from song browser

### Task 4: Update Agent Guidance And Tests
- [ ] Update `AGENTS.md` with mandatory i18n rules for future AI edits
- [ ] Update widget tests for accented Vietnamese defaults and locale-aware copy
- [ ] Run `dart format`, `flutter analyze`, and `flutter test`
