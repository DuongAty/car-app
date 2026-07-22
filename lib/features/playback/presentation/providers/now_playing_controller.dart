import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../data/audio_track_player.dart';
import '../../data/visualizer_assets.dart';
import '../../../song_browser/data/models/song_item.dart';
import '../../../song_browser/data/music_sdk_song_repository.dart';
import '../../../song_browser/presentation/providers/music_sdk_repository_provider.dart';
import '../../../source_selection/data/models/music_source.dart';

/// Single now-playing slot shared by every screen that can trigger playback
/// (song browser, queue).
///
/// Deliberately not `autoDispose` and not a family: the whole point is that
/// navigating between the browser and the queue screen must not interrupt
/// what's already playing — only picking a different song does.
final nowPlayingProvider =
    StateNotifierProvider<NowPlayingController, NowPlayingState>(
      (ref) => NowPlayingController(
        ref.watch(musicSdkSongRepositoryProvider),
        ref.watch(audioTrackPlayerFactoryProvider),
      ),
    );

/// The song and any resolved URL travel together so the UI can never show a
/// playable URL that doesn't match the song it's attached to.
sealed class PlaybackState {
  const PlaybackState();
}

class PlaybackIdle extends PlaybackState {
  const PlaybackIdle();
}

class PlaybackLoading extends PlaybackState {
  const PlaybackLoading(this.song);

  final SongItem song;
}

class PlaybackReady extends PlaybackState {
  const PlaybackReady(this.song, this.url);

  final SongItem song;
  final String url;
}

class PlaybackFailed extends PlaybackState {
  const PlaybackFailed(this.song);

  final SongItem song;
}

class NowPlayingState {
  const NowPlayingState({
    this.playback = const PlaybackIdle(),
    // Arbitrary until something is played — the preview always needs a
    // concrete source for its badge, even at rest.
    this.activeSource = MusicSourceLogoStyle.youtube,
    this.isExpanded = false,
    this.videoController,
    this.visualizerController,
    this.audioPlayer,
    this.audioPosition = Duration.zero,
    this.audioDuration = Duration.zero,
    this.audioIsPlaying = false,
  });

  final PlaybackState playback;
  final MusicSourceLogoStyle activeSource;

  /// Theater mode: shared so expanding on one screen stays expanded after
  /// navigating to the other.
  final bool isExpanded;

  /// Owned here rather than by the widget that happens to be displaying it,
  /// so it survives the browser/queue screen swapping in and out.
  final VideoPlayerController? videoController;

  /// Muted looping local video shown while audio-only sources are playing.
  final VideoPlayerController? visualizerController;

  /// Audio-only player used by SoundCloud and MixCloud so visualizer video
  /// playback cannot steal the same video-player session.
  final AudioTrackPlayer? audioPlayer;
  final Duration audioPosition;
  final Duration audioDuration;
  final bool audioIsPlaying;
}

class NowPlayingController extends StateNotifier<NowPlayingState> {
  NowPlayingController(this._repository, this._audioPlayerFactory)
    : super(const NowPlayingState());

  final MusicSdkSongRepository _repository;
  final AudioTrackPlayerFactory _audioPlayerFactory;
  final math.Random _random = math.Random();

  // MusicSDK's link resolution and just_audio's setup both talk to a
  // reverse-engineered native SDK and a remote CDN — either can stall
  // silently on a bad source instead of throwing. Without a bound, that
  // leaves the UI on "Đang tải video..." forever with no way out; timing out
  // converts a silent hang into a visible PlaybackFailed the user can act on.
  static const _resolveTimeout = Duration(seconds: 15);

  // A second play() started before the first resolves must win — this guards
  // against a slow, stale resolution overwriting a newer one.
  int _playRequestId = 0;
  bool _completionHandled = false;
  String? _lastVisualizerAsset;
  FutureOr<void> Function()? _onCompleted;
  final List<StreamSubscription<dynamic>> _audioSubscriptions = [];

  void setOnCompleted(FutureOr<void> Function()? onCompleted) {
    _onCompleted = onCompleted;
  }

  Future<void> play(SongItem song, MusicSourceLogoStyle source) async {
    final requestId = ++_playRequestId;
    _completionHandled = false;

    final oldController = state.videoController;
    oldController?.removeListener(_handleTick);
    unawaited(oldController?.dispose());
    final oldVisualizerController = state.visualizerController;
    unawaited(oldVisualizerController?.dispose());
    _disposeAudioPlayer();

    state = NowPlayingState(
      playback: PlaybackLoading(song),
      activeSource: source,
      isExpanded: state.isExpanded,
    );

    final String link;
    try {
      link = await _repository
          .getPlayableLink(source: source, trackId: song.id)
          .timeout(_resolveTimeout);
    } catch (_) {
      if (!mounted || requestId != _playRequestId) {
        return;
      }
      state = NowPlayingState(
        playback: PlaybackFailed(song),
        activeSource: state.activeSource,
        isExpanded: state.isExpanded,
      );
      return;
    }
    if (!mounted || requestId != _playRequestId) {
      return;
    }

    if (source == MusicSourceLogoStyle.youtube) {
      await _playVideoSource(song, source, link, requestId);
      return;
    }

    await _playAudioSource(song, source, link, requestId);
  }

  Future<void> _playVideoSource(
    SongItem song,
    MusicSourceLogoStyle source,
    String link,
    int requestId,
  ) async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(link),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: false),
    );
    controller.addListener(_handleTick);
    try {
      await controller.initialize().timeout(_resolveTimeout);
      if (!mounted || requestId != _playRequestId) {
        controller.removeListener(_handleTick);
        await controller.dispose();
        return;
      }
      await controller.play();
      state = NowPlayingState(
        playback: PlaybackReady(song, link),
        activeSource: state.activeSource,
        isExpanded: state.isExpanded,
        videoController: controller,
      );
    } catch (_) {
      // The link may have expired, point at an unsupported format, or (in a
      // test/desktop host with no platform video decoder) simply have no
      // implementation to run against — fall back to the idle backdrop
      // rather than leaving a broken player on screen.
      controller.removeListener(_handleTick);
      await controller.dispose();
      if (!mounted || requestId != _playRequestId) {
        return;
      }
      state = NowPlayingState(
        playback: PlaybackFailed(song),
        activeSource: state.activeSource,
        isExpanded: state.isExpanded,
      );
    }
  }

  Future<void> _playAudioSource(
    SongItem song,
    MusicSourceLogoStyle source,
    String link,
    int requestId,
  ) async {
    final audioPlayer = _audioPlayerFactory();

    try {
      await audioPlayer.setUrl(link).timeout(_resolveTimeout);
      if (!mounted || requestId != _playRequestId) {
        await audioPlayer.dispose();
        return;
      }

      _listenToAudioPlayer(audioPlayer);
      // just_audio's play() future does not resolve when playback *starts* —
      // it resolves when playback stops/pauses/completes, staying pending for
      // the whole track. Awaiting (or timing out) it here blocked this whole
      // method until the track ended, which is what left the UI stuck on
      // "Đang tải video..." indefinitely for SoundCloud and MixCloud. Kick
      // playback off and move on; playingStream already keeps audioIsPlaying
      // in sync, and setUrl() above already validated the source resolves.
      unawaited(
        audioPlayer.play().catchError((_) {
          if (!mounted || requestId != _playRequestId) {
            return;
          }
          state = NowPlayingState(
            playback: PlaybackFailed(song),
            activeSource: state.activeSource,
            isExpanded: state.isExpanded,
          );
        }),
      );
      state = NowPlayingState(
        playback: PlaybackReady(song, link),
        activeSource: state.activeSource,
        isExpanded: state.isExpanded,
        audioPlayer: audioPlayer,
        audioIsPlaying: true,
      );
      unawaited(_loadVisualizerAsync(source, requestId, audioPlayer));
    } catch (_) {
      await audioPlayer.dispose();
      if (!mounted || requestId != _playRequestId) {
        return;
      }
      state = NowPlayingState(
        playback: PlaybackFailed(song),
        activeSource: state.activeSource,
        isExpanded: state.isExpanded,
      );
    }
  }

  Future<void> _loadVisualizerAsync(
    MusicSourceLogoStyle source,
    int requestId,
    AudioTrackPlayer audioPlayer,
  ) async {
    final visualizerController = await _createVisualizerController(
      source,
      requestId,
    );
    if (visualizerController == null) {
      return;
    }
    if (!mounted ||
        requestId != _playRequestId ||
        state.audioPlayer != audioPlayer) {
      await visualizerController.dispose();
      return;
    }
    if (state.audioIsPlaying) {
      await visualizerController.play();
    }
    state = NowPlayingState(
      playback: state.playback,
      activeSource: state.activeSource,
      isExpanded: state.isExpanded,
      visualizerController: visualizerController,
      audioPlayer: state.audioPlayer,
      audioPosition: state.audioPosition,
      audioDuration: state.audioDuration,
      audioIsPlaying: state.audioIsPlaying,
    );
  }

  void togglePlayPause() {
    final audioPlayer = state.audioPlayer;
    if (audioPlayer != null) {
      if (state.audioIsPlaying) {
        audioPlayer.pause();
        state.visualizerController?.pause();
      } else {
        audioPlayer.play();
        state.visualizerController?.play();
      }
      return;
    }

    final controller = state.videoController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (controller.value.isPlaying) {
      controller.pause();
      state.visualizerController?.pause();
    } else {
      controller.play();
      state.visualizerController?.play();
    }
  }

  void toggleExpanded() {
    state = NowPlayingState(
      playback: state.playback,
      activeSource: state.activeSource,
      isExpanded: !state.isExpanded,
      videoController: state.videoController,
      visualizerController: state.visualizerController,
      audioPlayer: state.audioPlayer,
      audioPosition: state.audioPosition,
      audioDuration: state.audioDuration,
      audioIsPlaying: state.audioIsPlaying,
    );
  }

  /// The controller mutates its own `.value` in place, so re-assigning state
  /// with the same field values (rather than mutating anything) is what
  /// actually notifies watchers of the new position/playing flag.
  void _handleTick() {
    if (!mounted) {
      return;
    }
    final isCompleted = state.videoController?.value.isCompleted ?? false;
    state = NowPlayingState(
      playback: state.playback,
      activeSource: state.activeSource,
      isExpanded: state.isExpanded,
      videoController: state.videoController,
      visualizerController: state.visualizerController,
      audioPlayer: state.audioPlayer,
      audioPosition: state.audioPosition,
      audioDuration: state.audioDuration,
      audioIsPlaying: state.audioIsPlaying,
    );
    final onCompleted = _onCompleted;
    if (isCompleted && !_completionHandled && onCompleted != null) {
      _completionHandled = true;
      unawaited(Future<void>.sync(onCompleted));
    }
  }

  @override
  void dispose() {
    final controller = state.videoController;
    controller?.removeListener(_handleTick);
    controller?.dispose();
    state.visualizerController?.dispose();
    _disposeAudioPlayer();
    super.dispose();
  }

  void _listenToAudioPlayer(AudioTrackPlayer audioPlayer) {
    _audioSubscriptions
      ..add(
        audioPlayer.positionStream.listen((position) {
          if (!mounted || state.audioPlayer != audioPlayer) {
            return;
          }
          _updateAudioState(audioPosition: position);
        }),
      )
      ..add(
        audioPlayer.durationStream.listen((duration) {
          if (!mounted || state.audioPlayer != audioPlayer) {
            return;
          }
          _updateAudioState(audioDuration: duration ?? Duration.zero);
        }),
      )
      ..add(
        audioPlayer.playingStream.listen((isPlaying) {
          if (!mounted || state.audioPlayer != audioPlayer) {
            return;
          }
          _updateAudioState(audioIsPlaying: isPlaying);
        }),
      )
      ..add(
        audioPlayer.completedStream.listen((_) {
          if (!mounted || state.audioPlayer != audioPlayer) {
            return;
          }
          final onCompleted = _onCompleted;
          if (!_completionHandled && onCompleted != null) {
            _completionHandled = true;
            unawaited(Future<void>.sync(onCompleted));
          }
        }),
      );
  }

  void _updateAudioState({
    Duration? audioPosition,
    Duration? audioDuration,
    bool? audioIsPlaying,
  }) {
    state = NowPlayingState(
      playback: state.playback,
      activeSource: state.activeSource,
      isExpanded: state.isExpanded,
      visualizerController: state.visualizerController,
      audioPlayer: state.audioPlayer,
      audioPosition: audioPosition ?? state.audioPosition,
      audioDuration: audioDuration ?? state.audioDuration,
      audioIsPlaying: audioIsPlaying ?? state.audioIsPlaying,
    );
  }

  void _disposeAudioPlayer() {
    for (final subscription in _audioSubscriptions) {
      unawaited(subscription.cancel());
    }
    _audioSubscriptions.clear();
    final audioPlayer = state.audioPlayer;
    if (audioPlayer != null) {
      unawaited(audioPlayer.dispose());
    }
  }

  Future<VideoPlayerController?> _createVisualizerController(
    MusicSourceLogoStyle source,
    int requestId,
  ) async {
    if (source == MusicSourceLogoStyle.youtube) {
      return null;
    }

    final asset = _pickVisualizerAsset();
    final controller = VideoPlayerController.asset(
      asset,
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );
    try {
      await controller.initialize();
      if (!mounted || requestId != _playRequestId) {
        await controller.dispose();
        return null;
      }
      await controller.setLooping(true);
      await controller.setVolume(0);
      _lastVisualizerAsset = asset;
      return controller;
    } catch (_) {
      await controller.dispose();
      return null;
    }
  }

  String _pickVisualizerAsset() {
    final videos = VisualizerAssets.videos;
    if (videos.length <= 1) {
      return videos.first;
    }

    final candidates = videos
        .where((asset) => asset != _lastVisualizerAsset)
        .toList(growable: false);
    return candidates[_random.nextInt(candidates.length)];
  }
}
