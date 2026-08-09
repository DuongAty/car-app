import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/song_browser_provider.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';

import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';

const _source = MusicSource(
  id: 'youtube',
  subtitle: 'Kho nhạc & Video\nkhổng lồ',
  accentColor: AppColors.red,
  logoStyle: MusicSourceLogoStyle.youtube,
);

({ProviderContainer container, FakeMusicSdkPlatform platform}) _harness() {
  final platform = FakeMusicSdkPlatform();
  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(FakeLocalStorageService()),
      musicSdkPlatformProvider.overrideWithValue(platform),
    ],
  );
  addTearDown(container.dispose);
  return (container: container, platform: platform);
}

/// Sets the query then submits it. `submitSearch` takes no argument — it reads
/// `state.query` — so the two calls are the real API.
Future<void> _search(ProviderContainer container, String query) async {
  final controller = container.read(songBrowserProvider(_source).notifier);
  controller.setQuery(query);
  await controller.submitSearch();
}

void main() {
  test('a_query_containing_karaoke_keeps_the_word', () async {
    // The old SearchMode.applyToQuery stripped it, so typing "karaoke" searched
    // for nothing at all and returned the whole catalogue.
    final harness = _harness();

    await _search(harness.container, 'karaoke');

    expect(harness.platform.searchQueries, contains('karaoke'));
  });

  test('a_plain_query_reaches_the_repository_unchanged', () async {
    final harness = _harness();

    await _search(harness.container, 'Lạc Trôi');

    expect(harness.platform.searchQueries, contains('Lạc Trôi'));
  });

  test('surrounding_and_repeated_whitespace_is_normalized', () async {
    // Not cosmetic: the search cache key is built from this, so without it two
    // spellings of one search cost two network round trips.
    final harness = _harness();

    await _search(harness.container, '  Lạc   Trôi  ');

    expect(harness.platform.searchQueries, contains('Lạc Trôi'));
  });

  test('a_query_that_is_only_karaoke_is_not_emptied', () async {
    final harness = _harness();

    await _search(harness.container, '  KARAOKE ');

    expect(harness.platform.searchQueries, contains('KARAOKE'));
  });
}
