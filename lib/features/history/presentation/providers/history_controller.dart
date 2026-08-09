import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/persisted_song_entry.dart';
import '../../../../core/providers/local_storage_provider.dart';
import '../../../playback/presentation/providers/now_playing_controller.dart';
import '../../data/history_repository.dart';

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(ref.watch(localStorageServiceProvider)),
);

/// Global, not autoDispose: recording must keep working regardless of which
/// screen is on top, and the list must survive navigating everywhere. Records
/// a play by listening to [nowPlayingProvider] rather than being called
/// directly, so every playback path (search result, suggestion, queue,
/// favorites, history itself) is captured from one place.
final historyControllerProvider =
    StateNotifierProvider<HistoryController, List<PersistedSongEntry>>(
      (ref) => HistoryController(ref, ref.watch(historyRepositoryProvider)),
    );

class HistoryController extends StateNotifier<List<PersistedSongEntry>> {
  HistoryController(this._ref, this._repository) : super(const []) {
    _load();
    _ref.listen<PlaybackState>(
      nowPlayingProvider.select((value) => value.playback),
      _onPlaybackChanged,
    );
  }

  final Ref _ref;
  final HistoryRepository _repository;

  Future<void> _load() async {
    final entries = await _repository.load();
    if (mounted) {
      state = entries;
    }
  }

  void _onPlaybackChanged(PlaybackState? previous, PlaybackState next) {
    if (next is! PlaybackReady) {
      return;
    }
    final song = next.song;

    if (state.isNotEmpty && state.first.song.id == song.id) {
      // Same song replayed right after itself (or a rebuild fired the
      // listener again) — bump the timestamp instead of piling up
      // duplicate entries.
      state = [
        PersistedSongEntry(
          song: song,
          source: state.first.source,
          at: DateTime.now(),
        ),
        ...state.skip(1),
      ];
    } else {
      final source = _ref.read(nowPlayingProvider).activeSource;
      state = [
        PersistedSongEntry(song: song, source: source, at: DateTime.now()),
        ...state,
      ].take(HistoryRepository.maxEntries).toList(growable: false);
    }
    _repository.save(state);
  }

  void remove(String songId) {
    state = state.where((entry) => entry.song.id != songId).toList();
    _repository.save(state);
  }

  void clear() {
    state = const [];
    _repository.save(state);
  }
}
