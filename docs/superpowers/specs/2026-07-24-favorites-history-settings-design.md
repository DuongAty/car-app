# Favorites, History, Queue Repeat/Shuffle, Settings, and Category Browsing

## Context

The song browser and queue screens already carry UI scaffolding for features
that were never wired to real behavior:

- A "Yêu thích" bottom-bar hint (badge `D`, blue accent) exists in
  `song_browser_mock_data.dart` but `_handleHint` in `song_browser_page.dart`
  has no `'favorites'` case — tapping it does nothing.
- The "DANH SÁCH" and "CÀI ĐẶT" top-nav tabs exist in `topActions` but only
  `selectTopAction(index)` runs — the tab highlights, the screen body never
  changes.
- The preview player's rewind (⏪) and settings (⚙️) transport buttons are both
  wired to `onPlayPause` (`preview_player.dart:255,275`) instead of their own
  behavior.

This spec wires those existing anchors to real features, and adds queue
repeat/shuffle and a category-browsing view. It intentionally reuses existing
patterns (`recommendationSeedQuery`, the `SelectedQueuePage`/drawer duality,
`pushNamed` for the "ĐÃ CHỌN" tab) rather than inventing new ones.

## Scope

In scope: Favorites, play History, queue Repeat/Shuffle, a real Settings
page, category browsing under "DANH SÁCH", and the two dead transport
buttons.

Out of scope (deferred to a later phase): phone-as-remote pairing (the
"KẾT NỐI ĐT" tab stays as-is), singing score, sleep timer, offline
download, and the "THOÁT" (exit) tab.

Explicitly preserved: `queueProvider`'s session-only lifetime
(`queue_provider.dart:7-9` states this is deliberate) — the queue itself is
**not** persisted. Only Favorites and History are.

## Data & Persistence

Add `shared_preferences`. New `lib/core/services/local_storage_service.dart`
wraps it behind a small interface (`Future<String?> read(key)`,
`Future<void> write(key, value)`) so controllers depend on an interface, not
the plugin directly, matching the existing `VolumeService`/
`DeviceVolumeService` split.

Favorites and History are each stored as a single JSON-encoded list under one
`SharedPreferences` key (`favorites.v1`, `history.v1`). Both entries need
song + source + a timestamp, so a shared
`lib/core/models/persisted_song_entry.dart` (`SongItem song, MusicSource
source, DateTime at`) with `toJson`/`fromJson` backs both features rather than
duplicating the shape.

Loading is async; both controllers start in an empty/loading state and hydrate
once `SharedPreferences.getInstance()` resolves, same shape as
`SongBrowserController`'s existing async-load-into-state pattern.

## Favorites

`lib/features/favorites/`:
- `data/favorites_repository.dart` — reads/writes the persisted list via
  `LocalStorageService`.
- `presentation/providers/favorites_controller.dart` — `StateNotifierProvider`
  (not autoDispose, not family — one global list, same lifetime rationale as
  `queueProvider`). Exposes `toggle(SongItem, MusicSource)`, `remove(SongItem
  id)`, `isFavorite(String songId)`.
- `presentation/pages/favorites_page.dart` — same shell/layout family as
  `SelectedQueuePage` (top bar, `SelectedQueuePanel`-style list, preview
  player, bottom hint bar with back/play/remove). Route `/favorites`.
- A small reusable `FavoriteToggleButton` in
  `lib/core/shared/widgets/favorite_toggle_button.dart` (heart icon, filled
  when favorited) added to `search_result_tile.dart`, `suggestion_tile.dart`,
  `queued_song_tile.dart`, and the preview player's transport row is **not**
  touched further — favoriting the current song happens from the tile it was
  selected from, keeping the already-crowded transport row unchanged beyond
  the E section fixes.

Wiring: `song_browser_page.dart`'s `_handleHint` gains a `'favorites'` case
that does `Navigator.of(context).pushNamed(AppRouter.favorites)`, mirroring
the existing `'queue'`/`'back'` cases.

## Play History

`lib/features/history/`:
- `data/history_repository.dart` — same storage shape as favorites, capped at
  the most recent 100 entries (oldest dropped) so the persisted file can't
  grow unbounded over long-running installs.
- `presentation/providers/history_controller.dart` — global
  `StateNotifierProvider`. Records an entry by listening to
  `nowPlayingProvider.select((s) => s.playback)`; on a transition into
  `PlaybackReady` for a song not already the most recent entry, prepends a new
  entry (dedupes immediate consecutive replays of the same song into one
  timestamp bump, not a growing pile of duplicates). This listener is set up
  in the controller's constructor via the `Ref` passed in by the provider —
  deliberately independent of `QueuePlaybackController.history`, which is an
  unrelated in-session prev/next stack and is not touched.
- `presentation/pages/history_page.dart` — list of past plays with relative
  time, tap to re-play, swipe/button to remove one entry, and a "xoá tất cả"
  action. Route `/history`.

`VietKtvApp` (`lib/app.dart`) adds `ref.watch(historyControllerProvider)` in
its build method purely to keep the recorder alive for the app's lifetime
(same reasoning as `nowPlayingProvider` being global: it must exist before
the first play happens, not just when the history page is opened).

## Queue Repeat / Shuffle

`QueueController` (`queue_provider.dart`) gains:
- `RepeatMode { off, one, all }` and a `bool shuffle` flag, both part of a new
  `QueueState { List<QueuedSong> items, RepeatMode repeatMode, bool shuffle
  }` replacing the current bare `List<QueuedSong>` state. Every existing
  `ref.watch(queueProvider)` call site that expects a list is updated to
  `ref.watch(queueProvider.select((s) => s.items))` — no behavioral change
  for existing consumers.
- `setRepeatMode(RepeatMode)`, `toggleShuffle()`.

`QueuePlaybackController.playNext()` changes:
- `repeatMode == one` replays `state.history[historyIndex]` again instead of
  advancing.
- `repeatMode == all` and the queue is empty: instead of returning early,
  refills from the full play history (oldest history entry first) so the
  queue loops rather than stopping.
- `shuffle == true`: picks a random index from the current queue instead of
  always `queue.first`.

UI: two toggle icon buttons (repeat, shuffle) added to the header row of
`SelectedQueuePanel` (used by both `SelectedQueuePage` and the song browser's
slide-in queue drawer, so both entry points get them for free), next to the
existing clear-queue affordance. Active state uses the existing focus/active
glow treatment (`AppGlows`), not a new visual pattern.

## Dead Buttons & Settings Page

Preview player (`preview_player.dart`):
- Rewind button (`_TransportButton(icon: Icons.fast_rewind_rounded, ...)`)
  gets its own `onRewind` callback wired from `NowPlayingController`: seeks
  back 10s via `videoController.seekTo` (video sources) or
  `audioPlayer.seek` (audio sources), clamped to zero.
- Settings button's `onPressed` changes from `onPlayPause` to
  `Navigator.of(context).pushNamed(AppRouter.settings)`.

`song_browser_page.dart`'s `_handleTopAction` gains a case for the settings
tab index (matching the existing special-case for `selectedTabIndex`):
tapping "CÀI ĐẶT" also does `pushNamed(AppRouter.settings)` instead of only
toggling `selectedTopActionIndex`.

New `lib/features/settings/presentation/pages/settings_page.dart` (route
`/settings`), same shell family as the other full-screen pages. Real,
non-decorative content only:
- Language toggle (reuses `appLocaleProvider`/`LanguageToggle`, a second entry
  point to the same shared state already toggled elsewhere).
- "Xoá danh sách yêu thích" — clears favorites via
  `favoritesControllerProvider`, with a confirm step (reuses the same confirm
  pattern the queue's clear action would use, kept lightweight since no
  destructive-confirm widget exists yet — a simple two-state button press
  is enough here, no new dialog component).
- "Xoá lịch sử đã hát" — same, via `historyControllerProvider`.
- Link to History page (since Settings is the other natural discovery point
  for "DANH SÁCH" besides the category tab below).

## Category Browsing ("DANH SÁCH")

`song_browser_page.dart`'s body switches its left column and bottom panel
based on `state.selectedTopActionIndex`:
- Index 0 (TÌM BÀI, current default): unchanged — `SuggestionsPanel` +
  `SearchKeyboardPanel`.
- Index 1 (DANH SÁCH): left column becomes a new
  `lib/features/song_browser/presentation/widgets/category_grid_panel.dart`;
  the bottom keyboard panel collapses (no text entry needed). The right
  column keeps using the existing `SearchResultsPanel` unchanged.

Categories are a curated `lib/features/song_browser/data/song_categories.dart`
(sibling to `recommendation_seed.dart`, same seed-query mechanism): a fixed
list of `{label, seedQuery}` per source (e.g. "Nhạc trẻ", "Bolero / Trữ tình",
"Nhạc remix/DJ", "Nhạc thiếu nhi", "Top tìm kiếm"), reusing
`_repository.search`. Tapping a category calls a new
`SongBrowserController.browseCategory(String seedQuery)` that runs the same
codepath as `submitSearch()` against the seed query, reusing `SearchState`
and `SearchResultsPanel` as-is.

## Routing

`AppRouter` gains three routes: `favorites`, `history`, `settings`, each a
plain `MaterialPageRoute` with no arguments, following the existing
`selectedQueue` pattern.

## Localization

New keys added to both `app_vi.arb` and `app_en.arb`: favorites page title/
empty state, history page title/empty state/relative-time strings, settings
page section labels and confirm-clear copy, category panel title, and repeat/
shuffle button labels/tooltips. No existing key is renamed or removed.

## Error Handling

Storage reads/writes are wrapped in try/catch; a failed read starts the
controller with an empty list (same "fail soft" precedent as
`RecommendationsFailed`/`SearchFailed`); a failed write is silently retried on
the next mutation rather than surfaced as a blocking error, since losing a
single favorite/history write is not user-visible enough to justify an error
UI in a karaoke session.

## Testing

Widget/unit tests, named by behavior per project convention:
- `FavoritesController`: toggle adds/removes, persists across a fresh
  controller instance reading the same fake storage.
- `HistoryController`: records a play, dedupes consecutive replays of the
  same song, caps at 100 entries.
- `QueueController`/`QueuePlaybackController`: repeat-one replays the same
  song, repeat-all refills from history when the queue empties, shuffle
  picks from the current queue (seeded/deterministic random for the test).
- Existing queue/song-browser widget tests updated for the `QueueState`
  shape change (`queueProvider.select((s) => s.items)`) — must not regress.
- Settings/Favorites/History pages: smoke test each renders its empty state
  and its populated state without overflow at the existing tested viewport
  size(s).

Run `dart format .`, `flutter analyze`, and `flutter test` before considering
the work done, per project conventions.
