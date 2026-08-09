/// One published APK build, as returned by the Supabase RPC `latest_release()`
/// (see `backend/supabase/schema.sql`).
class AppRelease {
  const AppRelease({
    required this.versionCode,
    required this.versionName,
    required this.apkUrl,
    required this.sha256,
    required this.notes,
  });

  /// Compared against the installed build. This — never [versionName] — is
  /// what decides whether an update exists.
  final int versionCode;

  /// Display string, e.g. `1.2.0`.
  final String versionName;

  final String apkUrl;

  /// Lowercase hex digest of the published file, verified after download.
  final String sha256;

  /// Free text written by the publisher, shown verbatim. Deliberately not
  /// localized: it is authored once per release, in whatever language the
  /// publisher chose.
  final String? notes;

  /// Returns null when there is no release (`raw` is null) and when the
  /// payload is missing a required field. A partially built release would
  /// hand the downloader an empty URL, so a malformed row reads the same as
  /// no row at all.
  static AppRelease? tryParse(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final versionCode = raw['version_code'];
    final versionName = raw['version_name'];
    final apkUrl = raw['apk_url'];
    final sha256 = raw['sha256'];
    if (versionCode is! int ||
        versionName is! String ||
        apkUrl is! String ||
        sha256 is! String) {
      return null;
    }
    return AppRelease(
      versionCode: versionCode,
      versionName: versionName,
      apkUrl: apkUrl,
      sha256: sha256,
      notes: raw['notes'] as String?,
    );
  }
}
