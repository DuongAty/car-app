# In-App APK Update Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A user presses one button in Settings → Hệ thống and learns whether a newer build exists; a second press downloads, verifies, and installs it.

**Architecture:** Update metadata lives in the existing Supabase project as a new `app_releases` table plus a new public RPC `latest_release()` — `check_license` is not touched, because customer devices already run against it. The APK itself lives on GitHub Releases of the public `DuongAty/car-app` repo. A new `lib/features/app_update/` feature holds the model, repository, downloader, and controller; the install step reaches Android's `PackageInstaller` through the `viet_ktv/system` MethodChannel that already serves `restartApp`/`shutdownDevice`.

**Tech Stack:** Flutter, Riverpod (`StateNotifier`), `supabase_flutter` (already a dependency), `dart:io HttpClient` (no HTTP package needed), `crypto` (new — pure Dart, needed so SHA-256 verification is testable in `flutter test`), Kotlin `PackageInstaller`.

**Spec:** `docs/superpowers/specs/2026-08-09-apk-update-design.md`

## Global Constraints

- **The user runs all git commands.** Implementers must run NO git write command — no `add`, `commit`, `push`, `stash`, `checkout`, `restore`, `clean`. Read-only git is fine. The template's "commit" steps are therefore replaced by "run the suite" steps throughout.
- **Never run `dart format .`** — format only the files you touched, naming each explicitly.
- **Never build an APK, install to a device, or run adb.** The user builds and tests on hardware.
- `flutter analyze` must print "No issues found!" at the end of every task.
- The full suite must stay green. Baseline at the time of writing: **279 tests**.
- **Tokens first** — `AppColors.*`, `AppSpacing.*`, `AppRadius.*`, `AppLayout.*`, `AppIcons.*`. No hardcoded colours, spacing, radius, or text styles in feature screens.
- **All user-facing copy localized** — every new string needs a key in BOTH `lib/l10n/app_vi.arb` and `lib/l10n/app_en.arb`, with correct Vietnamese accents. Regenerate with `flutter gen-l10n`; never hand-edit `lib/l10n/app_localizations*.dart`.
- No `BackdropFilter`, no blur, no continuous animation — the target is a 2GB-RAM box.
- Landscape is the primary layout; D-pad/remote focus must stay obvious.
- `minSdk = 28`. Any API newer than that needs a guarded branch.
- **Compare versions by `versionCode` (int), never by `versionName` (String).** A remote code lower than or equal to the installed one means "up to date"; the app never downgrades.
- **`check_license` and `LicenseRpcResult` must not change.** Live customer devices depend on the exact current text codes.

## File Structure

| File | Responsibility |
| --- | --- |
| `../backend/supabase/migrations/20260809_add_app_releases.sql` (create) | Table, RPC, grants |
| `../backend/supabase/schema.sql` (modify) | Keep the canonical schema in sync |
| `lib/features/app_update/data/models/app_release.dart` (create) | Immutable release record + JSON parse |
| `lib/features/app_update/data/app_update_repository.dart` (create) | Interface + Supabase implementation |
| `lib/features/app_update/data/apk_downloader.dart` (create) | Streams the APK to disk, reports progress, returns its SHA-256 |
| `lib/features/app_update/presentation/providers/app_update_state.dart` (create) | Immutable state + `copyWith` |
| `lib/features/app_update/presentation/providers/app_update_controller.dart` (create) | `StateNotifier` state machine + providers |
| `lib/features/app_update/presentation/widgets/update_section.dart` (create) | The Settings row |
| `lib/core/services/app_system_service.dart` (modify) | `appVersionCode`, cache dir, install-permission and install methods |
| `android/app/src/main/kotlin/com/example/viet_ktv/MainActivity.kt` (modify) | Four new branches on the system channel |
| `android/app/src/main/AndroidManifest.xml` (modify) | `REQUEST_INSTALL_PACKAGES` |
| `pubspec.yaml` (modify) | `crypto` dependency |
| `test/support/fake_app_update_repository.dart` (create) | Fake backend |
| `test/support/fake_apk_downloader.dart` (create) | Fake downloader, records whether install was reached |

---

### Task 1: Backend — `app_releases` table and `latest_release()` RPC

**Files:**
- Create: `../backend/supabase/migrations/20260809_add_app_releases.sql`
- Modify: `../backend/supabase/schema.sql` (append after the existing grants block, currently ending at line 334)

**Interfaces:**
- Consumes: nothing.
- Produces: RPC `public.latest_release()` returning `json` — either `null`, or an object with keys `version_code` (int), `version_name` (text), `apk_url` (text), `sha256` (text), `notes` (text or null).

**Note on `backend/`:** that directory is not under version control. Write the files anyway; flag in your report that they are unversioned.

- [ ] **Step 1: Write the migration**

Create `../backend/supabase/migrations/20260809_add_app_releases.sql`:

```sql
-- Bản phát hành APK cho cập nhật trong app.
-- KHÔNG đụng tới check_license: máy khách đang chạy dựa vào chuỗi trả về
-- hiện tại, đổi là chúng kẹt ở cổng bản quyền.

create table if not exists public.app_releases (
  id            uuid primary key default gen_random_uuid(),
  version_code  int  not null unique,
  version_name  text not null,
  apk_url       text not null,
  sha256        text not null,
  notes         text,
  is_active     boolean not null default true,
  published_at  timestamptz not null default now()
);

comment on table public.app_releases is
  'Bản phát hành APK. App gọi latest_release() để lấy bản is_active có version_code cao nhất. Ngừng phát một bản: đặt is_active = false, không xoá dòng.';

alter table public.app_releases enable row level security;

-- anon (car app) KHÔNG đọc thẳng bảng; chỉ gọi RPC bên dưới.
-- Cùng khuôn với policy admin_full_access của bảng licenses.
create policy "admin_full_access_releases" on public.app_releases
  for all to authenticated using (true) with check (true);

create or replace function public.latest_release() returns json
language sql
stable
security definer
set search_path = public
as $$
  select json_build_object(
           'version_code', r.version_code,
           'version_name', r.version_name,
           'apk_url',      r.apk_url,
           'sha256',       r.sha256,
           'notes',        r.notes
         )
  from public.app_releases r
  where r.is_active
  order by r.version_code desc
  limit 1;
$$;

revoke all on function public.latest_release() from public;
grant execute on function public.latest_release() to anon, authenticated;
```

- [ ] **Step 2: Mirror the same block into `schema.sql`**

Append the identical `create table` / `enable row level security` / `create policy` / `create or replace function` / `revoke` / `grant` statements to `../backend/supabase/schema.sql`, after the existing grants block. `schema.sql` is the canonical full-schema file; the migration is the incremental one. Both must describe the same end state.

- [ ] **Step 3: Verify in the Supabase SQL Editor**

This is SQL against a hosted database, so there is no local test runner. Ask the user to run the migration in the Supabase SQL Editor, then these three checks:

```sql
-- 3a. Empty table → RPC returns null (this is "up to date", not an error)
select public.latest_release();
-- Expected: one row, one column, value NULL

-- 3b. Insert two releases; the higher active version_code wins
insert into public.app_releases (version_code, version_name, apk_url, sha256, notes)
values (2, '1.0.1', 'https://example.invalid/a.apk', 'aa', 'ghi chú'),
       (3, '1.0.2', 'https://example.invalid/b.apk', 'bb', null);
select public.latest_release();
-- Expected: {"version_code":3,"version_name":"1.0.2","apk_url":"https://example.invalid/b.apk","sha256":"bb","notes":null}

-- 3c. is_active = false takes a release out of circulation
update public.app_releases set is_active = false where version_code = 3;
select public.latest_release();
-- Expected: {"version_code":2,...,"notes":"ghi chú"}

-- 3d. Clean up the test rows
delete from public.app_releases where version_code in (2, 3);
```

- [ ] **Step 4: Report**

No Dart changed, so no `flutter test` / `flutter analyze` run is needed for this task. Report the three SQL results verbatim.

---

### Task 2: `AppRelease` model and repository

**Files:**
- Create: `lib/features/app_update/data/models/app_release.dart`
- Create: `lib/features/app_update/data/app_update_repository.dart`
- Create: `test/support/fake_app_update_repository.dart`
- Test: `test/features/app_update/app_release_test.dart`

**Interfaces:**
- Consumes: RPC `latest_release()` from Task 1.
- Produces:
  - `class AppRelease` with `final int versionCode; final String versionName; final String apkUrl; final String sha256; final String? notes;` and `static AppRelease? tryParse(Object? raw)`
  - `abstract interface class AppUpdateRepository { Future<AppRelease?> latestRelease(); }`
  - `class SupabaseAppUpdateRepository implements AppUpdateRepository`
  - `class FakeAppUpdateRepository implements AppUpdateRepository` with mutable `AppRelease? release;`, `Object? error;`, `int callCount = 0;`

- [ ] **Step 1: Write the failing test**

Create `test/features/app_update/app_release_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/features/app_update/data/models/app_release.dart';

void main() {
  test('parses_a_full_rpc_payload', () {
    final release = AppRelease.tryParse(<String, Object?>{
      'version_code': 7,
      'version_name': '1.2.0',
      'apk_url': 'https://example.invalid/youcar-1.2.0.apk',
      'sha256': 'abc123',
      'notes': 'Sửa lỗi phát nhạc nền',
    });

    expect(release, isNotNull);
    expect(release!.versionCode, 7);
    expect(release.versionName, '1.2.0');
    expect(release.apkUrl, 'https://example.invalid/youcar-1.2.0.apk');
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
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/features/app_update/app_release_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../app_release.dart'`.

- [ ] **Step 3: Write the model**

Create `lib/features/app_update/data/models/app_release.dart`:

```dart
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
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/features/app_update/app_release_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Write the repository**

Create `lib/features/app_update/data/app_update_repository.dart`, shaped like `lib/features/license/data/license_repository.dart`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_bootstrap.dart';
import 'models/app_release.dart';

abstract interface class AppUpdateRepository {
  /// The newest active release, or null when nothing has been published.
  /// Throws if the backend cannot be reached — the controller turns that into
  /// a retryable error, which is different from "no release".
  Future<AppRelease?> latestRelease();
}

class SupabaseAppUpdateRepository implements AppUpdateRepository {
  const SupabaseAppUpdateRepository();

  @override
  Future<AppRelease?> latestRelease() async {
    await ensureSupabaseInitialized();
    final raw = await Supabase.instance.client.rpc('latest_release');
    return AppRelease.tryParse(raw);
  }
}
```

- [ ] **Step 6: Write the fake**

Create `test/support/fake_app_update_repository.dart`, shaped like `test/support/fake_license_repository.dart`:

```dart
import 'package:viet_ktv/features/app_update/data/app_update_repository.dart';
import 'package:viet_ktv/features/app_update/data/models/app_release.dart';

/// Fake update backend. [release] is returned as-is; setting [error] makes
/// the call throw instead, so tests can drive both the "no release" and the
/// "server unreachable" paths without a network.
class FakeAppUpdateRepository implements AppUpdateRepository {
  FakeAppUpdateRepository({this.release, this.error});

  AppRelease? release;
  Object? error;
  int callCount = 0;

  @override
  Future<AppRelease?> latestRelease() async {
    callCount++;
    final thrown = error;
    if (thrown != null) {
      throw thrown;
    }
    return release;
  }
}
```

- [ ] **Step 7: Verify**

Run: `flutter test` → expected 283 passing (279 baseline + 4 new).
Run: `flutter analyze` → expected "No issues found!".
Run: `dart format lib/features/app_update/data/models/app_release.dart lib/features/app_update/data/app_update_repository.dart test/support/fake_app_update_repository.dart test/features/app_update/app_release_test.dart`

---

### Task 3: Native install support on the `viet_ktv/system` channel

**Files:**
- Modify: `android/app/src/main/AndroidManifest.xml` (add one `uses-permission` beside the existing ones at lines 3–13)
- Modify: `android/app/src/main/kotlin/com/example/viet_ktv/MainActivity.kt` (`onSystemMethodCall` at line 41, `systemInfo()` at line 231)
- Modify: `lib/core/services/app_system_service.dart`
- Test: `test/core/services/app_system_service_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces, on `AppSystemService`:
  - `AppSystemInfo` gains `final int appVersionCode;` (existing `appVersion` string stays untouched)
  - `Future<String> getUpdateCacheDir()`
  - `Future<bool> canInstallPackages()`
  - `Future<void> openInstallPermissionSettings()`
  - `Future<void> installApk(String path)`

**Why the cache directory comes from Kotlin rather than `path_provider`:** Kotlin has to open that same file to feed the `PackageInstaller` session. Having one side own the directory choice means the two can never disagree about where the APK landed, and it avoids adding a plugin for a single path lookup.

- [ ] **Step 1: Write the failing test**

Create `test/core/services/app_system_service_test.dart`:

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/services/app_system_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('viet_ktv/system');
  final calls = <MethodCall>[];

  void handle(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return handler(call);
    });
  }

  setUp(calls.clear);

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('system_info_exposes_the_numeric_version_code', () async {
    handle((_) async => <Object?, Object?>{
          'networkStatus': 'WiFi',
          'deviceName': 'Test Box',
          'androidVersion': 'Android 13 (API 33)',
          'appVersion': '1.2.0',
          'appVersionCode': 7,
          'storageSummary': '1.0GB / 8.0GB',
        });

    final info = await const AppSystemService().getSystemInfo();

    expect(info.appVersionCode, 7);
    expect(info.appVersion, '1.2.0');
  });

  test('missing_version_code_falls_back_to_zero_so_any_release_is_newer',
      () async {
    handle((_) async => <Object?, Object?>{'appVersion': '1.2.0'});

    final info = await const AppSystemService().getSystemInfo();

    expect(info.appVersionCode, 0);
  });

  test('install_apk_passes_the_path_to_the_platform', () async {
    handle((_) async => null);

    await const AppSystemService().installApk('/data/cache/update.apk');

    expect(calls.single.method, 'installApk');
    expect(calls.single.arguments, <String, Object?>{
      'path': '/data/cache/update.apk',
    });
  });

  test('can_install_packages_reports_false_when_the_platform_errors',
      () async {
    handle((_) async => throw PlatformException(code: 'boom'));

    expect(await const AppSystemService().canInstallPackages(), isFalse);
  });
}
```

- [ ] **Step 2: Run it and watch it fail**

Run: `flutter test test/core/services/app_system_service_test.dart`
Expected: FAIL — `The getter 'appVersionCode' isn't defined for the type 'AppSystemInfo'`, and `The method 'installApk' isn't defined`.

- [ ] **Step 3: Extend `AppSystemService`**

In `lib/core/services/app_system_service.dart`, add the field to `AppSystemInfo` (constructor, `fromMap`, and the field list):

```dart
  factory AppSystemInfo.fromMap(Map<Object?, Object?> map) {
    return AppSystemInfo(
      networkStatus: map['networkStatus'] as String? ?? 'Unknown',
      deviceName: map['deviceName'] as String? ?? 'Android',
      androidVersion: map['androidVersion'] as String? ?? 'Android',
      appVersion: map['appVersion'] as String? ?? '1.0.0',
      // 0, not 1: an unknown installed version must read as older than any
      // published release, so the user is never silently told they are current.
      appVersionCode: map['appVersionCode'] as int? ?? 0,
      storageSummary: map['storageSummary'] as String? ?? '--',
    );
  }
```

with `required this.appVersionCode,` in the constructor and `final int appVersionCode;` beside `final String appVersion;`.

Then add the four methods to `AppSystemService`:

```dart
  /// Directory the APK is downloaded into. Owned by the platform side, which
  /// has to reopen the same file to install it.
  Future<String> getUpdateCacheDir() async {
    final path = await _channel.invokeMethod<String>('getUpdateCacheDir');
    return path ?? '';
  }

  /// Android 8+ requires a per-app grant before this app may install another.
  /// A platform failure reads as "not allowed" so the caller routes the user
  /// to the settings screen rather than attempting an install that will fail.
  Future<bool> canInstallPackages() async {
    try {
      final allowed = await _channel.invokeMethod<bool>('canInstallPackages');
      return allowed ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openInstallPermissionSettings() =>
      _channel.invokeMethod<void>('openInstallPermissionSettings');

  Future<void> installApk(String path) =>
      _channel.invokeMethod<void>('installApk', <String, Object?>{'path': path});
```

- [ ] **Step 4: Run it and watch it pass**

Run: `flutter test test/core/services/app_system_service_test.dart`
Expected: PASS, 4 tests.

- [ ] **Step 5: Add the permission**

In `android/app/src/main/AndroidManifest.xml`, beside the existing `uses-permission` lines:

```xml
    <!-- Cần để app tự cài bản cập nhật tải từ GitHub Releases. Android 8+
         còn đòi người dùng cấp riêng quyền "cài ứng dụng không rõ nguồn gốc";
         canInstallPackages()/openInstallPermissionSettings() lo phần đó. -->
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES" />
```

- [ ] **Step 6: Implement the Kotlin side**

In `MainActivity.kt`, add these imports beside the existing ones:

```kotlin
import android.app.PendingIntent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.provider.Settings
import java.io.File
```

Add `"appVersionCode"` to the map returned by `systemInfo()` (line 231):

```kotlin
            "appVersion" to appVersion(),
            "appVersionCode" to appVersionCode(),
```

Add four branches to `onSystemMethodCall` (line 41):

```kotlin
            "getUpdateCacheDir" -> result.success(updateCacheDir().absolutePath)
            "canInstallPackages" -> result.success(packageManager.canRequestPackageInstalls())
            "openInstallPermissionSettings" -> openInstallPermissionSettings(result)
            "installApk" -> installApk(call, result)
```

`canRequestPackageInstalls()` needs API 26 and `minSdk` is 28, so no version guard is required.

Add the implementations:

```kotlin
    private fun appVersionCode(): Long {
        return try {
            val info = packageManager.getPackageInfo(packageName, 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                info.versionCode.toLong()
            }
        } catch (_: Throwable) {
            0L
        }
    }

    /** Private cache dir, so no storage permission is involved and Android
     *  reclaims the space on its own. */
    private fun updateCacheDir(): File {
        val dir = File(cacheDir, "updates")
        dir.mkdirs()
        return dir
    }

    private fun openInstallPermissionSettings(result: MethodChannel.Result) {
        try {
            val intent = Intent(
                Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                Uri.parse("package:$packageName"),
            )
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            result.success(true)
        } catch (error: Throwable) {
            result.error(
                "install_settings_unavailable",
                error.message ?: "Cannot open the unknown-sources screen.",
                null,
            )
        }
    }

    private fun installApk(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path.isNullOrEmpty()) {
            result.error("install_invalid_path", "A file path is required.", null)
            return
        }
        val apk = File(path)
        if (!apk.exists()) {
            result.error("install_file_missing", "No file at $path.", null)
            return
        }
        try {
            val installer = packageManager.packageInstaller
            val params = PackageInstaller.SessionParams(
                PackageInstaller.SessionParams.MODE_FULL_INSTALL,
            )
            val sessionId = installer.createSession(params)
            installer.openSession(sessionId).use { session ->
                session.openWrite("youcar", 0, apk.length()).use { out ->
                    apk.inputStream().use { input -> input.copyTo(out) }
                    session.fsync(out)
                }
                val intent = Intent(this, MainActivity::class.java)
                val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                    PendingIntent.FLAG_MUTABLE
                val pending = PendingIntent.getActivity(this, sessionId, intent, flags)
                session.commit(pending.intentSender)
            }
            result.success(true)
        } catch (error: Throwable) {
            result.error(
                "install_failed",
                error.message ?: "PackageInstaller rejected the session.",
                null,
            )
        }
    }
```

`FLAG_MUTABLE` is the constant the system requires from API 31 onward for an IntentSender it fills in itself. It was **added in API 31** — API 23 introduced `FLAG_IMMUTABLE`, not this one. No version guard is needed anyway: the constant is an inlined `int`, so it compiles at `minSdk = 28` and the bit is simply ignored on releases before 31.

- [ ] **Step 7: Verify**

Run: `flutter test` → expected 287 passing (283 + 4 new).
Run: `flutter analyze` → expected "No issues found!".
Run: `dart format lib/core/services/app_system_service.dart test/core/services/app_system_service_test.dart`

The Kotlin cannot be exercised from `flutter test`. Report that the install path is unverified until the user runs it on hardware, and say so plainly rather than implying it was tested.

---

### Task 4: `ApkDownloader`

**Files:**
- Modify: `pubspec.yaml` (add `crypto`)
- Create: `lib/features/app_update/data/apk_downloader.dart`
- Create: `test/support/fake_apk_downloader.dart`
- Test: `test/features/app_update/apk_downloader_test.dart`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `abstract interface class ApkDownloader { Future<String> download({required String url, required String destinationPath, required void Function(double progress) onProgress}); }` — returns the **lowercase hex SHA-256** of the file it wrote.
  - `class HttpApkDownloader implements ApkDownloader`
  - `class FakeApkDownloader implements ApkDownloader` with `String digest = ''; Object? error; String? lastUrl; String? lastDestination; List<double> reportedProgress = [];`

The downloader returns the digest rather than comparing it, so the comparison lives in the controller where it can be tested without a file system.

- [ ] **Step 1: Add the dependency**

In `pubspec.yaml`, under `dependencies:`, beside `supabase_flutter`:

```yaml
  # SHA-256 for the update download. Pure Dart, so verification can be tested
  # in `flutter test` — doing the digest natively would make the one guard
  # that matters most untestable.
  crypto: ^3.0.6
```

Run: `flutter pub get`

- [ ] **Step 2: Write the failing test**

Create `test/features/app_update/apk_downloader_test.dart`. It serves bytes from a real loopback `HttpServer`, which exercises the streaming path without any network:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/features/app_update/data/apk_downloader.dart';

void main() {
  late HttpServer server;
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('apk_downloader_test');
  });

  tearDown(() async {
    await server.close(force: true);
    await tempDir.delete(recursive: true);
  });

  Future<String> serve(List<int> body, {int status = 200}) async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.statusCode = status;
      request.response.headers.contentLength = body.length;
      request.response.add(body);
      await request.response.close();
    });
    return 'http://${server.address.address}:${server.port}/youcar.apk';
  }

  test('writes_the_body_and_returns_its_sha256', () async {
    // sha256("youcar") — a known digest, so the test proves the hash is of
    // the written bytes rather than of whatever the implementation felt like.
    final url = await serve('youcar'.codeUnits);
    final destination = '${tempDir.path}/update.apk';

    final digest = await const HttpApkDownloader().download(
      url: url,
      destinationPath: destination,
      onProgress: (_) {},
    );

    expect(File(destination).readAsStringSync(), 'youcar');
    expect(
      digest,
      '3a769e561d5130190cc06be93fb5a51027b39196b1faac9a0cf41a4aaa1161d5',
    );
  });

  test('reports_progress_between_zero_and_one', () async {
    final url = await serve(List<int>.filled(4096, 65));

    final progress = <double>[];
    await const HttpApkDownloader().download(
      url: url,
      destinationPath: '${tempDir.path}/update.apk',
      onProgress: progress.add,
    );

    expect(progress, isNotEmpty);
    expect(progress.every((p) => p >= 0 && p <= 1), isTrue);
    expect(progress.last, closeTo(1.0, 0.001));
  });

  test('a_non_200_response_throws_and_leaves_no_file_behind', () async {
    final url = await serve(const [], status: 404);
    final destination = '${tempDir.path}/update.apk';

    await expectLater(
      const HttpApkDownloader().download(
        url: url,
        destinationPath: destination,
        onProgress: (_) {},
      ),
      throwsA(isA<Exception>()),
    );
    // A half-written file left on disk would be installed on the next attempt.
    expect(File(destination).existsSync(), isFalse);
  });
}
```

That digest is the real `printf 'youcar' | shasum -a 256`, verified before this plan was written — it is not a placeholder. If the test fails on it, the implementation is hashing something other than the bytes it wrote.

- [ ] **Step 3: Run it and watch it fail**

Run: `flutter test test/features/app_update/apk_downloader_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../apk_downloader.dart'`.

- [ ] **Step 4: Write the downloader**

Create `lib/features/app_update/data/apk_downloader.dart`:

```dart
import 'dart:io';

import 'package:crypto/crypto.dart';

abstract interface class ApkDownloader {
  /// Streams [url] into [destinationPath] and returns the lowercase hex
  /// SHA-256 of what was written.
  ///
  /// The digest is returned rather than checked here so the comparison can
  /// live in the controller, where it is testable without a file system.
  /// Throws on any transport failure, leaving no file behind.
  Future<String> download({
    required String url,
    required String destinationPath,
    required void Function(double progress) onProgress,
  });
}

class HttpApkDownloader implements ApkDownloader {
  const HttpApkDownloader();

  @override
  Future<String> download({
    required String url,
    required String destinationPath,
    required void Function(double progress) onProgress,
  }) async {
    final file = File(destinationPath);
    final client = HttpClient();
    IOSink? sink;
    try {
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Update download failed with HTTP ${response.statusCode}',
          uri: Uri.parse(url),
        );
      }

      final total = response.contentLength;
      var received = 0;
      final digest = AccumulatorSink<Digest>();
      final hasher = sha256.startChunkedConversion(digest);

      await file.parent.create(recursive: true);
      sink = file.openWrite();
      await for (final chunk in response) {
        sink.add(chunk);
        hasher.add(chunk);
        received += chunk.length;
        if (total > 0) {
          onProgress(received / total);
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;

      hasher.close();
      return digest.events.single.toString();
    } catch (_) {
      // A half-written file would be installed on the next attempt.
      await sink?.close();
      if (file.existsSync()) {
        await file.delete();
      }
      rethrow;
    } finally {
      client.close(force: true);
    }
  }
}
```

`AccumulatorSink` comes from `package:crypto/crypto.dart` via `convert`; if the analyzer cannot resolve it, import `package:convert/convert.dart` as well — `convert` arrives transitively with `crypto`.

- [ ] **Step 5: Run it and watch it pass**

Run: `flutter test test/features/app_update/apk_downloader_test.dart`
Expected: PASS, 3 tests.

- [ ] **Step 6: Write the fake**

Create `test/support/fake_apk_downloader.dart`:

```dart
import 'package:viet_ktv/features/app_update/data/apk_downloader.dart';

/// Fake downloader. Returns [digest] without touching the disk, so controller
/// tests can drive the checksum-match and checksum-mismatch paths directly.
class FakeApkDownloader implements ApkDownloader {
  FakeApkDownloader({this.digest = '', this.error});

  String digest;
  Object? error;

  String? lastUrl;
  String? lastDestination;
  final List<double> reportedProgress = <double>[];

  @override
  Future<String> download({
    required String url,
    required String destinationPath,
    required void Function(double progress) onProgress,
  }) async {
    lastUrl = url;
    lastDestination = destinationPath;
    final thrown = error;
    if (thrown != null) {
      throw thrown;
    }
    onProgress(0.5);
    onProgress(1);
    reportedProgress
      ..add(0.5)
      ..add(1);
    return digest;
  }
}
```

- [ ] **Step 7: Verify**

Run: `flutter test` → expected 290 passing (287 + 3 new).
Run: `flutter analyze` → expected "No issues found!".
Run: `dart format lib/features/app_update/data/apk_downloader.dart test/support/fake_apk_downloader.dart test/features/app_update/apk_downloader_test.dart`

---

### Task 5: `AppUpdateState` and `AppUpdateController`

**Files:**
- Create: `lib/features/app_update/presentation/providers/app_update_state.dart`
- Create: `lib/features/app_update/presentation/providers/app_update_controller.dart`
- Test: `test/features/app_update/app_update_controller_test.dart`

**Interfaces:**
- Consumes: `AppRelease`, `AppUpdateRepository`, `ApkDownloader`, `AppSystemService` (`getSystemInfo().appVersionCode`, `getUpdateCacheDir()`, `canInstallPackages()`, `openInstallPermissionSettings()`, `installApk(path)`), plus `FakeAppUpdateRepository` and `FakeApkDownloader` in tests.
- Produces:
  - `enum AppUpdateStatus { idle, checking, upToDate, available, downloading, verifying, installing, error }`
  - `enum AppUpdateError { none, network, download, checksum, install, permission }`
  - `class AppUpdateState`
  - `abstract interface class AppUpdateSystem` with `installedVersionCode()`, `updateCacheDir()`, `canInstallPackages()`, `openInstallPermissionSettings()`, `installApk(String path)`, `deleteFile(String path)`
  - `class PlatformAppUpdateSystem implements AppUpdateSystem`
  - `class AppUpdateController extends StateNotifier<AppUpdateState>` with `Future<void> check()`, `Future<void> downloadAndInstall()`, `Future<void> openPermissionSettings()`
  - `final appUpdateControllerProvider = StateNotifierProvider<AppUpdateController, AppUpdateState>(...)`
  - `test/support/fake_app_update_system.dart` → `class FakeAppUpdateSystem implements AppUpdateSystem`, **created here and reused by Task 6**

- [ ] **Step 1: Write the failing test**

Create `test/features/app_update/app_update_controller_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/services/app_system_service.dart';
import 'package:viet_ktv/features/app_update/data/models/app_release.dart';
import 'package:viet_ktv/features/app_update/presentation/providers/app_update_controller.dart';
import 'package:viet_ktv/features/app_update/presentation/providers/app_update_state.dart';

import '../../support/fake_apk_downloader.dart';
import '../../support/fake_app_update_repository.dart';
import '../../support/fake_app_update_system.dart';

const _release = AppRelease(
  versionCode: 7,
  versionName: '1.2.0',
  apkUrl: 'https://example.invalid/youcar.apk',
  sha256: 'goodhash',
  notes: 'Sửa lỗi',
);

AppUpdateController build({
  FakeAppUpdateRepository? repository,
  FakeApkDownloader? downloader,
  FakeAppUpdateSystem? system,
}) {
  return AppUpdateController(
    repository: repository ?? FakeAppUpdateRepository(),
    downloader: downloader ?? FakeApkDownloader(),
    system: system ?? FakeAppUpdateSystem(),
  );
}

void main() {
  test('starts_idle', () {
    expect(build().state.status, AppUpdateStatus.idle);
  });

  test('a_higher_remote_version_code_offers_the_update', () async {
    final controller = build(
      repository: FakeAppUpdateRepository(release: _release),
      system: FakeAppUpdateSystem(versionCode: 1),
    );

    await controller.check();

    expect(controller.state.status, AppUpdateStatus.available);
    expect(controller.state.release?.versionName, '1.2.0');
  });

  test('an_equal_version_code_reads_as_up_to_date', () async {
    final controller = build(
      repository: FakeAppUpdateRepository(release: _release),
      system: FakeAppUpdateSystem(versionCode: 7),
    );

    await controller.check();

    expect(controller.state.status, AppUpdateStatus.upToDate);
  });

  test('a_lower_version_code_never_offers_a_downgrade', () async {
    final controller = build(
      repository: FakeAppUpdateRepository(release: _release),
      system: FakeAppUpdateSystem(versionCode: 9),
    );

    await controller.check();

    expect(controller.state.status, AppUpdateStatus.upToDate);
  });

  test('no_published_release_is_up_to_date_not_an_error', () async {
    final controller = build(repository: FakeAppUpdateRepository());

    await controller.check();

    expect(controller.state.status, AppUpdateStatus.upToDate);
  });

  test('an_unreachable_backend_is_a_retryable_network_error', () async {
    final controller = build(
      repository: FakeAppUpdateRepository(error: Exception('offline')),
    );

    await controller.check();

    expect(controller.state.status, AppUpdateStatus.error);
    expect(controller.state.error, AppUpdateError.network);
  });

  test('a_matching_checksum_installs_the_downloaded_file', () async {
    final system = FakeAppUpdateSystem(versionCode: 1);
    final controller = build(
      repository: FakeAppUpdateRepository(release: _release),
      downloader: FakeApkDownloader(digest: 'goodhash'),
      system: system,
    );

    await controller.check();
    await controller.downloadAndInstall();

    expect(system.installedPath, '/tmp/updates/youcar-7.apk');
    expect(controller.state.status, AppUpdateStatus.installing);
  });

  test('a_mismatched_checksum_errors_and_never_calls_install', () async {
    // The guard that matters most: a corrupted 145MB download must not reach
    // the system installer, where it fails with a parse error that tells the
    // user nothing.
    final system = FakeAppUpdateSystem(versionCode: 1);
    final controller = build(
      repository: FakeAppUpdateRepository(release: _release),
      downloader: FakeApkDownloader(digest: 'tampered'),
      system: system,
    );

    await controller.check();
    await controller.downloadAndInstall();

    expect(controller.state.status, AppUpdateStatus.error);
    expect(controller.state.error, AppUpdateError.checksum);
    expect(system.installedPath, isNull);
    // Left on disk, a bad file would be installed by the next attempt.
    expect(system.deletedPaths, ['/tmp/updates/youcar-7.apk']);
  });

  test('a_failed_download_is_a_retryable_error_and_does_not_install', () async {
    final system = FakeAppUpdateSystem(versionCode: 1);
    final controller = build(
      repository: FakeAppUpdateRepository(release: _release),
      downloader: FakeApkDownloader(error: Exception('connection reset')),
      system: system,
    );

    await controller.check();
    await controller.downloadAndInstall();

    expect(controller.state.error, AppUpdateError.download);
    expect(system.installedPath, isNull);
  });

  test('missing_install_permission_prompts_instead_of_downloading', () async {
    final system = FakeAppUpdateSystem(versionCode: 1, canInstall: false);
    final downloader = FakeApkDownloader(digest: 'goodhash');
    final controller = build(
      repository: FakeAppUpdateRepository(release: _release),
      downloader: downloader,
      system: system,
    );

    await controller.check();
    await controller.downloadAndInstall();

    expect(controller.state.error, AppUpdateError.permission);
    expect(downloader.lastUrl, isNull);
    expect(system.installedPath, isNull);
  });

  test('opening_the_permission_screen_reaches_the_platform', () async {
    final system = FakeAppUpdateSystem();
    final controller = build(system: system);

    await controller.openPermissionSettings();

    expect(system.permissionScreenOpened, 1);
  });
}
```

- [ ] **Step 2: Write the shared fake system**

Create `test/support/fake_app_update_system.dart`. It lives in `support/` rather than inside the controller test because Task 6 reuses it:

```dart
import 'package:viet_ktv/features/app_update/presentation/providers/app_update_controller.dart';

/// Records what the controller asked the platform to do. [installedPath] stays
/// null unless `installApk` was actually reached — that absence is what the
/// checksum test asserts on.
class FakeAppUpdateSystem implements AppUpdateSystem {
  FakeAppUpdateSystem({this.versionCode = 1, this.canInstall = true});

  int versionCode;
  bool canInstall;

  String? installedPath;
  int permissionScreenOpened = 0;
  final List<String> deletedPaths = <String>[];

  @override
  Future<int> installedVersionCode() async => versionCode;

  @override
  Future<String> updateCacheDir() async => '/tmp/updates';

  @override
  Future<bool> canInstallPackages() async => canInstall;

  @override
  Future<void> openInstallPermissionSettings() async {
    permissionScreenOpened++;
  }

  @override
  Future<void> installApk(String path) async {
    installedPath = path;
  }

  @override
  Future<void> deleteFile(String path) async {
    deletedPaths.add(path);
  }
}
```

- [ ] **Step 3: Run it and watch it fail**

Run: `flutter test test/features/app_update/app_update_controller_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../app_update_controller.dart'`.

- [ ] **Step 4: Write the state**

Create `lib/features/app_update/presentation/providers/app_update_state.dart`:

```dart
import '../../data/models/app_release.dart';

enum AppUpdateStatus {
  /// Nothing asked for yet — the row shows the installed version and a check
  /// button. The app never checks on its own.
  idle,
  checking,
  upToDate,
  available,
  downloading,
  verifying,

  /// Handed to the system installer, which owns the screen from here.
  installing,
  error,
}

enum AppUpdateError { none, network, download, checksum, install, permission }

class AppUpdateState {
  const AppUpdateState({
    this.status = AppUpdateStatus.idle,
    this.release,
    this.progress = 0,
    this.error = AppUpdateError.none,
  });

  final AppUpdateStatus status;

  /// The release on offer. Set once [status] reaches
  /// [AppUpdateStatus.available] and kept through the download so the row can
  /// keep showing what is being installed.
  final AppRelease? release;

  /// 0..1 while [status] is [AppUpdateStatus.downloading].
  final double progress;

  final AppUpdateError error;

  AppUpdateState copyWith({
    AppUpdateStatus? status,
    Object? release = _unset,
    double? progress,
    AppUpdateError? error,
  }) {
    return AppUpdateState(
      status: status ?? this.status,
      release: identical(release, _unset)
          ? this.release
          : release as AppRelease?,
      progress: progress ?? this.progress,
      error: error ?? this.error,
    );
  }
}

const _unset = Object();
```

- [ ] **Step 5: Write the controller**

Create `lib/features/app_update/presentation/providers/app_update_controller.dart`:

```dart
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/app_system_service.dart';
import '../../data/apk_downloader.dart';
import '../../data/app_update_repository.dart';
import 'app_update_state.dart';

/// The slice of the platform the updater needs, named separately so tests can
/// fake five small methods instead of the whole [AppSystemService].
abstract interface class AppUpdateSystem {
  Future<int> installedVersionCode();
  Future<String> updateCacheDir();
  Future<bool> canInstallPackages();
  Future<void> openInstallPermissionSettings();
  Future<void> installApk(String path);

  /// Removes a downloaded APK. Called when its checksum does not match, so a
  /// corrupt file cannot be picked up by the next attempt.
  Future<void> deleteFile(String path);
}

class PlatformAppUpdateSystem implements AppUpdateSystem {
  const PlatformAppUpdateSystem({AppSystemService? service})
    : _service = service ?? const AppSystemService();

  final AppSystemService _service;

  @override
  Future<int> installedVersionCode() async =>
      (await _service.getSystemInfo()).appVersionCode;

  @override
  Future<String> updateCacheDir() => _service.getUpdateCacheDir();

  @override
  Future<bool> canInstallPackages() => _service.canInstallPackages();

  @override
  Future<void> openInstallPermissionSettings() =>
      _service.openInstallPermissionSettings();

  @override
  Future<void> installApk(String path) => _service.installApk(path);

  @override
  Future<void> deleteFile(String path) async {
    final file = File(path);
    if (file.existsSync()) {
      await file.delete();
    }
  }
}

class AppUpdateController extends StateNotifier<AppUpdateState> {
  AppUpdateController({
    required this.repository,
    required this.downloader,
    required this.system,
  }) : super(const AppUpdateState());

  final AppUpdateRepository repository;
  final ApkDownloader downloader;
  final AppUpdateSystem system;

  Future<void> check() async {
    state = state.copyWith(
      status: AppUpdateStatus.checking,
      error: AppUpdateError.none,
      release: null,
    );
    try {
      final release = await repository.latestRelease();
      final installed = await system.installedVersionCode();
      if (release == null || release.versionCode <= installed) {
        // No row published, or the server is not ahead of us. Both are
        // "up to date"; neither is an error, and neither may downgrade.
        state = state.copyWith(status: AppUpdateStatus.upToDate);
        return;
      }
      state = state.copyWith(
        status: AppUpdateStatus.available,
        release: release,
      );
    } catch (_) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        error: AppUpdateError.network,
      );
    }
  }

  Future<void> downloadAndInstall() async {
    final release = state.release;
    if (release == null) {
      return;
    }

    if (!await system.canInstallPackages()) {
      // Downloading 145MB the user cannot install wastes their data.
      state = state.copyWith(
        status: AppUpdateStatus.error,
        error: AppUpdateError.permission,
      );
      return;
    }

    state = state.copyWith(
      status: AppUpdateStatus.downloading,
      progress: 0,
      error: AppUpdateError.none,
    );

    final String path;
    final String digest;
    try {
      final dir = await system.updateCacheDir();
      path = '$dir/youcar-${release.versionCode}.apk';
      digest = await downloader.download(
        url: release.apkUrl,
        destinationPath: path,
        onProgress: (progress) {
          state = state.copyWith(progress: progress);
        },
      );
    } catch (_) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        error: AppUpdateError.download,
      );
      return;
    }

    state = state.copyWith(status: AppUpdateStatus.verifying);
    if (digest.toLowerCase() != release.sha256.toLowerCase()) {
      // A truncated download reaching the system installer fails with a parse
      // error that tells the user nothing. Stop here — and delete the file,
      // or the next attempt would pick the same bad bytes back up.
      await system.deleteFile(path);
      state = state.copyWith(
        status: AppUpdateStatus.error,
        error: AppUpdateError.checksum,
      );
      return;
    }

    try {
      await system.installApk(path);
      state = state.copyWith(status: AppUpdateStatus.installing);
    } catch (_) {
      state = state.copyWith(
        status: AppUpdateStatus.error,
        error: AppUpdateError.install,
      );
    }
  }

  Future<void> openPermissionSettings() =>
      system.openInstallPermissionSettings();
}

final appUpdateControllerProvider =
    StateNotifierProvider<AppUpdateController, AppUpdateState>(
      (ref) => AppUpdateController(
        repository: const SupabaseAppUpdateRepository(),
        downloader: const HttpApkDownloader(),
        system: const PlatformAppUpdateSystem(),
      ),
    );
```

- [ ] **Step 6: Run it and watch it pass**

Run: `flutter test test/features/app_update/app_update_controller_test.dart`
Expected: PASS, 11 tests — count them in Step 1 above; an earlier draft of this plan said 12, which was a miscount.

- [ ] **Step 7: Verify**

Run: `flutter test` → expected 302 passing. (Task 4's review added one test beyond its own step count, so the baseline entering this task is 291, and 291 + 11 = 302.)
Run: `flutter analyze` → expected "No issues found!".
Run: `dart format` on the two new lib files and the new test file, naming each.

---

### Task 6: The Settings row

**Files:**
- Create: `lib/features/app_update/presentation/widgets/update_section.dart`
- Modify: `lib/features/settings/presentation/widgets/settings_content_panel.dart` (`_systemSettings`, line 324)
- Modify: `lib/l10n/app_vi.arb`, `lib/l10n/app_en.arb`
- Test: `test/features/app_update/update_section_test.dart`

**Interfaces:**
- Consumes: `appUpdateControllerProvider`, `AppUpdateState`, `AppUpdateStatus`, `AppUpdateError`.
- Produces: `class UpdateSection extends ConsumerWidget` — a public widget, since it is built from another feature's file.

- [ ] **Step 1: Add the localization keys**

Add to `lib/l10n/app_vi.arb`:

```json
  "settingsCheckUpdate": "Kiểm tra cập nhật",
  "settingsUpdateChecking": "Đang kiểm tra...",
  "settingsUpdateUpToDate": "Không có bản cập nhật mới",
  "settingsUpdateAvailable": "Có bản mới {version}",
  "@settingsUpdateAvailable": {
    "placeholders": {
      "version": {
        "type": "String"
      }
    }
  },
  "settingsUpdateInstall": "Cập nhật",
  "settingsUpdateDownloading": "Đang tải {percent}%",
  "@settingsUpdateDownloading": {
    "placeholders": {
      "percent": {
        "type": "int"
      }
    }
  },
  "settingsUpdateVerifying": "Đang kiểm tra tệp...",
  "settingsUpdateInstalling": "Đang cài đặt...",
  "settingsUpdateErrorNetwork": "Không kiểm tra được. Kiểm tra kết nối mạng rồi thử lại.",
  "settingsUpdateErrorDownload": "Tải bản cập nhật thất bại. Thử lại.",
  "settingsUpdateErrorChecksum": "Tệp tải về bị hỏng. Đã xoá, vui lòng thử lại.",
  "settingsUpdateErrorInstall": "Không mở được trình cài đặt.",
  "settingsUpdateErrorPermission": "Cần cho phép cài ứng dụng từ nguồn này.",
  "settingsUpdateOpenPermission": "Mở cài đặt",
  "settingsUpdateRetry": "Thử lại",
```

And the matching keys in `lib/l10n/app_en.arb`:

```json
  "settingsCheckUpdate": "Check for updates",
  "settingsUpdateChecking": "Checking...",
  "settingsUpdateUpToDate": "No new version available",
  "settingsUpdateAvailable": "Version {version} available",
  "@settingsUpdateAvailable": {
    "placeholders": {
      "version": {
        "type": "String"
      }
    }
  },
  "settingsUpdateInstall": "Update",
  "settingsUpdateDownloading": "Downloading {percent}%",
  "@settingsUpdateDownloading": {
    "placeholders": {
      "percent": {
        "type": "int"
      }
    }
  },
  "settingsUpdateVerifying": "Verifying file...",
  "settingsUpdateInstalling": "Installing...",
  "settingsUpdateErrorNetwork": "Could not check. Check your connection and try again.",
  "settingsUpdateErrorDownload": "Download failed. Try again.",
  "settingsUpdateErrorChecksum": "The downloaded file was corrupt. It has been deleted; please try again.",
  "settingsUpdateErrorInstall": "Could not open the installer.",
  "settingsUpdateErrorPermission": "Allow installing apps from this source first.",
  "settingsUpdateOpenPermission": "Open settings",
  "settingsUpdateRetry": "Try again",
```

Run: `flutter gen-l10n`

- [ ] **Step 2: Write the failing test**

Create `test/features/app_update/update_section_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/features/app_update/data/models/app_release.dart';
import 'package:viet_ktv/features/app_update/presentation/providers/app_update_controller.dart';
import 'package:viet_ktv/features/app_update/presentation/providers/app_update_state.dart';
import 'package:viet_ktv/features/app_update/presentation/widgets/update_section.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import '../../support/fake_apk_downloader.dart';
import '../../support/fake_app_update_repository.dart';
import '../../support/fake_app_update_system.dart';

/// `appUpdateControllerProvider` is typed
/// `StateNotifierProvider<AppUpdateController, AppUpdateState>`, so an
/// override must produce an [AppUpdateController] — a bare StateNotifier will
/// not compile. Subclass it with fakes and seed the state directly.
class _StubController extends AppUpdateController {
  _StubController(AppUpdateState initial)
    : super(
        repository: FakeAppUpdateRepository(),
        downloader: FakeApkDownloader(),
        system: FakeAppUpdateSystem(),
      ) {
    state = initial;
  }
}

Future<void> _pump(WidgetTester tester, AppUpdateState state) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appUpdateControllerProvider.overrideWith(
          (ref) => _StubController(state),
        ),
      ],
      child: MaterialApp(
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: UpdateSection()),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('idle_shows_the_check_button', (tester) async {
    await _pump(tester, const AppUpdateState());

    expect(find.text('Kiểm tra cập nhật'), findsOneWidget);
  });

  testWidgets('up_to_date_says_there_is_no_new_version', (tester) async {
    await _pump(
      tester,
      const AppUpdateState(status: AppUpdateStatus.upToDate),
    );

    expect(find.text('Không có bản cập nhật mới'), findsOneWidget);
  });

  testWidgets('available_shows_the_version_notes_and_update_button',
      (tester) async {
    await _pump(
      tester,
      const AppUpdateState(
        status: AppUpdateStatus.available,
        release: AppRelease(
          versionCode: 7,
          versionName: '1.2.0',
          apkUrl: 'https://example.invalid/a.apk',
          sha256: 'aa',
          notes: 'Sửa lỗi phát nhạc nền',
        ),
      ),
    );

    expect(find.text('Có bản mới 1.2.0'), findsOneWidget);
    expect(find.text('Sửa lỗi phát nhạc nền'), findsOneWidget);
    expect(find.text('Cập nhật'), findsOneWidget);
  });

  testWidgets('a_checksum_error_explains_itself_and_offers_a_retry',
      (tester) async {
    await _pump(
      tester,
      const AppUpdateState(
        status: AppUpdateStatus.error,
        error: AppUpdateError.checksum,
      ),
    );

    expect(find.text('Tệp tải về bị hỏng. Đã xoá, vui lòng thử lại.'),
        findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);
  });

  testWidgets('a_permission_error_offers_the_settings_shortcut',
      (tester) async {
    await _pump(
      tester,
      const AppUpdateState(
        status: AppUpdateStatus.error,
        error: AppUpdateError.permission,
      ),
    );

    expect(find.text('Mở cài đặt'), findsOneWidget);
  });
}
```

- [ ] **Step 3: Run it and watch it fail**

Run: `flutter test test/features/app_update/update_section_test.dart`
Expected: FAIL — `Target of URI doesn't exist: '.../update_section.dart'`.

- [ ] **Step 4: Write the widget**

Create `lib/features/app_update/presentation/widgets/update_section.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_icons.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/l10n.dart';
import '../providers/app_update_controller.dart';
import '../providers/app_update_state.dart';

/// The one place the user can ask whether a newer build exists. Nothing here
/// runs on its own: the app never checks at startup and never blocks on an
/// old version.
class UpdateSection extends ConsumerWidget {
  const UpdateSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateControllerProvider);
    final controller = ref.read(appUpdateControllerProvider.notifier);
    final busy =
        state.status == AppUpdateStatus.checking ||
        state.status == AppUpdateStatus.downloading ||
        state.status == AppUpdateStatus.verifying ||
        state.status == AppUpdateStatus.installing;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.panelStrong,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.panelBorder),
      ),
      child: Row(
        children: [
          const Icon(AppIcons.info, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _title(context, state),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                if (_subtitle(context, state) case final String subtitle)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xxs),
                    child: Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (busy)
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            FilledButton(
              onPressed: () => _onPressed(controller, state),
              child: Text(_actionLabel(context, state)),
            ),
        ],
      ),
    );
  }

  void _onPressed(AppUpdateController controller, AppUpdateState state) {
    if (state.status == AppUpdateStatus.available) {
      controller.downloadAndInstall();
      return;
    }
    if (state.error == AppUpdateError.permission) {
      controller.openPermissionSettings();
      return;
    }
    controller.check();
  }

  String _title(BuildContext context, AppUpdateState state) {
    final l10n = context.l10n;
    return switch (state.status) {
      AppUpdateStatus.checking => l10n.settingsUpdateChecking,
      AppUpdateStatus.upToDate => l10n.settingsUpdateUpToDate,
      AppUpdateStatus.available => l10n.settingsUpdateAvailable(
        state.release?.versionName ?? '',
      ),
      AppUpdateStatus.downloading => l10n.settingsUpdateDownloading(
        (state.progress * 100).round(),
      ),
      AppUpdateStatus.verifying => l10n.settingsUpdateVerifying,
      AppUpdateStatus.installing => l10n.settingsUpdateInstalling,
      AppUpdateStatus.error => _errorMessage(context, state.error),
      AppUpdateStatus.idle => l10n.settingsCheckUpdate,
    };
  }

  String? _subtitle(BuildContext context, AppUpdateState state) {
    if (state.status != AppUpdateStatus.available) {
      return null;
    }
    final notes = state.release?.notes;
    return (notes == null || notes.isEmpty) ? null : notes;
  }

  String _actionLabel(BuildContext context, AppUpdateState state) {
    final l10n = context.l10n;
    if (state.status == AppUpdateStatus.available) {
      return l10n.settingsUpdateInstall;
    }
    if (state.error == AppUpdateError.permission) {
      return l10n.settingsUpdateOpenPermission;
    }
    if (state.status == AppUpdateStatus.error) {
      return l10n.settingsUpdateRetry;
    }
    return l10n.settingsCheckUpdate;
  }

  String _errorMessage(BuildContext context, AppUpdateError error) {
    final l10n = context.l10n;
    return switch (error) {
      AppUpdateError.network => l10n.settingsUpdateErrorNetwork,
      AppUpdateError.download => l10n.settingsUpdateErrorDownload,
      AppUpdateError.checksum => l10n.settingsUpdateErrorChecksum,
      AppUpdateError.install => l10n.settingsUpdateErrorInstall,
      AppUpdateError.permission => l10n.settingsUpdateErrorPermission,
      AppUpdateError.none => l10n.settingsCheckUpdate,
    };
  }
}
```

Every helper reads `context.l10n` itself, so `build` deliberately does not hold an `l10n` local — one there would be unused and the analyzer would reject it.

Tokens used, all confirmed to exist: `AppRadius.sm` (14), `AppSpacing.xxs/sm/md`, `AppColors.panelStrong/panelBorder/textPrimary/textSecondary`, `AppIcons.info`.

- [ ] **Step 5: Run it and watch it pass**

Run: `flutter test test/features/app_update/update_section_test.dart`
Expected: PASS, 5 tests.

- [ ] **Step 6: Put it in Settings**

In `lib/features/settings/presentation/widgets/settings_content_panel.dart`, import the widget and add it to `_systemSettings` (line 324), after `_SystemInfoRows` and before the existing `_NavigationRow`s:

```dart
      _SectionTitle(l10n.settingsSystem),
      const _SystemInfoRows(),
      const SizedBox(height: AppSpacing.lg),
      const UpdateSection(),
      const SizedBox(height: AppSpacing.lg),
      _NavigationRow(
```

- [ ] **Step 7: Verify**

Run: `flutter test` → expected 307 passing (302 + 5 new).
Run: `flutter analyze` → expected "No issues found!".
Run: `dart format` on the new widget, the modified panel, and the new test, naming each.

---

## After The Plan

These are the user's to do, not the implementer's:

1. **Back up `~/.android/debug.keystore`.** Without it no already-sold device can be updated, and this whole feature is moot. See the spec's prerequisite section.
2. Run the Task 1 migration against the Supabase project.
3. Publish the first release: bump `version:` in `pubspec.yaml`, build and sign, upload to a GitHub Release on `DuongAty/car-app`, `shasum -a 256` the file, insert the row.
4. Install that first build by hand on existing devices — they have no updater yet.
