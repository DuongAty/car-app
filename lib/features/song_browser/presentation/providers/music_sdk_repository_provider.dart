import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/services/music_sdk_platform.dart';
import '../../data/music_sdk_song_repository.dart';

final musicSdkPlatformProvider = Provider<MusicSdkPlatform>(
  (ref) => MethodChannelMusicSdkPlatform(),
);

final musicSdkSongRepositoryProvider = Provider<MusicSdkSongRepository>(
  (ref) => MusicSdkSongRepository(ref.watch(musicSdkPlatformProvider)),
);
