import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../song_browser/data/models/song_item.dart';
import '../../../source_selection/data/models/music_source.dart';
import '../../data/models/queued_song.dart';

/// Deliberately not `autoDispose`: the queue is a single karaoke session's
/// running playlist, so it must survive navigating between sources and back
/// to the queue screen, not just the lifetime of one song browser page.
final queueProvider = StateNotifierProvider<QueueController, List<QueuedSong>>(
  (ref) => QueueController(),
);

class QueueController extends StateNotifier<List<QueuedSong>> {
  QueueController() : super(const []);

  /// Queuing the same song twice is allowed — a duplicate just means singing
  /// it again later, same as a real karaoke queue.
  void add(SongItem song, MusicSource source) {
    state = [...state, QueuedSong(song: song, source: source)];
  }

  void removeAt(int index) {
    if (index < 0 || index >= state.length) {
      return;
    }
    state = [...state]..removeAt(index);
  }

  void clear() {
    state = const [];
  }

  /// Swaps [index] with its predecessor. No-op at the top of the list.
  void moveUp(int index) => _move(index, index - 1);

  /// Swaps [index] with its successor. No-op at the bottom of the list.
  void moveDown(int index) => _move(index, index + 1);

  void _move(int from, int to) {
    if (from < 0 ||
        from >= state.length ||
        to < 0 ||
        to >= state.length ||
        from == to) {
      return;
    }
    final list = [...state];
    final item = list.removeAt(from);
    list.insert(to, item);
    state = list;
  }
}
