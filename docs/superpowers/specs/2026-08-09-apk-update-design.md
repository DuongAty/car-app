# In-App Update For Sideloaded APKs

## Context

The app ships as an APK installed by hand — car head units and karaoke boxes,
no Play Store. There is no way to tell a customer's machine that a newer build
exists, and no way for them to get it without someone physically bringing a
file.

The license system already talks to a Supabase project (`schema.sql`, RPCs
`request_activation` and `check_license`). Update metadata reuses that backend
rather than introducing a second service.

## Goals

A user can open Settings, press one button, and learn whether a newer build
exists. If one does, a second press downloads and installs it.

## Non-Goals

- **No automatic check.** Nothing runs at startup. The check happens only when
  the user asks for it.
- **No forced update, and no version floor.** An old build keeps working
  forever. Nothing is ever gated on being current.
- **No delta updates.** Not available outside the Play Store; every update is a
  full APK download.
- **No rollback.** A `version_code` at or below the installed one reads as "up
  to date"; the app never downgrades itself.

## Blocking Prerequisite: The Signing Key

Android installs an update over an existing app only when both APKs carry the
same signature. A mismatch fails with `INSTALL_FAILED_UPDATE_INCOMPATIBLE`, and
the only way through is an uninstall — which destroys the saved license key,
favorites, history, and settings, and forces re-activation through admin
approval because licenses are device-bound.

`android/app/build.gradle.kts:32` signs release builds with the **debug**
keystore:

```kotlin
signingConfig = signingConfigs.getByName("debug")
```

That file is `~/.android/debug.keystore` (2.6 KB, created 2026-07-23, valid to
2056, password `android`, alias `androiddebugkey`, SHA-256 fingerprint
`92:B3:8A:F1:5D:...`). It exists in exactly one place: the developer's Mac. It
is auto-generated per machine and cannot be reproduced.

**Lose it and no already-sold device can ever be updated again** — this feature
included. Back it up off-machine before shipping anything that depends on
updates working.

Do not commit it. `DuongAty/car-app` is public, and whoever holds the signing
key can push a modified build that every customer device will install without
warning. The license gate does not help here: it protects the software from
strangers, while the signing key protects customers from impostors.

Migrating to a proper release key later is possible without breaking installed
devices — APK Signature Scheme v3 key rotation carries a lineage proving the
new key succeeds the old one, and it needs Android 9, which `minSdk = 28`
already guarantees. That migration still starts from the current debug key, so
the backup comes first either way.

## Where The APK Lives

GitHub Releases on `DuongAty/car-app`. The repo is public, so downloads need no
token and carry no bandwidth cap.

Supabase Storage was rejected: the free tier allows roughly 5 GB of egress per
month, and at the current ~145 MB APK that is about 34 downloads in total,
across all customers.

A public APK is acceptable. Anyone can download it, but two locks make it
useless: the license gate, and — more importantly — the MusicSDK license key,
which `music_sdk_bootstrap.dart:5` reads from `--dart-define` with **no default
value**. A build without that key initializes no SDK, so it cannot search or
play anything, and the key is not in the repository.

## Backend

`check_license` is **not touched**. Customer devices are already running
against it, `LicenseRpcResult.parse` throws on any unrecognised string, and a
changed return type would strand those devices at the license gate.

New table, mirroring the `licenses` conventions (RLS on, anon reaches it only
through a `security definer` RPC):

```sql
create table public.app_releases (
  id            uuid primary key default gen_random_uuid(),
  version_code  int  not null unique,
  version_name  text not null,
  apk_url       text not null,
  sha256        text not null,
  notes         text,
  is_active     boolean not null default true,
  published_at  timestamptz not null default now()
);
```

One public RPC returning JSON — a new function, not a changed one:

```sql
create function public.latest_release() returns json
```

It returns the active row with the highest `version_code` as
`{version_code, version_name, apk_url, sha256, notes}`, or SQL `null` when no
active release exists. Returning JSON rather than text is safe here precisely
because the function is new: nothing in the field calls it yet.

Grants follow the pattern at `schema.sql:318-334` — revoke from `public`, then
grant execute to `anon, authenticated`, exactly as `check_license` does. Admin
writes to `app_releases` go through the table's RLS policy for authenticated
users, so no `admin_*` RPC is needed for publishing.

The change ships as a new file in `backend/supabase/migrations/`, following the
dated-filename convention already there. Note that `backend/` is currently not
under version control at all — see the rollout note.

`notes` is a plain string shown verbatim. It is authored per release and is not
localized — one text, whichever language the publisher writes it in.

## Publishing A Release

Manual, matching the convention already stated in `schema.sql` ("dùng ngay để
test bằng SQL Editor trong lúc app-admin chưa có UI"):

1. Bump `version:` in `pubspec.yaml`. The number after `+` is the
   `versionCode`, and it must increase.
2. Build and sign the release APK with the key described above.
3. Upload it to a GitHub Release on `DuongAty/car-app`.
4. Compute `shasum -a 256` of the uploaded file.
5. Insert a row into `app_releases` through the Supabase SQL Editor.

A publishing screen in `app-admin` is a later, separate piece of work.

## Client Architecture

New feature folder `lib/features/app_update/`, following the existing
feature-first layout:

| File | Responsibility |
| --- | --- |
| `data/models/app_release.dart` | Immutable release record; parses the RPC JSON |
| `data/app_update_repository.dart` | `abstract interface class` + Supabase implementation, shaped like `LicenseRepository` |
| `data/apk_downloader.dart` | Streams the APK to disk, reports progress, computes SHA-256 |
| `presentation/providers/app_update_state.dart` | Immutable state + `copyWith` |
| `presentation/providers/app_update_controller.dart` | `StateNotifier` holding the state machine |
| `presentation/widgets/update_section.dart` | The Settings row |

The repository and downloader are separate because they fail differently and
are faked differently in tests: one is a single small RPC, the other is a long
transfer with progress and an integrity check.

### Platform channel

`AppSystemService` already owns the `viet_ktv/system` channel (`getSystemInfo`,
`restartApp`, `shutdownDevice`, `requestNotificationPermission`). The update
work extends it rather than adding a plugin dependency:

- `AppSystemInfo` gains `appVersionCode` (int). The existing `appVersion` is
  the display string; comparison must use the code, never the name.
- `canInstallPackages()` → bool
- `openInstallPermissionSettings()` → void
- `installApk(String path)` → void

Kotlin side: three new branches in `onSystemMethodCall`, plus
`REQUEST_INSTALL_PACKAGES` in the manifest. Installation uses `PackageInstaller`
sessions, which take a stream rather than a URI and so need no `FileProvider`
declaration.

### State machine

```
idle ──check──▶ checking ──▶ upToDate
                         └─▶ available ──update──▶ downloading(progress)
                                                 ──▶ verifying
                                                 ──▶ installing (system UI takes over)
        any step ──▶ error(message, retryable)
```

`idle` shows the installed version and a *Kiểm tra* button. `upToDate` shows
"no new version". `available` shows the new version name, `notes`, and a
*Cập nhật* button.

## Failure Handling

| Situation | Behaviour |
| --- | --- |
| No network / RPC throws | `error`, message about the connection, retry available |
| `latest_release()` returns null | `upToDate` — an empty table is not an error |
| Remote `version_code` <= installed | `upToDate` |
| Download interrupted | `error`, partial file deleted, retry available |
| SHA-256 mismatch | `error`, file deleted, **`installApk` is never called** |
| Install permission not granted | Explain, and offer a button opening the system screen |
| User cancels the system installer | Return to `available`; the app is untouched |

The APK downloads into the app's private cache directory, so no storage
permission is involved and Android reclaims the space on its own.

The checksum check is not optional. A truncated 145 MB download otherwise
reaches the system installer and fails with a parse error that tells the user
nothing.

## Testing

Whether the OS installer actually runs cannot be tested in a widget test; the
platform channel and the downloader are faked. What is tested:

- `AppRelease` parses the RPC payload, and a `null` payload yields no release.
- Controller transitions: idle → checking → upToDate; idle → checking →
  available; and the error branch from each step.
- Version comparison uses `version_code`: a lower remote code and an equal one
  both read as `upToDate`, so a downgrade can never be offered.
- A checksum mismatch produces `error` **and** leaves `installApk` uncalled —
  asserted on the fake, since this is the guard that matters most.
- Missing install permission routes to the permission prompt rather than
  attempting the install.

## Rollout Note

The devices already in the field have no updater. The first build carrying this
feature must be installed by hand, exactly as today. Everything after that can
update itself.

Two risks outside this feature's code, both worth resolving before it ships:

- `~/.android/debug.keystore` is not backed up. Stated above, repeated here
  because it is the one item that makes the whole feature moot if missed.
- `backend/` and `app-admin/` are not in any git repository. The schema and
  migrations for a licensing system already running on customer hardware exist
  only on one disk. This spec adds a migration to that same unversioned
  directory.
