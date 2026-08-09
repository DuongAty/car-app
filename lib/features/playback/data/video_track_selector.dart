import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

final videoTrackSelectorProvider = Provider<VideoTrackSelector>(
  (ref) => PlatformVideoTrackSelector(),
);

/// Narrow port over video quality selection.
///
/// `VideoPlayerController` does not wrap `getVideoTracks`/`selectVideoTrack`
/// even though the platform interface declares them and Android implements
/// them, so this reaches `VideoPlayerPlatform.instance` directly using the
/// controller's public `playerId`. Keeping that in one file means a future
/// plugin version that exposes these properly is a one-file change.
abstract interface class VideoTrackSelector {
  /// Returns true only when a genuinely smaller track was selected.
  Future<bool> downscaleToSmallest(int playerId);

  /// Restores adaptive (automatic) quality selection.
  Future<void> restoreAdaptive(int playerId);
}

typedef VideoTracksReader = Future<List<VideoTrack>> Function(int playerId);
typedef VideoTrackWriter =
    Future<void> Function(int playerId, VideoTrack? track);

class PlatformVideoTrackSelector implements VideoTrackSelector {
  PlatformVideoTrackSelector({
    bool Function()? isSupported,
    VideoTracksReader? readTracks,
    VideoTrackWriter? writeTrack,
  }) : _isSupportedOverride = isSupported,
       _readTracksOverride = readTracks,
       _writeTrackOverride = writeTrack;

  final bool Function()? _isSupportedOverride;
  final VideoTracksReader? _readTracksOverride;
  final VideoTrackWriter? _writeTrackOverride;

  // Resolved per call, never captured as a tear-off in the constructor:
  // `VideoPlayerPlatform.instance` is swapped by tests (see
  // `test/support/fake_video_player_platform.dart`), and a tear-off bound at
  // construction time would keep pointing at whichever instance was current
  // when this provider was first read.
  bool _isSupported() =>
      _isSupportedOverride?.call() ??
      VideoPlayerPlatform.instance.isVideoTrackSupportAvailable();

  Future<List<VideoTrack>> _readTracks(int playerId) =>
      _readTracksOverride?.call(playerId) ??
      VideoPlayerPlatform.instance.getVideoTracks(playerId);

  Future<void> _writeTrack(int playerId, VideoTrack? track) =>
      _writeTrackOverride?.call(playerId, track) ??
      VideoPlayerPlatform.instance.selectVideoTrack(playerId, track);

  @override
  Future<bool> downscaleToSmallest(int playerId) async {
    if (!_isSupported()) {
      return false;
    }
    try {
      final tracks = await _readTracks(playerId);
      // Fewer than two tracks means there is nothing smaller to move to. This
      // is the normal case when the user pinned a quality, because the URL was
      // already narrowed to a single rendition before playback started.
      if (tracks.length < 2) {
        return false;
      }
      final measured = tracks.where((track) => track.height != null).toList();
      if (measured.isEmpty) {
        return false;
      }
      final smallest = measured.reduce(
        (a, b) => a.height! <= b.height! ? a : b,
      );
      await _writeTrack(playerId, smallest);
      return true;
    } catch (_) {
      // Track selection is an optimisation. It must never break playback.
      return false;
    }
  }

  @override
  Future<void> restoreAdaptive(int playerId) async {
    if (!_isSupported()) {
      return;
    }
    try {
      await _writeTrack(playerId, null);
    } catch (_) {
      // Same reasoning as above.
    }
  }
}
