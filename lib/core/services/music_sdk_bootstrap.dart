import 'dart:developer' as developer;

import 'music_sdk_platform.dart';

const String _musicSdkLicenseKey = String.fromEnvironment(
  'MUSIC_SDK_LICENSE_KEY',
);

Future<void>? _initialization;

/// Kicks off native MusicSDK initialization once and returns a cached future.
///
/// Called at startup WITHOUT awaiting, so the native SDK handshake never blocks
/// the first frame (the launch screen doesn't need the SDK). The repository
/// awaits this same cached future before its first network call, so the first
/// search/playback can never race an unfinished init.
Future<void> ensureMusicSdkInitialized({MusicSdkPlatform? platform}) {
  // With no license key (all tests, and dev runs without the define) there is
  // nothing to initialize. Return a fresh completed future rather than caching
  // one in a module global — a single cached Future awaited across many
  // flutter_test zones is a classic source of hangs.
  if (_musicSdkLicenseKey.isEmpty) {
    return Future<void>.value();
  }
  return _initialization ??= _initialize(platform);
}

Future<void> _initialize(MusicSdkPlatform? platform) async {
  if (_musicSdkLicenseKey.isEmpty) {
    return;
  }

  try {
    await (platform ?? MethodChannelMusicSdkPlatform()).initialize(
      _musicSdkLicenseKey,
    );
  } catch (error, stackTrace) {
    developer.log(
      'MusicSDK initialization failed',
      name: 'viet_ktv.music_sdk',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
