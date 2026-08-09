/// Which action a double tap on the video picture triggers, chosen by where
/// along the picture's width the tap landed.
enum DoubleTapZone { seekBackward, toggleFullscreen, seekForward }

/// Fraction of the picture's width given to each outer (seek) zone.
///
/// 30/40/30 rather than a YouTube-style 40/20/40: the centre has to be hit
/// reliably on a head unit in a moving car, and a mis-hit there does not merely
/// do nothing — it jumps the song 10 seconds.
const double _seekZoneFraction = 0.3;

/// Classifies a double tap. [dx] is the horizontal offset within the picture.
///
/// The boundaries themselves belong to the centre zone, so an edge mis-hit
/// toggles fullscreen rather than seeking.
DoubleTapZone doubleTapZoneFor(double dx, double width) {
  if (width <= 0) {
    return DoubleTapZone.toggleFullscreen;
  }
  final fraction = dx / width;
  if (fraction < _seekZoneFraction) {
    return DoubleTapZone.seekBackward;
  }
  if (fraction > 1 - _seekZoneFraction) {
    return DoubleTapZone.seekForward;
  }
  return DoubleTapZone.toggleFullscreen;
}
