import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:viet_ktv/features/playback/data/video_track_selector.dart';

VideoTrack _track(String id, int? height) =>
    VideoTrack(id: id, isSelected: false, height: height);

PlatformVideoTrackSelector _selector({
  required List<VideoTrack> tracks,
  bool supported = true,
  List<VideoTrack?>? written,
  Object? readThrows,
}) {
  return PlatformVideoTrackSelector(
    isSupported: () => supported,
    readTracks: (_) async {
      if (readThrows != null) {
        throw readThrows;
      }
      return tracks;
    },
    writeTrack: (_, track) async => written?.add(track),
  );
}

void main() {
  test('selects_the_smallest_track_when_several_are_available', () async {
    final written = <VideoTrack?>[];
    final selector = _selector(
      tracks: [_track('0_0', 720), _track('0_1', 144), _track('0_2', 480)],
      written: written,
    );

    final didDownscale = await selector.downscaleToSmallest(7);

    expect(didDownscale, isTrue);
    expect(written.single?.id, '0_1');
  });

  test('ignores_tracks_with_unknown_height', () async {
    // VideoTrack.height is nullable; a null must never be treated as smallest.
    final written = <VideoTrack?>[];
    final selector = _selector(
      tracks: [_track('0_0', null), _track('0_1', 360)],
      written: written,
    );

    final didDownscale = await selector.downscaleToSmallest(7);

    expect(didDownscale, isTrue);
    expect(written.single?.id, '0_1');
  });

  test('does_nothing_when_only_one_track_is_available', () async {
    // A pinned VideoQuality narrows the URL to a single rendition, so there is
    // nothing smaller to pick and switching would be pointless churn.
    final written = <VideoTrack?>[];
    final selector = _selector(tracks: [_track('0_0', 720)], written: written);

    expect(await selector.downscaleToSmallest(7), isFalse);
    expect(written, isEmpty);
  });

  test('does_nothing_when_no_track_has_a_known_height', () async {
    final written = <VideoTrack?>[];
    final selector = _selector(
      tracks: [_track('0_0', null), _track('0_1', null)],
      written: written,
    );

    expect(await selector.downscaleToSmallest(7), isFalse);
    expect(written, isEmpty);
  });

  test('does_nothing_when_the_platform_lacks_track_support', () async {
    final written = <VideoTrack?>[];
    final selector = _selector(
      tracks: [_track('0_0', 720), _track('0_1', 144)],
      supported: false,
      written: written,
    );

    expect(await selector.downscaleToSmallest(7), isFalse);
    expect(written, isEmpty);
  });

  test('reports_no_downscale_when_the_platform_throws', () async {
    final selector = _selector(
      tracks: const [],
      readThrows: StateError('boom'),
    );

    expect(await selector.downscaleToSmallest(7), isFalse);
  });

  test('restore_passes_null_to_re_enable_adaptive_selection', () async {
    final written = <VideoTrack?>[];
    final selector = _selector(tracks: const [], written: written);

    await selector.restoreAdaptive(7);

    expect(written, [isNull]);
  });

  test('restore_is_silent_when_the_platform_lacks_track_support', () async {
    final written = <VideoTrack?>[];
    final selector = _selector(
      tracks: const [],
      supported: false,
      written: written,
    );

    await selector.restoreAdaptive(7);

    expect(written, isEmpty);
  });
}
