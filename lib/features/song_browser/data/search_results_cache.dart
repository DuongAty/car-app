import 'models/song_item.dart';

/// In-memory, per-session cache of search/browse results keyed by
/// "source|normalizedQuery".
///
/// Lives in a non-autoDispose provider so it survives leaving and returning to
/// the (autoDispose) song browser: re-pressing the same category/artist tile,
/// or re-submitting a query, is served from here instead of re-hitting the
/// network. Not persisted — a fresh app launch starts empty, which is fine
/// since it only skips redundant same-session fetches.
class SearchResultsCache {
  SearchResultsCache({this.maxEntries = 50, this.maxResultsPerEntry = 50});

  final int maxEntries;
  final int maxResultsPerEntry;

  // LinkedHashMap iteration order = insertion order, used for oldest-first
  // eviction once the cache is full.
  final Map<String, List<SongItem>> _byKey = {};

  List<SongItem>? get(String key) {
    final results = _byKey.remove(key);
    if (results == null) {
      return null;
    }
    // Move a hit to the end so eviction is true LRU rather than FIFO.
    _byKey[key] = results;
    return results;
  }

  void put(String key, List<SongItem> results) {
    // Re-insert so a refreshed key counts as most-recently-used.
    _byKey.remove(key);
    _byKey[key] = results.take(maxResultsPerEntry).toList(growable: false);
    if (_byKey.length > maxEntries) {
      _byKey.remove(_byKey.keys.first);
    }
  }
}
