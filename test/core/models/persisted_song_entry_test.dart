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
