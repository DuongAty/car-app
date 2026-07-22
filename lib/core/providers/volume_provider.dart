import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/device_volume_service.dart';
import '../services/volume_service.dart';

/// Override this in tests to avoid touching the platform audio service.
final volumeServiceProvider = Provider<VolumeService>((ref) {
  final service = DeviceVolumeService();
  ref.onDispose(service.dispose);
  return service;
});

final volumeProvider = StateNotifierProvider<VolumeController, VolumeState>(
  (ref) => VolumeController(ref.watch(volumeServiceProvider)),
);

class VolumeState {
  const VolumeState({this.level = 0, this.isAvailable = false});

  /// Media volume from 0.0 to 1.0.
  final double level;

  /// False until the device reports a volume. Stays false on platforms with no
  /// volume control, which is the cue to render the bar as inert.
  final bool isAvailable;

  int get percent => (level * 100).round();

  VolumeState copyWith({double? level, bool? isAvailable}) {
    return VolumeState(
      level: level ?? this.level,
      isAvailable: isAvailable ?? this.isAvailable,
    );
  }
}

class VolumeController extends StateNotifier<VolumeState> {
  VolumeController(this._service) : super(const VolumeState()) {
    unawaited(_load());
  }

  final VolumeService _service;
  StreamSubscription<double>? _subscription;

  Future<void> _load() async {
    final level = await _service.read();
    if (!mounted) {
      return;
    }
    if (level == null) {
      return;
    }

    state = state.copyWith(level: level, isAvailable: true);

    // Keeps the bar in sync when the volume is changed from outside the app,
    // e.g. the hardware keys on the remote.
    _subscription = _service.changes.listen((value) {
      if (mounted) {
        state = state.copyWith(level: value);
      }
    });
  }

  /// Applies [level] optimistically so dragging stays smooth, then pushes it to
  /// the device.
  Future<void> setLevel(double level) async {
    if (!state.isAvailable) {
      return;
    }

    final clamped = level.clamp(0.0, 1.0);
    state = state.copyWith(level: clamped);
    await _service.write(clamped);
  }

  Future<void> nudge(double delta) => setLevel(state.level + delta);

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
