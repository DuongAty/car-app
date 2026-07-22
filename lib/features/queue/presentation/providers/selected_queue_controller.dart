import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../playback/presentation/providers/now_playing_controller.dart';
import '../../data/models/queued_song.dart';

/// Which queue row is highlighted. Scoped to this page (autoDispose) — the
/// queue list lives in [queueProvider] and actual playback lives in
/// [nowPlayingProvider], both of which outlive this; only the highlighted row
/// resets each visit.
final selectedQueueControllerProvider =
    StateNotifierProvider.autoDispose<SelectedQueueController, int>(
      (ref) => SelectedQueueController(ref.watch(nowPlayingProvider.notifier)),
    );

class SelectedQueueController extends StateNotifier<int> {
  SelectedQueueController(this._nowPlaying) : super(0);

  final NowPlayingController _nowPlaying;

  void selectIndex(int index) {
    state = index;
  }

  Future<void> play(QueuedSong item) {
    return _nowPlaying.play(item.song, item.source.logoStyle);
  }
}
