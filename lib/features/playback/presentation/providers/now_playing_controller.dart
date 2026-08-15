import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';

import '../../data/audio_track_player.dart';
import '../../data/visualizer_assets.dart';
import '../../data/youtube_quality_selector.dart';
import '../../../settings/data/models/app_settings.dart';
import '../../../song_browser/data/models/song_item.dart';
import '../../../song_browser/data/music_sdk_song_repository.dart';
import '../../../song_browser/presentation/providers/music_sdk_repository_provider.dart';
import '../../../source_selection/data/models/music_source.dart';
import '../../../settings/presentation/providers/settings_controller.dart';

/// Single now-playing slot shared by every screen that can trigger playback
/// (song browser, queue).
///
/// Deliberately not `autoDispose` and not a family: the whole point is that
/// navigating between the browser and the queue screen must not interrupt
/// what's already playing — only picking a different song does.
final nowPlayingProvider =
    StateNotifierProvider<NowPlayingController, NowPlayingState>((ref) {
      final controller = NowPlayingController(
        ref.watch(musicSdkSongRepositoryProvider),
        ref.watch(audioTrackPlayerFactoryProvider),
      );
      // Seed initial values with read (NOT watch). Watching a setting here made
      // nowPlayingProvider a dependency of it, so changing volume/visualizer/
      // quality — e.g. dragging the volume slider mid-song — disposed and
      // recreated this controller, tearing down the live video decoder and
      // stopping playback. The ref.listen blocks below apply changes in place.
      final settings = ref.read(settingsControllerProvider);
      controller.setPlaybackVolume(settings.musicVolume);
      controller.setVisualizerEnabled(settings.visualizerEnabled);
      controller.setVideoQuality(settings.videoQuality);
      ref.listen<double>(
        settingsControllerProvider.select((value) => value.musicVolume),
        (_, volume) => controller.setPlaybackVolume(volume),
      );
      ref.listen<bool>(
        settingsControllerProvider.select((value) => value.visualizerEnabled),
        (_, enabled) => controller.setVisualizerEnabled(enabled),
      );
      ref.listen<VideoQuality>(
        settingsControllerProvider.select((value) => value.videoQuality),
        (_, quality) => controller.setVideoQuality(quality),
      );
      return controller;
    });

/// How much of the screen the player occupies.
///
/// A single enum rather than two booleans: "expanded and fullscreen at the same
/// time" has no defined meaning, and an enum makes it unrepresentable.
enum PlayerViewMode {
  /// Search/results column on the left, player on the right.
  normal,

  /// Left column collapsed, player full width. App chrome still visible.
  wide,

  /// Player owns the whole screen; top nav and bottom bar are gone.
  fullscreen,
}

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
    this.mode = PlayerViewMode.normal,
    this.videoController,
    this.visualizerController,
    this.audioPlayer,
    this.audioPosition = Duration.zero,
    this.audioDuration = Duration.zero,
    this.audioIsPlaying = false,
  });

  final PlaybackState playback;
  final MusicSourceLogoStyle activeSource;

  /// Theater mode: shared so a mode chosen on one screen survives navigating
  /// to another.
  final PlayerViewMode mode;

  /// Owned here rather than by the widget that happens to be displaying it,
  /// so it survives the browser/queue screen swapping in and out.
  final VideoPlayerController? videoController;

  /// Muted looping local video shown while audio-only sources are playing.
  final VideoPlayerController? visualizerController;

  /// Audio-only player used by SoundCloud so visualizer video playback
  /// cannot steal the same video-player session.
  final AudioTrackPlayer? audioPlayer;
  final Duration audioPosition;
  final Duration audioDuration;
  final bool audioIsPlaying;
}

class NowPlayingController extends StateNotifier<NowPlayingState> {
  NowPlayingController(
    this._repository,
    this._audioPlayerFactory, [
    this._qualitySelector = const YoutubeQualitySelector(),
  ]) : super(const NowPlayingState());

  final MusicSdkSongRepository _repository;
  final AudioTrackPlayerFactory _audioPlayerFactory;
  final YoutubeQualitySelector _qualitySelector;
  double _userVolume = 1;
  // Ducking is a separate multiplier rather than an overwrite of _userVolume,
  // so a volume change during a navigation prompt is not lost when the prompt
  // ends, and releasing the duck restores whatever the user has set by then.
  double _duckFactor = 1;

  double get _effectiveVolume => _userVolume * _duckFactor;
  VideoQuality _videoQuality = VideoQuality.auto;
  // Matches the persisted default (AppSettings.visualizerEnabled == false).
  // Defaulting to true would spin up a 720p looping decoder on the first
  // audio-only source if the provider wiring ever applied the setting late.
  bool _visualizerEnabled = false;
  final math.Random _random = math.Random();

  // Short-lived cache of resolved playable links, keyed by "source|trackId".
  // Resolving a link is the slowest call in the app (native SDK + CDN, 15s
  // timeout) and sits on the critical playback path. Repeat-one, previous, and
  // repeat-all re-play the same track and would otherwise re-resolve it every
  // time. Links expire, so this is TTL-bounded and evicted on playback failure.
  static const Duration _linkCacheTtl = Duration(seconds: 90);
  final Map<String, _CachedLink> _linkCache = {};

  // MusicSDK's link resolution and just_audio's setup both talk to a
  // reverse-engineered native SDK and a remote CDN — either can stall
  // silently on a bad source instead of throwing. Without a bound, that
  // leaves the UI on "Đang tải video..." forever with no way out; timing out
  // converts a silent hang into a visible PlaybackFailed the user can act on.
  static const _resolveTimeout = Duration(seconds: 15);
  static const _rewindStep = Duration(seconds: 10);
  static const _fastForwardStep = Duration(seconds: 10);
  static const _maxPlaybackAttempts = 3;

  // A terminal PlaybackFailed advances the queue (see the tail of [play]), so
  // a queue whose links have all expired — easy after the app sat idle past
  // the CDN's expiry — would otherwise chain failure→advance→failure with no
  // await between resolutions and burn through every entry in a tight loop,
  // hammering the native SDK on a 2GB box. Three is the smallest cap that
  // still covers the realistic case this exists for: one or two dead links in
  // an otherwise good queue. Past that the queue is broken, not unlucky, and
  // stopping leaves the notification showing the failed track with a working
  // play button (KaraokeAudioHandler.play retries it).
  static const _maxConsecutiveFailedAdvances = 3;
  int _consecutiveFailedStarts = 0;

  // A second play() started before the first resolves must win — this guards
  // against a slow, stale resolution overwriting a newer one.
  int _playRequestId = 0;
  bool _completionHandled = false;
  int _lastVideoUiSecond = -1;
  bool? _lastVideoUiIsPlaying;
  int _lastAudioUiSecond = -1;
  String? _lastVisualizerAsset;
  FutureOr<void> Function({bool fromCompletion})? _onCompleted;
  final List<StreamSubscription<dynamic>> _audioSubscriptions = [];

  void setOnCompleted(
    FutureOr<void> Function({bool fromCompletion})? onCompleted,
  ) {
    _onCompleted = onCompleted;
  }

  void setVideoQuality(VideoQuality quality) {
    if (_videoQuality == quality) {
      return;
    }
    _videoQuality = quality;
    _linkCache.removeWhere((key, _) => key.startsWith('youtube|'));
  }

  Future<void> play(SongItem song, MusicSourceLogoStyle source) async {
    final requestId = ++_playRequestId;
    _completionHandled = false;
    _lastVideoUiSecond = -1;
    _lastVideoUiIsPlaying = null;
    _lastAudioUiSecond = -1;

    final oldController = state.videoController;
    oldController?.removeListener(_handleTick);
    unawaited(oldController?.dispose());
    final oldVisualizerController = state.visualizerController;
    unawaited(oldVisualizerController?.dispose());
    _disposeAudioPlayer();

    state = NowPlayingState(
      playback: PlaybackLoading(song),
      activeSource: source,
      mode: state.mode,
    );

    for (var attempt = 1; attempt <= _maxPlaybackAttempts; attempt++) {
      final quality = source == MusicSourceLogoStyle.youtube
          ? _qualityForAttempt(attempt)
          : null;
      final link = await _resolvePlayableLink(
        song,
        source,
        requestId,
        quality: quality,
      );
      if (!mounted || requestId != _playRequestId) {
        return;
      }
      if (link == null) {
        break;
      }

      final didStart = source == MusicSourceLogoStyle.youtube
          ? await _playVideoSource(song, source, link, requestId)
          : await _playAudioSource(song, source, link, requestId);
      if (didStart) {
        _consecutiveFailedStarts = 0;
        return;
      }
      if (!mounted || requestId != _playRequestId) {
        return;
      }

      _evictLink(source, song.id);
      if (attempt < _maxPlaybackAttempts) {
        state = NowPlayingState(
          playback: PlaybackLoading(song),
          activeSource: state.activeSource,
          mode: state.mode,
        );
      }
    }

    if (!mounted || requestId != _playRequestId) {
      return;
    }
    state = NowPlayingState(
      playback: PlaybackFailed(song),
      activeSource: state.activeSource,
      mode: state.mode,
    );

    // Driving with the screen off, an expired link used to end the session for
    // good: nothing called the completion callback on the terminal failure, so
    // `continuousPlayback` never advanced, and with both players disposed the
    // notification's play button was dead too. Treat the failure as a track
    // ending so the queue moves on — bounded by _maxConsecutiveFailedAdvances.
    _consecutiveFailedStarts++;
    final onCompleted = _onCompleted;
    if (onCompleted != null &&
        !_completionHandled &&
        _consecutiveFailedStarts <= _maxConsecutiveFailedAdvances) {
      _completionHandled = true;
      unawaited(Future<void>.sync(() => onCompleted(fromCompletion: true)));
    }
  }

  Future<String?> _resolvePlayableLink(
    SongItem song,
    MusicSourceLogoStyle source,
    int requestId, {
    VideoQuality? quality,
  }) async {
    final cacheKey = _linkCacheKey(source, song.id, quality: quality);
    final cached = _cachedLink(cacheKey);
    if (cached != null) {
      return cached;
    }

    try {
      final resolvedLink = await _repository
          .getPlayableLink(source: source, trackId: song.id)
          .timeout(_resolveTimeout);
      if (!mounted || requestId != _playRequestId) {
        return null;
      }
      final link = source == MusicSourceLogoStyle.youtube
          ? await _qualitySelector
                .selectPlayableUrl(resolvedLink, quality ?? _videoQuality)
                .timeout(_resolveTimeout, onTimeout: () => resolvedLink)
          : resolvedLink;
      _cacheLink(cacheKey, link);
      return link;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _playVideoSource(
    SongItem song,
    MusicSourceLogoStyle source,
    String link,
    int requestId,
  ) async {
    final controller = VideoPlayerController.networkUrl(
      Uri.parse(link),
      videoPlayerOptions: VideoPlayerOptions(
        mixWithOthers: false,
        // Suppresses video_player's own _VideoAppLifeCycleObserver, which
        // otherwise pauses the track the moment the app is backgrounded. This
        // flag is Dart-side only; it is never sent to the platform.
        allowBackgroundPlayback: true,
      ),
    );
    controller.addListener(_handleTick);
    try {
      await controller.initialize().timeout(_resolveTimeout);
      if (!mounted || requestId != _playRequestId) {
        controller.removeListener(_handleTick);
        await controller.dispose();
        return false;
      }
      await controller.setVolume(_userVolume);
      await controller.play();
      state = NowPlayingState(
        playback: PlaybackReady(song, link),
        activeSource: state.activeSource,
        mode: state.mode,
        videoController: controller,
      );
      return true;
    } catch (_) {
      // The link may have expired, point at an unsupported format, or (in a
      // test/desktop host with no platform video decoder) simply have no
      // implementation to run against — fall back to the idle backdrop
      // rather than leaving a broken player on screen.
      controller.removeListener(_handleTick);
      await controller.dispose();
      // Drop the (possibly expired) cached link so the next play re-resolves.
      _evictLink(source, song.id);
      return false;
    }
  }

  Future<bool> _playAudioSource(
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
        return false;
      }
      await audioPlayer.setVolume(_effectiveVolume);

      _listenToAudioPlayer(audioPlayer);
      // just_audio's play() future does not resolve when playback *starts* —
      // it resolves when playback stops/pauses/completes, staying pending for
      // the whole track. Awaiting (or timing out) it here blocked this whole
      // method until the track ended, which is what left the UI stuck on
      // "Đang tải video..." indefinitely for SoundCloud. Kick
      // playback off and move on; playingStream already keeps audioIsPlaying
      // in sync, and setUrl() above already validated the source resolves.
      unawaited(
        audioPlayer.play().catchError((_) {
          _handleAudioPlaybackFailure(song, source, requestId);
        }),
      );
      state = NowPlayingState(
        playback: PlaybackReady(song, link),
        activeSource: state.activeSource,
        mode: state.mode,
        audioPlayer: audioPlayer,
        audioIsPlaying: true,
      );
      if (_visualizerEnabled) {
        unawaited(_loadVisualizerAsync(source, requestId, audioPlayer));
      }
      return true;
    } catch (_) {
      await audioPlayer.dispose();
      _evictLink(source, song.id);
      return false;
    }
  }

  Future<void> _loadVisualizerAsync(
    MusicSourceLogoStyle source,
    int requestId,
    AudioTrackPlayer audioPlayer,
  ) async {
    if (!_visualizerEnabled) {
      return;
    }
    final visualizerController = await _createVisualizerController(
      source,
      requestId,
    );
    if (visualizerController == null) {
      return;
    }
    if (!mounted ||
        requestId != _playRequestId ||
        !_visualizerEnabled ||
        state.audioPlayer != audioPlayer) {
      await visualizerController.dispose();
      return;
    }
    if (state.audioIsPlaying) {
      try {
        await visualizerController.play();
      } catch (_) {
        await visualizerController.dispose();
        return;
      }
    }
    state = NowPlayingState(
      playback: state.playback,
      activeSource: state.activeSource,
      mode: state.mode,
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

  /// Explicit, idempotent pause used by [PlaybackInterruptionHandler]. Unlike
  /// [togglePlayPause], calling this when playback is already paused is a
  /// no-op — required so a stale `_pausedByInterruption` flag can never flip
  /// already-paused (or already-resumed) playback the wrong way.
  void pausePlayback() {
    final audioPlayer = state.audioPlayer;
    if (audioPlayer != null) {
      if (state.audioIsPlaying) {
        audioPlayer.pause();
        state.visualizerController?.pause();
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
    }
  }

  /// Explicit, idempotent resume counterpart to [pausePlayback]. See there for
  /// why toggling is unsafe for interruption handling.
  void resumePlayback() {
    final audioPlayer = state.audioPlayer;
    if (audioPlayer != null) {
      if (!state.audioIsPlaying) {
        audioPlayer.play();
        state.visualizerController?.play();
      }
      return;
    }

    final controller = state.videoController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    if (!controller.value.isPlaying) {
      controller.play();
      state.visualizerController?.play();
    }
  }

  /// Called by [PlaybackLifecycleObserver]. Only the visualizer stops; the
  /// primary player must keep running in the background.
  void pauseVisualizer() {
    unawaited(state.visualizerController?.pause());
  }

  void resumeVisualizer() {
    unawaited(state.visualizerController?.play());
  }

  Future<void> replayFromStart() {
    final playback = state.playback;
    final song = switch (playback) {
      PlaybackLoading(:final song) => song,
      PlaybackReady(:final song) => song,
      PlaybackFailed(:final song) => song,
      PlaybackIdle() => null,
    };
    if (song == null) {
      return Future.value();
    }
    return play(song, state.activeSource);
  }

  /// Tears playback down completely. Reached by dismissing the media
  /// notification, which on Android means the user wants playback gone, not
  /// merely paused.
  void stopPlayback() {
    _playRequestId++;
    final controller = state.videoController;
    controller?.removeListener(_handleTick);
    unawaited(controller?.dispose());
    unawaited(state.visualizerController?.dispose());
    _disposeAudioPlayer();
    state = NowPlayingState(activeSource: state.activeSource, mode: state.mode);
  }

  void setPlaybackVolume(double volume) {
    _userVolume = volume.clamp(0.0, 1.0);
    _applyVolume();
  }

  /// Only the audio path is ducked here. On the video path ExoPlayer holds
  /// audio focus itself (`mixWithOthers: false` sets `handleAudioFocus=true`)
  /// and already ducks on transient loss, so applying a second duck would
  /// lower the volume twice.
  void setDuckFactor(double factor) {
    final clamped = factor.clamp(0.0, 1.0);
    if (_duckFactor == clamped) {
      return;
    }
    _duckFactor = clamped;
    if (state.audioPlayer == null) {
      return;
    }
    _applyVolume();
  }

  void _applyVolume() {
    final videoController = state.videoController;
    if (videoController != null && videoController.value.isInitialized) {
      unawaited(videoController.setVolume(_userVolume));
    }
    final audioPlayer = state.audioPlayer;
    if (audioPlayer != null) {
      unawaited(audioPlayer.setVolume(_effectiveVolume));
    }
  }

  void setVisualizerEnabled(bool enabled) {
    if (!mounted) {
      return;
    }
    if (_visualizerEnabled == enabled) {
      return;
    }
    _visualizerEnabled = enabled;

    if (!enabled) {
      final visualizerController = state.visualizerController;
      unawaited(visualizerController?.dispose());
      if (visualizerController == null) {
        return;
      }
      state = NowPlayingState(
        playback: state.playback,
        activeSource: state.activeSource,
        mode: state.mode,
        videoController: state.videoController,
        audioPlayer: state.audioPlayer,
        audioPosition: state.audioPosition,
        audioDuration: state.audioDuration,
        audioIsPlaying: state.audioIsPlaying,
      );
      return;
    }

    final audioPlayer = state.audioPlayer;
    if (audioPlayer != null && state.visualizerController == null) {
      unawaited(
        _loadVisualizerAsync(state.activeSource, _playRequestId, audioPlayer),
      );
    }
  }

  void seekBackward() {
    final controller = state.videoController;
    if (controller != null && controller.value.isInitialized) {
      final target = controller.value.position - _rewindStep;
      controller.seekTo(target < Duration.zero ? Duration.zero : target);
      return;
    }

    final audioPlayer = state.audioPlayer;
    if (audioPlayer != null) {
      final target = state.audioPosition - _rewindStep;
      audioPlayer.seek(target < Duration.zero ? Duration.zero : target);
    }
  }

  void seekForward() {
    final controller = state.videoController;
    if (controller != null && controller.value.isInitialized) {
      final duration = controller.value.duration;
      final target = controller.value.position + _fastForwardStep;
      controller.seekTo(target > duration ? duration : target);
      return;
    }

    final audioPlayer = state.audioPlayer;
    if (audioPlayer != null) {
      final target = state.audioPosition + _fastForwardStep;
      audioPlayer.seek(
        target > state.audioDuration ? state.audioDuration : target,
      );
    }
  }

  /// Absolute seek, clamped to the track. Media-button and notification seeks
  /// are absolute, and both playback paths need the same clamping rule, so all
  /// other seek entry points funnel through here.
  void seekTo(Duration position) {
    final controller = state.videoController;
    if (controller != null && controller.value.isInitialized) {
      unawaited(controller.seekTo(_clamp(position, controller.value.duration)));
      return;
    }

    final audioPlayer = state.audioPlayer;
    if (audioPlayer != null) {
      unawaited(audioPlayer.seek(_clamp(position, state.audioDuration)));
    }
  }

  void seekToFraction(double fraction) {
    final normalized = fraction.clamp(0.0, 1.0);
    final controller = state.videoController;
    final duration = controller != null && controller.value.isInitialized
        ? controller.value.duration
        : state.audioDuration;
    seekTo(
      Duration(milliseconds: (duration.inMilliseconds * normalized).round()),
    );
  }

  Duration _clamp(Duration position, Duration duration) {
    if (position < Duration.zero) {
      return Duration.zero;
    }
    if (duration > Duration.zero && position > duration) {
      return duration;
    }
    return position;
  }

  /// Remembers where fullscreen was entered from, so leaving it restores that
  /// layout instead of always dropping back to [PlayerViewMode.normal].
  PlayerViewMode _modeBeforeFullscreen = PlayerViewMode.normal;

  /// From [PlayerViewMode.fullscreen] this lands in [PlayerViewMode.normal],
  /// not [PlayerViewMode.wide]. In fullscreen the button shows the
  /// "open the panel" icon, so landing in `wide` — where the side panel is
  /// still collapsed — would make the icon a lie. Going to `normal` matches
  /// what the icon promises and gives a second one-press route out of
  /// fullscreen into a layout that still has app chrome.
  void toggleWide() {
    // A press here is the user taking the layout back into their own hands, so
    // the phone must not undo it later.
    _wideFromRemote = false;
    _setMode(
      state.mode == PlayerViewMode.normal
          ? PlayerViewMode.wide
          : PlayerViewMode.normal,
    );
  }

  /// True while the side panel is collapsed because a phone joined, not
  /// because the user pressed the panel button.
  bool _wideFromRemote = false;

  /// Collapses the search column while a phone is driving, and restores it
  /// when the phone leaves.
  ///
  /// Once a phone is connected, typing happens on the phone keyboard — the
  /// on-screen search column is dead weight in front of the video. This only
  /// moves between [PlayerViewMode.normal] and [PlayerViewMode.wide]:
  /// fullscreen is left alone (it is already a more committed choice than
  /// anything the phone should override), and the restore only fires when the
  /// collapse came from here, so a user who pressed the panel button keeps the
  /// layout they chose.
  void setRemoteBrowsingActive(bool active) {
    if (active) {
      if (state.mode != PlayerViewMode.normal) {
        return;
      }
      _wideFromRemote = true;
      _setMode(PlayerViewMode.wide);
      return;
    }

    if (!_wideFromRemote) {
      return;
    }
    _wideFromRemote = false;
    if (state.mode == PlayerViewMode.wide) {
      _setMode(PlayerViewMode.normal);
    }
  }

  void enterFullscreen() {
    if (state.mode == PlayerViewMode.fullscreen) {
      return;
    }
    _modeBeforeFullscreen = state.mode;
    _setMode(PlayerViewMode.fullscreen);
  }

  void exitFullscreen() {
    if (state.mode != PlayerViewMode.fullscreen) {
      return;
    }
    _setMode(_modeBeforeFullscreen);
  }

  void _setMode(PlayerViewMode mode) {
    state = NowPlayingState(
      playback: state.playback,
      activeSource: state.activeSource,
      mode: mode,
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
    final controller = state.videoController;
    if (controller == null) {
      return;
    }
    final value = controller.value;
    final isCompleted = value.isCompleted;
    final positionSecond = value.position.inSeconds;
    final isPlaying = value.isPlaying;
    final shouldNotifyUi =
        isCompleted ||
        positionSecond != _lastVideoUiSecond ||
        isPlaying != _lastVideoUiIsPlaying;
    if (shouldNotifyUi) {
      _lastVideoUiSecond = positionSecond;
      _lastVideoUiIsPlaying = isPlaying;
      state = NowPlayingState(
        playback: state.playback,
        activeSource: state.activeSource,
        mode: state.mode,
        videoController: state.videoController,
        visualizerController: state.visualizerController,
        audioPlayer: state.audioPlayer,
        audioPosition: state.audioPosition,
        audioDuration: state.audioDuration,
        audioIsPlaying: state.audioIsPlaying,
      );
    }
    final onCompleted = _onCompleted;
    if (isCompleted && !_completionHandled && onCompleted != null) {
      _completionHandled = true;
      unawaited(Future<void>.sync(() => onCompleted(fromCompletion: true)));
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
            unawaited(
              Future<void>.sync(() => onCompleted(fromCompletion: true)),
            );
          }
        }),
      );
  }

  void _updateAudioState({
    Duration? audioPosition,
    Duration? audioDuration,
    bool? audioIsPlaying,
  }) {
    if (audioPosition != null &&
        audioDuration == null &&
        audioIsPlaying == null &&
        audioPosition.inSeconds == _lastAudioUiSecond) {
      return;
    }
    if (audioPosition != null) {
      _lastAudioUiSecond = audioPosition.inSeconds;
    }
    state = NowPlayingState(
      playback: state.playback,
      activeSource: state.activeSource,
      mode: state.mode,
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
    if (!_visualizerEnabled || source == MusicSourceLogoStyle.youtube) {
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

  VideoQuality _qualityForAttempt(int attempt) {
    if (attempt == 1 || _videoQuality == VideoQuality.sd) {
      return _videoQuality;
    }
    // An ARM32 box that cannot initialize the selected HD stream retries once
    // at SD. This only runs after a decoder/setup failure; a healthy 720p
    // session never has its quality reduced.
    return VideoQuality.sd;
  }

  void _handleAudioPlaybackFailure(
    SongItem song,
    MusicSourceLogoStyle source,
    int requestId,
  ) {
    if (!mounted || requestId != _playRequestId) {
      return;
    }
    _evictLink(source, song.id);
    final visualizerController = state.visualizerController;
    unawaited(visualizerController?.dispose());
    _disposeAudioPlayer();
    state = NowPlayingState(
      playback: PlaybackFailed(song),
      activeSource: state.activeSource,
      mode: state.mode,
    );
  }

  String _linkCacheKey(
    MusicSourceLogoStyle source,
    String trackId, {
    VideoQuality? quality,
  }) {
    final qualityKey = source == MusicSourceLogoStyle.youtube
        ? '|${(quality ?? _videoQuality).name}'
        : '';
    return '${source.name}|$trackId$qualityKey';
  }

  String? _cachedLink(String key) {
    final cached = _linkCache[key];
    if (cached == null) {
      return null;
    }
    if (DateTime.now().difference(cached.resolvedAt) > _linkCacheTtl) {
      _linkCache.remove(key);
      return null;
    }
    // Keep a hot repeat/previous entry from being evicted before an older one.
    _linkCache
      ..remove(key)
      ..[key] = cached;
    return cached.link;
  }

  void _cacheLink(String key, String link) {
    final now = DateTime.now();
    // Sweep expired entries on write so the map stays at the handful of tracks
    // resolved within the TTL window (you can't play many songs in 90s).
    _linkCache.removeWhere(
      (_, cached) => now.difference(cached.resolvedAt) > _linkCacheTtl,
    );
    while (_linkCache.length >= 50) {
      _linkCache.remove(_linkCache.keys.first);
    }
    _linkCache[key] = _CachedLink(link, now);
  }

  void _evictLink(MusicSourceLogoStyle source, String trackId) {
    if (source == MusicSourceLogoStyle.youtube) {
      _linkCache.removeWhere(
        (key, _) => key.startsWith('${source.name}|$trackId|'),
      );
      return;
    }
    _linkCache.remove(_linkCacheKey(source, trackId));
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

class _CachedLink {
  const _CachedLink(this.link, this.resolvedAt);

  final String link;
  final DateTime resolvedAt;
}
