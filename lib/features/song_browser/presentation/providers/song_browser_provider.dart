import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers/local_storage_provider.dart';
import '../../../playback/presentation/providers/now_playing_controller.dart';
import '../../../queue/presentation/providers/queue_provider.dart';
import '../../../source_selection/data/models/music_source.dart';
import '../../data/mock/song_browser_mock_data.dart';
import '../../data/models/song_item.dart';
import '../../data/music_sdk_song_repository.dart';
import '../../data/recommendation_seed.dart';
import '../../data/recommendations_cache_repository.dart';
import '../../data/search_results_cache.dart';
import 'music_sdk_repository_provider.dart';

final recommendationsCacheProvider = Provider<RecommendationsCacheRepository>(
  (ref) =>
      RecommendationsCacheRepository(ref.watch(localStorageServiceProvider)),
);

/// Non-autoDispose so browse/search results survive the autoDispose browser
/// controller being torn down and recreated on re-navigation.
final searchResultsCacheProvider = Provider<SearchResultsCache>(
  (ref) => SearchResultsCache(),
);

final songBrowserProvider = StateNotifierProvider.autoDispose
    .family<SongBrowserController, SongBrowserState, MusicSource>(
      (ref, source) => SongBrowserController(
        source,
        ref.watch(musicSdkSongRepositoryProvider),
        ref.watch(queueProvider.notifier),
        ref.watch(nowPlayingProvider.notifier),
        ref.watch(recommendationsCacheProvider),
        ref.watch(searchResultsCacheProvider),
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

enum BrowseTab { genres, artists }

enum ArtistRegion { vietnam, international }

class SongBrowserState {
  const SongBrowserState({
    required this.source,
    this.query = '',
    this.selectedTopActionIndex = SongBrowserMockData.searchTabIndex,
    this.selectedSuggestionIndex = 0,
    this.selectedResultIndex = 0,
    this.selectedCategoryIndex = 0,
    this.selectedArtistIndex = 0,
    this.browseTab = BrowseTab.genres,
    this.artistRegion = ArtistRegion.vietnam,
    this.recommendations = const RecommendationsLoading(),
    this.search = const SearchIdle(),
  });

  final MusicSource source;
  final String query;
  final int selectedTopActionIndex;
  final int selectedSuggestionIndex;
  final int selectedResultIndex;
  final int selectedCategoryIndex;
  final int selectedArtistIndex;
  final BrowseTab browseTab;
  final ArtistRegion artistRegion;

  final RecommendationsState recommendations;
  final SearchState search;

  SongBrowserState copyWith({
    String? query,
    int? selectedTopActionIndex,
    int? selectedSuggestionIndex,
    int? selectedResultIndex,
    int? selectedCategoryIndex,
    int? selectedArtistIndex,
    BrowseTab? browseTab,
    ArtistRegion? artistRegion,
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
      selectedCategoryIndex:
          selectedCategoryIndex ?? this.selectedCategoryIndex,
      selectedArtistIndex: selectedArtistIndex ?? this.selectedArtistIndex,
      browseTab: browseTab ?? this.browseTab,
      artistRegion: artistRegion ?? this.artistRegion,
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
    this._recommendationsCache,
    this._searchCache,
  ) : super(SongBrowserState(source: source)) {
    _loadRecommendations();
  }

  final MusicSdkSongRepository _repository;
  final QueueController _queue;
  final NowPlayingController _nowPlaying;
  final RecommendationsCacheRepository _recommendationsCache;
  final SearchResultsCache _searchCache;

  // The last query key handed to _runSearch, used to drop duplicate requests
  // (double-tap TÌM, re-pressing the same category) while one is in flight or
  // already displayed. Reset on failure so a retry is allowed.
  String? _lastRequestedQuery;

  // Requests are fire-and-forget against a real network call, so a second
  // search started before the first resolves must win — this guards against a
  // slow, stale response overwriting a newer one.
  int _recommendationsRequestId = 0;
  int _searchRequestId = 0;

  /// Stale-while-revalidate: paint the last cached list immediately (so the
  /// column is not a spinner on every open), then refresh from the network in
  /// the background and rewrite the cache. A network failure keeps the cached
  /// list on screen; the error state is only shown when there was no cache.
  Future<void> _loadRecommendations() async {
    final requestId = ++_recommendationsRequestId;
    final source = state.source.logoStyle;

    final cached = await _recommendationsCache.load(source);
    if (!mounted || requestId != _recommendationsRequestId) {
      return;
    }
    final hasCache = cached != null && cached.isNotEmpty;
    if (hasCache) {
      state = state.copyWith(recommendations: RecommendationsSuccess(cached));
    }

    try {
      final items = await _repository.search(
        source: source,
        query: _normalizeQuery(recommendationSeedQuery(source)),
      );
      if (!mounted || requestId != _recommendationsRequestId) {
        return;
      }
      state = state.copyWith(recommendations: RecommendationsSuccess(items));
      unawaited(_recommendationsCache.save(source, items));
    } catch (_) {
      if (!mounted || requestId != _recommendationsRequestId) {
        return;
      }
      if (!hasCache) {
        state = state.copyWith(recommendations: const RecommendationsFailed());
      }
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

  QueueAddResult addSongToQueue(SongItem song) {
    return _queue.add(song, state.source);
  }

  /// Updates the native system search field without starting a request. The
  /// request is intentionally started only when the keyboard action is
  /// submitted, so typing never fires an API call for every character.
  void setQuery(String query) => _setQuery(query);

  void _setQuery(String query) {
    state = state.copyWith(
      query: query,
      selectedResultIndex: 0,
      // Clearing the box (however the user got there) drops stale results
      // immediately rather than leaving them up until the next TÌM press.
      search: query.isEmpty ? const SearchIdle() : state.search,
    );
  }

  void selectCategory(int index) {
    state = state.copyWith(selectedCategoryIndex: index);
  }

  void selectBrowseTab(BrowseTab tab) {
    state = state.copyWith(browseTab: tab);
  }

  void selectArtistRegion(ArtistRegion region) {
    state = state.copyWith(artistRegion: region, selectedArtistIndex: 0);
  }

  void selectArtist(int index) {
    state = state.copyWith(selectedArtistIndex: index);
  }

  Future<void> browseCategory(int index, String seedQuery) async {
    state = state.copyWith(
      query: seedQuery,
      selectedCategoryIndex: index,
      selectedResultIndex: 0,
    );
    await _runSearch(seedQuery);
  }

  Future<void> browseArtist(int index, String seedQuery) async {
    state = state.copyWith(
      query: seedQuery,
      selectedArtistIndex: index,
      selectedResultIndex: 0,
    );
    await _runSearch(seedQuery);
  }

  Future<void> submitSearch() async {
    final query = state.query.trim();
    if (query.isEmpty) {
      state = state.copyWith(search: const SearchIdle());
      return;
    }
    await _runSearch(query);
  }

  Future<void> _runSearch(String query) async {
    final source = state.source.logoStyle;
    final normalized = _normalizeQuery(query);
    final cacheKey = '${source.name}|$normalized';

    // Dedupe: the same query is already loading or already on screen — don't
    // fire a duplicate network request (double-tap TÌM, re-press same tile).
    if (_lastRequestedQuery == cacheKey &&
        (state.search is SearchLoading || state.search is SearchSuccess)) {
      return;
    }
    _lastRequestedQuery = cacheKey;

    // Cache hit: show instantly, no network. Covers re-pressing a category and
    // re-submitting a query, including after leaving and returning to the page.
    final cached = _searchCache.get(cacheKey);
    if (cached != null) {
      state = state.copyWith(
        search: SearchSuccess(cached),
        selectedResultIndex: 0,
      );
      return;
    }

    final requestId = ++_searchRequestId;
    state = state.copyWith(
      search: const SearchLoading(),
      selectedResultIndex: 0,
    );

    try {
      final results = await _repository.search(
        source: source,
        query: normalized,
      );
      if (!mounted || requestId != _searchRequestId) {
        return;
      }
      _searchCache.put(cacheKey, results);
      state = state.copyWith(search: SearchSuccess(results));
    } catch (_) {
      if (!mounted || requestId != _searchRequestId) {
        return;
      }
      // Allow a retry of the same query after a failure.
      _lastRequestedQuery = null;
      state = state.copyWith(search: const SearchFailed());
    }
  }

  /// Delegates to the shared now-playing slot: playback must survive
  /// navigating to the queue screen and back, not reset with this page.
  Future<void> playSong(SongItem song) {
    return _nowPlaying.play(song, state.source.logoStyle);
  }
}

/// Collapses surrounding and repeated whitespace.
///
/// Kept after the karaoke mode was removed because the search cache key is
/// built from the result — without it, "abc " and "abc" become two cache
/// entries and two network round trips for the same search.
String _normalizeQuery(String query) =>
    query.replaceAll(RegExp(r'\s+'), ' ').trim();
