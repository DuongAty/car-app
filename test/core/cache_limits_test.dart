import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/models/persisted_song_entry.dart';
import 'package:viet_ktv/features/favorites/data/favorites_repository.dart';
import 'package:viet_ktv/features/history/data/history_repository.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/song_browser/data/recommendations_cache_repository.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';

import '../support/fake_local_storage_service.dart';

void main() {
  SongItem song(int index) => SongItem(
    id: '$index',
    title: 'Track $index',
    subtitle: 'Artist',
    duration: '03:00',
    thumbnailSeed: index,
    badge: null,
  );

  List<PersistedSongEntry> entries() => List.generate(
    51,
    (index) => PersistedSongEntry(
      song: song(index),
      source: MusicSourceLogoStyle.youtube,
      at: DateTime(2026, 1, 1),
    ),
  );

  test('persisted caches keep at most 50 newest entries', () async {
    final storage = FakeLocalStorageService();
    final history = HistoryRepository(storage);
    final favorites = FavoritesRepository(storage);
    final recommendations = RecommendationsCacheRepository(storage);

    await history.save(entries());
    await favorites.save(entries());
    await recommendations.save(
      MusicSourceLogoStyle.youtube,
      List.generate(51, song),
    );

    expect(await history.load(), hasLength(50));
    expect(await favorites.load(), hasLength(50));
    expect(
      await recommendations.load(MusicSourceLogoStyle.youtube),
      hasLength(50),
    );
  });
}
