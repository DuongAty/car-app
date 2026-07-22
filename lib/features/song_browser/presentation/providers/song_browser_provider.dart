import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../playback/presentation/providers/now_playing_controller.dart';
import '../../../queue/presentation/providers/queue_provider.dart';
import '../../../source_selection/data/models/music_source.dart';
import '../../data/mock/song_browser_mock_data.dart';
import '../../data/models/song_item.dart';
import '../../data/music_sdk_song_repository.dart';
import '../../data/recommendation_seed.dart';
import 'music_sdk_repository_provider.dart';

final songBrowserProvider = StateNotifierProvider.autoDispose
    .family<SongBrowserController, SongBrowserState, MusicSource>(
      (ref, source) => SongBrowserController(
        source,
        ref.watch(musicSdkSongRepositoryProvider),
        ref.watch(queueProvider.notifier),
        ref.watch(nowPlayingProvider.notifier),
      ),
    );

/// State of the search-results column. Modeled as a sealed class rather than a
/// status enum plus a results list, so a stale list can never be shown
/// alongside a "loading" or "idle" status.
sealed class SearchState {
  const SearchState();
}

/// Nothing has been searched yet, or the query was cleared back to empty.
class SearchIdle extends SearchState {
  const SearchIdle();
}

class SearchLoading extends SearchState {
  const SearchLoading();
}

class SearchSuccess extends SearchState {
  const SearchSuccess(this.results);

  final List<SongItem> results;
}

class SearchFailed extends SearchState {
  const SearchFailed();
}

/// State of the left "GỢI Ý CHO BẠN" column. Modeled the same way as
/// [SearchState]. There is no recommendations endpoint on MusicSDK, so this is
/// backed by a curated seed search rather than user history — see
/// [recommendationSeedQuery].
sealed class RecommendationsState {
  const RecommendationsState();
}

class RecommendationsLoading extends RecommendationsState {
  const RecommendationsLoading();
}

class RecommendationsSuccess extends RecommendationsState {
  const RecommendationsSuccess(this.items);

  final List<SongItem> items;
}

class RecommendationsFailed extends RecommendationsState {
  const RecommendationsFailed();
}

class SongBrowserState {
  const SongBrowserState({
    required this.source,
    this.query = '',
    this.selectedTopActionIndex = 0,
    this.selectedSuggestionIndex = 0,
    this.selectedResultIndex = 0,
    this.recommendations = const RecommendationsLoading(),
    this.search = const SearchIdle(),
  });

  final MusicSource source;
  final String query;
  final int selectedTopActionIndex;
  final int selectedSuggestionIndex;
  final int selectedResultIndex;

  final RecommendationsState recommendations;
  final SearchState search;

  SongBrowserState copyWith({
    String? query,
    int? selectedTopActionIndex,
    int? selectedSuggestionIndex,
    int? selectedResultIndex,
    RecommendationsState? recommendations,
    SearchState? search,
  }) {
    return SongBrowserState(
      source: source,
      query: query ?? this.query,
      selectedTopActionIndex:
          selectedTopActionIndex ?? this.selectedTopActionIndex,
      selectedSuggestionIndex:
          selectedSuggestionIndex ?? this.selectedSuggestionIndex,
      selectedResultIndex: selectedResultIndex ?? this.selectedResultIndex,
      recommendations: recommendations ?? this.recommendations,
      search: search ?? this.search,
    );
  }
}

class SongBrowserController extends StateNotifier<SongBrowserState> {
  SongBrowserController(
    MusicSource source,
    this._repository,
    this._queue,
    this._nowPlaying,
  ) : super(SongBrowserState(source: source)) {
    _loadRecommendations();
  }

  final MusicSdkSongRepository _repository;
  final QueueController _queue;
  final NowPlayingController _nowPlaying;

  // Requests are fire-and-forget against a real network call, so a second
  // search started before the first resolves must win — this guards against a
  // slow, stale response overwriting a newer one.
  int _recommendationsRequestId = 0;
  int _searchRequestId = 0;

  Future<void> _loadRecommendations() async {
    final requestId = ++_recommendationsRequestId;

    try {
      final items = await _repository.search(
        source: state.source.logoStyle,
        query: recommendationSeedQuery(state.source.logoStyle),
      );
      if (!mounted || requestId != _recommendationsRequestId) {
        return;
      }
      state = state.copyWith(recommendations: RecommendationsSuccess(items));
    } catch (_) {
      if (!mounted || requestId != _recommendationsRequestId) {
        return;
      }
      state = state.copyWith(recommendations: const RecommendationsFailed());
    }
  }

  void selectTopAction(int index) {
    state = state.copyWith(selectedTopActionIndex: index);
  }

  void selectSuggestion(int index) {
    state = state.copyWith(selectedSuggestionIndex: index);
  }

  void selectResult(int index) {
    state = state.copyWith(selectedResultIndex: index);
  }

  void addSongToQueue(SongItem song) {
    _queue.add(song, state.source);
  }

  /// Handles one press on the on-screen keyboard, resolving the control keys
  /// into query edits. TÌM submits the current query as a real search.
  void pressKey(String key) {
    switch (key) {
      case SongBrowserMockData.keySearch:
        submitSearch();
      case SongBrowserMockData.keyNumbers:
        return;
      case SongBrowserMockData.keySpace:
        _setQuery('${state.query} ');
      case SongBrowserMockData.keyClear:
        _setQuery('');
      case SongBrowserMockData.keyBackspace:
        if (state.query.isNotEmpty) {
          _setQuery(state.query.substring(0, state.query.length - 1));
        }
      default:
        _setQuery('${state.query}$key');
    }
  }

  void _setQuery(String query) {
    state = state.copyWith(
      query: query,
      selectedResultIndex: 0,
      // Clearing the box (however the user got there) drops stale results
      // immediately rather than leaving them up until the next TÌM press.
      search: query.isEmpty ? const SearchIdle() : state.search,
    );
  }

  Future<void> submitSearch() async {
    final query = state.query.trim();
    if (query.isEmpty) {
      state = state.copyWith(search: const SearchIdle());
      return;
    }

    final requestId = ++_searchRequestId;
    state = state.copyWith(
      search: const SearchLoading(),
      selectedResultIndex: 0,
    );

    try {
      final results = await _repository.search(
        source: state.source.logoStyle,
        query: query,
      );
      if (!mounted || requestId != _searchRequestId) {
        return;
      }
      state = state.copyWith(search: SearchSuccess(results));
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) {
        return;
      }
      state = state.copyWith(search: const SearchFailed());
    }
  }

  /// Delegates to the shared now-playing slot: playback must survive
  /// navigating to the queue screen and back, not reset with this page.
  Future<void> playSong(SongItem song) {
    return _nowPlaying.play(song, state.source.logoStyle);
  }
}
