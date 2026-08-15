import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:viet_ktv/core/providers/volume_provider.dart';

import 'support/fake_volume_service.dart';

/// Provider-level volume behaviour, independent of any screen. The rail entry
/// and its popup are covered in `features/navigation/nav_rail_volume_test.dart`.
Future<ProviderContainer> _container(FakeVolumeService service) async {
  final container = ProviderContainer(
    overrides: [volumeServiceProvider.overrideWithValue(service)],
  );
  addTearDown(container.dispose);
  // Let the provider's initial read() settle.
  container.read(volumeProvider);
  await Future<void>.delayed(Duration.zero);
  return container;
}

void main() {
  test('reads_the_volume_reported_by_the_device', () async {
    final container = await _container(FakeVolumeService(initial: 0.42));

    expect(container.read(volumeProvider).level, closeTo(0.42, 0.001));
    expect(container.read(volumeProvider).isAvailable, isTrue);
  });

  test('writes_to_the_device_when_the_level_is_set', () async {
    final service = FakeVolumeService(initial: 0.1);
    final container = await _container(service);

    await container.read(volumeProvider.notifier).setLevel(0.9);

    expect(service.written, isNotEmpty);
    expect(service.written.last, closeTo(0.9, 0.001));
    expect(container.read(volumeProvider).level, closeTo(0.9, 0.001));
  });

  test('follows_volume_changed_outside_the_app', () async {
    final service = FakeVolumeService(initial: 0.2);
    final container = await _container(service);

    // The hardware keys moved the volume; the app state must follow without
    // writing back, or the two would fight each other.
    service.emitExternalChange(0.8);
    await Future<void>.delayed(Duration.zero);

    expect(container.read(volumeProvider).level, closeTo(0.8, 0.001));
    expect(service.written, isEmpty);
  });

  test('reports_unavailable_when_the_device_has_no_volume_service', () async {
    final container = await _container(FakeVolumeService(initial: null));

    expect(container.read(volumeProvider).isAvailable, isFalse);
  });
}
