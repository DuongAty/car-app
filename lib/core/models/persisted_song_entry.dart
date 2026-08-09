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
    'song': song.toJson(),
    'source': source.name,
    'at': at.toIso8601String(),
  };

  factory PersistedSongEntry.fromJson(Map<String, dynamic> json) {
    return PersistedSongEntry(
      song: SongItem.fromJson(json['song'] as Map<String, dynamic>),
      source: MusicSourceLogoStyle.values.byName(json['source'] as String),
      at: DateTime.parse(json['at'] as String),
    );
  }

  /// Same as [fromJson], but returns null instead of throwing when the
  /// entry can't be reconstructed — e.g. it was saved under a
  /// [MusicSourceLogoStyle] value that no longer exists (a music source was
  /// removed after the entry was persisted). Callers should skip a null
  /// result rather than let one bad entry take down an entire stored list.
  static PersistedSongEntry? tryFromJson(Map<String, dynamic> json) {
    try {
      return PersistedSongEntry.fromJson(json);
    } catch (_) {
      return null;
    }
  }
}
