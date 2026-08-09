import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../queue/presentation/providers/queue_playback_controller.dart';
import '../../song_browser/data/models/song_item.dart';
// `NowPlayingState`'s own `PlaybackState` sealed class (PlaybackIdle /
// PlaybackLoading / PlaybackReady / PlaybackFailed) collides with
// `audio_service`'s `PlaybackState`. Only the subtypes are referenced by name
// in this file — hide the app's `PlaybackState` so `audio_service`'s wins.
import '../presentation/providers/now_playing_controller.dart'
    hide PlaybackState;

/// Bridges the media notification, lock screen, and hardware media buttons to
/// the controllers that already own playback.
///
/// It holds a [ProviderContainer] rather than a late-bound delegate because
/// `AudioService.init()` runs before `runApp`, and a media button pressed
/// during startup must still find a working target.
class KaraokeAudioHandler extends BaseAudioHandler with SeekHandler {
  KaraokeAudioHandler(this._container);

  final ProviderContainer _container;

  NowPlayingController get _nowPlaying =>
      _container.read(nowPlayingProvider.notifier);

  QueuePlaybackController get _queue =>
      _container.read(queuePlaybackControllerProvider.notifier);

  bool get _hasPlayback {
    final state = _container.read(nowPlayingProvider);
    return state.videoController != null || state.audioPlayer != null;
  }

  bool get _isPlaying {
    final state = _container.read(nowPlayingProvider);
    final video = state.videoController;
    if (video != null) {
      return video.value.isPlaying;
    }
    return state.audioIsPlaying;
  }

  @override
  Future<void> play() async {
    // After a terminal PlaybackFailed both players are disposed, so
    // `_hasPlayback` is false and the notification's play button would be
    // dead — the user would have to pick up the head unit. Treat play on a
    // failed track as an explicit retry instead.
    if (_container.read(nowPlayingProvider).playback is PlaybackFailed) {
      await _nowPlaying.replayFromStart();
      syncFromPlayback();
      return;
    }
    if (!_hasPlayback || _isPlaying) {
      return;
    }
    _nowPlaying.togglePlayPause();
    syncFromPlayback();
  }

  @override
  Future<void> pause() async {
    if (!_hasPlayback || !_isPlaying) {
      return;
    }
    _nowPlaying.togglePlayPause();
    syncFromPlayback();
  }

  @override
  Future<void> seek(Duration position) async {
    if (!_hasPlayback) {
      return;
    }
    _nowPlaying.seekTo(position);
  }

  @override
  Future<void> skipToNext() => _queue.playNext(fromCompletion: false);

  @override
  Future<void> skipToPrevious() => _queue.playPrevious();

  @override
  Future<void> stop() async {
    if (!_hasPlayback) {
      return;
    }
    _nowPlaying.stopPlayback();
    syncFromPlayback();
  }

  /// Last value pushed to [mediaItem], so unchanged metadata is never
  /// re-published. See [syncFromPlayback].
  MediaItem? _lastMediaItem;
  bool _hasPublishedMediaItem = false;

  /// Pushes the current playback state into the notification. Called from the
  /// provider listener whenever [nowPlayingProvider] changes.
  ///
  /// [nowPlayingProvider] ticks once per second while a track plays, but track
  /// metadata only changes on a track change. `mediaItem` is a plain
  /// `BehaviorSubject` — `audio_service` neither dedupes nor `.distinct()`s it,
  /// and every emission crosses to `AudioServicePlugin.setMediaItem`, which
  /// spins up a fresh single-thread executor, re-sets the media-session
  /// metadata, re-posts the notification and re-runs an art-cache lookup. Once
  /// a second that is ~3600 thread creations per playback hour on a 2GB box,
  /// and it makes AVRCP displays on car head units restart their title scroll
  /// continuously. So only publish when the metadata actually differs;
  /// `playbackState` stays per-tick because it is the intended position channel
  /// and costs no executor.
  void syncFromPlayback() {
    final state = _container.read(nowPlayingProvider);
    final item = _mediaItemFor(state);
    if (!_hasPublishedMediaItem || !_sameMediaItem(_lastMediaItem, item)) {
      _hasPublishedMediaItem = true;
      _lastMediaItem = item;
      mediaItem.add(item);
    }
    playbackState.add(_playbackStateFor(state));
  }

  /// `MediaItem` has no value equality, and `_mediaItemFor` builds a fresh one
  /// each call, so compare the fields the notification actually renders.
  static bool _sameMediaItem(MediaItem? a, MediaItem? b) {
    if (a == null || b == null) {
      return a == null && b == null;
    }
    return a.id == b.id &&
        a.title == b.title &&
        a.artist == b.artist &&
        a.artUri == b.artUri &&
        a.duration == b.duration;
  }

  MediaItem? _mediaItemFor(NowPlayingState state) {
    final song = switch (state.playback) {
      PlaybackLoading(:final song) => song,
      PlaybackReady(:final song) => song,
      PlaybackFailed(:final song) => song,
      PlaybackIdle() => null,
    };
    if (song == null) {
      return null;
    }
    return MediaItem(
      id: song.id,
      title: song.title,
      artist: song.subtitle,
      artUri: _artUri(song),
      duration: _durationFor(state),
    );
  }

  Uri? _artUri(SongItem song) {
    // SongItem.imageUrl is nullable and is empty for several mock sources.
    final imageUrl = song.imageUrl;
    if (imageUrl == null || imageUrl.isEmpty) {
      return null;
    }
    return Uri.tryParse(imageUrl);
  }

  Duration? _durationFor(NowPlayingState state) {
    final video = state.videoController;
    if (video != null && video.value.isInitialized) {
      return video.value.duration;
    }
    return state.audioDuration > Duration.zero ? state.audioDuration : null;
  }

  PlaybackState _playbackStateFor(NowPlayingState state) {
    final video = state.videoController;
    final playing = _isPlaying;
    final position = video != null && video.value.isInitialized
        ? video.value.position
        : state.audioPosition;
    return PlaybackState(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
      ],
      systemActions: const {MediaAction.seek},
      androidCompactActionIndices: const [0, 1, 2],
      processingState: switch (state.playback) {
        PlaybackIdle() => AudioProcessingState.idle,
        PlaybackLoading() => AudioProcessingState.loading,
        PlaybackReady() => AudioProcessingState.ready,
        PlaybackFailed() => AudioProcessingState.error,
      },
      playing: playing,
      updatePosition: position,
    );
  }
}
