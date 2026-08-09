import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/services/music_sdk_bootstrap.dart';
import 'core/services/supabase_bootstrap.dart';
import 'features/playback/data/karaoke_audio_handler.dart';
import 'features/playback/presentation/providers/background_playback_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _tuneImageCacheForTvBox();
  // Start native SDK init in the background — do NOT await it here, or the
  // blank native window stays up until the handshake returns. The repository
  // awaits the same cached future before its first call.
  unawaited(ensureMusicSdkInitialized());
  // Same shape: the license repository awaits this cached future before its
  // first RPC call, so the splash screen is never blocked on it either.
  unawaited(ensureSupabaseInitialized());

  // The handler needs the controllers, but AudioService.init must run before
  // runApp. Building the container here lets the handler hold a working
  // target from the very first media-button press.
  final container = ProviderContainer();

  audioHandler = await AudioService.init(
    builder: () => KaraokeAudioHandler(container),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.example.viet_ktv.playback',
      androidNotificationChannelName: 'Phát nhạc',
      // Without this, audio_service defaults to `mipmap/ic_launcher`. Android
      // uses only the alpha channel of a notification's small icon, so a
      // full-colour launcher icon renders as a white blob on the status bar.
      androidNotificationIcon: 'drawable/ic_notification',
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: true,
    ),
  );

  runApp(
    UncontrolledProviderScope(container: container, child: const VietKtvApp()),
  );
}

void _tuneImageCacheForTvBox() {
  final imageCache = PaintingBinding.instance.imageCache;
  // A TV browse screen never needs dozens of full-size images alive at once.
  // Keep both the entry and byte budgets bounded for 2GB ARM32 boxes.
  imageCache.maximumSize = 50;
  imageCache.maximumSizeBytes = 32 << 20;
}
