import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/double_tap_zone.dart';

void main() {
  test('left_third_seeks_backward', () {
    expect(doubleTapZoneFor(20, 100), DoubleTapZone.seekBackward);
  });

  test('middle_toggles_fullscreen', () {
    expect(doubleTapZoneFor(50, 100), DoubleTapZone.toggleFullscreen);
  });

  test('right_third_seeks_forward', () {
    expect(doubleTapZoneFor(80, 100), DoubleTapZone.seekForward);
  });

  test('boundaries_belong_to_the_middle_zone', () {
    // Exactly 30% and 70% are centre, so a mis-hit near the edge does nothing
    // rather than jumping the song 10 seconds.
    expect(doubleTapZoneFor(30, 100), DoubleTapZone.toggleFullscreen);
    expect(doubleTapZoneFor(70, 100), DoubleTapZone.toggleFullscreen);
  });

  test('just_outside_the_boundaries_seeks', () {
    expect(doubleTapZoneFor(29.9, 100), DoubleTapZone.seekBackward);
    expect(doubleTapZoneFor(70.1, 100), DoubleTapZone.seekForward);
  });

  test('scales_with_width_rather_than_using_fixed_pixels', () {
    expect(doubleTapZoneFor(400, 1920), DoubleTapZone.seekBackward);
    expect(doubleTapZoneFor(960, 1920), DoubleTapZone.toggleFullscreen);
    expect(doubleTapZoneFor(1500, 1920), DoubleTapZone.seekForward);
  });

  test('degenerate_width_falls_back_to_the_middle_zone', () {
    // A zero or negative width would make the fraction undefined; the safe
    // fallback is the non-destructive action.
    expect(doubleTapZoneFor(0, 0), DoubleTapZone.toggleFullscreen);
    expect(doubleTapZoneFor(10, -5), DoubleTapZone.toggleFullscreen);
  });
}
