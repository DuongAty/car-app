import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/song_browser/data/search_results_cache.dart';

void main() {
  const item = SongItem(
    id: 'track',
    title: 'Track',
    subtitle: 'Artist',
    duration: '03:00',
    thumbnailSeed: 1,
    badge: null,
  );

  test('keeps_at_most_50_keys_and_evicts_the_least_recently_used_key', () {
    final cache = SearchResultsCache();
    for (var index = 0; index < 50; index++) {
      cache.put('query-$index', [item]);
    }

    expect(cache.get('query-0'), isNotNull);
    cache.put('query-new', [item]);

    expect(cache.get('query-0'), isNotNull);
    expect(cache.get('query-1'), isNull);
    expect(cache.get('query-new'), isNotNull);
  });

  test('keeps_at_most_50_results_for_one_key', () {
    final cache = SearchResultsCache();
    final results = List.generate(
      51,
      (index) => SongItem(
        id: '$index',
        title: 'Track $index',
        subtitle: 'Artist',
        duration: '03:00',
        thumbnailSeed: index,
        badge: null,
      ),
    );

    cache.put('query', results);

    expect(cache.get('query'), hasLength(50));
  });
}
