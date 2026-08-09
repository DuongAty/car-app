import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../playback/presentation/providers/now_playing_controller.dart';
import '../../../settings/presentation/providers/settings_controller.dart';
import '../../data/models/queued_song.dart';
import 'queue_provider.dart';

final queuePlaybackControllerProvider =
    StateNotifierProvider<QueuePlaybackController, QueuePlaybackState>((ref) {
      final nowPlaying = ref.watch(nowPlayingProvider.notifier);
      final controller = QueuePlaybackController(
        ref.watch(queueProvider.notifier),
        nowPlaying,
      );
      ref.listen<bool>(
        settingsControllerProvider.select((value) => value.continuousPlayback),
        (_, enabled) => controller.setContinuousPlayback(enabled),
        fireImmediately: true,
      );
      nowPlaying.setOnCompleted(controller.playNext);
      ref.onDispose(() => nowPlaying.setOnCompleted(null));
      return controller;
    });

class QueuePlaybackState {
  const QueuePlaybackState({
    this.history = const [],
    this.historyIndex,
    this.currentItem,
  });

  final List<QueuedSong> history;
  final int? historyIndex;
  final QueuedSong? currentItem;

  QueuePlaybackState copyWith({
    List<QueuedSong>? history,
    int? historyIndex,
    QueuedSong? currentItem,
  }) {
    return QueuePlaybackState(
      history: history ?? this.history,
      historyIndex: historyIndex ?? this.historyIndex,
      currentItem: currentItem ?? this.currentItem,
    );
  }
}

class QueuePlaybackController extends StateNotifier<QueuePlaybackState> {
  QueuePlaybackController(this._queue, this._nowPlaying, {math.Random? random})
    : _random = random ?? math.Random(),
      super(const QueuePlaybackState());

  final QueueController _queue;
  final NowPlayingController _nowPlaying;
  bool _continuousPlayback = true;
  final math.Random _random;

  // The back-stack is capped so an always-on box on repeat-all doesn't grow the
  // history list without bound over days of continuous playback. 50 covers far
  // more "previous" presses than anyone uses in one sitting.
  static const int _maxHistory = 50;

  Future<void> playAt(int index) async {
    final items = _queue.state.items;
    if (index < 0 || index >= items.length) {
      return;
    }
    final item = items[index];
    await _appendAndPlay(item);
  }

  Future<void> playNext({bool fromCompletion = false}) async {
    if (fromCompletion && !_continuousPlayback) {
      return;
    }
    final repeatMode = _queue.state.repeatMode;
    final currentItem = state.currentItem;
    final items = _queue.state.items;

    // Repeat-one overrides everything else: replay the current track. This
    // must be checked before the `items.isEmpty` bail-out below — repeat-one
    // means "replay whatever is currently playing" regardless of whether the
    // queue has anything in it or whether playback started from the queue at
    // all (e.g. a song played directly from search results, where the queue
    // is empty and `currentItem` is never set). If nothing has ever been
    // queued either, fall back to replaying the live nowPlaying track;
    // otherwise (nothing playing yet, but the queue has items) fall through
    // to the normal start-of-queue logic below.
    if (repeatMode == QueueRepeatMode.one) {
      if (currentItem != null) {
        await _play(currentItem);
        return;
      }
      if (items.isEmpty) {
        await _nowPlaying.replayFromStart();
        return;
      }
    }

    if (items.isEmpty) {
      return;
    }

    final currentIndex = _indexOf(items, currentItem);
    if (currentIndex == -1) {
      await _appendAndPlay(items[_initialIndex(items)]);
      return;
    }

    if (repeatMode == QueueRepeatMode.all) {
      await _appendAndPlay(items[_nextLoopIndex(items, currentIndex)]);
      return;
    }

    final nextIndex = _nextNonLoopIndex(items, currentIndex);
    if (nextIndex == null) {
      return;
    }

    final previousItem = currentItem;
    await _appendAndPlay(items[nextIndex]);
    final previousIndex = _indexOf(_queue.state.items, previousItem);
    if (previousIndex != -1) {
      _queue.removeAt(previousIndex);
    }
  }

  void setContinuousPlayback(bool enabled) {
    _continuousPlayback = enabled;
  }

  Future<void> playPrevious() async {
    final historyIndex = state.historyIndex;
    if (historyIndex == null || historyIndex <= 0) {
      return;
    }

    final previousIndex = historyIndex - 1;
    final previousItem = state.history[previousIndex];
    state = QueuePlaybackState(
      history: state.history,
      historyIndex: previousIndex,
      currentItem: previousItem,
    );
    await _play(previousItem);
  }

  int _indexOf(List<QueuedSong> items, QueuedSong? item) {
    if (item == null) {
      return -1;
    }
    return items.indexWhere((candidate) => identical(candidate, item));
  }

  int _initialIndex(List<QueuedSong> items) {
    return _queue.state.shuffle ? _random.nextInt(items.length) : 0;
  }

  int _nextLoopIndex(List<QueuedSong> items, int currentIndex) {
    if (!_queue.state.shuffle || items.length == 1) {
      return (currentIndex + 1) % items.length;
    }
    final candidates = [
      for (var index = 0; index < items.length; index++)
        if (index != currentIndex) index,
    ];
    return candidates[_random.nextInt(candidates.length)];
  }

  int? _nextNonLoopIndex(List<QueuedSong> items, int currentIndex) {
    if (_queue.state.shuffle) {
      final candidates = [
        for (var index = 0; index < items.length; index++)
          if (index != currentIndex) index,
      ];
      return candidates.isEmpty
          ? null
          : candidates[_random.nextInt(candidates.length)];
    }
    final nextIndex = currentIndex + 1;
    return nextIndex < items.length ? nextIndex : null;
  }

  Future<void> _appendAndPlay(QueuedSong item) async {
    final historyIndex = state.historyIndex;
    final retainedHistory = historyIndex == null
        ? state.history
        : state.history.take(historyIndex + 1).toList(growable: false);
    final appended = [...retainedHistory, item];
    // Keep only the most recent [_maxHistory] entries; drop from the front.
    final nextHistory = appended.length > _maxHistory
        ? appended.sublist(appended.length - _maxHistory)
        : appended;
    state = QueuePlaybackState(
      history: nextHistory,
      historyIndex: nextHistory.length - 1,
      currentItem: item,
    );
    await _play(item);
  }

  Future<void> _play(QueuedSong item) {
    return _nowPlaying.play(item.song, item.source.logoStyle);
  }
}
