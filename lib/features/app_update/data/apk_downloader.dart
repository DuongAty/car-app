import 'dart:io';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

abstract interface class ApkDownloader {
  /// Streams [url] into [destinationPath] and returns the lowercase hex
  /// SHA-256 of what was written.
  ///
  /// The digest is returned rather than checked here so the comparison can
  /// live in the controller, where it is testable without a file system.
  /// Throws on any transport failure, leaving no file behind.
  ///
  /// [onProgress] is only called when the server declares a `Content-Length`
  /// for the response. Some servers stream without one (e.g. chunked
  /// transfer encoding), in which case a fraction of the total cannot be
  /// computed and [onProgress] is never invoked, not even once at the end.
  /// Callers must tolerate never receiving a progress callback.
  Future<String> download({
    required String url,
    required String destinationPath,
    required void Function(double progress) onProgress,
  });
}

class HttpApkDownloader implements ApkDownloader {
  const HttpApkDownloader();

  /// Time allowed to establish the TCP connection to the update server.
  static const _connectTimeout = Duration(seconds: 30);

  /// Time allowed with no bytes arriving before the transfer is aborted.
  ///
  /// This is deliberately an *idle* timeout, not a total deadline: a healthy
  /// 145 MB download over slow car wifi or a phone hotspot can legitimately
  /// take several minutes, and a single overall timeout would kill it.
  /// `Stream.timeout` resets on every event, so this only fires when the
  /// connection has genuinely stalled.
  static const _idleTimeout = Duration(seconds: 60);

  @override
  Future<String> download({
    required String url,
    required String destinationPath,
    required void Function(double progress) onProgress,
  }) async {
    final file = File(destinationPath);
    final client = HttpClient()..connectionTimeout = _connectTimeout;
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
      await for (final chunk in response.timeout(_idleTimeout)) {
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
      // A half-written file would be installed on the next attempt. Closing
      // a sink that is carrying a pending write error re-throws that error
      // on every call, which would otherwise skip the delete below and mask
      // the original failure with an unrelated close error.
      try {
        await sink?.close();
      } catch (_) {
        // Ignored: the original error is what must propagate.
      }
      if (file.existsSync()) {
        await file.delete();
      }
      rethrow;
    } finally {
      client.close(force: true);
    }
  }
}
