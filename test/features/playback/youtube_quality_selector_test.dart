import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/features/playback/data/youtube_quality_selector.dart';
import 'package:viet_ktv/features/settings/data/models/app_settings.dart';

void main() {
  test('selects_hd_variant_from_hls_master_playlist', () async {
    final server = await _HlsTestServer.start();
    addTearDown(server.close);

    final selector = YoutubeQualitySelector();
    final url = await selector.selectPlayableUrl(
      server.masterUrl,
      VideoQuality.hd,
    );

    expect(url, server.variantUrl('720.m3u8'));
  });

  test('selects_sd_variant_from_hls_master_playlist', () async {
    final server = await _HlsTestServer.start();
    addTearDown(server.close);

    final selector = YoutubeQualitySelector();
    final url = await selector.selectPlayableUrl(
      server.masterUrl,
      VideoQuality.sd,
    );

    expect(url, server.variantUrl('480.m3u8'));
  });

  test('keeps_non_hls_url_unchanged', () async {
    const selector = YoutubeQualitySelector();
    const url = 'https://example.test/video.mp4';

    expect(await selector.selectPlayableUrl(url, VideoQuality.hd), url);
  });
}

class _HlsTestServer {
  _HlsTestServer(this._server);

  final HttpServer _server;

  String get masterUrl => 'http://localhost:${_server.port}/master.m3u8';

  String variantUrl(String name) => 'http://localhost:${_server.port}/$name';

  static Future<_HlsTestServer> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final wrapper = _HlsTestServer(server);
    server.listen(wrapper._handleRequest);
    return wrapper;
  }

  Future<void> close() => _server.close(force: true);

  void _handleRequest(HttpRequest request) {
    request.response.headers.contentType = ContentType(
      'application',
      'vnd.apple.mpegurl',
    );
    request.response.write('''
#EXTM3U
#EXT-X-STREAM-INF:BANDWIDTH=900000,RESOLUTION=854x480
480.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1800000,RESOLUTION=1280x720
720.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=3500000,RESOLUTION=1920x1080
1080.m3u8
''');
    request.response.close();
  }
}
