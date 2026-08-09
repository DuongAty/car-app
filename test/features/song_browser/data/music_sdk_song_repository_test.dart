import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/services/music_sdk_platform.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/song_browser/data/music_sdk_song_repository.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';

class _FakeMusicSdkPlatform implements MusicSdkPlatform {
  List<MusicSdkTrack> searchResult = const [];
  MusicSourceLogoStyle? lastSearchSource;
  String? lastSearchQuery;
  MusicSourceLogoStyle? lastPlayableLinkSource;
  String? lastPlayableLinkTrackId;

  @override
  Future<void> initialize(String licenseKey) async {}

  @override
  Future<String> getPlayableLink({
    required MusicSourceLogoStyle source,
    required String trackId,
  }) async {
    lastPlayableLinkSource = source;
    lastPlayableLinkTrackId = trackId;
    return 'https://media.example/$trackId';
  }

  @override
  Future<List<MusicSdkTrack>> search({
    required MusicSourceLogoStyle source,
    required String query,
  }) async {
    lastSearchSource = source;
    lastSearchQuery = query;
    return searchResult;
  }
}

void main() {
  group('MusicSdkSongRepository', () {
    test(
      'searches platform by source and maps tracks into song items',
      () async {
        final platform = _FakeMusicSdkPlatform()
          ..searchResult = const [
            MusicSdkTrack(
              id: 'yt-1',
              title: 'Em Cua Ngay Hom Qua',
              subtitle: 'Official Karaoke',
              duration: '04:12',
              imageUrl: 'https://img.example/yt-1.jpg',
              badge: 'HOT',
            ),
          ];
        final repository = MusicSdkSongRepository(platform);

        final songs = await repository.search(
          source: MusicSourceLogoStyle.youtube,
          query: 'em cua',
        );

        expect(platform.lastSearchSource, MusicSourceLogoStyle.youtube);
        expect(platform.lastSearchQuery, 'em cua');
        expect(songs, [
          isA<SongItem>()
              .having((item) => item.id, 'id', 'yt-1')
              .having((item) => item.title, 'title', 'Em Cua Ngay Hom Qua')
              .having((item) => item.subtitle, 'subtitle', 'Official Karaoke')
              .having((item) => item.duration, 'duration', '04:12')
              .having(
                (item) => item.imageUrl,
                'imageUrl',
                'https://img.example/yt-1.jpg',
              )
              .having((item) => item.badge, 'badge', 'HOT'),
        ]);
        expect(songs.single.thumbnailSeed, isNot(0));
      },
    );

    test('gets a playable link for the selected source and track id', () async {
      final platform = _FakeMusicSdkPlatform();
      final repository = MusicSdkSongRepository(platform);

      final link = await repository.getPlayableLink(
        source: MusicSourceLogoStyle.soundcloud,
        trackId: 'sc-42',
      );

      expect(link, 'https://media.example/sc-42');
      expect(platform.lastPlayableLinkSource, MusicSourceLogoStyle.soundcloud);
      expect(platform.lastPlayableLinkTrackId, 'sc-42');
    });
  });
}
