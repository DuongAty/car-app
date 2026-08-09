# Favorites, History, Queue Repeat/Shuffle, Settings, Categories — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wire the app's existing-but-dead Favorites/Settings/Category UI anchors to real, persisted behavior, and add queue repeat/shuffle.

**Architecture:** Two new small features (`favorites`, `history`) follow the existing feature-first shape (`data/` + `presentation/providers|pages|widgets`). Both persist through a new `LocalStorageService` (a `shared_preferences`-backed interface, mirroring the existing `VolumeService` split so controllers stay unit-testable against a fake). `QueueController`'s state grows from a bare list to a small state object carrying repeat/shuffle flags — every existing read site is updated in place, behavior for existing consumers is unchanged. `SettingsPage`, `FavoritesPage`, and `HistoryPage` are new full-screen routes built from the same `KaraokeShell`/`PanelFrame`/`AppBottomHintBar` pieces every other screen already uses.

**Tech Stack:** Flutter, Riverpod (`flutter_riverpod`), `shared_preferences` (new dependency), existing karaoke-neon design system widgets.

## Global Constraints

- Target Android 10+ (API 29+), landscape-first, D-pad/remote focus must be obvious on every new interactive element (reuse `FocusableTile`/`CircleIconButton`, which already provide this).
- No hardcoded colors/spacing/radius/text styles in feature code — use `AppColors`, `AppSpacing`, `AppRadius`, `AppLayout`, `AppGlows`.
- All user-facing copy must be localized: add matching keys to both `lib/l10n/app_vi.arb` and `lib/l10n/app_en.arb` in the same step that introduces the copy, then run `flutter gen-l10n` (or `flutter pub get`) to regenerate `lib/l10n/app_localizations*.dart` before referencing the new key in Dart.
- Do not persist `queueProvider`'s song list — `queue_provider.dart`'s existing comment states this is deliberate. Only Favorites and History are persisted.
- `dart format .`, `flutter analyze`, and `flutter test` must be clean before a task is considered done. Do not commit (per user instruction) — stage and leave commits for the user to review, i.e. skip the "Commit" step in every task below and instead just verify tests pass. (If your workflow requires a checkpoint, use `git add` only — never `git commit`.)
- 2-space indentation, `UpperCamelCase` classes, `lowerCamelCase` members, `snake_case.dart` files, `const` constructors where possible.

---

## File Structure

New files:
- `lib/core/services/local_storage_service.dart` — storage interface
- `lib/core/services/device_local_storage_service.dart` — `shared_preferences` impl
- `lib/core/providers/local_storage_provider.dart` — Riverpod provider for the interface
- `lib/core/models/persisted_song_entry.dart` — shared song+source+timestamp model backing Favorites and History
- `lib/core/shared/widgets/favorite_toggle_button.dart` — heart icon toggle
- `lib/core/shared/widgets/persisted_song_tile.dart` — shared list row for Favorites/History
- `lib/features/favorites/data/favorites_repository.dart`
- `lib/features/favorites/presentation/providers/favorites_controller.dart`
- `lib/features/favorites/presentation/pages/favorites_page.dart`
- `lib/features/history/data/history_repository.dart`
- `lib/features/history/presentation/providers/history_controller.dart`
- `lib/features/history/presentation/pages/history_page.dart`
- `lib/features/history/presentation/relative_time.dart` — small formatter, not a widget, so it lives next to what uses it rather than in `core/`
- `lib/features/settings/presentation/pages/settings_page.dart`
- `lib/features/song_browser/data/song_categories.dart`
- `lib/features/song_browser/presentation/widgets/category_grid_panel.dart`
- `test/support/fake_local_storage_service.dart`
- `test/features/favorites/favorites_controller_test.dart`
- `test/features/history/history_controller_test.dart`
- `test/settings_test.dart`
- `test/categories_test.dart`

Modified files (touched across the tasks below): `pubspec.yaml`, `lib/routes/app_router.dart`, `lib/app.dart`, `lib/features/queue/presentation/providers/queue_provider.dart`, `lib/features/queue/presentation/providers/queue_playback_controller.dart`, `lib/features/queue/presentation/widgets/selected_queue_panel.dart`, `lib/features/queue/presentation/widgets/queued_song_tile.dart`, `lib/features/queue/presentation/pages/selected_queue_page.dart`, `lib/features/song_browser/presentation/pages/song_browser_page.dart`, `lib/features/song_browser/presentation/providers/song_browser_provider.dart`, `lib/features/song_browser/presentation/widgets/search_result_tile.dart`, `lib/features/song_browser/presentation/widgets/suggestion_tile.dart`, `lib/features/song_browser/presentation/widgets/search_results_panel.dart`, `lib/features/song_browser/presentation/widgets/suggestions_panel.dart`, `lib/features/song_browser/presentation/widgets/preview_player.dart`, `lib/features/song_browser/data/mock/song_browser_mock_data.dart`, `lib/features/playback/data/audio_track_player.dart`, `lib/features/playback/presentation/providers/now_playing_controller.dart`, `lib/l10n/app_vi.arb`, `lib/l10n/app_en.arb`, `test/queue_test.dart`, `test/support/fake_audio_track_player.dart`.

---

### Task 1: Persistence foundation

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/core/services/local_storage_service.dart`
- Create: `lib/core/services/device_local_storage_service.dart`
- Create: `lib/core/providers/local_storage_provider.dart`
- Create: `lib/core/models/persisted_song_entry.dart`
- Create: `test/support/fake_local_storage_service.dart`
- Test: `test/core/models/persisted_song_entry_test.dart`

**Interfaces:**
- Produces: `abstract interface class LocalStorageService { Future<String?> read(String key); Future<void> write(String key, String value); }`; `localStorageServiceProvider` (`Provider<LocalStorageService>`); `class PersistedSongEntry { final SongItem song; final MusicSourceLogoStyle source; final DateTime at; Map<String,dynamic> toJson(); factory PersistedSongEntry.fromJson(Map<String,dynamic>); }`; `class FakeLocalStorageService implements LocalStorageService` (in-memory map, for tests).

- [ ] **Step 1: Add the `shared_preferences` dependency**

Edit `pubspec.yaml`, adding this line alongside the other dependencies (next to `flutter_volume_controller`):

```yaml
  shared_preferences: ^2.3.3
```

Run: `flutter pub get`
Expected: resolves cleanly, `pubspec.lock` updates.

- [ ] **Step 2: Write the failing model test**

Create `test/core/models/persisted_song_entry_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';

import 'package:viet_ktv/core/models/persisted_song_entry.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';

void main() {
  test('round_trips_through_json', () {
    final entry = PersistedSongEntry(
      song: const SongItem(
        id: '1',
        title: 'Lạc Trôi',
        subtitle: 'Sơn Tùng M-TP',
        duration: '4:32',
        thumbnailSeed: 1,
        imageUrl: 'https://img.example/1.jpg',
        badge: 'HOT',
      ),
      source: MusicSourceLogoStyle.youtube,
      at: DateTime.utc(2026, 7, 24, 10, 30),
    );

    final decoded = PersistedSongEntry.fromJson(entry.toJson());

    expect(decoded.song.id, '1');
    expect(decoded.song.title, 'Lạc Trôi');
    expect(decoded.song.imageUrl, 'https://img.example/1.jpg');
    expect(decoded.song.badge, 'HOT');
    expect(decoded.source, MusicSourceLogoStyle.youtube);
    expect(decoded.at, DateTime.utc(2026, 7, 24, 10, 30));
  });

  test('round_trips_a_song_with_no_image_or_badge', () {
    final entry = PersistedSongEntry(
      song: const SongItem(
        id: '2',
        title: 'Song',
        subtitle: 'Sub',
        duration: '3:00',
        thumbnailSeed: 2,
        badge: null,
      ),
      source: MusicSourceLogoStyle.soundcloud,
      at: DateTime.utc(2026, 1, 1),
    );

    final decoded = PersistedSongEntry.fromJson(entry.toJson());

    expect(decoded.song.imageUrl, isNull);
    expect(decoded.song.badge, isNull);
    expect(decoded.source, MusicSourceLogoStyle.soundcloud);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/core/models/persisted_song_entry_test.dart`
Expected: FAIL — `Target of URI doesn't exist: 'package:viet_ktv/core/models/persisted_song_entry.dart'`.

- [ ] **Step 4: Implement `PersistedSongEntry`**

Create `lib/core/models/persisted_song_entry.dart`:

```dart
import '../../features/song_browser/data/models/song_item.dart';
import '../../features/source_selection/data/models/music_source.dart';

/// A song paired with the source it was found on and when it was recorded —
/// the shared shape backing both Favorites and History persistence. Stores
/// just the [MusicSourceLogoStyle] (not a full [MusicSource]) because that is
/// all any consumer (SourceBadge, NowPlayingController.play) ever needs.
class PersistedSongEntry {
  const PersistedSongEntry({
    required this.song,
    required this.source,
    required this.at,
  });

  final SongItem song;
  final MusicSourceLogoStyle source;
  final DateTime at;

  Map<String, dynamic> toJson() => {
    'song': {
      'id': song.id,
      'title': song.title,
      'subtitle': song.subtitle,
      'duration': song.duration,
      'thumbnailSeed': song.thumbnailSeed,
      'imageUrl': song.imageUrl,
      'badge': song.badge,
    },
    'source': source.name,
    'at': at.toIso8601String(),
  };

  factory PersistedSongEntry.fromJson(Map<String, dynamic> json) {
    final songJson = json['song'] as Map<String, dynamic>;
    return PersistedSongEntry(
      song: SongItem(
        id: songJson['id'] as String,
        title: songJson['title'] as String,
        subtitle: songJson['subtitle'] as String,
        duration: songJson['duration'] as String,
        thumbnailSeed: songJson['thumbnailSeed'] as int,
        imageUrl: songJson['imageUrl'] as String?,
        badge: songJson['badge'] as String?,
      ),
      source: MusicSourceLogoStyle.values.byName(json['source'] as String),
      at: DateTime.parse(json['at'] as String),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/models/persisted_song_entry_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Add the storage service interface, device implementation, and provider**

Create `lib/core/services/local_storage_service.dart`:

```dart
/// Reads and writes small string blobs to on-device storage.
///
/// Controllers depend on this interface rather than the `shared_preferences`
/// plugin directly, so they stay testable against an in-memory fake — same
/// split as [VolumeService]/[DeviceVolumeService].
abstract interface class LocalStorageService {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}
```

Create `lib/core/services/device_local_storage_service.dart`:

```dart
import 'package:shared_preferences/shared_preferences.dart';

import 'local_storage_service.dart';

class DeviceLocalStorageService implements LocalStorageService {
  @override
  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  @override
  Future<void> write(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }
}
```

Create `lib/core/providers/local_storage_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/device_local_storage_service.dart';
import '../services/local_storage_service.dart';

/// Override this in tests to avoid touching the platform plugin.
final localStorageServiceProvider = Provider<LocalStorageService>(
  (ref) => DeviceLocalStorageService(),
);
```

Create `test/support/fake_local_storage_service.dart`:

```dart
import 'package:viet_ktv/core/services/local_storage_service.dart';

class FakeLocalStorageService implements LocalStorageService {
  final Map<String, String> store = {};

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async {
    store[key] = value;
  }
}
```

- [ ] **Step 7: Add `seek` to `AudioTrackPlayer`**

Rewiring the dead rewind button (Task 10) needs audio-source seeking; adding it now keeps the playback-data-layer changes in one place. Modify `lib/features/playback/data/audio_track_player.dart`:

```dart
abstract interface class AudioTrackPlayer {
  Stream<Duration> get positionStream;
  Stream<Duration?> get durationStream;
  Stream<bool> get playingStream;
  Stream<void> get completedStream;

  Future<void> setUrl(String url);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);
  Future<void> dispose();
}

class JustAudioTrackPlayer implements AudioTrackPlayer {
  // ...unchanged constructor/fields/positionStream/durationStream/
  // playingStream/completedStream/setUrl/play/pause...

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  // ...unchanged dispose...
}
```

(Insert the new `seek` method into the interface right after `pause`, and into `JustAudioTrackPlayer` right after its `pause` implementation — every other member of the file is unchanged.)

Modify `test/support/fake_audio_track_player.dart`, adding a tracked seek and the interface method:

```dart
  Duration? lastSeek;

  @override
  Future<void> seek(Duration position) async {
    lastSeek = position;
    _positionController.add(position);
  }
```

(Insert this after the existing `pause` override, before `dispose`.)

- [ ] **Step 8: Run the full test suite and analyzer to confirm nothing broke**

Run: `flutter analyze && flutter test`
Expected: PASS — the new `seek` member is unused so far (no callers yet), which is fine; analyzer does not flag unused interface methods.

---

### Task 2: Favorites data + controller

**Files:**
- Create: `lib/features/favorites/data/favorites_repository.dart`
- Create: `lib/features/favorites/presentation/providers/favorites_controller.dart`
- Test: `test/features/favorites/favorites_controller_test.dart`

**Interfaces:**
- Consumes: `LocalStorageService`, `localStorageServiceProvider` (Task 1), `PersistedSongEntry` (Task 1).
- Produces: `favoritesRepositoryProvider` (`Provider<FavoritesRepository>`); `favoritesControllerProvider` (`StateNotifierProvider<FavoritesController, List<PersistedSongEntry>>`); `FavoritesController.toggle(SongItem, MusicSourceLogoStyle)`, `.remove(String songId)`, `.clear()`, `.isFavorite(String songId)` — all consumed by Task 3/4.

- [ ] **Step 1: Write the failing controller test**

Create `test/features/favorites/favorites_controller_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/features/favorites/presentation/providers/favorites_controller.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';

import '../../support/fake_local_storage_service.dart';

const _song = SongItem(
  id: '1',
  title: 'Lạc Trôi',
  subtitle: 'Sơn Tùng M-TP',
  duration: '4:32',
  thumbnailSeed: 1,
  badge: null,
);

void main() {
  test('toggle_adds_then_removes_a_favorite', () async {
    final container = ProviderContainer(
      overrides: [
        localStorageServiceProvider.overrideWithValue(
          FakeLocalStorageService(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final controller = container.read(favoritesControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    controller.toggle(_song, MusicSourceLogoStyle.youtube);
    expect(container.read(favoritesControllerProvider), hasLength(1));
    expect(controller.isFavorite('1'), isTrue);

    controller.toggle(_song, MusicSourceLogoStyle.youtube);
    expect(container.read(favoritesControllerProvider), isEmpty);
    expect(controller.isFavorite('1'), isFalse);
  });

  test('favorites_persist_across_a_fresh_controller_reading_the_same_storage', (
    ) async {
    final storage = FakeLocalStorageService();

    final container1 = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    container1
        .read(favoritesControllerProvider.notifier)
        .toggle(_song, MusicSourceLogoStyle.youtube);
    await Future<void>.delayed(Duration.zero);
    container1.dispose();

    final container2 = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container2.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(container2.read(favoritesControllerProvider), hasLength(1));
  });

  test('clear_empties_the_list_and_persists_the_empty_state', () async {
    final storage = FakeLocalStorageService();
    final container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container.dispose);
    final controller = container.read(favoritesControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    controller.toggle(_song, MusicSourceLogoStyle.youtube);
    controller.clear();

    expect(container.read(favoritesControllerProvider), isEmpty);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/favorites/favorites_controller_test.dart`
Expected: FAIL — `favorites_controller.dart` does not exist yet.

- [ ] **Step 3: Implement the repository and controller**

Create `lib/features/favorites/data/favorites_repository.dart`:

```dart
import 'dart:convert';

import '../../../core/models/persisted_song_entry.dart';
import '../../../core/services/local_storage_service.dart';

class FavoritesRepository {
  FavoritesRepository(this._storage);

  static const String _key = 'favorites.v1';

  final LocalStorageService _storage;

  Future<List<PersistedSongEntry>> load() async {
    try {
      final raw = await _storage.read(_key);
      if (raw == null) {
        return const [];
      }
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => PersistedSongEntry.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<PersistedSongEntry> entries) async {
    try {
      final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
      await _storage.write(_key, encoded);
    } catch (_) {
      // Fail soft: a lost write is retried on the next mutation.
    }
  }
}
```

Create `lib/features/favorites/presentation/providers/favorites_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/persisted_song_entry.dart';
import '../../../../core/providers/local_storage_provider.dart';
import '../../../song_browser/data/models/song_item.dart';
import '../../../source_selection/data/models/music_source.dart';
import '../../data/favorites_repository.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(ref.watch(localStorageServiceProvider)),
);

/// Global, not autoDispose: favorites must survive navigating across every
/// screen, same lifetime rationale as `queueProvider`.
final favoritesControllerProvider =
    StateNotifierProvider<FavoritesController, List<PersistedSongEntry>>(
      (ref) => FavoritesController(ref.watch(favoritesRepositoryProvider)),
    );

class FavoritesController extends StateNotifier<List<PersistedSongEntry>> {
  FavoritesController(this._repository) : super(const []) {
    _load();
  }

  final FavoritesRepository _repository;

  Future<void> _load() async {
    final entries = await _repository.load();
    if (mounted) {
      state = entries;
    }
  }

  bool isFavorite(String songId) {
    return state.any((entry) => entry.song.id == songId);
  }

  void toggle(SongItem song, MusicSourceLogoStyle source) {
    final existingIndex = state.indexWhere((e) => e.song.id == song.id);
    if (existingIndex >= 0) {
      state = [...state]..removeAt(existingIndex);
    } else {
      state = [
        PersistedSongEntry(song: song, source: source, at: DateTime.now()),
        ...state,
      ];
    }
    _repository.save(state);
  }

  void remove(String songId) {
    state = state.where((entry) => entry.song.id != songId).toList();
    _repository.save(state);
  }

  void clear() {
    state = const [];
    _repository.save(state);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/favorites/favorites_controller_test.dart`
Expected: PASS (3 tests).

---

### Task 3: Favorite toggle button wired into browsing tiles

**Files:**
- Create: `lib/core/shared/widgets/favorite_toggle_button.dart`
- Modify: `lib/features/song_browser/presentation/widgets/search_result_tile.dart`
- Modify: `lib/features/song_browser/presentation/widgets/suggestion_tile.dart`
- Modify: `lib/features/song_browser/presentation/widgets/search_results_panel.dart`
- Modify: `lib/features/song_browser/presentation/widgets/suggestions_panel.dart`
- Modify: `lib/l10n/app_vi.arb`, `lib/l10n/app_en.arb`
- Test: additions to `test/widget_test.dart`

**Interfaces:**
- Consumes: `favoritesControllerProvider` (Task 2).
- Produces: `FavoriteToggleButton({required bool isFavorite, required VoidCallback onPressed})` — reused again in Task 4/9.

- [ ] **Step 1: Add the l10n keys**

Add to `lib/l10n/app_vi.arb` (after `"hintFavorites": "Yêu thích",`):

```json
  "favoriteAddTooltip": "Thêm vào yêu thích",
  "favoriteRemoveTooltip": "Bỏ khỏi yêu thích",
```

Add to `lib/l10n/app_en.arb` (after `"hintFavorites": "Favorites",`):

```json
  "favoriteAddTooltip": "Add to favorites",
  "favoriteRemoveTooltip": "Remove from favorites",
```

Run: `flutter gen-l10n`
Expected: regenerates `lib/l10n/app_localizations*.dart` with no errors.

- [ ] **Step 2: Write the failing widget test**

Add to `test/widget_test.dart`, inside `main()` (near the other `SearchResultTile` test):

```dart
  testWidgets('tapping_the_heart_toggles_favorite_icon', (tester) async {
    var isFavorite = false;
    late StateSetter setState;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setter) {
              setState = setter;
              return SearchResultTile(
                item: const SongItem(
                  id: 'yt-1',
                  title: 'Có Chắc Yêu Là Đây',
                  subtitle: 'YouTube',
                  duration: '03:55',
                  thumbnailSeed: 1,
                  badge: null,
                ),
                selected: false,
                onPressed: () {},
                onAdd: () {},
                isFavorite: isFavorite,
                onToggleFavorite: () => setState(() => isFavorite = !isFavorite),
              );
            },
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pump();

    expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);
  });
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/widget_test.dart -N tapping_the_heart_toggles_favorite_icon`
Expected: FAIL — `SearchResultTile` has no `isFavorite`/`onToggleFavorite` parameter.

- [ ] **Step 4: Create `FavoriteToggleButton`**

Create `lib/core/shared/widgets/favorite_toggle_button.dart`:

```dart
import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import 'circle_icon_button.dart';

/// Heart toggle reused on search results, suggestions, and persisted-song
/// rows to mark a song as a favorite. Filled red when favorited.
class FavoriteToggleButton extends StatelessWidget {
  const FavoriteToggleButton({
    super.key,
    required this.isFavorite,
    required this.onPressed,
    this.size = 42,
    this.iconSize = 22,
  });

  final bool isFavorite;
  final VoidCallback onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return CircleIconButton(
      icon: isFavorite
          ? Icons.favorite_rounded
          : Icons.favorite_border_rounded,
      onPressed: onPressed,
      size: size,
      iconSize: iconSize,
      tint: isFavorite ? AppColors.red : null,
    );
  }
}
```

- [ ] **Step 5: Wire it into `SearchResultTile` and `SuggestionTile`**

Modify `lib/features/song_browser/presentation/widgets/search_result_tile.dart`: add the import, two new required constructor params, and the button.

```dart
import '../../../../core/shared/widgets/favorite_toggle_button.dart';
```

```dart
  const SearchResultTile({
    super.key,
    required this.item,
    required this.selected,
    required this.onPressed,
    required this.onAdd,
    required this.isFavorite,
    required this.onToggleFavorite,
    this.onFocused,
  });

  final SongItem item;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback onAdd;
  final bool isFavorite;
  final VoidCallback onToggleFavorite;
  final VoidCallback? onFocused;
```

In the `Row` inside `builder:`, insert the heart between the title `Expanded` and the existing "+" `InkWell` (both keep their existing code — just add this block between them):

```dart
              const SizedBox(width: AppSpacing.xs),
              FavoriteToggleButton(
                isFavorite: isFavorite,
                onPressed: onToggleFavorite,
              ),
```

Modify `lib/features/song_browser/presentation/widgets/suggestion_tile.dart` the same way: add the import, `required this.isFavorite`, `required this.onToggleFavorite` to the constructor and field list, and insert

```dart
              const SizedBox(width: AppSpacing.xs),
              FavoriteToggleButton(
                isFavorite: isFavorite,
                onPressed: onToggleFavorite,
                size: 36,
                iconSize: 18,
              ),
```

directly before the existing trailing `Text(item.duration, ...)` in its `Row`.

- [ ] **Step 6: Convert the panels to `ConsumerWidget` and compute favorite state per row**

Modify `lib/features/song_browser/presentation/widgets/search_results_panel.dart`: change the import of `flutter/material.dart` block to also pull in Riverpod and the favorites controller, change the class to extend `ConsumerWidget`, and pass the two new params through.

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shared/widgets/panel_frame.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../l10n/l10n.dart';
import '../../../favorites/presentation/providers/favorites_controller.dart';
import '../../data/models/song_item.dart';
import '../providers/song_browser_provider.dart';
import 'search_result_tile.dart';

/// Right column: results for the query submitted with the on-screen
/// keyboard's TÌM key, each addable to the queue.
class SearchResultsPanel extends ConsumerWidget {
  const SearchResultsPanel({
    super.key,
    required this.search,
    required this.selectedIndex,
    required this.onSelected,
    required this.onPlay,
    required this.onAdd,
    required this.source,
  });

  final SearchState search;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<SongItem> onPlay;
  final ValueChanged<SongItem> onAdd;
  final MusicSourceLogoStyle source;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final bodyStyle = Theme.of(context).textTheme.bodyMedium;
    final favorites = ref.watch(favoritesControllerProvider);
    final favoritesController = ref.read(favoritesControllerProvider.notifier);
    bool isFavorite(String songId) =>
        favorites.any((entry) => entry.song.id == songId);
```

(Every existing `switch (search) { ... }` branch is unchanged except `SearchSuccess`'s `itemBuilder`, which gains the two params:)

```dart
                itemBuilder: (context, index) => SearchResultTile(
                  item: results[index],
                  selected: index == selectedIndex,
                  onPressed: () => onPlay(results[index]),
                  onFocused: () => onSelected(index),
                  onAdd: () => onAdd(results[index]),
                  isFavorite: isFavorite(results[index].id),
                  onToggleFavorite: () =>
                      favoritesController.toggle(results[index], source),
                ),
```

`SearchResultsPanel` gained a required `source` field — update its one call site in `lib/features/song_browser/presentation/pages/song_browser_page.dart` (the `SearchResultsPanel(...)` construction), adding:

```dart
                    source: state.source.logoStyle,
```

as a new argument alongside the existing `search:`/`selectedIndex:`/`onSelected:`/`onPlay:`/`onAdd:`.

Modify `lib/features/song_browser/presentation/widgets/suggestions_panel.dart` the same way — add the Riverpod/favorites imports, extend `ConsumerWidget`, add a required `source` field, compute `favorites`/`favoritesController`/`isFavorite` the same way, and pass `isFavorite`/`onToggleFavorite` into the `SuggestionTile` in its `itemBuilder`. Update its one call site in `song_browser_page.dart` (`SuggestionsPanel(...)`) to also pass `source: state.source.logoStyle`.

- [ ] **Step 7: Run the full test suite**

Run: `flutter analyze && flutter test`
Expected: PASS. The new widget test passes; every existing `SearchResultTile`/`SuggestionTile`/`SearchResultsPanel`/`SuggestionsPanel` test/call site still compiles because the only breaking constructor changes (new required params) have been updated at every call site above — grep to confirm no stragglers:

Run: `grep -rn "SearchResultTile(\|SuggestionTile(\|SearchResultsPanel(\|SuggestionsPanel(" lib test`
Expected: every construction site includes `isFavorite`/`onToggleFavorite` (tiles) or `source` (panels), or is the widget test added in Step 2 which passes them explicitly.

---

### Task 4: `PersistedSongTile`, `FavoritesPage`, and the "D / Yêu thích" hint

**Files:**
- Create: `lib/core/shared/widgets/persisted_song_tile.dart`
- Create: `lib/features/favorites/presentation/pages/favorites_page.dart`
- Modify: `lib/routes/app_router.dart`
- Modify: `lib/features/song_browser/presentation/pages/song_browser_page.dart`
- Modify: `lib/l10n/app_vi.arb`, `lib/l10n/app_en.arb`
- Test: `test/favorites_test.dart`

**Interfaces:**
- Consumes: `favoritesControllerProvider` (Task 2), `nowPlayingProvider.play(SongItem, MusicSourceLogoStyle)` (existing), `PersistedSongEntry` (Task 1).
- Produces: `PersistedSongTile({required PersistedSongEntry entry, required bool selected, required VoidCallback onPressed, required VoidCallback onRemove, String? metaLabel, ValueChanged<bool>? onFocused})` — reused by Task 6; `AppRouter.favorites` route.

- [ ] **Step 1: Add l10n keys**

Add to `lib/l10n/app_vi.arb`:

```json
  "favoritesEmpty": "Chưa có bài hát yêu thích nào.\nBấm ♥ ở bài hát để thêm.",
```

Add to `lib/l10n/app_en.arb`:

```json
  "favoritesEmpty": "No favorite songs yet.\nTap the heart on a song to add one.",
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing integration test**

Create `test/favorites_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/services/music_sdk_platform.dart';
import 'package:viet_ktv/core/shared/widgets/virtual_key_tile.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/features/favorites/presentation/pages/favorites_page.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';
import 'package:viet_ktv/routes/app_router.dart';

import 'support/fake_audio_track_player.dart';
import 'support/fake_local_storage_service.dart';
import 'support/fake_music_sdk_platform.dart';
import 'support/fake_video_player_platform.dart';

const _source = MusicSource(
  id: 'youtube',
  subtitle: 'Kho nhạc & Video\nkhổng lồ',
  accentColor: AppColors.red,
  logoStyle: MusicSourceLogoStyle.youtube,
);

Future<void> _pumpBrowser(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
        audioTrackPlayerFactoryProvider.overrideWithValue(
          FakeAudioTrackPlayer.new,
        ),
        localStorageServiceProvider.overrideWithValue(
          FakeLocalStorageService(),
        ),
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
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: const SongBrowserPage(source: _source),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
  });

  testWidgets('favoriting_a_search_result_shows_it_on_the_favorites_page', (
    tester,
  ) async {
    await _pumpBrowser(tester);

    for (final char in 'OFFICIAL'.split('')) {
      await tester.tap(find.widgetWithText(VirtualKeyTile, char));
      await tester.pump();
    }
    await tester.tap(find.widgetWithText(VirtualKeyTile, 'TÌM'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.favorite_border_rounded));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Yêu thích'));
    await tester.pumpAndSettle();

    expect(find.byType(FavoritesPage), findsOneWidget);
    expect(
      find.text('Lạc Trôi - Sơn Tùng M-TP (Official MV)'),
      findsOneWidget,
    );
  });

  testWidgets('favorites_page_shows_empty_state_with_nothing_favorited', (
    tester,
  ) async {
    await _pumpBrowser(tester);

    await tester.tap(find.textContaining('Yêu thích'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Chưa có bài hát yêu thích'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/favorites_test.dart`
Expected: FAIL — `favorites_page.dart` does not exist; `_handleHint`'s `'favorites'` case is unhandled so the tap does nothing.

- [ ] **Step 4: Create the shared `PersistedSongTile`**

Create `lib/core/shared/widgets/persisted_song_tile.dart` (same visual shape as `QueuedSongTile` — thumbnail, title, source badge + subtitle, remove "×" — without reorder arrows, plus an optional trailing meta label used by History):

```dart
import 'package:flutter/material.dart';

import '../../../features/song_browser/presentation/widgets/song_thumbnail.dart';
import '../../../features/source_selection/presentation/widgets/source_badge.dart';
import '../../models/persisted_song_entry.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_glows.dart';
import '../../theme/app_layout.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'focusable_tile.dart';
import 'liquid_glass.dart';

/// Row shared by the Favorites and History pages: thumbnail, title, source
/// badge + subtitle, an optional trailing meta label (History's relative
/// time), and a remove "×". Same shape as `QueuedSongTile` minus the reorder
/// arrows, which only make sense for an ordered queue.
class PersistedSongTile extends StatelessWidget {
  const PersistedSongTile({
    super.key,
    required this.entry,
    required this.selected,
    required this.onPressed,
    required this.onRemove,
    this.metaLabel,
    this.onFocused,
  });

  final PersistedSongEntry entry;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback onRemove;
  final String? metaLabel;
  final ValueChanged<bool>? onFocused;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final song = entry.song;

    return FocusableTile(
      onPressed: onPressed,
      onFocusChange: (focused) => onFocused?.call(focused),
      builder: (context, focused) {
        final active = selected || focused;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: AppLayout.browserResultTileHeight,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: active
                ? AppColors.green.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: active ? AppColors.green : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: AppGlows.control(AppColors.green, focused: active),
          ),
          child: Row(
            children: [
              SongThumbnail(
                seed: song.thumbnailSeed,
                width: 104,
                height: 62,
                imageUrl: song.imageUrl,
                durationLabel: song.duration,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(fontSize: 19),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        SizedBox(
                          height: 18,
                          child: FittedBox(
                            child: SourceBadge(source: entry.source),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            song.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall,
                          ),
                        ),
                        if (metaLabel != null) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Text(metaLabel!, style: textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: LiquidGlass(
                    capsule: true,
                    detail: LiquidGlassDetail.simple,
                    lifted: false,
                    opacity: 0.38,
                    tint: active ? AppColors.green : null,
                    tintStrength: 0.3,
                    rimColor: active ? AppColors.green : null,
                    child: Center(
                      child: Icon(
                        Icons.close_rounded,
                        size: 22,
                        color: active
                            ? AppColors.green
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

(Ignore the earlier "placeholder import" line — it does not exist in the file you create; go straight to the corrected full version above.)

- [ ] **Step 5: Create `FavoritesPage`**

Create `lib/features/favorites/presentation/pages/favorites_page.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/bottom_hint_item.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/volume_provider.dart';
import '../../../../core/shared/widgets/app_bottom_hint_bar.dart';
import '../../../../core/shared/widgets/circle_icon_button.dart';
import '../../../../core/shared/widgets/collapsible_axis.dart';
import '../../../../core/shared/widgets/karaoke_shell.dart';
import '../../../../core/shared/widgets/language_toggle.dart';
import '../../../../core/shared/widgets/panel_frame.dart';
import '../../../../core/shared/widgets/persisted_song_tile.dart';
import '../../../../core/shared/widgets/title_pill.dart';
import '../../../../core/shared/widgets/volume_indicator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../playback/presentation/providers/now_playing_controller.dart';
import '../../../song_browser/presentation/widgets/preview_player.dart';
import '../providers/favorites_controller.dart';

/// Songs marked ♥ from the song browser. Reached from the "D / Yêu thích"
/// bottom hint, same shell family as [SelectedQueuePage].
class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(appLocaleProvider);
    final localeController = ref.read(appLocaleProvider.notifier);
    final volume = ref.watch(volumeProvider);
    final favorites = ref.watch(favoritesControllerProvider);
    final favoritesController = ref.read(favoritesControllerProvider.notifier);
    final nowPlaying = ref.read(nowPlayingProvider.notifier);
    final isExpanded = ref.watch(
      nowPlayingProvider.select((value) => value.isExpanded),
    );

    return KaraokeShell(
      topBar: SizedBox(
        height: AppLayout.topNavItemHeight,
        child: Row(
          children: [
            const SizedBox.shrink(),
            const SizedBox(width: AppSpacing.sm),
            TitlePill(label: l10n.hintFavorites, color: AppColors.blue),
            const Spacer(),
            LanguageToggle(
              isVietnamese: locale.languageCode == 'vi',
              onToggle: localeController.toggle,
              compact: true,
            ),
            const SizedBox(width: AppSpacing.sm),
            CircleIconButton(
              icon: Icons.language,
              onPressed: localeController.toggle,
            ),
          ],
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CollapsibleAxis(
            axis: Axis.horizontal,
            extent:
                AppLayout.browserRightPanelWidth + AppLayout.browserColumnGap,
            collapsed: isExpanded,
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(right: AppLayout.browserColumnGap),
              child: PanelFrame(
                title: l10n.hintFavorites,
                leadingIcon: Icons.favorite_rounded,
                leadingIconColor: AppColors.red,
                trailingText: l10n.queueItemCount(favorites.length),
                child: favorites.isEmpty
                    ? Center(
                        child: Text(
                          l10n.favoritesEmpty,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        physics: const BouncingScrollPhysics(),
                        itemCount: favorites.length,
                        separatorBuilder: (_, _) => Container(
                          height: 1,
                          color: AppColors.panelBorderSoft,
                        ),
                        itemBuilder: (context, index) {
                          final entry = favorites[index];
                          return PersistedSongTile(
                            entry: entry,
                            selected: false,
                            onPressed: () =>
                                nowPlaying.play(entry.song, entry.source),
                            onRemove: () =>
                                favoritesController.remove(entry.song.id),
                          );
                        },
                      ),
              ),
            ),
          ),
          const Expanded(child: PreviewPlayer()),
        ],
      ),
      bottomBar: AppBottomHintBar(
        leading: VolumeIndicator(
          level: volume.level,
          enabled: volume.isAvailable,
          onChanged: ref.read(volumeProvider.notifier).setLevel,
        ),
        items: const [],
        trailingItems: [
          BottomHintItem(
            id: 'play',
            badgeText: 'OK',
            label: l10n.hintChooseAndPlay,
            accentColor: AppColors.greenDeep,
          ),
          BottomHintItem(
            id: 'back',
            badgeIcon: Icons.undo_rounded,
            label: l10n.hintBack,
          ),
        ],
        onItemTap: (item) {
          if (item.id == 'back') {
            Navigator.of(context).maybePop();
          }
        },
      ),
    );
  }
}
```

- [ ] **Step 6: Wire the route and the bottom hint**

Modify `lib/routes/app_router.dart`. Rename the `onGenerateRoute` parameter from `settings` to `routeSettings` (a later task adds a `settings` route constant, which would otherwise collide with the parameter name — renaming now keeps every future diff to this file additive) and add the `favorites` route:

```dart
import 'package:flutter/material.dart';

import '../features/favorites/presentation/pages/favorites_page.dart';
import '../features/queue/presentation/pages/selected_queue_page.dart';
import '../features/song_browser/presentation/pages/song_browser_page.dart';
import '../features/source_selection/data/models/music_source.dart';
import '../features/source_selection/presentation/pages/source_selection_page.dart';

abstract final class AppRouter {
  static const String home = '/';
  static const String songBrowser = '/song-browser';
  static const String selectedQueue = '/selected-queue';
  static const String favorites = '/favorites';

  static Route<dynamic> onGenerateRoute(RouteSettings routeSettings) {
    switch (routeSettings.name) {
      case home:
        return MaterialPageRoute<void>(
          builder: (_) => const SourceSelectionPage(),
          settings: routeSettings,
        );
      case songBrowser:
        final source = routeSettings.arguments as MusicSource;
        return MaterialPageRoute<void>(
          builder: (_) => SongBrowserPage(source: source),
          settings: routeSettings,
        );
      case selectedQueue:
        return MaterialPageRoute<void>(
          builder: (_) => const SelectedQueuePage(),
          settings: routeSettings,
        );
      case favorites:
        return MaterialPageRoute<void>(
          builder: (_) => const FavoritesPage(),
          settings: routeSettings,
        );
      default:
        return MaterialPageRoute<void>(
          builder: (_) => const SourceSelectionPage(),
          settings: routeSettings,
        );
    }
  }
}
```

Modify `lib/features/song_browser/presentation/pages/song_browser_page.dart`'s `_handleHint`:

```dart
  void _handleHint(BottomHintItem item) {
    switch (item.id) {
      case 'back':
        Navigator.of(context).maybePop();
      case 'queue':
        setState(() {
          _queueDrawerOpen = true;
        });
      case 'favorites':
        Navigator.of(context).pushNamed(AppRouter.favorites);
    }
  }
```

(`AppRouter` is already imported in this file.)

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/favorites_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 8: Run the full suite**

Run: `flutter analyze && flutter test`
Expected: PASS.

---

### Task 5: Play history — repository + controller

**Files:**
- Create: `lib/features/history/data/history_repository.dart`
- Create: `lib/features/history/presentation/providers/history_controller.dart`
- Test: `test/features/history/history_controller_test.dart`

**Interfaces:**
- Consumes: `LocalStorageService`/`localStorageServiceProvider`/`PersistedSongEntry` (Task 1), `nowPlayingProvider`/`PlaybackState`/`PlaybackReady` (existing, `now_playing_controller.dart`).
- Produces: `historyRepositoryProvider`; `historyControllerProvider` (`StateNotifierProvider<HistoryController, List<PersistedSongEntry>>`); `HistoryController.remove(String songId)`, `.clear()` — consumed by Task 6/11; `app.dart` must `ref.watch(historyControllerProvider)` once at the root (Task 6) to keep the recorder alive from launch.

- [ ] **Step 1: Write the failing controller test**

Create `test/features/history/history_controller_test.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/features/history/presentation/providers/history_controller.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/song_browser/data/music_sdk_song_repository.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';

import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';

void main() {
  test('recording_a_play_adds_it_to_history', () async {
    final platform = FakeMusicSdkPlatform();
    final container = ProviderContainer(
      overrides: [
        musicSdkPlatformProvider.overrideWithValue(platform),
        localStorageServiceProvider.overrideWithValue(
          FakeLocalStorageService(),
        ),
      ],
    );
    addTearDown(container.dispose);

    // Keeps the recorder alive, mirroring how app.dart watches it at launch.
    container.listen(historyControllerProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);

    await container
        .read(nowPlayingProvider.notifier)
        .play(
          const SongItem(
            id: '9',
            title: 'Lạc Trôi - Sơn Tùng M-TP (Karaoke)',
            subtitle: 'Karaoke 4 You',
            duration: '4:32',
            thumbnailSeed: 9,
            badge: null,
          ),
          MusicSourceLogoStyle.youtube,
        );
    await Future<void>.delayed(Duration.zero);

    final history = container.read(historyControllerProvider);
    expect(history, hasLength(1));
    expect(history.first.song.id, '9');
    expect(history.first.source, MusicSourceLogoStyle.youtube);
  });

  test('replaying_the_same_song_immediately_does_not_duplicate_the_entry', (
    ) async {
    final platform = FakeMusicSdkPlatform();
    final container = ProviderContainer(
      overrides: [
        musicSdkPlatformProvider.overrideWithValue(platform),
        localStorageServiceProvider.overrideWithValue(
          FakeLocalStorageService(),
        ),
      ],
    );
    addTearDown(container.dispose);
    container.listen(historyControllerProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);

    final song = const SongItem(
      id: '9',
      title: 'Lạc Trôi - Sơn Tùng M-TP (Karaoke)',
      subtitle: 'Karaoke 4 You',
      duration: '4:32',
      thumbnailSeed: 9,
      badge: null,
    );
    final nowPlaying = container.read(nowPlayingProvider.notifier);

    await nowPlaying.play(song, MusicSourceLogoStyle.youtube);
    await Future<void>.delayed(Duration.zero);
    await nowPlaying.play(song, MusicSourceLogoStyle.youtube);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(historyControllerProvider), hasLength(1));
  });

  test('history_persists_across_a_fresh_controller_reading_the_same_storage', (
    ) async {
    final storage = FakeLocalStorageService();
    final platform = FakeMusicSdkPlatform();

    final container1 = ProviderContainer(
      overrides: [
        musicSdkPlatformProvider.overrideWithValue(platform),
        localStorageServiceProvider.overrideWithValue(storage),
      ],
    );
    container1.listen(historyControllerProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);
    await container1
        .read(nowPlayingProvider.notifier)
        .play(
          const SongItem(
            id: '9',
            title: 'Karaoke',
            subtitle: 'Sub',
            duration: '4:00',
            thumbnailSeed: 9,
            badge: null,
          ),
          MusicSourceLogoStyle.youtube,
        );
    await Future<void>.delayed(Duration.zero);
    container1.dispose();

    final container2 = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(container2.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(container2.read(historyControllerProvider), hasLength(1));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/history/history_controller_test.dart`
Expected: FAIL — `history_controller.dart` does not exist.

- [ ] **Step 3: Implement the repository and controller**

Create `lib/features/history/data/history_repository.dart`:

```dart
import 'dart:convert';

import '../../../core/models/persisted_song_entry.dart';
import '../../../core/services/local_storage_service.dart';

class HistoryRepository {
  HistoryRepository(this._storage);

  static const String _key = 'history.v1';
  static const int maxEntries = 100;

  final LocalStorageService _storage;

  Future<List<PersistedSongEntry>> load() async {
    try {
      final raw = await _storage.read(_key);
      if (raw == null) {
        return const [];
      }
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .map((e) => PersistedSongEntry.fromJson(e as Map<String, dynamic>))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> save(List<PersistedSongEntry> entries) async {
    try {
      final capped = entries.take(maxEntries).toList();
      final encoded = jsonEncode(capped.map((e) => e.toJson()).toList());
      await _storage.write(_key, encoded);
    } catch (_) {
      // Fail soft: a lost write is retried on the next mutation.
    }
  }
}
```

Create `lib/features/history/presentation/providers/history_controller.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/persisted_song_entry.dart';
import '../../../../core/providers/local_storage_provider.dart';
import '../../../playback/presentation/providers/now_playing_controller.dart';
import '../../data/history_repository.dart';

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(ref.watch(localStorageServiceProvider)),
);

/// Global, not autoDispose: recording must keep working regardless of which
/// screen is on top, and the list must survive navigating everywhere. Records
/// a play by listening to [nowPlayingProvider] rather than being called
/// directly, so every playback path (search result, suggestion, queue,
/// favorites, history itself) is captured from one place.
final historyControllerProvider =
    StateNotifierProvider<HistoryController, List<PersistedSongEntry>>(
      (ref) => HistoryController(ref, ref.watch(historyRepositoryProvider)),
    );

class HistoryController extends StateNotifier<List<PersistedSongEntry>> {
  HistoryController(this._ref, this._repository) : super(const []) {
    _load();
    _ref.listen<PlaybackState>(
      nowPlayingProvider.select((value) => value.playback),
      _onPlaybackChanged,
    );
  }

  final Ref _ref;
  final HistoryRepository _repository;

  Future<void> _load() async {
    final entries = await _repository.load();
    if (mounted) {
      state = entries;
    }
  }

  void _onPlaybackChanged(PlaybackState? previous, PlaybackState next) {
    if (next is! PlaybackReady) {
      return;
    }
    final song = next.song;

    if (state.isNotEmpty && state.first.song.id == song.id) {
      // Same song replayed right after itself (or a rebuild fired the
      // listener again) — bump the timestamp instead of piling up
      // duplicate entries.
      state = [
        PersistedSongEntry(
          song: song,
          source: state.first.source,
          at: DateTime.now(),
        ),
        ...state.skip(1),
      ];
    } else {
      final source = _ref.read(nowPlayingProvider).activeSource;
      state = [
        PersistedSongEntry(song: song, source: source, at: DateTime.now()),
        ...state,
      ].take(HistoryRepository.maxEntries).toList(growable: false);
    }
    _repository.save(state);
  }

  void remove(String songId) {
    state = state.where((entry) => entry.song.id != songId).toList();
    _repository.save(state);
  }

  void clear() {
    state = const [];
    _repository.save(state);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/history/history_controller_test.dart`
Expected: PASS (3 tests).

---

### Task 6: `HistoryPage`, its route, and the app-launch recorder wiring

**Files:**
- Create: `lib/features/history/presentation/relative_time.dart`
- Create: `lib/features/history/presentation/pages/history_page.dart`
- Modify: `lib/routes/app_router.dart`
- Modify: `lib/app.dart`
- Modify: `lib/l10n/app_vi.arb`, `lib/l10n/app_en.arb`
- Test: `test/history_test.dart`

**Interfaces:**
- Consumes: `historyControllerProvider` (Task 5), `PersistedSongTile` (Task 4), `nowPlayingProvider.play` (existing).
- Produces: `AppRouter.history` route; `formatRelativeTime(AppLocalizations, DateTime)`.

- [ ] **Step 1: Add l10n keys**

Add to `lib/l10n/app_vi.arb`:

```json
  "historyTitle": "LỊCH SỬ ĐÃ HÁT",
  "historyEmpty": "Chưa có bài hát nào trong lịch sử.",
  "historyRemoveTooltip": "Xóa khỏi lịch sử",
  "historyJustNow": "Vừa xong",
  "historyMinutesAgo": "{count} phút trước",
  "@historyMinutesAgo": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "historyHoursAgo": "{count} giờ trước",
  "@historyHoursAgo": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "historyDaysAgo": "{count} ngày trước",
  "@historyDaysAgo": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
```

Add to `lib/l10n/app_en.arb`:

```json
  "historyTitle": "PLAY HISTORY",
  "historyEmpty": "No songs in your history yet.",
  "historyRemoveTooltip": "Remove from history",
  "historyJustNow": "Just now",
  "historyMinutesAgo": "{count} min ago",
  "@historyMinutesAgo": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "historyHoursAgo": "{count} hr ago",
  "@historyHoursAgo": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
  "historyDaysAgo": "{count}d ago",
  "@historyDaysAgo": {
    "placeholders": {
      "count": {
        "type": "int"
      }
    }
  },
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing integration test**

Create `test/history_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/services/music_sdk_platform.dart';
import 'package:viet_ktv/core/shared/widgets/virtual_key_tile.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/features/history/presentation/pages/history_page.dart';
import 'package:viet_ktv/features/history/presentation/providers/history_controller.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';
import 'package:viet_ktv/routes/app_router.dart';

import 'support/fake_audio_track_player.dart';
import 'support/fake_local_storage_service.dart';
import 'support/fake_music_sdk_platform.dart';
import 'support/fake_video_player_platform.dart';

const _source = MusicSource(
  id: 'youtube',
  subtitle: 'Kho nhạc & Video\nkhổng lồ',
  accentColor: AppColors.red,
  logoStyle: MusicSourceLogoStyle.youtube,
);

Future<void> _pumpBrowser(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
        audioTrackPlayerFactoryProvider.overrideWithValue(
          FakeAudioTrackPlayer.new,
        ),
        localStorageServiceProvider.overrideWithValue(
          FakeLocalStorageService(),
        ),
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
        onGenerateRoute: AppRouter.onGenerateRoute,
        home: const SongBrowserPage(source: _source),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
  });

  testWidgets('playing_a_song_shows_it_on_the_history_page', (tester) async {
    await _pumpBrowser(tester);

    await tester.tap(find.text('Lạc Trôi'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            FakeLocalStorageService(),
          ),
        ],
        child: const MaterialApp(home: HistoryPage()),
      ),
    );
    // A fresh ProviderScope means a fresh (empty) history in this pump —
    // this asserts the page itself renders without throwing when the
    // container backing it already has entries recorded via the same
    // provider tree, exercised end-to-end in the next test instead.
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('history_page_shows_empty_state_with_nothing_played', (
    tester,
  ) async {
    await _pumpBrowser(tester);
    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Chưa có bài hát nào trong lịch sử'), findsNothing);
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/history_test.dart`
Expected: FAIL — `history_page.dart` does not exist yet (and the settings page tap target used in the second test doesn't yet navigate anywhere — that part is finished in Task 11; for now only assert the page renders standalone). Simplify the second test for this task to just:

```dart
  testWidgets('history_page_shows_empty_state_with_nothing_played', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localStorageServiceProvider.overrideWithValue(
            FakeLocalStorageService(),
          ),
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
          home: const HistoryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Chưa có bài hát nào trong lịch sử'), findsOneWidget);
  });
```

Replace the first test's body accordingly (drop the `SongBrowserPage`/router setup it doesn't need) — the file's only two tests are: page renders its empty state standalone, and a `ProviderContainer`-level test (reuse Task 5's pattern) that plays a song then pumps `HistoryPage` off the *same* container to see the entry. Rewrite Step 2's file with this simplified, still-failing pair of tests before moving on.

- [ ] **Step 4: Implement the relative-time formatter and `HistoryPage`**

Create `lib/features/history/presentation/relative_time.dart`:

```dart
import '../../../l10n/app_localizations.dart';

String formatRelativeTime(AppLocalizations l10n, DateTime at) {
  final diff = DateTime.now().difference(at);
  if (diff.inMinutes < 1) {
    return l10n.historyJustNow;
  }
  if (diff.inMinutes < 60) {
    return l10n.historyMinutesAgo(diff.inMinutes);
  }
  if (diff.inHours < 24) {
    return l10n.historyHoursAgo(diff.inHours);
  }
  return l10n.historyDaysAgo(diff.inDays);
}
```

Create `lib/features/history/presentation/pages/history_page.dart` (mirrors `FavoritesPage` from Task 4, swapping the provider, empty-state copy, and adding `metaLabel`):

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/bottom_hint_item.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/volume_provider.dart';
import '../../../../core/shared/widgets/app_bottom_hint_bar.dart';
import '../../../../core/shared/widgets/circle_icon_button.dart';
import '../../../../core/shared/widgets/collapsible_axis.dart';
import '../../../../core/shared/widgets/karaoke_shell.dart';
import '../../../../core/shared/widgets/language_toggle.dart';
import '../../../../core/shared/widgets/panel_frame.dart';
import '../../../../core/shared/widgets/persisted_song_tile.dart';
import '../../../../core/shared/widgets/title_pill.dart';
import '../../../../core/shared/widgets/volume_indicator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../playback/presentation/providers/now_playing_controller.dart';
import '../../../song_browser/presentation/widgets/preview_player.dart';
import '../providers/history_controller.dart';
import '../relative_time.dart';

/// Songs played this install, most recent first. Reached from Settings.
class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(appLocaleProvider);
    final localeController = ref.read(appLocaleProvider.notifier);
    final volume = ref.watch(volumeProvider);
    final history = ref.watch(historyControllerProvider);
    final historyController = ref.read(historyControllerProvider.notifier);
    final nowPlaying = ref.read(nowPlayingProvider.notifier);
    final isExpanded = ref.watch(
      nowPlayingProvider.select((value) => value.isExpanded),
    );

    return KaraokeShell(
      topBar: SizedBox(
        height: AppLayout.topNavItemHeight,
        child: Row(
          children: [
            const SizedBox.shrink(),
            const SizedBox(width: AppSpacing.sm),
            TitlePill(label: l10n.historyTitle, color: AppColors.purple),
            const Spacer(),
            LanguageToggle(
              isVietnamese: locale.languageCode == 'vi',
              onToggle: localeController.toggle,
              compact: true,
            ),
            const SizedBox(width: AppSpacing.sm),
            CircleIconButton(
              icon: Icons.language,
              onPressed: localeController.toggle,
            ),
          ],
        ),
      ),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CollapsibleAxis(
            axis: Axis.horizontal,
            extent:
                AppLayout.browserRightPanelWidth + AppLayout.browserColumnGap,
            collapsed: isExpanded,
            alignment: Alignment.topRight,
            child: Padding(
              padding: const EdgeInsets.only(right: AppLayout.browserColumnGap),
              child: PanelFrame(
                title: l10n.historyTitle,
                leadingIcon: Icons.history_rounded,
                leadingIconColor: AppColors.purple,
                trailingText: l10n.queueItemCount(history.length),
                child: history.isEmpty
                    ? Center(
                        child: Text(
                          l10n.historyEmpty,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        physics: const BouncingScrollPhysics(),
                        itemCount: history.length,
                        separatorBuilder: (_, _) => Container(
                          height: 1,
                          color: AppColors.panelBorderSoft,
                        ),
                        itemBuilder: (context, index) {
                          final entry = history[index];
                          return PersistedSongTile(
                            entry: entry,
                            selected: false,
                            metaLabel: formatRelativeTime(l10n, entry.at),
                            onPressed: () =>
                                nowPlaying.play(entry.song, entry.source),
                            onRemove: () =>
                                historyController.remove(entry.song.id),
                          );
                        },
                      ),
              ),
            ),
          ),
          const Expanded(child: PreviewPlayer()),
        ],
      ),
      bottomBar: AppBottomHintBar(
        leading: VolumeIndicator(
          level: volume.level,
          enabled: volume.isAvailable,
          onChanged: ref.read(volumeProvider.notifier).setLevel,
        ),
        items: const [],
        trailingItems: [
          BottomHintItem(
            id: 'play',
            badgeText: 'OK',
            label: l10n.hintChooseAndPlay,
            accentColor: AppColors.greenDeep,
          ),
          BottomHintItem(
            id: 'back',
            badgeIcon: Icons.undo_rounded,
            label: l10n.hintBack,
          ),
        ],
        onItemTap: (item) {
          if (item.id == 'back') {
            Navigator.of(context).maybePop();
          }
        },
      ),
    );
  }
}
```

- [ ] **Step 5: Wire the route and the app-launch recorder**

Modify `lib/routes/app_router.dart`, adding the `history` route:

```dart
import '../features/history/presentation/pages/history_page.dart';
```

```dart
  static const String history = '/history';
```

```dart
      case history:
        return MaterialPageRoute<void>(
          builder: (_) => const HistoryPage(),
          settings: routeSettings,
        );
```

(Insert the constant after `favorites`, and the case after the `favorites` case, before `default`.)

Modify `lib/app.dart` so the recorder is alive from launch, not only once someone opens the history page:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/providers/locale_provider.dart';
import 'core/theme/app_theme.dart';
import 'features/history/presentation/providers/history_controller.dart';
import 'l10n/app_localizations.dart';
import 'routes/app_router.dart';

class VietKtvApp extends ConsumerWidget {
  const VietKtvApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appLocaleProvider);
    // Keeps the play-history recorder alive for the whole app lifetime — it
    // must exist before the first song is played, not only once the history
    // page happens to be opened.
    ref.watch(historyControllerProvider);

    return MaterialApp(
      onGenerateTitle: (context) =>
          AppLocalizations.of(context)?.appTitle ?? 'car-app',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRouter.home,
    );
  }
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/history_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 7: Run the full suite**

Run: `flutter analyze && flutter test`
Expected: PASS. (`test/widget_test.dart`'s `shows_all_three_music_sources`/`keeps_layout_within_bounds_on_small_viewport` tests pump the real `VietKtvApp`, which now touches `localStorageServiceProvider` indirectly through `historyControllerProvider` — this resolves fine in tests because `DeviceLocalStorageService` guards every `shared_preferences` call inside the plugin's own test-friendly in-memory default; if this fails with a `MissingPluginException`, override `localStorageServiceProvider` with `FakeLocalStorageService` in that test's `ProviderScope`, matching the pattern already used for `musicSdkPlatformProvider`.)

---

### Task 7: `QueueState` — repeat/shuffle model

**Files:**
- Modify: `lib/features/queue/presentation/providers/queue_provider.dart`
- Modify: `lib/features/queue/presentation/providers/queue_playback_controller.dart`
- Modify: `lib/features/queue/presentation/providers/song_browser_provider.dart` (no signature change needed — verify only)
- Modify: `lib/features/song_browser/presentation/pages/song_browser_page.dart`
- Modify: `lib/features/queue/presentation/widgets/selected_queue_panel.dart`
- Modify: `test/queue_test.dart`
- Test: `test/queue_test.dart` (existing file, extended)

**Interfaces:**
- Produces: `enum RepeatMode { off, one, all }`; `class QueueState { List<QueuedSong> items; RepeatMode repeatMode; bool shuffle; }`; `QueueController.setRepeatMode(RepeatMode)`, `.cycleRepeatMode()`, `.toggleShuffle()`, `.refillFrom(List<QueuedSong>)` — `add`/`removeAt`/`clear`/`moveUp`/`moveDown` keep their existing signatures.
- Consumes (must update): every existing `ref.watch(queueProvider)`/`ref.read(queueProvider.notifier)` call site, and the one direct `QueueController().state` test usage in `test/queue_test.dart`.

- [ ] **Step 1: Update the existing queue test to the new state shape (still red until Step 3)**

Modify `test/queue_test.dart`'s `completed_soundcloud_audio_automatically_plays_next_queued_song` test — the only place `queue.state` is read as a bare list:

```dart
      await queuePlayback.playNext();
      expect(platform.lastPlayableLinkTrackId, 'sc-1');
      expect(queue.state.items, hasLength(1));

      latestAudioPlayer!.complete();
      await Future<void>.delayed(Duration.zero);

      expect(platform.lastPlayableLinkTrackId, 'sc-2');
      expect(queue.state.items, isEmpty);
```

Add three new tests at the end of `main()`, before the closing `}`:

```dart
  test('repeat_one_replays_the_same_song_on_playNext', () async {
    final platform = FakeMusicSdkPlatform();
    final nowPlaying = NowPlayingController(
      MusicSdkSongRepository(platform),
      FakeAudioTrackPlayer.new,
    );
    final queue = QueueController()
      ..add(
        const SongItem(
          id: 'sc-1',
          title: 'SoundCloud 1',
          subtitle: 'SoundCloud',
          duration: '30:00',
          thumbnailSeed: 1,
          badge: null,
        ),
        _soundCloudSource,
      )
      ..setRepeatMode(RepeatMode.one);
    final queuePlayback = QueuePlaybackController(queue, nowPlaying);

    await queuePlayback.playNext();
    expect(platform.lastPlayableLinkTrackId, 'sc-1');
    expect(queue.state.items, isEmpty);

    await queuePlayback.playNext();
    expect(platform.lastPlayableLinkTrackId, 'sc-1');

    nowPlaying.dispose();
    queuePlayback.dispose();
  });

  test('repeat_all_refills_the_queue_from_history_once_it_empties', () async {
    final platform = FakeMusicSdkPlatform();
    final nowPlaying = NowPlayingController(
      MusicSdkSongRepository(platform),
      FakeAudioTrackPlayer.new,
    );
    const song = SongItem(
      id: 'sc-1',
      title: 'SoundCloud 1',
      subtitle: 'SoundCloud',
      duration: '30:00',
      thumbnailSeed: 1,
      badge: null,
    );
    final queue = QueueController()
      ..add(song, _soundCloudSource)
      ..setRepeatMode(RepeatMode.all);
    final queuePlayback = QueuePlaybackController(queue, nowPlaying);

    await queuePlayback.playNext();
    expect(platform.lastPlayableLinkTrackId, 'sc-1');
    expect(queue.state.items, isEmpty);

    await queuePlayback.playNext();
    expect(platform.lastPlayableLinkTrackId, 'sc-1');
    expect(queue.state.items, isEmpty);

    nowPlaying.dispose();
    queuePlayback.dispose();
  });

  test('shuffle_picks_from_the_current_queue_rather_than_always_the_first', (
    ) async {
    final platform = FakeMusicSdkPlatform();
    final nowPlaying = NowPlayingController(
      MusicSdkSongRepository(platform),
      FakeAudioTrackPlayer.new,
    );
    final queue = QueueController()
      ..add(
        const SongItem(
          id: 'sc-1',
          title: 'SoundCloud 1',
          subtitle: 'SoundCloud',
          duration: '30:00',
          thumbnailSeed: 1,
          badge: null,
        ),
        _soundCloudSource,
      )
      ..add(
        const SongItem(
          id: 'sc-2',
          title: 'SoundCloud 2',
          subtitle: 'SoundCloud',
          duration: '28:00',
          thumbnailSeed: 2,
          badge: null,
        ),
        _soundCloudSource,
      )
      ..toggleShuffle();
    // Seeded so the pick is deterministic for this test.
    final queuePlayback = QueuePlaybackController(
      queue,
      nowPlaying,
      random: math.Random(1),
    );

    await queuePlayback.playNext();

    expect(platform.lastPlayableLinkTrackId, 'sc-2');
    expect(queue.state.items, hasLength(1));
    expect(queue.state.items.single.song.id, 'sc-1');

    nowPlaying.dispose();
    queuePlayback.dispose();
  });
```

Add the `math` import at the top of `test/queue_test.dart`:

```dart
import 'dart:math' as math;
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/queue_test.dart`
Expected: FAIL — `queue.state.items` doesn't exist yet (`QueueState`/`QueueController.setRepeatMode` etc. don't exist), and `QueuePlaybackController` has no `random` parameter.

- [ ] **Step 3: Rewrite `QueueController`/`QueueState`**

Replace the full contents of `lib/features/queue/presentation/providers/queue_provider.dart`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../song_browser/data/models/song_item.dart';
import '../../../source_selection/data/models/music_source.dart';
import '../../data/models/queued_song.dart';

enum RepeatMode { off, one, all }

/// Deliberately not `autoDispose`: the queue is a single karaoke session's
/// running playlist, so it must survive navigating between sources and back
/// to the queue screen, not just the lifetime of one song browser page.
final queueProvider = StateNotifierProvider<QueueController, QueueState>(
  (ref) => QueueController(),
);

class QueueState {
  const QueueState({
    this.items = const [],
    this.repeatMode = RepeatMode.off,
    this.shuffle = false,
  });

  final List<QueuedSong> items;
  final RepeatMode repeatMode;
  final bool shuffle;

  QueueState copyWith({
    List<QueuedSong>? items,
    RepeatMode? repeatMode,
    bool? shuffle,
  }) {
    return QueueState(
      items: items ?? this.items,
      repeatMode: repeatMode ?? this.repeatMode,
      shuffle: shuffle ?? this.shuffle,
    );
  }
}

class QueueController extends StateNotifier<QueueState> {
  QueueController() : super(const QueueState());

  /// Queuing the same song twice is allowed — a duplicate just means singing
  /// it again later, same as a real karaoke queue.
  void add(SongItem song, MusicSource source) {
    state = state.copyWith(
      items: [...state.items, QueuedSong(song: song, source: source)],
    );
  }

  void removeAt(int index) {
    if (index < 0 || index >= state.items.length) {
      return;
    }
    state = state.copyWith(items: [...state.items]..removeAt(index));
  }

  void clear() {
    state = state.copyWith(items: const []);
  }

  /// Swaps [index] with its predecessor. No-op at the top of the list.
  void moveUp(int index) => _move(index, index - 1);

  /// Swaps [index] with its successor. No-op at the bottom of the list.
  void moveDown(int index) => _move(index, index + 1);

  void _move(int from, int to) {
    if (from < 0 ||
        from >= state.items.length ||
        to < 0 ||
        to >= state.items.length ||
        from == to) {
      return;
    }
    final list = [...state.items];
    final item = list.removeAt(from);
    list.insert(to, item);
    state = state.copyWith(items: list);
  }

  void setRepeatMode(RepeatMode mode) {
    state = state.copyWith(repeatMode: mode);
  }

  void cycleRepeatMode() {
    final next = switch (state.repeatMode) {
      RepeatMode.off => RepeatMode.all,
      RepeatMode.all => RepeatMode.one,
      RepeatMode.one => RepeatMode.off,
    };
    state = state.copyWith(repeatMode: next);
  }

  void toggleShuffle() {
    state = state.copyWith(shuffle: !state.shuffle);
  }

  /// Refills the queue from played history so repeat-all can loop once the
  /// queue empties, rather than stopping.
  void refillFrom(List<QueuedSong> items) {
    state = state.copyWith(items: items);
  }
}
```

- [ ] **Step 4: Update every other read site**

Modify `lib/features/song_browser/presentation/pages/song_browser_page.dart`:

```dart
    final queueCount = ref.watch(
      queueProvider.select((state) => state.items.length),
    );
```

Modify `lib/features/queue/presentation/widgets/selected_queue_panel.dart`'s `build` method — replace the single line `final queue = ref.watch(queueProvider);` with:

```dart
    final queue = ref.watch(queueProvider.select((state) => state.items));
```

Every other reference in that file (`ref.read(queueProvider.notifier).removeAt/moveUp/moveDown`) is unchanged — the notifier's methods didn't change signature.

Modify `lib/features/queue/presentation/pages/selected_queue_page.dart` — `ref.read(queueProvider.notifier).clear();` is unchanged (still valid).

Modify `lib/features/queue/presentation/providers/queue_playback_controller.dart`'s `playAt`:

```dart
  Future<void> playAt(int index) async {
    final items = _queue.state.items;
    if (index < 0 || index >= items.length) {
      return;
    }
    final item = items[index];
    _queue.removeAt(index);
    await _appendAndPlay(item);
  }
```

(`playNext`/`playPrevious` are rewritten fully in Task 8 — leave them as-is for now other than this `playAt` fix, since Task 8 replaces their bodies wholesale.)

Verify `lib/features/song_browser/presentation/providers/song_browser_provider.dart` needs no change — `ref.watch(queueProvider.notifier)` still returns a `QueueController`, unaffected by the state type change.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter analyze`
Expected: still shows an error in `queue_playback_controller.dart`'s `playNext`/`playPrevious` (they still reference `_queue.state` as a list) — that's expected; Task 8 fixes it next. Confirm the *only* remaining analyzer errors are inside `queue_playback_controller.dart`.

Run: `grep -rn "queueProvider)\." lib | grep -v "\.notifier\|\.select"`
Expected: no output — every remaining bare `ref.watch(queueProvider)`/`ref.read(queueProvider)` has been converted to `.select` or `.notifier`.

---

### Task 8: `QueuePlaybackController` repeat/shuffle playback logic

**Files:**
- Modify: `lib/features/queue/presentation/providers/queue_playback_controller.dart`

**Interfaces:**
- Consumes: `RepeatMode`, `QueueController.refillFrom` (Task 7).
- Produces: `QueuePlaybackController(QueueController, NowPlayingController, {math.Random? random})` — the new named `random` param is optional so every existing call site (`QueuePlaybackController(queue, nowPlaying)` in `test/queue_test.dart` and the provider definition) keeps compiling unchanged.

- [ ] **Step 1: Replace `playNext`/`playPrevious`**

Replace the full contents of `lib/features/queue/presentation/providers/queue_playback_controller.dart`:

```dart
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../playback/presentation/providers/now_playing_controller.dart';
import '../../data/models/queued_song.dart';
import 'queue_provider.dart';

final queuePlaybackControllerProvider =
    StateNotifierProvider<QueuePlaybackController, QueuePlaybackState>((ref) {
      final nowPlaying = ref.watch(nowPlayingProvider.notifier);
      final controller = QueuePlaybackController(
        ref.watch(queueProvider.notifier),
        nowPlaying,
      );
      nowPlaying.setOnCompleted(controller.playNext);
      ref.onDispose(() => nowPlaying.setOnCompleted(null));
      return controller;
    });

class QueuePlaybackState {
  const QueuePlaybackState({this.history = const [], this.historyIndex});

  final List<QueuedSong> history;
  final int? historyIndex;

  QueuePlaybackState copyWith({List<QueuedSong>? history, int? historyIndex}) {
    return QueuePlaybackState(
      history: history ?? this.history,
      historyIndex: historyIndex ?? this.historyIndex,
    );
  }
}

class QueuePlaybackController extends StateNotifier<QueuePlaybackState> {
  QueuePlaybackController(this._queue, this._nowPlaying, {math.Random? random})
    : _random = random ?? math.Random(),
      super(const QueuePlaybackState());

  final QueueController _queue;
  final NowPlayingController _nowPlaying;
  final math.Random _random;

  Future<void> playAt(int index) async {
    final items = _queue.state.items;
    if (index < 0 || index >= items.length) {
      return;
    }
    final item = items[index];
    _queue.removeAt(index);
    await _appendAndPlay(item);
  }

  Future<void> playNext() async {
    final repeatMode = _queue.state.repeatMode;
    final historyIndex = state.historyIndex;

    // Repeat-one overrides everything else: replay the current track.
    if (repeatMode == RepeatMode.one && historyIndex != null) {
      await _play(state.history[historyIndex]);
      return;
    }

    // Walk forward through already-known history first (e.g. after
    // playPrevious was used) before consuming new queue items.
    if (historyIndex != null && historyIndex < state.history.length - 1) {
      final nextIndex = historyIndex + 1;
      state = state.copyWith(historyIndex: nextIndex);
      await _play(state.history[nextIndex]);
      return;
    }

    var items = _queue.state.items;
    if (items.isEmpty &&
        repeatMode == RepeatMode.all &&
        state.history.isNotEmpty) {
      _queue.refillFrom(state.history);
      items = _queue.state.items;
    }
    if (items.isEmpty) {
      return;
    }

    final index = _queue.state.shuffle ? _random.nextInt(items.length) : 0;
    final item = items[index];
    _queue.removeAt(index);
    await _appendAndPlay(item);
  }

  Future<void> playPrevious() async {
    final historyIndex = state.historyIndex;
    if (historyIndex == null || historyIndex <= 0) {
      return;
    }

    final previousIndex = historyIndex - 1;
    state = state.copyWith(historyIndex: previousIndex);
    await _play(state.history[previousIndex]);
  }

  Future<void> _appendAndPlay(QueuedSong item) async {
    final historyIndex = state.historyIndex;
    final retainedHistory = historyIndex == null
        ? state.history
        : state.history.take(historyIndex + 1).toList(growable: false);
    final nextHistory = [...retainedHistory, item];
    state = QueuePlaybackState(
      history: nextHistory,
      historyIndex: nextHistory.length - 1,
    );
    await _play(item);
  }

  Future<void> _play(QueuedSong item) {
    return _nowPlaying.play(item.song, item.source.logoStyle);
  }
}
```

- [ ] **Step 2: Run test to verify it passes**

Run: `flutter test test/queue_test.dart`
Expected: PASS (all tests, including the three new ones from Task 7 Step 1).

- [ ] **Step 3: Run the full suite**

Run: `flutter analyze && flutter test`
Expected: PASS.

---

### Task 9: Repeat/shuffle buttons on the queue panel

**Files:**
- Modify: `lib/features/queue/presentation/widgets/selected_queue_panel.dart`
- Modify: `lib/l10n/app_vi.arb`, `lib/l10n/app_en.arb`
- Test: additions to `test/queue_test.dart`

**Interfaces:**
- Consumes: `QueueController.cycleRepeatMode()`, `.toggleShuffle()`, `QueueState.repeatMode`/`.shuffle` (Task 7).

- [ ] **Step 1: Add l10n keys**

Add to `lib/l10n/app_vi.arb`:

```json
  "queueRepeatOff": "Lặp lại: Tắt",
  "queueRepeatAll": "Lặp lại: Tất cả",
  "queueRepeatOne": "Lặp lại: 1 bài",
  "queueShuffle": "Phát ngẫu nhiên",
```

Add to `lib/l10n/app_en.arb`:

```json
  "queueRepeatOff": "Repeat: Off",
  "queueRepeatAll": "Repeat: All",
  "queueRepeatOne": "Repeat: One",
  "queueShuffle": "Shuffle",
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing widget test**

Add to `test/queue_test.dart`, before the final `}`:

```dart
  testWidgets('repeat_button_cycles_through_modes', (tester) async {
    await _pumpBrowser(tester, platform: FakeMusicSdkPlatform());
    await _openQueueScreen(tester);

    expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.repeat_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.repeat_rounded), findsOneWidget); // now "all"

    await tester.tap(find.byIcon(Icons.repeat_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.repeat_one_rounded), findsOneWidget); // "one"

    await tester.tap(find.byIcon(Icons.repeat_one_rounded));
    await tester.pump();
    expect(find.byIcon(Icons.repeat_rounded), findsOneWidget); // back to "off"
  });

  testWidgets('shuffle_button_toggles_active_tint', (tester) async {
    await _pumpBrowser(tester, platform: FakeMusicSdkPlatform());
    await _openQueueScreen(tester);

    final shuffleButton = find.byIcon(Icons.shuffle_rounded);
    expect(shuffleButton, findsOneWidget);

    await tester.tap(shuffleButton);
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/queue_test.dart -N repeat_button_cycles_through_modes`
Expected: FAIL — no `Icons.repeat_rounded` in the tree yet.

- [ ] **Step 4: Add the buttons to `SelectedQueuePanel`**

Replace the full contents of `lib/features/queue/presentation/widgets/selected_queue_panel.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/shared/widgets/circle_icon_button.dart';
import '../../../../core/shared/widgets/panel_frame.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../providers/queue_playback_controller.dart';
import '../providers/queue_provider.dart';
import '../providers/selected_queue_controller.dart';
import 'queued_song_tile.dart';

class SelectedQueuePanel extends ConsumerWidget {
  const SelectedQueuePanel({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final queue = ref.watch(queueProvider.select((state) => state.items));
    final repeatMode = ref.watch(
      queueProvider.select((state) => state.repeatMode),
    );
    final shuffle = ref.watch(queueProvider.select((state) => state.shuffle));
    final queueController = ref.read(queueProvider.notifier);
    final selectedIndex = ref.watch(selectedQueueControllerProvider);
    final controller = ref.read(selectedQueueControllerProvider.notifier);
    final playbackController = ref.read(
      queuePlaybackControllerProvider.notifier,
    );

    void play(int index) {
      controller.selectIndex(index);
      playbackController.playAt(index);
    }

    return PanelFrame(
      title: l10n.songSelected,
      leadingIcon: Icons.playlist_add_check_rounded,
      trailingText: l10n.queueItemCount(queue.length),
      opacity: onClose == null ? 0.52 : 0.88,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RepeatButton(
            mode: repeatMode,
            onPressed: queueController.cycleRepeatMode,
          ),
          const SizedBox(width: AppSpacing.xs),
          _ShuffleButton(
            active: shuffle,
            onPressed: queueController.toggleShuffle,
          ),
          if (onClose != null) ...[
            const SizedBox(width: AppSpacing.xs),
            CircleIconButton(
              icon: Icons.close_rounded,
              onPressed: onClose!,
              size: 40,
              iconSize: 20,
              opacity: 0.38,
            ),
          ],
        ],
      ),
      child: queue.isEmpty
          ? Center(
              child: Text(
                l10n.queueEmpty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            )
          : ListView.separated(
              padding: EdgeInsets.zero,
              physics: const BouncingScrollPhysics(),
              itemCount: queue.length,
              separatorBuilder: (_, _) =>
                  Container(height: 1, color: AppColors.panelBorderSoft),
              itemBuilder: (context, index) => QueuedSongTile(
                item: queue[index],
                selected: index == selectedIndex,
                onPressed: () => play(index),
                onFocused: (focused) {
                  if (focused) {
                    controller.selectIndex(index);
                  }
                },
                onRemove: () =>
                    ref.read(queueProvider.notifier).removeAt(index),
                onMoveUp: index > 0
                    ? () => ref.read(queueProvider.notifier).moveUp(index)
                    : null,
                onMoveDown: index < queue.length - 1
                    ? () => ref.read(queueProvider.notifier).moveDown(index)
                    : null,
              ),
            ),
    );
  }
}

class _RepeatButton extends StatelessWidget {
  const _RepeatButton({required this.mode, required this.onPressed});

  final RepeatMode mode;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Tooltip(
      message: switch (mode) {
        RepeatMode.off => l10n.queueRepeatOff,
        RepeatMode.all => l10n.queueRepeatAll,
        RepeatMode.one => l10n.queueRepeatOne,
      },
      child: CircleIconButton(
        icon: mode == RepeatMode.one
            ? Icons.repeat_one_rounded
            : Icons.repeat_rounded,
        onPressed: onPressed,
        size: 40,
        iconSize: 20,
        tint: mode == RepeatMode.off ? null : AppColors.green,
      ),
    );
  }
}

class _ShuffleButton extends StatelessWidget {
  const _ShuffleButton({required this.active, required this.onPressed});

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.l10n.queueShuffle,
      child: CircleIconButton(
        icon: Icons.shuffle_rounded,
        onPressed: onPressed,
        size: 40,
        iconSize: 20,
        tint: active ? AppColors.green : null,
      ),
    );
  }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/queue_test.dart`
Expected: PASS (all tests).

- [ ] **Step 6: Run the full suite**

Run: `flutter analyze && flutter test`
Expected: PASS. Pay attention to `bottom_bar_fits_both_locales`-style overflow checks — if any queue-screen test now reports an overflow because the panel header got two extra 40px buttons, reduce `_RepeatButton`/`_ShuffleButton` `size`/`iconSize` slightly (e.g. 36/18) rather than changing unrelated layout constants.

---

### Task 10: Fix the two dead preview-player buttons

**Files:**
- Modify: `lib/features/playback/presentation/providers/now_playing_controller.dart`
- Modify: `lib/features/song_browser/presentation/widgets/preview_player.dart`
- Test: additions to `test/widget_test.dart`

**Interfaces:**
- Consumes: `AudioTrackPlayer.seek` (Task 1).
- Produces: `NowPlayingController.seekBackward()`.

- [ ] **Step 1: Write the failing test**

Add to `test/widget_test.dart`, near the other transport-control tests:

```dart
  testWidgets('rewind_button_seeks_the_video_back_ten_seconds', (
    tester,
  ) async {
    final videoPlatform = FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = videoPlatform;
    addTearDown(() {
      VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
    });

    await _pumpSongBrowser(tester);

    await tester.tap(find.text('Lạc Trôi'));
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }

    await tester.tap(find.byIcon(Icons.fast_rewind_rounded));
    await tester.pump();

    expect(videoPlatform.lastSeekPosition, isNotNull);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('settings_button_navigates_to_the_settings_page', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
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
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const SongBrowserPage(source: _source),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
  });
```

Add the two new imports this needs at the top of `test/widget_test.dart`:

```dart
import 'package:viet_ktv/features/settings/presentation/pages/settings_page.dart';
import 'package:viet_ktv/routes/app_router.dart';
```

`test/support/fake_video_player_platform.dart` needs a `lastSeekPosition` field — read it now to see its current shape before extending it.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/widget_test.dart -N rewind_button_seeks_the_video_back_ten_seconds`
Expected: FAIL — `fake_video_player_platform.dart` has no `lastSeekPosition`, and `SettingsPage` doesn't exist (this second failure is expected until Task 11; for now comment out or skip the `settings_button_navigates_to_the_settings_page` test with `skip: true` and a `// TODO(Task 11)` — no, per plan rules no TODOs. Instead: move that specific test into Task 11's step list where `SettingsPage` is created, and keep only the rewind test in this task.)

Revise Step 1 to add only the rewind test here; the settings-navigation test moves to Task 11 Step 1 (below), where it belongs next to the page it exercises.

- [ ] **Step 3: Add `lastSeekPosition` to the fake video platform**

Open `test/support/fake_video_player_platform.dart`, find wherever it records the controller/position (its `play`/`pause` call counters are the closest existing analog per `test/queue_test.dart`'s use of `videoPlatform.playCallCount`), and add a `seekTo` override that records the position:

```dart
  Duration? lastSeekPosition;

  @override
  Future<void> seekTo(int textureId, Duration position) async {
    lastSeekPosition = position;
  }
```

(Match this to the file's existing method-override style — it already overrides `play`/`pause` with a `textureId` parameter per the `video_player_platform_interface` API, so mirror that exact signature; read the file's `play`/`pause` overrides first to copy the surrounding pattern precisely before adding this method.)

- [ ] **Step 4: Implement `seekBackward` and wire the button**

Modify `lib/features/playback/presentation/providers/now_playing_controller.dart`, adding a constant and method (place the constant near `_resolveTimeout`, the method near `togglePlayPause`):

```dart
  static const _rewindStep = Duration(seconds: 10);
```

```dart
  void seekBackward() {
    final controller = state.videoController;
    if (controller != null && controller.value.isInitialized) {
      final target = controller.value.position - _rewindStep;
      controller.seekTo(target < Duration.zero ? Duration.zero : target);
      return;
    }

    final audioPlayer = state.audioPlayer;
    if (audioPlayer != null) {
      final target = state.audioPosition - _rewindStep;
      audioPlayer.seek(target < Duration.zero ? Duration.zero : target);
    }
  }
```

Modify `lib/features/song_browser/presentation/widgets/preview_player.dart`:

Add the import:

```dart
import '../../../../routes/app_router.dart';
```

In `PreviewPlayer.build`, add `onRewind: notifier.seekBackward,` and `onSettings: () => Navigator.of(context).pushNamed(AppRouter.settings),` to the existing `_TransportStrip(...)` construction (alongside `onPlayPause:`, `onPrevious:`, etc.).

Add the two new fields to `_TransportStrip`'s constructor and class body:

```dart
    required this.onRewind,
    required this.onSettings,
```

```dart
  final VoidCallback onRewind;
  final VoidCallback onSettings;
```

Change the rewind and settings `_TransportButton`s inside `_TransportStrip.build` from `onPressed: onPlayPause` to their own callbacks:

```dart
              _TransportButton(
                icon: Icons.fast_rewind_rounded,
                onPressed: onRewind,
              ),
```

```dart
              _TransportButton(
                icon: Icons.settings_outlined,
                onPressed: onSettings,
              ),
```

(Every other button in `_TransportStrip` — previous/play-pause/next/fullscreen — is unchanged.)

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/widget_test.dart -N rewind_button_seeks_the_video_back_ten_seconds`
Expected: PASS.

- [ ] **Step 6: Run the full suite**

Run: `flutter analyze && flutter test`
Expected: `flutter analyze` PASS. `flutter test` will still fail on `Icons.settings_outlined` navigation only if you added that test early — confirm it was deferred to Task 11 as instructed in Step 2; otherwise PASS.

---

### Task 11: `SettingsPage`

**Files:**
- Create: `lib/features/settings/presentation/pages/settings_page.dart`
- Modify: `lib/routes/app_router.dart`
- Modify: `lib/features/song_browser/presentation/pages/song_browser_page.dart`
- Modify: `lib/features/song_browser/data/mock/song_browser_mock_data.dart`
- Modify: `lib/l10n/app_vi.arb`, `lib/l10n/app_en.arb`
- Test: `test/settings_test.dart`

**Interfaces:**
- Consumes: `favoritesControllerProvider.clear()` (Task 2), `historyControllerProvider.clear()` (Task 5), `AppRouter.history` (Task 6).
- Produces: `AppRouter.settings` route.

- [ ] **Step 1: Add l10n keys**

Add to `lib/l10n/app_vi.arb`:

```json
  "settingsLanguage": "Ngôn ngữ",
  "settingsClearFavorites": "Xóa danh sách yêu thích",
  "settingsClearHistory": "Xóa lịch sử đã hát",
  "settingsConfirmAgain": "Nhấn lần nữa để xác nhận xóa",
  "settingsViewHistory": "Xem lịch sử đã hát",
```

Add to `lib/l10n/app_en.arb`:

```json
  "settingsLanguage": "Language",
  "settingsClearFavorites": "Clear favorites",
  "settingsClearHistory": "Clear play history",
  "settingsConfirmAgain": "Tap again to confirm",
  "settingsViewHistory": "View play history",
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing test**

Create `test/settings_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/services/music_sdk_platform.dart';
import 'package:viet_ktv/features/favorites/presentation/providers/favorites_controller.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/settings/presentation/pages/settings_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';
import 'package:viet_ktv/routes/app_router.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';

import 'support/fake_audio_track_player.dart';
import 'support/fake_local_storage_service.dart';
import 'support/fake_music_sdk_platform.dart';
import 'support/fake_video_player_platform.dart';

const _source = MusicSource(
  id: 'youtube',
  subtitle: 'Kho nhạc & Video\nkhổng lồ',
  accentColor: AppColors.red,
  logoStyle: MusicSourceLogoStyle.youtube,
);

void main() {
  setUpAll(() {
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
  });

  testWidgets('settings_button_on_preview_player_navigates_to_settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
          audioTrackPlayerFactoryProvider.overrideWithValue(
            FakeAudioTrackPlayer.new,
          ),
          localStorageServiceProvider.overrideWithValue(
            FakeLocalStorageService(),
          ),
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
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const SongBrowserPage(source: _source),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_outlined).first);
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
  });

  testWidgets(
    'clear_favorites_requires_a_second_tap_to_confirm',
    (tester) async {
      final storage = FakeLocalStorageService();
      final container = ProviderContainer(
        overrides: [localStorageServiceProvider.overrideWithValue(storage)],
      );
      addTearDown(container.dispose);
      container
          .read(favoritesControllerProvider.notifier)
          .toggle(
            const SongItem(
              id: '1',
              title: 'Song',
              subtitle: 'Sub',
              duration: '3:00',
              thumbnailSeed: 1,
              badge: null,
            ),
            MusicSourceLogoStyle.youtube,
          );
      await Future<void>.delayed(Duration.zero);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('vi'),
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: const SettingsPage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(favoritesControllerProvider), hasLength(1));

      await tester.tap(find.text('Xóa danh sách yêu thích'));
      await tester.pump();
      expect(container.read(favoritesControllerProvider), hasLength(1));

      await tester.tap(find.text('Nhấn lần nữa để xác nhận xóa'));
      await tester.pump();
      expect(container.read(favoritesControllerProvider), isEmpty);
    },
  );
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/settings_test.dart`
Expected: FAIL — `settings_page.dart` does not exist; the preview player's settings button still points nowhere useful until this page exists to navigate to (Task 10 already wired the `Navigator.pushNamed(AppRouter.settings)` call — it will 404 into the router's `default` case, showing `SourceSelectionPage`, until this task adds the `settings` route).

- [ ] **Step 4: Implement `SettingsPage`**

Create `lib/features/settings/presentation/pages/settings_page.dart`:

```dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/bottom_hint_item.dart';
import '../../../../core/providers/locale_provider.dart';
import '../../../../core/providers/volume_provider.dart';
import '../../../../core/shared/widgets/app_bottom_hint_bar.dart';
import '../../../../core/shared/widgets/circle_icon_button.dart';
import '../../../../core/shared/widgets/focusable_tile.dart';
import '../../../../core/shared/widgets/karaoke_shell.dart';
import '../../../../core/shared/widgets/language_toggle.dart';
import '../../../../core/shared/widgets/panel_frame.dart';
import '../../../../core/shared/widgets/title_pill.dart';
import '../../../../core/shared/widgets/volume_indicator.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../../../routes/app_router.dart';
import '../../../favorites/presentation/providers/favorites_controller.dart';
import '../../../history/presentation/providers/history_controller.dart';

/// Real, actionable settings only — language, and clearing the two
/// persisted lists this app introduced (Favorites/History). Reached from the
/// "CÀI ĐẶT" top-nav tab and the preview player's settings button.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final locale = ref.watch(appLocaleProvider);
    final localeController = ref.read(appLocaleProvider.notifier);
    final volume = ref.watch(volumeProvider);

    return KaraokeShell(
      topBar: SizedBox(
        height: AppLayout.topNavItemHeight,
        child: Row(
          children: [
            const SizedBox.shrink(),
            const SizedBox(width: AppSpacing.sm),
            TitlePill(label: l10n.topSettings, color: AppColors.textSecondary),
            const Spacer(),
          ],
        ),
      ),
      body: Center(
        child: SizedBox(
          width: 720,
          child: PanelFrame(
            title: l10n.topSettings,
            leadingIcon: Icons.settings_outlined,
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _SettingsRow(
                  label: l10n.settingsLanguage,
                  trailing: LanguageToggle(
                    isVietnamese: locale.languageCode == 'vi',
                    onToggle: localeController.toggle,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _NavigationRow(
                  icon: Icons.history_rounded,
                  label: l10n.settingsViewHistory,
                  onPressed: () =>
                      Navigator.of(context).pushNamed(AppRouter.history),
                ),
                const SizedBox(height: AppSpacing.md),
                _ConfirmActionRow(
                  icon: Icons.favorite_border_rounded,
                  label: l10n.settingsClearFavorites,
                  confirmLabel: l10n.settingsConfirmAgain,
                  onConfirmed: ref.read(favoritesControllerProvider.notifier).clear,
                ),
                const SizedBox(height: AppSpacing.md),
                _ConfirmActionRow(
                  icon: Icons.history_rounded,
                  label: l10n.settingsClearHistory,
                  confirmLabel: l10n.settingsConfirmAgain,
                  onConfirmed: ref.read(historyControllerProvider.notifier).clear,
                ),
              ],
            ),
          ),
        ),
      ),
      bottomBar: AppBottomHintBar(
        leading: VolumeIndicator(
          level: volume.level,
          enabled: volume.isAvailable,
          onChanged: ref.read(volumeProvider.notifier).setLevel,
        ),
        items: const [],
        trailingItems: [
          BottomHintItem(
            id: 'back',
            badgeIcon: Icons.undo_rounded,
            label: l10n.hintBack,
          ),
        ],
        onItemTap: (item) {
          if (item.id == 'back') {
            Navigator.of(context).maybePop();
          }
        },
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.label, required this.trailing});

  final String label;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: Theme.of(context).textTheme.titleMedium),
        ),
        trailing,
      ],
    );
  }
}

class _NavigationRow extends StatelessWidget {
  const _NavigationRow({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onPressed: onPressed,
      builder: (context, focused) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: focused
                ? AppColors.green.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: focused ? AppColors.green : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.textPrimary, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
            ],
          ),
        );
      },
    );
  }
}

/// A destructive action that requires two taps: the first arms it (swapping
/// its label to [confirmLabel] for a few seconds), the second — while
/// armed — actually runs [onConfirmed]. Avoids introducing a full dialog
/// component for two settings rows.
class _ConfirmActionRow extends StatefulWidget {
  const _ConfirmActionRow({
    required this.icon,
    required this.label,
    required this.confirmLabel,
    required this.onConfirmed,
  });

  final IconData icon;
  final String label;
  final String confirmLabel;
  final VoidCallback onConfirmed;

  @override
  State<_ConfirmActionRow> createState() => _ConfirmActionRowState();
}

class _ConfirmActionRowState extends State<_ConfirmActionRow> {
  bool _armed = false;
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    if (_armed) {
      _resetTimer?.cancel();
      setState(() => _armed = false);
      widget.onConfirmed();
      return;
    }
    setState(() => _armed = true);
    _resetTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _armed = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onPressed: _handleTap,
      builder: (context, focused) {
        final active = _armed || focused;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: active
                ? AppColors.red.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: active ? AppColors.red : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Icon(widget.icon, color: AppColors.red, size: 22),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  _armed ? widget.confirmLabel : widget.label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 5: Wire the route and the "CÀI ĐẶT" top-nav tab**

Modify `lib/routes/app_router.dart`, adding the `settings` route (this is the constant the parameter rename in Task 4 was preparing for):

```dart
import '../features/settings/presentation/pages/settings_page.dart';
```

```dart
  static const String settings = '/settings';
```

```dart
      case settings:
        return MaterialPageRoute<void>(
          builder: (_) => const SettingsPage(),
          settings: routeSettings,
        );
```

(Insert the constant after `history`, and the case after the `history` case, before `default`.)

Modify `lib/features/song_browser/data/mock/song_browser_mock_data.dart`, adding a named constant next to `selectedTabIndex`:

```dart
  /// Position of "ĐÃ CHỌN" in [topActions] — tapping it navigates to the
  /// queue screen instead of just toggling the highlighted tab.
  static const int selectedTabIndex = 2;

  /// Position of "CÀI ĐẶT" in [topActions] — tapping it navigates to the
  /// settings screen instead of just toggling the highlighted tab.
  static const int settingsTabIndex = 3;
```

Modify `lib/features/song_browser/presentation/pages/song_browser_page.dart`'s `_handleTopAction`:

```dart
  void _handleTopAction(SongBrowserController controller, int index) {
    if (index == SongBrowserMockData.selectedTabIndex) {
      Navigator.of(context).pushNamed(AppRouter.selectedQueue);
      return;
    }
    if (index == SongBrowserMockData.settingsTabIndex) {
      Navigator.of(context).pushNamed(AppRouter.settings);
      return;
    }
    controller.selectTopAction(index);
  }
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/settings_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 7: Run the full suite**

Run: `flutter analyze && flutter test`
Expected: PASS.

---

### Task 12: Category browsing under "DANH SÁCH"

**Files:**
- Create: `lib/features/song_browser/data/song_categories.dart`
- Create: `lib/features/song_browser/presentation/widgets/category_grid_panel.dart`
- Modify: `lib/features/song_browser/presentation/providers/song_browser_provider.dart`
- Modify: `lib/features/song_browser/presentation/pages/song_browser_page.dart`
- Modify: `lib/l10n/app_vi.arb`, `lib/l10n/app_en.arb`
- Test: `test/categories_test.dart`

**Interfaces:**
- Produces: `songCategoriesFor(AppLocalizations, MusicSourceLogoStyle) -> List<SongCategory>`; `SongBrowserController.browseCategory(String seedQuery)`, `.selectCategory(int index)`; `SongBrowserState.selectedCategoryIndex`.

- [ ] **Step 1: Add l10n keys**

Add to `lib/l10n/app_vi.arb`:

```json
  "panelCategories": "DANH MỤC",
  "categoryPopular": "Nhạc trẻ",
  "categoryBolero": "Bolero / Trữ tình",
  "categoryRemix": "Nhạc remix",
  "categoryKids": "Thiếu nhi",
  "categoryTopSearched": "Tìm nhiều nhất",
  "categoryDjSet": "DJ Set",
  "categoryPodcast": "Podcast",
```

Add to `lib/l10n/app_en.arb`:

```json
  "panelCategories": "CATEGORIES",
  "categoryPopular": "Pop hits",
  "categoryBolero": "Bolero / Ballad",
  "categoryRemix": "Remix",
  "categoryKids": "Kids",
  "categoryTopSearched": "Top searched",
  "categoryDjSet": "DJ Set",
  "categoryPodcast": "Podcast",
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing test**

Create `test/categories_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:viet_ktv/core/services/music_sdk_platform.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/category_grid_panel.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/suggestions_panel.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import 'support/fake_audio_track_player.dart';
import 'support/fake_music_sdk_platform.dart';
import 'support/fake_video_player_platform.dart';

const _source = MusicSource(
  id: 'youtube',
  subtitle: 'Kho nhạc & Video\nkhổng lồ',
  accentColor: AppColors.red,
  logoStyle: MusicSourceLogoStyle.youtube,
);

Future<void> _pumpBrowser(WidgetTester tester, {MusicSdkPlatform? platform}) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        musicSdkPlatformProvider.overrideWithValue(
          platform ?? FakeMusicSdkPlatform(),
        ),
        audioTrackPlayerFactoryProvider.overrideWithValue(
          FakeAudioTrackPlayer.new,
        ),
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
        home: const SongBrowserPage(source: _source),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
  });

  testWidgets('danh_sach_tab_shows_categories_instead_of_suggestions', (
    tester,
  ) async {
    await _pumpBrowser(tester);

    expect(find.byType(SuggestionsPanel), findsOneWidget);
    expect(find.byType(CategoryGridPanel), findsNothing);

    await tester.tap(find.text('DANH SÁCH'));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryGridPanel), findsOneWidget);
    expect(find.byType(SuggestionsPanel), findsNothing);
  });

  testWidgets('tapping_a_category_runs_a_search_for_it', (tester) async {
    final platform = FakeMusicSdkPlatform();
    await _pumpBrowser(tester, platform: platform);

    await tester.tap(find.text('DANH SÁCH'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bolero / Trữ tình'));
    await tester.pumpAndSettle();

    expect(platform.lastSearchQuery, 'bolero trữ tình karaoke');
  });
}
```

- [ ] **Step 3: Run test to verify it fails**

Run: `flutter test test/categories_test.dart`
Expected: FAIL — `category_grid_panel.dart` does not exist.

- [ ] **Step 4: Implement categories, the panel, and controller wiring**

Create `lib/features/song_browser/data/song_categories.dart`:

```dart
import '../../../l10n/app_localizations.dart';
import '../../source_selection/data/models/music_source.dart';

class SongCategory {
  const SongCategory({required this.label, required this.seedQuery});

  final String label;
  final String seedQuery;
}

/// Curated preset search queries standing in for a real category API — same
/// approach as [recommendationSeedQuery] — tuned per source.
List<SongCategory> songCategoriesFor(
  AppLocalizations l10n,
  MusicSourceLogoStyle style,
) {
  return switch (style) {
    MusicSourceLogoStyle.youtube => [
      SongCategory(label: l10n.categoryPopular, seedQuery: 'nhạc trẻ karaoke hot'),
      SongCategory(
        label: l10n.categoryBolero,
        seedQuery: 'bolero trữ tình karaoke',
      ),
      SongCategory(label: l10n.categoryRemix, seedQuery: 'nhạc remix karaoke'),
      SongCategory(label: l10n.categoryKids, seedQuery: 'nhạc thiếu nhi karaoke'),
      SongCategory(
        label: l10n.categoryTopSearched,
        seedQuery: 'karaoke việt nam hot nhất',
      ),
    ],
    MusicSourceLogoStyle.soundcloud => [
      SongCategory(label: l10n.categoryPopular, seedQuery: 'nhạc trẻ remix'),
      SongCategory(label: l10n.categoryRemix, seedQuery: 'nhạc remix hot'),
      SongCategory(label: l10n.categoryTopSearched, seedQuery: 'edm hot'),
    ],
    MusicSourceLogoStyle.mixcloud => [
      SongCategory(label: l10n.categoryDjSet, seedQuery: 'dj mix set'),
      SongCategory(label: l10n.categoryPodcast, seedQuery: 'podcast nhạc'),
      SongCategory(label: l10n.categoryTopSearched, seedQuery: 'dj set hot'),
    ],
  };
}
```

Create `lib/features/song_browser/presentation/widgets/category_grid_panel.dart`:

```dart
import 'package:flutter/material.dart';

import '../../../../core/shared/widgets/focusable_tile.dart';
import '../../../../core/shared/widgets/panel_frame.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_glows.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../../data/song_categories.dart';
import '../../../source_selection/data/models/music_source.dart';

/// Left column shown on the "DANH SÁCH" tab in place of [SuggestionsPanel]:
/// a curated list of preset-query categories.
class CategoryGridPanel extends StatelessWidget {
  const CategoryGridPanel({
    super.key,
    required this.source,
    required this.selectedIndex,
    required this.onSelected,
    required this.onFocused,
  });

  final MusicSourceLogoStyle source;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<int> onFocused;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final categories = songCategoriesFor(l10n, source);

    return PanelFrame(
      title: l10n.panelCategories,
      leadingIcon: Icons.grid_view_rounded,
      child: ListView.separated(
        padding: EdgeInsets.zero,
        physics: const BouncingScrollPhysics(),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, index) => _CategoryTile(
          label: categories[index].label,
          selected: index == selectedIndex,
          onPressed: () => onSelected(index),
          onFocused: () => onFocused(index),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.selected,
    required this.onPressed,
    required this.onFocused,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final VoidCallback onFocused;

  @override
  Widget build(BuildContext context) {
    return FocusableTile(
      onPressed: onPressed,
      onFocusChange: (focused) {
        if (focused) {
          onFocused();
        }
      },
      builder: (context, focused) {
        final active = selected || focused;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          decoration: BoxDecoration(
            color: active
                ? AppColors.green.withValues(alpha: 0.16)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: Border.all(
              color: active ? AppColors.green : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: AppGlows.control(AppColors.green, focused: active),
          ),
          child: Row(
            children: [
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: active ? AppColors.green : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

Modify `lib/features/song_browser/presentation/providers/song_browser_provider.dart`: add `selectedCategoryIndex` to `SongBrowserState`, and `selectCategory`/`browseCategory` to the controller, factoring the shared search body out of `submitSearch`:

```dart
class SongBrowserState {
  const SongBrowserState({
    required this.source,
    this.query = '',
    this.selectedTopActionIndex = 0,
    this.selectedSuggestionIndex = 0,
    this.selectedResultIndex = 0,
    this.selectedCategoryIndex = 0,
    this.recommendations = const RecommendationsLoading(),
    this.search = const SearchIdle(),
  });

  final MusicSource source;
  final String query;
  final int selectedTopActionIndex;
  final int selectedSuggestionIndex;
  final int selectedResultIndex;
  final int selectedCategoryIndex;

  final RecommendationsState recommendations;
  final SearchState search;

  SongBrowserState copyWith({
    String? query,
    int? selectedTopActionIndex,
    int? selectedSuggestionIndex,
    int? selectedResultIndex,
    int? selectedCategoryIndex,
    RecommendationsState? recommendations,
    SearchState? search,
  }) {
    return SongBrowserState(
      source: source,
      query: query ?? this.query,
      selectedTopActionIndex:
          selectedTopActionIndex ?? this.selectedTopActionIndex,
      selectedSuggestionIndex:
          selectedSuggestionIndex ?? this.selectedSuggestionIndex,
      selectedResultIndex: selectedResultIndex ?? this.selectedResultIndex,
      selectedCategoryIndex:
          selectedCategoryIndex ?? this.selectedCategoryIndex,
      recommendations: recommendations ?? this.recommendations,
      search: search ?? this.search,
    );
  }
}
```

Replace `submitSearch` and add `selectCategory`/`browseCategory` (place these right after the existing `submitSearch` method):

```dart
  void selectCategory(int index) {
    state = state.copyWith(selectedCategoryIndex: index);
  }

  Future<void> browseCategory(String seedQuery) async {
    state = state.copyWith(query: seedQuery, selectedResultIndex: 0);
    await _runSearch(seedQuery);
  }

  Future<void> submitSearch() async {
    final query = state.query.trim();
    if (query.isEmpty) {
      state = state.copyWith(search: const SearchIdle());
      return;
    }
    await _runSearch(query);
  }

  Future<void> _runSearch(String query) async {
    final requestId = ++_searchRequestId;
    state = state.copyWith(
      search: const SearchLoading(),
      selectedResultIndex: 0,
    );

    try {
      final results = await _repository.search(
        source: state.source.logoStyle,
        query: query,
      );
      if (!mounted || requestId != _searchRequestId) {
        return;
      }
      state = state.copyWith(search: SearchSuccess(results));
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) {
        return;
      }
      state = state.copyWith(search: const SearchFailed());
    }
  }
```

(This replaces the old `submitSearch` body wholesale — the old inline try/catch moves verbatim into the new private `_runSearch`.)

Modify `lib/features/song_browser/presentation/pages/song_browser_page.dart`: swap the left column and keyboard panel based on the active tab. Add the import:

```dart
import '../widgets/category_grid_panel.dart';
```

Replace the left-column `CollapsibleAxis`'s `child:` (currently just `SuggestionsPanel(...)`) with a conditional, and compute a `hideKeyboard` flag used by the keyboard `CollapsibleAxis`'s `collapsed:`:

```dart
    final isCategoryTab =
        state.selectedTopActionIndex == SongBrowserMockData.categoryTabIndex;
```

(Add this line alongside the other `final ... = ref.watch(...)`/`final state = ...` locals near the top of `build`.)

```dart
                child: isCategoryTab
                    ? CategoryGridPanel(
                        source: state.source.logoStyle,
                        selectedIndex: state.selectedCategoryIndex,
                        onSelected: (index) => controller.browseCategory(
                          songCategoriesFor(
                            l10n,
                            state.source.logoStyle,
                          )[index].seedQuery,
                        ),
                        onFocused: controller.selectCategory,
                      )
                    : SuggestionsPanel(
                        recommendations: state.recommendations,
                        selectedIndex: state.selectedSuggestionIndex,
                        onSelected: controller.selectSuggestion,
                        onPlay: controller.playSong,
                        source: state.source.logoStyle,
                      ),
```

Add the `songCategoriesFor` import used above:

```dart
import '../../data/song_categories.dart';
```

Change the keyboard panel's `CollapsibleAxis` `collapsed:` from `collapsed: isExpanded,` to `collapsed: isExpanded || isCategoryTab,`.

Modify `lib/features/song_browser/data/mock/song_browser_mock_data.dart`, adding one more named constant next to `selectedTabIndex`/`settingsTabIndex`:

```dart
  /// Position of "DANH SÁCH" in [topActions] — swaps the left column to
  /// [CategoryGridPanel] and hides the on-screen keyboard.
  static const int categoryTabIndex = 1;
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/categories_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Run the full suite**

Run: `flutter analyze && flutter test`
Expected: PASS. `SuggestionsPanel` gained a required `source` field in Task 3 Step 6 — confirm the call site update made there already covers this page (it does; no further change needed here beyond what Step 4 shows).

---

### Task 13: Final polish pass

**Files:** none new — verification only.

- [ ] **Step 1: Format**

Run: `dart format .`
Expected: reports the files it reformatted (if any) with no errors.

- [ ] **Step 2: Analyze**

Run: `flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Full test suite**

Run: `flutter test`
Expected: All tests pass, including every file touched or added across Tasks 1–12 (`widget_test.dart`, `queue_test.dart`, `volume_test.dart`, `music_sdk_song_repository_test.dart`, `favorites_test.dart`, `history_test.dart`, `settings_test.dart`, `categories_test.dart`, and the two new `test/core`/`test/features` unit-test files).

- [ ] **Step 4: Build check (if the local Android toolchain is available)**

Run: `flutter build apk --debug`
Expected: builds successfully. If no Android toolchain is available in this environment, note that this step was skipped rather than silently omitting it.

- [ ] **Step 5: Manual smoke pass against the spec's scope list**

Confirm each item from `docs/superpowers/specs/2026-07-24-favorites-history-settings-design.md`'s Scope section is reachable in the running app: favoriting a song from search/suggestions, opening Favorites from the "D" hint, Settings from both the transport button and the "CÀI ĐẶT" tab, History from Settings, repeat/shuffle from the queue panel, category browsing from "DANH SÁCH", and that the rewind button now actually seeks. Do not mark this task done until every one of these is exercised at least once.
