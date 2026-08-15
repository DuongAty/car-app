import 'dart:async';

import 'package:viet_ktv/core/services/volume_service.dart';

/// Stands in for the platform audio service.
class FakeVolumeService implements VolumeService {
  FakeVolumeService({this.initial = 0.25});

  final double? initial;
  final List<double> written = [];
  final StreamController<double> _changes =
      StreamController<double>.broadcast();

  /// Simulates the hardware volume keys.
  void emitExternalChange(double level) => _changes.add(level);

  @override
  Future<double?> read() async => initial;

  @override
  Future<void> write(double level) async => written.add(level);

  @override
  Stream<double> get changes => _changes.stream;

  @override
  Future<void> dispose() async => _changes.close();
}
