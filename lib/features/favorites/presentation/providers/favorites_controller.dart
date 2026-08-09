import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/persisted_song_entry.dart';
import '../../../../core/providers/local_storage_provider.dart';
import '../../../song_browser/data/models/song_item.dart';
import '../../../source_selection/data/models/music_source.dart';
import '../../data/favorites_repository.dart';

final favoritesRepositoryProvider = Provider<FavoritesRepository>(
  (ref) => FavoritesRepository(ref.watch(localStorageServiceProvider)),
);

/// Global, not autoDispose: favorites must survive navigating across every
/// screen, same lifetime rationale as `queueProvider`.
final favoritesControllerProvider =
    StateNotifierProvider<FavoritesController, List<PersistedSongEntry>>(
      (ref) => FavoritesController(ref.watch(favoritesRepositoryProvider)),
    );

class FavoritesController extends StateNotifier<List<PersistedSongEntry>> {
  FavoritesController(this._repository) : super(const []) {
    _load();
  }

  final FavoritesRepository _repository;

  Future<void> _load() async {
    final entries = await _repository.load();
    if (mounted) {
      state = entries;
    }
  }

  bool isFavorite(String songId) {
    return state.any((entry) => entry.song.id == songId);
  }

  void toggle(SongItem song, MusicSourceLogoStyle source) {
    final existingIndex = state.indexWhere((e) => e.song.id == song.id);
    if (existingIndex >= 0) {
      state = [...state]..removeAt(existingIndex);
    } else {
      state = [
        PersistedSongEntry(song: song, source: source, at: DateTime.now()),
        ...state,
      ].take(FavoritesRepository.maxEntries).toList(growable: false);
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
