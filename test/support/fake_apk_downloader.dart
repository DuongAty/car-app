import 'dart:async';

import 'package:viet_ktv/features/app_update/data/apk_downloader.dart';

/// Fake downloader. Returns [digest] without touching the disk, so controller
/// tests can drive the checksum-match and checksum-mismatch paths directly.
/// Pass [gate] to hold the download open until the test completes it, so
/// overlapping calls can be tested for real rather than simulated.
class FakeApkDownloader implements ApkDownloader {
  FakeApkDownloader({
    this.digest = '',
    this.error,
    this.gate,
    this.progressSequence,
  });

  String digest;
  Object? error;
  final Completer<void>? gate;

  /// Progress fractions to report, in order. Defaults to a coarse two-step
  /// sequence; pass a long one to exercise per-chunk throttling.
  final List<double>? progressSequence;

  String? lastUrl;
  String? lastDestination;
  int callCount = 0;
  final List<double> reportedProgress = <double>[];

  @override
  Future<String> download({
    required String url,
    required String destinationPath,
    required void Function(double progress) onProgress,
  }) async {
    callCount++;
    lastUrl = url;
    lastDestination = destinationPath;
    final gate = this.gate;
    if (gate != null) {
      await gate.future;
    }
    final thrown = error;
    if (thrown != null) {
      throw thrown;
    }
    for (final progress in progressSequence ?? const <double>[0.5, 1]) {
      onProgress(progress);
      reportedProgress.add(progress);
    }
    return digest;
  }
}
