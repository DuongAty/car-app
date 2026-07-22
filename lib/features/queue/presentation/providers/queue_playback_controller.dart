import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../playback/presentation/providers/now_playing_controller.dart';
import '../../data/models/queued_song.dart';
import 'queue_provider.dart';

final queuePlaybackControllerProvider =
    StateNotifierProvider<QueuePlaybackController, QueuePlaybackState>((ref) {
      final nowPlaying = ref.watch(nowPlayingProvider.notifier);
      final controller = QueuePlaybackController(
        ref.watch(queueProvider.notifier),
        nowPlaying,
      );
      nowPlaying.setOnCompleted(controller.playNext);
      ref.onDispose(() => nowPlaying.setOnCompleted(null));
      return controller;
    });

class QueuePlaybackState {
  const QueuePlaybackState({this.history = const [], this.historyIndex});

  final List<QueuedSong> history;
  final int? historyIndex;

  QueuePlaybackState copyWith({List<QueuedSong>? history, int? historyIndex}) {
    return QueuePlaybackState(
      history: history ?? this.history,
      historyIndex: historyIndex ?? this.historyIndex,
    );
  }
}

class QueuePlaybackController extends StateNotifier<QueuePlaybackState> {
  QueuePlaybackController(this._queue, this._nowPlaying)
    : super(const QueuePlaybackState());

  final QueueController _queue;
  final NowPlayingController _nowPlaying;

  Future<void> playAt(int index) async {
    final queue = _queue.state;
    if (index < 0 || index >= queue.length) {
      return;
    }
    final item = queue[index];
    _queue.removeAt(index);
    await _appendAndPlay(item);
  }

  Future<void> playNext() async {
    final historyIndex = state.historyIndex;
    if (historyIndex != null && historyIndex < state.history.length - 1) {
      final nextIndex = historyIndex + 1;
      state = state.copyWith(historyIndex: nextIndex);
      await _play(state.history[nextIndex]);
      return;
    }

    final queue = _queue.state;
    if (queue.isEmpty) {
      return;
    }
    final item = queue.first;
    _queue.removeAt(0);
    await _appendAndPlay(item);
  }

  Future<void> playPrevious() async {
    final historyIndex = state.historyIndex;
    if (historyIndex == null || historyIndex <= 0) {
      return;
    }

    final previousIndex = historyIndex - 1;
    state = state.copyWith(historyIndex: previousIndex);
    await _play(state.history[previousIndex]);
  }

  Future<void> _appendAndPlay(QueuedSong item) async {
    final historyIndex = state.historyIndex;
    final retainedHistory = historyIndex == null
        ? state.history
        : state.history.take(historyIndex + 1).toList(growable: false);
    final nextHistory = [...retainedHistory, item];
    state = QueuePlaybackState(
      history: nextHistory,
      historyIndex: nextHistory.length - 1,
    );
    await _play(item);
  }

  Future<void> _play(QueuedSong item) {
    return _nowPlaying.play(item.song, item.source.logoStyle);
  }
}
