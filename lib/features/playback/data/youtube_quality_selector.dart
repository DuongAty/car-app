import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../settings/data/models/app_settings.dart';

class YoutubeQualitySelector {
  const YoutubeQualitySelector();

  Future<String> selectPlayableUrl(String url, VideoQuality quality) async {
    if (quality == VideoQuality.auto || !_looksLikeHls(url)) {
      return url;
    }

    final client = HttpClient();
    try {
      final playlist = await _readUrl(client, Uri.parse(url));
      final variants = _parseVariants(playlist, Uri.parse(url));
      final selected = _selectVariant(variants, _targetHeight(quality));
      return selected?.url.toString() ?? url;
    } catch (_) {
      return url;
    } finally {
      client.close(force: true);
    }
  }

  bool _looksLikeHls(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }
    return uri.path.toLowerCase().endsWith('.m3u8') ||
        uri.query.toLowerCase().contains('m3u8');
  }

  Future<String> _readUrl(HttpClient client, Uri uri) async {
    final request = await client
        .getUrl(uri)
        .timeout(const Duration(seconds: 5));
    final response = await request.close().timeout(const Duration(seconds: 8));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw const HttpException('HLS playlist request failed.');
    }
    return response.transform(utf8.decoder).join();
  }

  List<_HlsVariant> _parseVariants(String playlist, Uri baseUri) {
    final lines = playlist
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final variants = <_HlsVariant>[];

    for (var index = 0; index < lines.length - 1; index++) {
      final line = lines[index];
      if (!line.startsWith('#EXT-X-STREAM-INF:')) {
        continue;
      }
      final next = lines[index + 1];
      if (next.startsWith('#')) {
        continue;
      }
      final height = _parseHeight(line);
      if (height == null) {
        continue;
      }
      variants.add(_HlsVariant(url: baseUri.resolve(next), height: height));
    }

    return variants;
  }

  _HlsVariant? _selectVariant(List<_HlsVariant> variants, int targetHeight) {
    if (variants.isEmpty) {
      return null;
    }
    final sorted = [...variants]..sort((a, b) => a.height.compareTo(b.height));
    for (final variant in sorted.reversed) {
      if (variant.height <= targetHeight) {
        return variant;
      }
    }
    return sorted.first;
  }

  int? _parseHeight(String streamInfo) {
    final match = RegExp(r'RESOLUTION=\d+x(\d+)').firstMatch(streamInfo);
    return int.tryParse(match?.group(1) ?? '');
  }

  int _targetHeight(VideoQuality quality) {
    return switch (quality) {
      VideoQuality.fourK => 2160,
      VideoQuality.fullHd => 1080,
      VideoQuality.hd => 720,
      VideoQuality.sd => 480,
      VideoQuality.auto => 0,
    };
  }
}

class _HlsVariant {
  const _HlsVariant({required this.url, required this.height});

  final Uri url;
  final int height;
}
