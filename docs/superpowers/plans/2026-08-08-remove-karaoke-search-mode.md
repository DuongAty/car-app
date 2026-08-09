# Remove The Karaoke Search Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Delete the karaoke search mode entirely — the toggle, the mode pill,
the enum, and the query rewriting — so searches run on exactly what the user
typed.

**Architecture:** One atomic task. The enum, its provider, its toggle widget and
its consumers reference each other, so removing them piecemeal leaves the tree
uncompilable between steps. The only logic that survives is whitespace
normalization, which moves to a private helper in the controller because the
search cache key depends on it.

**Tech Stack:** Flutter, Riverpod (`StateNotifier`), `gen-l10n`.

**Spec:** `docs/superpowers/specs/2026-08-08-remove-karaoke-search-mode-design.md`

## Global Constraints

- **Do not run any git write command.** No `git add`, `git commit`, `git push`,
  `git stash`, `git checkout`, `git restore`, `git clean`. The user manages git
  themselves. This overrides the usual per-task commit step; the task ends at
  "tests pass".
- **Do not run `dart format .`** — it reformats the whole repo, including the
  user's unrelated uncommitted work. Format only the files you touch, naming
  each explicitly.
- `flutter analyze` must report "No issues found!" and the full suite must stay
  green. 228 tests pass before this plan starts.
- Android 10 (API 29) minimum. Primary targets: 2GB RAM Android TV/karaoke boxes
  and car head units.
- All user-facing text goes through `gen-l10n`; ARB keys live in both
  `lib/l10n/app_vi.arb` and `lib/l10n/app_en.arb`.
- Test names are snake_case behavioural names.
- **Do not restore the karaoke strip to keep a test green.** If a test breaks
  because the result list is shorter, change that test's query.

---

### Task 1: Delete the karaoke search mode

**Files:**
- Delete: `lib/core/models/search_mode.dart`
- Delete: `lib/core/providers/search_mode_provider.dart`
- Delete: `lib/core/shared/widgets/search_mode_toggle.dart`
- Delete: `lib/core/shared/widgets/title_pill.dart`
- Delete: `test/core/models/search_mode_test.dart`
- Modify: `lib/features/song_browser/presentation/providers/song_browser_provider.dart`
- Modify: `lib/features/song_browser/presentation/widgets/main_top_bar.dart`
- Modify: `lib/features/source_selection/presentation/pages/source_selection_page.dart`
- Modify: `lib/l10n/app_vi.arb`, `lib/l10n/app_en.arb`
- Modify: `test/support/fake_music_sdk_platform.dart` — add a `searchQueries` log
- Test: `test/features/song_browser/search_query_test.dart`
- Test: `test/features/song_browser/search_mode_removed_test.dart`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing public. `SongBrowserController`'s constructor loses its
  `SearchMode Function()` positional parameter — it goes from 7 positional
  arguments to 6.

- [ ] **Step 1: Write the failing query test**

Create `test/features/song_browser/search_query_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/song_browser_provider.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';

import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';

const _source = MusicSource(
  id: 'youtube',
  subtitle: 'Kho nhạc & Video\nkhổng lồ',
  accentColor: AppColors.red,
  logoStyle: MusicSourceLogoStyle.youtube,
);

({ProviderContainer container, FakeMusicSdkPlatform platform}) _harness() {
  final platform = FakeMusicSdkPlatform();
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(FakeLocalStorageService()),
      musicSdkPlatformProvider.overrideWithValue(platform),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, platform: platform);
}

/// Sets the query then submits it. `submitSearch` takes no argument — it reads
/// `state.query` — so the two calls are the real API.
Future<void> _search(ProviderContainer container, String query) async {
  final controller = container.read(songBrowserProvider(_source).notifier);
  controller.setQuery(query);
  await controller.submitSearch();
}

void main() {
  test('a_query_containing_karaoke_keeps_the_word', () async {
    // The old SearchMode.applyToQuery stripped it, so typing "karaoke" searched
    // for nothing at all and returned the whole catalogue.
    final harness = _harness();

    await _search(harness.container, 'karaoke');

    expect(harness.platform.searchQueries, contains('karaoke'));
  });

  test('a_plain_query_reaches_the_repository_unchanged', () async {
    final harness = _harness();

    await _search(harness.container, 'Lạc Trôi');

    expect(harness.platform.searchQueries, contains('Lạc Trôi'));
  });

  test('surrounding_and_repeated_whitespace_is_normalized', () async {
    // Not cosmetic: the search cache key is built from this, so without it two
    // spellings of one search cost two network round trips.
    final harness = _harness();

    await _search(harness.container, '  Lạc   Trôi  ');

    expect(harness.platform.searchQueries, contains('Lạc Trôi'));
  });

  test('a_query_that_is_only_karaoke_is_not_emptied', () async {
    final harness = _harness();

    await _search(harness.container, '  KARAOKE ');

    expect(harness.platform.searchQueries, contains('KARAOKE'));
  });
}
```

- [ ] **Step 2: Add the query log to the fake, then run the test to verify it fails**

The test above needs a `searchQueries` list that does not exist yet, so add it
first or the file will not compile and you will get a false RED.

In `test/support/fake_music_sdk_platform.dart`, alongside the existing
`lastSearchQuery`:

```dart
  final List<String> searchQueries = [];
```

and in `search`, next to the existing assignment:

```dart
    lastSearchQuery = query;
    searchQueries.add(query);
```

Leave `lastSearchQuery` in place — other suites read it.

Then run: `flutter test test/features/song_browser/search_query_test.dart`
Expected: FAIL on `a_query_containing_karaoke_keeps_the_word` — the logged query
is `''`, not `'karaoke'`, because `applyToQuery` strips the word. Confirm the
failure says that and is not a compile error.

**Verified for you, do not re-derive:** the controller's API is
`setQuery(String)` followed by `submitSearch()` (no argument — it reads
`state.query`, and already trims it at `song_browser_provider.dart:288`).

The assertions use `contains` on a list rather than `lastSearchQuery` on purpose:
`_loadRecommendations()` fires from the controller's constructor, so a
"last query wins" assertion would race the recommendations request. `contains`
asserts exactly what matters — that the submitted query reached the platform in
that form — and is immune to ordering.

- [ ] **Step 3: Write the failing UI test**

Create `test/features/song_browser/search_mode_removed_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';
import 'package:viet_ktv/features/source_selection/presentation/pages/source_selection_page.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';

const _source = MusicSource(
  id: 'youtube',
  subtitle: 'Kho nhạc & Video\nkhổng lồ',
  accentColor: AppColors.red,
  logoStyle: MusicSourceLogoStyle.youtube,
);

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(
          FakeLocalStorageService(),
        ),
        musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
      ],
      child: MaterialApp(
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('source_picker_has_no_mode_toggle', (tester) async {
    await _pump(tester, const SourceSelectionPage());

    expect(find.text('KARAOKE'), findsNothing);
    expect(find.text('NGHE NHẠC'), findsNothing);
  });

  testWidgets('browser_top_bar_has_no_mode_pill', (tester) async {
    await _pump(tester, const SongBrowserPage(source: _source));

    expect(find.text('NGHE NHẠC'), findsNothing);
    expect(find.text('KARAOKE'), findsNothing);
  });
}
```

- [ ] **Step 4: Run the UI test to verify it fails**

Run: `flutter test test/features/song_browser/search_mode_removed_test.dart`
Expected: FAIL — `find.text('NGHE NHẠC')` finds the pill and the toggle.

- [ ] **Step 5: Replace the query rewriting in the controller**

In `song_browser_provider.dart`, add a private helper near the bottom of the
file, outside the class:

```dart
/// Collapses surrounding and repeated whitespace.
///
/// Kept after the karaoke mode was removed because the search cache key is
/// built from the result — without it, "abc " and "abc" become two cache
/// entries and two network round trips for the same search.
String _normalizeQuery(String query) =>
    query.replaceAll(RegExp(r'\s+'), ' ').trim();
```

Replace line 205:

```dart
        query: _normalizeQuery(recommendationSeedQuery(source)),
```

Replace line 298:

```dart
    final normalized = _normalizeQuery(query);
```

- [ ] **Step 6: Drop the mode from the controller's constructor**

In `song_browser_provider.dart`, remove `this._readSearchMode,` from the
`SongBrowserController` constructor (line 160) and remove the field declaration
(line 170):

```dart
  final SearchMode Function() _readSearchMode;
```

Remove `() => ref.read(searchModeProvider),` from the provider body (line 37),
and remove the `search_mode.dart` and `search_mode_provider.dart` imports.

- [ ] **Step 7: Remove the toggle from the source picker**

In `source_selection_page.dart`, delete the import on line 11
(`search_mode_toggle.dart`), and in the `topBar` `Row` delete both:

```dart
              const SearchModeToggle(),
              SizedBox(width: compact ? 12 : 28),
```

The `Expanded` holding the centred nav stays. Check whether `compact` is still
referenced afterwards — if it is not, remove the now-unused local rather than
leaving a dead variable.

- [ ] **Step 8: Remove the pill from the browser top bar**

In `main_top_bar.dart`, delete the `searchMode` watch (line 45):

```dart
    final searchMode = ref.watch(searchModeProvider);
```

and the whole `TitlePill(...)` widget (lines 61-67) from the `Row`, leaving the
`Spacer()` as the row's first child so the right-hand cluster stays right.

Delete these three imports:

```dart
import '../../../../core/providers/search_mode_provider.dart';
import '../../../../core/models/search_mode.dart';
import '../../../../core/shared/widgets/title_pill.dart';
```

`AppColors` may still be used elsewhere in the file — check before removing its
import.

- [ ] **Step 9: Delete the dead files**

```bash
rm lib/core/models/search_mode.dart \
   lib/core/providers/search_mode_provider.dart \
   lib/core/shared/widgets/search_mode_toggle.dart \
   lib/core/shared/widgets/title_pill.dart \
   test/core/models/search_mode_test.dart
```

- [ ] **Step 10: Remove the localization keys**

Delete these three entries from **both** `lib/l10n/app_vi.arb` and
`lib/l10n/app_en.arb`, along with any `@`-prefixed metadata entries that
accompany them:

- `searchModeKaraoke`
- `searchModeMusic`
- `karaokeLabel`

Then regenerate:

Run: `flutter gen-l10n`
Expected: completes without error; the generated
`lib/l10n/app_localizations*.dart` no longer declare those three getters.

- [ ] **Step 11: Confirm nothing references the removed symbols**

Run: `grep -rn "SearchMode\|searchModeProvider\|SearchModeToggle\|TitlePill\|karaokeLabel" lib/ test/`
Expected: no output. Paste the result in your report.

- [ ] **Step 12: Run both new test files**

Run: `flutter test test/features/song_browser/search_query_test.dart test/features/song_browser/search_mode_removed_test.dart`
Expected: PASS, 6 tests.

- [ ] **Step 13: Run the full suite and handle the karaoke-query tests**

Run: `flutter test`

Four tests in `test/widget_test.dart` and two in `test/queue_test.dart` submit
the literal query `KARAOKE`. Until now the strip turned that into `''`, and
`FakeMusicSdkPlatform.search` (`test/support/fake_music_sdk_platform.dart:58-65`)
lowercases the query and substring-matches it against each track's title and
subtitle — an empty string matched everything, so those tests received the whole
catalogue.

Now the query really is `karaoke`. Track id `9`
(`'Lạc Trôi - Sơn Tùng M-TP (Karaoke)'`, subtitle `'Karaoke 4 You'`) still
matches, and that is the track they tap, so they should stay green with a
shorter result list.

If one fails because it also asserts on a track without `karaoke` in its title or
subtitle, change **that test's query** to something matching what it asserts on.
Do not reinstate the strip. Report any test you changed and why.

Expected when done: **232 tests pass** — 228 today, minus the 2 in
`search_mode_test.dart` (verified: that file has exactly 2 tests), plus the 6
new ones. If the real number differs, report it and explain why rather than
adjusting the expectation to match.

- [ ] **Step 14: Format and analyze**

Run: `dart format` naming only the files you touched, then `flutter analyze`
Expected: "No issues found!"

---

## Self-Review

**Spec coverage.** Deletions list → Step 9 plus Step 10 for the ARB keys;
`source_selection_page` change → Step 7; `main_top_bar` change → Step 8;
controller change → Steps 5-6; the substantive decision (strip goes with append,
normalization stays for the cache key) → Step 5 with the reason in the comment,
and tested by `a_query_containing_karaoke_keeps_the_word` and
`surrounding_and_repeated_whitespace_is_normalized`; test impact → Step 13, with
the spec's "change the test, not the production code" rule restated; the spec's
testing list → Steps 1, 3 and 11 cover all five bullets.

**Type consistency.** `_normalizeQuery(String) → String` is defined in Step 5 and
used at both call sites in that same step. The constructor change in Step 6 is
the only signature change, and no other file constructs `SongBrowserController`
directly — the provider at line 33 is the sole caller, edited in the same step.

**Resolved before writing, not left as risks.** The controller's search API was
checked directly: `setQuery(String)` then `submitSearch()` with no argument
(`song_browser_provider.dart:241, 287`). `search_mode_test.dart` was counted: 2
tests, so the expected total is 232. The assertion style was changed from
`lastSearchQuery` to a `searchQueries` list because `_loadRecommendations()`
fires from the constructor and would race a last-wins assertion — that required
one addition to `test/support/fake_music_sdk_platform.dart`, which the Files
list now names.
