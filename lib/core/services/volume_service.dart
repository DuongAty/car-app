/// Access to the device's media volume.
///
/// The UI talks to this interface rather than the platform plugin directly, so
/// screens stay testable on hosts that have no audio service at all.
abstract interface class VolumeService {
  /// Current media volume from 0.0 to 1.0, or `null` when the platform exposes
  /// no volume control (desktop hosts, widget tests).
  Future<double?> read();

  /// Sets the device media volume. Values outside 0.0–1.0 are clamped.
  Future<void> write(double level);

  /// Volume changes made outside the app, e.g. the hardware volume keys.
  Stream<double> get changes;

  Future<void> dispose();
}
