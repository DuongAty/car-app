import 'package:remote_protocol/remote_protocol.dart';

import '../../queue/data/models/queued_song.dart';
import '../../queue/presentation/providers/queue_provider.dart';
import '../../song_browser/data/models/song_item.dart';
import '../../source_selection/data/mock/source_selection_mock_data.dart';
import '../../source_selection/data/models/music_source.dart';

/// The single translation layer between the car app's internal models and the
/// wire protocol shared with the phone app.
///
/// Publisher and command handler MUST both go through here: an entry id minted
/// one way on the way out and parsed another way on the way back in would make
/// "remove this queue row" delete the wrong song, and the bug would only show
/// up on a device with a non-trivial queue.
abstract final class RemoteMappers {
  /// Stable id for one queue row.
  ///
  /// `QueueController.add`/`insertAt` de-duplicate on (song.id, source.id), so
  /// this pair is unique within the queue and survives reordering — which an
  /// index does not. The phone may have drawn its list before a reorder landed.
  static String entryId(QueuedSong item) =>
      entryIdFor(item.source.logoStyle, item.song.id);

  static String entryIdFor(MusicSourceLogoStyle style, String songId) =>
      '${style.name}/$songId';

  static RemoteSource sourceOf(MusicSourceLogoStyle style) => switch (style) {
    MusicSourceLogoStyle.youtube => RemoteSource.youtube,
    MusicSourceLogoStyle.soundcloud => RemoteSource.soundcloud,
  };

  static MusicSourceLogoStyle logoStyleOf(RemoteSource source) =>
      switch (source) {
        RemoteSource.youtube => MusicSourceLogoStyle.youtube,
        RemoteSource.soundcloud => MusicSourceLogoStyle.soundcloud,
      };

  /// The real [MusicSource] the rest of the app uses, minus the localized
  /// subtitle — a remote command arrives with no `BuildContext` to localize
  /// against, and nothing downstream of the queue reads that subtitle.
  static MusicSource musicSourceOf(RemoteSource source) =>
      SourceSelectionMockData.unlocalizedSource(logoStyleOf(source));

  static SongSnapshot songSnapshot(
    SongItem song,
    MusicSourceLogoStyle style, {
    int? durationMs,
  }) {
    return SongSnapshot(
      id: song.id,
      title: song.title,
      artist: song.subtitle,
      source: sourceOf(style),
      durationMs: durationMs,
      durationLabel: song.duration.isEmpty ? null : song.duration,
      thumbnailUrl: song.imageUrl,
      badge: song.badge,
    );
  }

  /// Rebuilds the internal model from a snapshot the phone sent back.
  ///
  /// [thumbnailSeed] is regenerated with the same rule as
  /// `MusicSdkSongRepository._stableThumbnailSeed`, so a song queued from the
  /// phone paints the identical placeholder gradient as one queued on the box.
  static SongItem songItem(SongSnapshot snapshot) {
    return SongItem(
      id: snapshot.id,
      title: snapshot.title,
      subtitle: snapshot.artist,
      duration: snapshot.durationLabel ?? '',
      thumbnailSeed: thumbnailSeed(snapshot.id),
      imageUrl: snapshot.thumbnailUrl,
      badge: snapshot.badge,
    );
  }

  static int thumbnailSeed(String id) {
    final hash = id.hashCode.abs();
    return hash == 0 ? 1 : hash;
  }

  static QueuedSong queuedSong(SongSnapshot snapshot) => QueuedSong(
    song: songItem(snapshot),
    source: musicSourceOf(snapshot.source),
  );

  static RemoteRepeatMode repeatModeOf(QueueRepeatMode mode) => switch (mode) {
    QueueRepeatMode.off => RemoteRepeatMode.off,
    QueueRepeatMode.one => RemoteRepeatMode.one,
    QueueRepeatMode.all => RemoteRepeatMode.all,
  };

  static QueueRepeatMode queueRepeatModeOf(RemoteRepeatMode mode) =>
      switch (mode) {
        RemoteRepeatMode.off => QueueRepeatMode.off,
        RemoteRepeatMode.one => QueueRepeatMode.one,
        RemoteRepeatMode.all => QueueRepeatMode.all,
      };
}
