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
    return 'http://${server.address.address}:${server.port}/wetube.apk';
  }

  test('writes_the_body_and_returns_its_sha256', () async {
    // sha256("wetube") — a known digest, so the test proves the hash is of
    // the written bytes rather than of whatever the implementation felt like.
    final url = await serve('wetube'.codeUnits);
    final destination = '${tempDir.path}/update.apk';

    final digest = await const HttpApkDownloader().download(
      url: url,
      destinationPath: destination,
      onProgress: (_) {},
    );

    expect(File(destination).readAsStringSync(), 'wetube');
    expect(
      digest,
      '498a42859a4ff2356615ccb59a491888ebf2034776e42227fb8f9bae07090235',
    );
  });

  test('reports_progress_between_zero_and_one', () async {
    // NOTE: this only proves 0 <= progress <= 1 and that the final value is
    // ~1. A stronger version that serves several explicit writes with a
    // flush between them (to force >1 chunk) was tried and is flaky: under
    // load (e.g. running the whole suite) loopback still coalesces the
    // writes into a single read on the client side, so the assertion that
    // more than one onProgress call happened fails intermittently. Kept as
    // the weaker, reliable assertion per the instruction not to ship a
    // flaky test.
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

  test('reports_no_progress_when_server_omits_content_length', () async {
    // sha256("wetube") again, but served without a Content-Length header
    // (chunked transfer encoding) so the total size is unknowable.
    final body = 'wetube'.codeUnits;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      request.response.statusCode = 200;
      // Deliberately not setting headers.contentLength: Dart's HttpServer
      // then falls back to chunked transfer encoding.
      request.response.add(body);
      await request.response.close();
    });
    final url = 'http://${server.address.address}:${server.port}/wetube.apk';
    final destination = '${tempDir.path}/update.apk';

    final progress = <double>[];
    final digest = await const HttpApkDownloader().download(
      url: url,
      destinationPath: destination,
      onProgress: progress.add,
    );

    expect(File(destination).readAsStringSync(), 'wetube');
    expect(
      digest,
      '498a42859a4ff2356615ccb59a491888ebf2034776e42227fb8f9bae07090235',
    );
    expect(progress, isEmpty);
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
