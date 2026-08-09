import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/features/queue/presentation/providers/queue_provider.dart';
import 'package:viet_ktv/features/settings/data/models/app_settings.dart';
import 'package:viet_ktv/features/settings/presentation/providers/settings_controller.dart';

import '../../support/fake_local_storage_service.dart';

Future<void> _waitForSettingsLoad() => Future<void>.delayed(Duration.zero);

void main() {
  test('settings_persist_and_apply_queue_playback_modes', () async {
    final storage = FakeLocalStorageService();
    final container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );

    final controller = container.read(settingsControllerProvider.notifier);
    await _waitForSettingsLoad();
    controller.setContinuousPlayback(false);
    controller.setRepeatAll(true);
    controller.setShuffle(true);
    await _waitForSettingsLoad();

    expect(
      container.read(settingsControllerProvider).continuousPlayback,
      isFalse,
    );
    expect(container.read(queueProvider).repeatMode, QueueRepeatMode.all);
    expect(container.read(queueProvider).shuffle, isTrue);

    container.read(queueProvider.notifier).cycleQueueRepeatMode();
    container.read(queueProvider.notifier).toggleShuffle();
    await _waitForSettingsLoad();
    expect(container.read(settingsControllerProvider).repeatOne, isTrue);
    expect(container.read(settingsControllerProvider).repeatAll, isFalse);
    expect(container.read(settingsControllerProvider).shuffle, isFalse);

    container.dispose();
    final restoredContainer = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
    );
    addTearDown(restoredContainer.dispose);
    await _waitForSettingsLoad();

    restoredContainer.read(settingsControllerProvider.notifier);
    await _waitForSettingsLoad();
    final restored = restoredContainer.read(settingsControllerProvider);
    expect(restored.continuousPlayback, isFalse);
    expect(restored.repeatOne, isTrue);
    expect(restored.shuffle, isFalse);
  });

  test('invalid_saved_settings_fall_back_to_defaults', () {
    final settings = AppSettings.decode('{not-json}');
    expect(settings.continuousPlayback, isTrue);
    expect(settings.videoQuality, VideoQuality.hd);
  });

  test('legacy_settings_are_migrated_to_box_performance_defaults', () {
    final settings = AppSettings.decode(
      '{"visualizerEnabled":true,"particlesEnabled":true,"glowLevel":0.9}',
    );

    expect(settings.visualizerEnabled, isFalse);
    expect(settings.particlesEnabled, isFalse);
    expect(settings.glowLevel, 0.42);
    expect(settings.performanceDefaultsVersion, 2);
  });

  test('current_settings_keep_user_visual_effect_choices', () {
    final settings = AppSettings.decode(
      '{"visualizerEnabled":true,"particlesEnabled":true,'
      '"glowLevel":0.9,"performanceDefaultsVersion":2}',
    );

    expect(settings.visualizerEnabled, isTrue);
    expect(settings.particlesEnabled, isTrue);
    expect(settings.glowLevel, 0.9);
  });
}
