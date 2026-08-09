/// Reads and writes small string blobs to on-device storage.
///
/// Controllers depend on this interface rather than the `shared_preferences`
/// plugin directly, so they stay testable against an in-memory fake — same
/// split as [VolumeService]/[DeviceVolumeService].
abstract interface class LocalStorageService {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
}
