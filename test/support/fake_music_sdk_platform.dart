import 'package:flutter/services.dart';
import 'package:viet_ktv/core/services/music_sdk_platform.dart';
import 'package:viet_ktv/features/song_browser/data/recommendation_seed.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';

/// Stands in for the platform channel to `vn.kod.vkmusic.MusicSDK`.
///
/// The catalog includes an entry matching [recommendationSeedQuery] for
/// youtube so `SongBrowserController`'s automatic recommendations fetch (which
/// runs on every page open, not just on an explicit user search) resolves to a
/// deterministic, non-empty list in tests.
class FakeMusicSdkPlatform implements MusicSdkPlatform {
  FakeMusicSdkPlatform({this.failSearch = false, this.failLink = false});

  static final List<MusicSdkTrack> catalog = [
    MusicSdkTrack(
      id: '1',
      title: 'Lạc Trôi',
      // Matches on subtitle so the recommendations search (source: youtube)
      // finds this without colliding with the id/title used by explicit
      // 'OFFICIAL'/'Z' search assertions below.
      subtitle: recommendationSeedQuery(MusicSourceLogoStyle.youtube),
      duration: '4:20',
    ),
    const MusicSdkTrack(
      id: '9',
      title: 'Lạc Trôi - Sơn Tùng M-TP (Karaoke)',
      subtitle: 'Karaoke 4 You',
      duration: '4:32',
    ),
    const MusicSdkTrack(
      id: '10',
      title: 'Lạc Trôi - Sơn Tùng M-TP (Official MV)',
      subtitle: 'Sơn Tùng M-TP Official',
      duration: '4:35',
    ),
  ];

  final bool failSearch;
  final bool failLink;

  String? lastSearchQuery;
  final List<String> searchQueries = [];
  String? lastPlayableLinkTrackId;

  @override
  Future<void> initialize(String licenseKey) async {}

  @override
  Future<List<MusicSdkTrack>> search({
    required MusicSourceLogoStyle source,
    required String query,
  }) async {
    lastSearchQuery = query;
    searchQueries.add(query);
    if (failSearch) {
      throw PlatformException(code: 'music_sdk_search_failed');
    }

    final normalized = query.trim().toLowerCase();
    return catalog
        .where(
          (track) =>
              track.title.toLowerCase().contains(normalized) ||
              track.subtitle.toLowerCase().contains(normalized),
        )
        .toList();
  }

  @override
  Future<String> getPlayableLink({
    required MusicSourceLogoStyle source,
    required String trackId,
  }) async {
    lastPlayableLinkTrackId = trackId;
    if (failLink) {
      throw PlatformException(code: 'music_sdk_link_failed');
    }
    return 'https://example.test/$trackId.mp4';
  }
}
