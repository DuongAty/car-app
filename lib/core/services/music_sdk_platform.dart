import 'package:flutter/services.dart';

import '../../features/source_selection/data/models/music_source.dart';

class MusicSdkTrack {
  const MusicSdkTrack({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.duration,
    this.imageUrl,
    this.badge,
  });

  factory MusicSdkTrack.fromMap(Map<Object?, Object?> map) {
    return MusicSdkTrack(
      id: map['id'] as String? ?? '',
      title: map['title'] as String? ?? '',
      subtitle: map['subtitle'] as String? ?? '',
      duration: map['duration'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      badge: map['badge'] as String?,
    );
  }

  final String id;
  final String title;
  final String subtitle;
  final String duration;
  final String? imageUrl;
  final String? badge;
}

abstract class MusicSdkPlatform {
  Future<void> initialize(String licenseKey);

  Future<List<MusicSdkTrack>> search({
    required MusicSourceLogoStyle source,
    required String query,
  });

  Future<String> getPlayableLink({
    required MusicSourceLogoStyle source,
    required String trackId,
  });
}

class MethodChannelMusicSdkPlatform implements MusicSdkPlatform {
  MethodChannelMusicSdkPlatform({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(_channelName);

  static const String _channelName = 'viet_ktv/music_sdk';

  final MethodChannel _channel;

  @override
  Future<void> initialize(String licenseKey) async {
    await _channel.invokeMethod<void>('init', {'licenseKey': licenseKey});
  }

  @override
  Future<String> getPlayableLink({
    required MusicSourceLogoStyle source,
    required String trackId,
  }) async {
    final result = await _channel.invokeMethod<String>('getPlayableLink', {
      'source': source.name,
      'trackId': trackId,
    });

    if (result == null || result.isEmpty) {
      throw PlatformException(
        code: 'empty_playable_link',
        message: 'MusicSDK returned an empty playable link.',
      );
    }

    return result;
  }

  @override
  Future<List<MusicSdkTrack>> search({
    required MusicSourceLogoStyle source,
    required String query,
  }) async {
    final result = await _channel.invokeListMethod<Map<Object?, Object?>>(
      'search',
      {'source': source.name, 'query': query},
    );

    return (result ?? const [])
        .map(MusicSdkTrack.fromMap)
        .where((track) => track.id.isNotEmpty && track.title.isNotEmpty)
        .toList(growable: false);
  }
}
