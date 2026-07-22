import 'dart:developer' as developer;

import 'music_sdk_platform.dart';

const String _musicSdkLicenseKey = String.fromEnvironment(
  'MUSIC_SDK_LICENSE_KEY',
);

Future<void> bootstrapMusicSdk({MusicSdkPlatform? platform}) async {
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
