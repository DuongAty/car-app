import 'dart:async';

import 'package:viet_ktv/features/app_update/data/app_update_repository.dart';
import 'package:viet_ktv/features/app_update/data/models/app_release.dart';

/// Fake update backend. [release] is returned as-is; setting [error] makes
/// the call throw instead, so tests can drive both the "no release" and the
/// "server unreachable" paths without a network. Pass [gate] to hold the call
/// open until the test completes it, so overlapping calls can be tested for
/// real rather than simulated.
class FakeAppUpdateRepository implements AppUpdateRepository {
  FakeAppUpdateRepository({this.release, this.error, this.gate});

  AppRelease? release;
  Object? error;
  int callCount = 0;
  final Completer<void>? gate;

  @override
  Future<AppRelease?> latestRelease() async {
    callCount++;
    final gate = this.gate;
    if (gate != null) {
      await gate.future;
    }
    final thrown = error;
    if (thrown != null) {
      throw thrown;
    }
    return release;
  }
}
