import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/features/app_update/data/models/app_release.dart';

void main() {
  test('parses_a_full_rpc_payload', () {
    final release = AppRelease.tryParse(<String, Object?>{
      'version_code': 7,
      'version_name': '1.2.0',
      'apk_url': 'https://example.invalid/wetube-1.2.0.apk',
      'sha256': 'abc123',
      'notes': 'Sửa lỗi phát nhạc nền',
    });

    expect(release, isNotNull);
    expect(release!.versionCode, 7);
    expect(release.versionName, '1.2.0');
    expect(release.apkUrl, 'https://example.invalid/wetube-1.2.0.apk');
    expect(release.sha256, 'abc123');
    expect(release.notes, 'Sửa lỗi phát nhạc nền');
  });

  test('null_payload_means_no_release_not_an_error', () {
    expect(AppRelease.tryParse(null), isNull);
  });

  test('null_notes_is_allowed', () {
    final release = AppRelease.tryParse(<String, Object?>{
      'version_code': 7,
      'version_name': '1.2.0',
      'apk_url': 'https://example.invalid/a.apk',
      'sha256': 'abc123',
      'notes': null,
    });

    expect(release, isNotNull);
    expect(release!.notes, isNull);
  });

  test('a_payload_missing_a_required_field_is_rejected_not_half_built', () {
    // A half-built release would send the downloader at an empty URL.
    expect(
      AppRelease.tryParse(<String, Object?>{
        'version_code': 7,
        'version_name': '1.2.0',
        'sha256': 'abc123',
      }),
      isNull,
    );
  });
}
