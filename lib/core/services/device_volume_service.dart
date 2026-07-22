import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';

import 'volume_service.dart';

/// Reads and writes the real Android media volume.
///
/// Every platform call is guarded: on a host without the plugin registered the
/// channel throws, and the karaoke screens must still render rather than fail
/// on a missing audio service.
class DeviceVolumeService implements VolumeService {
  DeviceVolumeService() {
    // The app draws its own volume bar, so suppress the system overlay that
    // would otherwise pop up on every change.
    unawaited(_silenceSystemUi());
  }

  final StreamController<double> _changes =
      StreamController<double>.broadcast();
  StreamSubscription<double>? _platformListener;
  bool _unavailable = false;

  Future<void> _silenceSystemUi() async {
    try {
      await FlutterVolumeController.updateShowSystemUI(false);
    } on PlatformException {
      // Non-fatal: the system overlay stays visible.
    } on MissingPluginException {
      _unavailable = true;
    }
  }

  @override
  Future<double?> read() async {
    if (_unavailable) {
      return null;
    }

    try {
      return await FlutterVolumeController.getVolume();
    } on MissingPluginException {
      _unavailable = true;
      return null;
    } on PlatformException {
      return null;
    }
  }

  @override
  Future<void> write(double level) async {
    if (_unavailable) {
      return;
    }

    try {
      await FlutterVolumeController.setVolume(level.clamp(0.0, 1.0));
    } on MissingPluginException {
      _unavailable = true;
    } on PlatformException {
      // Ignore: a failed write leaves the device at its previous volume.
    }
  }

  @override
  Stream<double> get changes {
    _platformListener ??= _startListening();
    return _changes.stream;
  }

  StreamSubscription<double>? _startListening() {
    if (_unavailable) {
      return null;
    }

    try {
      // emitOnStart is off: the initial value comes from [read], and echoing it
      // here would fight the optimistic update after a user drag.
      return FlutterVolumeController.addListener(
        _changes.add,
        emitOnStart: false,
      );
    } on MissingPluginException {
      _unavailable = true;
      return null;
    }
  }

  @override
  Future<void> dispose() async {
    await _platformListener?.cancel();
    _platformListener = null;
    FlutterVolumeController.removeListener();
    await _changes.close();
  }
}
