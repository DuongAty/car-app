import '../../../song_browser/data/models/song_item.dart';
import '../../../source_selection/data/models/music_source.dart';

/// A song added to the karaoke queue, paired with the source it was found on
/// so it can be resolved to a playable link later regardless of which
/// [MusicSource] the browser happened to be on at the time.
class QueuedSong {
  const QueuedSong({required this.song, required this.source});

  final SongItem song;
  final MusicSource source;
}
