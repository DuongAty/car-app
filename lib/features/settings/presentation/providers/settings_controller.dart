import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/local_storage_provider.dart';
import '../../../../core/providers/volume_provider.dart';
import '../../../queue/presentation/providers/queue_provider.dart';
import '../../data/models/app_settings.dart';
import '../../data/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => SettingsRepository(ref.watch(localStorageServiceProvider)),
);

final settingsControllerProvider =
    StateNotifierProvider<SettingsController, AppSettings>(
      (ref) => SettingsController(ref, ref.watch(settingsRepositoryProvider)),
    );

class SettingsController extends StateNotifier<AppSettings> {
  SettingsController(this._ref, this._repository) : super(const AppSettings()) {
    _ref.listen<QueueState>(queueProvider, (_, queue) {
      _syncFromQueue(queue);
    });
    unawaited(_load());
  }

  final Ref _ref;
  final SettingsRepository _repository;

  Future<void> _load() async {
    final settings = await _repository.load();
    if (!mounted) {
      return;
    }
    state = settings;
    _applyQueueSettings(settings);
  }

  void _set(AppSettings next) {
    state = next;
    unawaited(_repository.save(next));
  }

  void _applyQueueSettings(AppSettings settings) {
    final queue = _ref.read(queueProvider.notifier);
    queue.setQueueRepeatMode(
      settings.repeatOne
          ? QueueRepeatMode.one
          : settings.repeatAll
          ? QueueRepeatMode.all
          : QueueRepeatMode.off,
    );
    queue.setShuffle(settings.shuffle);
  }

  void _syncFromQueue(QueueState queue) {
    final repeatAll = queue.repeatMode == QueueRepeatMode.all;
    final repeatOne = queue.repeatMode == QueueRepeatMode.one;
    if (state.repeatAll == repeatAll &&
        state.repeatOne == repeatOne &&
        state.shuffle == queue.shuffle) {
      return;
    }
    _set(
      state.copyWith(
        repeatAll: repeatAll,
        repeatOne: repeatOne,
        shuffle: queue.shuffle,
      ),
    );
  }

  void selectCategory(SettingsCategory category) {
    state = state.copyWith(selectedCategory: category);
  }

  void selectVideoQuality(VideoQuality quality) {
    _set(state.copyWith(videoQuality: quality));
  }

  void setContinuousPlayback(bool value) {
    _set(state.copyWith(continuousPlayback: value));
  }

  void setRepeatAll(bool value) {
    final next = state.copyWith(
      repeatAll: value,
      repeatOne: value ? false : null,
    );
    _set(next);
    _applyQueueSettings(next);
  }

  void setRepeatOne(bool value) {
    final next = state.copyWith(
      repeatOne: value,
      repeatAll: value ? false : null,
    );
    _set(next);
    _applyQueueSettings(next);
  }

  void setShuffle(bool value) {
    final next = state.copyWith(shuffle: value);
    _set(next);
    _ref.read(queueProvider.notifier).setShuffle(value);
  }

  void stepBuffer(int delta) {
    final next = (state.bufferSeconds + delta).clamp(3, 15);
    _set(state.copyWith(bufferSeconds: next));
  }

  void setAutoPlayMv(bool value) {
    _set(state.copyWith(autoPlayMv: value));
  }

  void setShowCaptions(bool value) {
    _set(state.copyWith(showCaptions: value));
  }

  void setDemoVideoEnabled(bool value) {
    _set(state.copyWith(demoVideoEnabled: value));
  }

  void setMasterVolume(double value) {
    _set(state.copyWith(masterVolume: value));
    unawaited(_ref.read(volumeProvider.notifier).setLevel(value));
  }

  void setMusicVolume(double value) {
    _set(state.copyWith(musicVolume: value));
  }

  void setVocalBoost(bool value) {
    _set(state.copyWith(vocalBoost: value));
  }

  void setLyricScale(double value) {
    _set(state.copyWith(lyricScale: value));
  }

  void setVisualizerEnabled(bool value) {
    _set(state.copyWith(visualizerEnabled: value));
  }

  void setGlowLevel(double value) {
    _set(state.copyWith(glowLevel: value));
  }

  void setParticlesEnabled(bool value) {
    _set(state.copyWith(particlesEnabled: value));
  }
}
