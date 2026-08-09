import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../song_browser/data/models/song_item.dart';
import '../../../source_selection/data/models/music_source.dart';
import '../../data/models/queued_song.dart';

enum QueueRepeatMode { off, one, all }

enum QueueAddResult { added, duplicate }

/// Deliberately not `autoDispose`: the queue is a single karaoke session's
/// running playlist, so it must survive navigating between sources and back
/// to the queue screen, not just the lifetime of one song browser page.
final queueProvider = StateNotifierProvider<QueueController, QueueState>(
  (ref) => QueueController(),
);

class QueueState {
  const QueueState({
    this.items = const [],
    this.repeatMode = QueueRepeatMode.off,
    this.shuffle = false,
  });

  final List<QueuedSong> items;
  final QueueRepeatMode repeatMode;
  final bool shuffle;

  QueueState copyWith({
    List<QueuedSong>? items,
    QueueRepeatMode? repeatMode,
    bool? shuffle,
  }) {
    return QueueState(
      items: items ?? this.items,
      repeatMode: repeatMode ?? this.repeatMode,
      shuffle: shuffle ?? this.shuffle,
    );
  }
}

class QueueController extends StateNotifier<QueueState> {
  QueueController() : super(const QueueState());

  QueueAddResult add(SongItem song, MusicSource source) {
    final alreadyQueued = state.items.any(
      (item) => item.song.id == song.id && item.source.id == source.id,
    );
    if (alreadyQueued) {
      return QueueAddResult.duplicate;
    }
    state = state.copyWith(
      items: [
        ...state.items,
        QueuedSong(song: song, source: source),
      ],
    );
    return QueueAddResult.added;
  }

  QueuedSong? removeAt(int index) {
    if (index < 0 || index >= state.items.length) {
      return null;
    }
    final items = [...state.items];
    final removed = items.removeAt(index);
    state = state.copyWith(items: items);
    return removed;
  }

  void insertAt(int index, QueuedSong item) {
    final items = [...state.items];
    final insertionIndex = index.clamp(0, items.length);
    final alreadyQueued = items.any(
      (queued) =>
          queued.song.id == item.song.id && queued.source.id == item.source.id,
    );
    if (alreadyQueued) {
      return;
    }
    items.insert(insertionIndex, item);
    state = state.copyWith(items: items);
  }

  void clear() {
    state = state.copyWith(items: const []);
  }

  /// Swaps [index] with its predecessor. No-op at the top of the list.
  void moveUp(int index) => _move(index, index - 1);

  /// Swaps [index] with its successor. No-op at the bottom of the list.
  void moveDown(int index) => _move(index, index + 1);

  /// Moves an item to a stable insertion slot between queue entries.
  void moveToSlot(int oldIndex, int targetSlot) {
    if (oldIndex < 0 || oldIndex >= state.items.length) {
      return;
    }
    final items = [...state.items];
    final item = items.removeAt(oldIndex);
    final insertionIndex = (oldIndex < targetSlot ? targetSlot - 1 : targetSlot)
        .clamp(0, items.length);
    if (insertionIndex == oldIndex) {
      return;
    }
    items.insert(insertionIndex, item);
    state = state.copyWith(items: items);
  }

  void _move(int from, int to) {
    if (from < 0 ||
        from >= state.items.length ||
        to < 0 ||
        to >= state.items.length ||
        from == to) {
      return;
    }
    final list = [...state.items];
    final item = list.removeAt(from);
    list.insert(to, item);
    state = state.copyWith(items: list);
  }

  void setQueueRepeatMode(QueueRepeatMode mode) {
    state = state.copyWith(repeatMode: mode);
  }

  void cycleQueueRepeatMode() {
    final next = switch (state.repeatMode) {
      QueueRepeatMode.off => QueueRepeatMode.all,
      QueueRepeatMode.all => QueueRepeatMode.one,
      QueueRepeatMode.one => QueueRepeatMode.off,
    };
    state = state.copyWith(repeatMode: next);
  }

  void toggleShuffle() {
    state = state.copyWith(shuffle: !state.shuffle);
  }

  void setShuffle(bool value) {
    state = state.copyWith(shuffle: value);
  }

  /// Refills the queue from played history so repeat-all can loop once the
  /// queue empties, rather than stopping.
  void refillFrom(List<QueuedSong> items) {
    state = state.copyWith(items: items);
  }
}
