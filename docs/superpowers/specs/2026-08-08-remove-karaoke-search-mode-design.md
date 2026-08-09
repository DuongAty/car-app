# Remove The Karaoke Search Mode

## Context

The app has two search modes, `SearchMode { karaoke, music }`
(`lib/core/models/search_mode.dart`). The mode is held by a non-persisted
`StateNotifier` that already defaults to `music`
(`search_mode_provider.dart`).

Three places surface or consume it:

- `SearchModeToggle` on the source-picker page (`source_selection_page.dart:157`)
  switches between them.
- A `TitlePill` in the browser's top bar (`main_top_bar.dart:61-67`) reports the
  current mode — blue "NGHE NHẠC" or green "KARAOKE".
- `SongBrowserController` reads the mode and runs every query through
  `SearchMode.applyToQuery` (`song_browser_provider.dart:205` for the
  recommendations seed, `:298` for a typed search).

`applyToQuery` does two things: it strips any `karaoke` token already in the
query, and then appends ` karaoke` when the mode is `karaoke`.

## Goals

Remove the karaoke mode entirely. Searches run on exactly what the user typed.

## Non-Goals

Changing the search UI itself, the recommendations seed, the result caching
strategy, or anything about playback.

## What Is Deleted

- `lib/core/models/search_mode.dart`
- `lib/core/providers/search_mode_provider.dart`
- `lib/core/shared/widgets/search_mode_toggle.dart`
- `lib/core/shared/widgets/title_pill.dart` — its only consumer is the pill being
  removed below
- `test/core/models/search_mode_test.dart`
- ARB keys `searchModeKaraoke`, `searchModeMusic`, and `karaokeLabel` from both
  `app_vi.arb` and `app_en.arb`, with localizations regenerated

## What Is Changed

**`source_selection_page.dart`** — drop `SearchModeToggle()` and the `SizedBox`
that spaced it from the nav. The nav stays centred in its `Expanded`.

**`main_top_bar.dart`** — drop the `TitlePill`, the `searchMode` watch, and the
now-unused imports. The row keeps its `Spacer`, so the right-hand cluster stays
right and the top-left simply becomes empty. This is a deliberate choice: a pill
that can only ever say one thing carries no information.

**`song_browser_provider.dart`** — drop the `_readSearchMode` constructor
parameter and field, and replace both `applyToQuery` calls.

## The Substantive Decision

`applyToQuery`'s stripping must go along with its appending.

Removing only the append would leave a search box that silently erases the word
`karaoke` whenever a user types it — worse than the behaviour being removed,
because it is invisible.

So queries pass through as typed, with one exception: whitespace is still
trimmed and collapsed, by a small private helper on the controller. That is not
cosmetic. The search cache key is built from the normalized query
(`song_browser_provider.dart:299`), so without it `"abc "` and `"abc"` become two
cache entries and two network round trips for the same search.

**Behaviour change, and it is an improvement.** Today, searching `karaoke` in
music mode produces an *empty* query, which returns the entire catalogue. After
this change it searches for `karaoke`.

## Test Impact

Four tests in `test/widget_test.dart` and two in `test/queue_test.dart` type the
literal query `KARAOKE`.

Today the strip turns that into `""`, and `FakeMusicSdkPlatform.search`
substring-matches a lowercased query against each track's title and subtitle
(`fake_music_sdk_platform.dart:58-65`) — an empty string matches everything, so
those tests currently receive the whole catalogue.

After the change the query really is `karaoke`. Track id `9`
(`'Lạc Trôi - Sơn Tùng M-TP (Karaoke)'`, subtitle `'Karaoke 4 You'`) still
matches, and that is the track those tests tap, so they should stay green — but
the result list is shorter. If any of them also asserts on a track without
`karaoke` in its title or subtitle, that test's query must be changed. The
production behaviour is correct; do not restore the strip to keep a test green.

## Testing

- A typed query reaches the repository unchanged apart from whitespace
  normalization — in particular, a query containing `karaoke` keeps it.
- Leading, trailing, and repeated internal whitespace are normalized, so two
  spellings of the same search share one cache entry.
- The source-picker page no longer renders a mode toggle.
- The browser's top bar no longer renders the mode pill, and its remaining
  controls stay right-aligned.
- The full suite stays green and `flutter analyze` stays clean, with no
  references to `SearchMode`, `searchModeProvider`, `SearchModeToggle`, or
  `TitlePill` left anywhere in `lib/` or `test/`.
