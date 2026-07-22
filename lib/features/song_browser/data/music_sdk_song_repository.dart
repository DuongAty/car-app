import '../../../core/services/music_sdk_platform.dart';
import '../../source_selection/data/models/music_source.dart';
import 'models/song_item.dart';

class MusicSdkSongRepository {
  const MusicSdkSongRepository(this._platform);

  final MusicSdkPlatform _platform;

  Future<void> initialize(String licenseKey) {
    return _platform.initialize(licenseKey);
  }

  Future<List<SongItem>> search({
    required MusicSourceLogoStyle source,
    required String query,
  }) async {
    final tracks = await _platform.search(source: source, query: query);

    return tracks
        .map(
          (track) => SongItem(
            id: track.id,
            title: track.title,
            subtitle: track.subtitle,
            duration: track.duration,
            thumbnailSeed: _stableThumbnailSeed(track.id),
            imageUrl: track.imageUrl,
            badge: track.badge,
          ),
        )
        .toList(growable: false);
  }

  Future<String> getPlayableLink({
    required MusicSourceLogoStyle source,
    required String trackId,
  }) {
    return _platform.getPlayableLink(source: source, trackId: trackId);
  }

  int _stableThumbnailSeed(String id) {
    final hash = id.hashCode.abs();
    return hash == 0 ? 1 : hash;
  }
}
