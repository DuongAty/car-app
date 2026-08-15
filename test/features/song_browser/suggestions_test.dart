import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/core/theme/app_icons.dart';
import 'package:viet_ktv/features/queue/presentation/providers/queue_provider.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/song_browser/data/recommendation_seed.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/search_results_panel.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/suggestion_tile.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/suggestions_panel.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';

const _source = MusicSource(
  id: 'youtube',
  subtitle: 'Kho nhạc & Video\nkhổng lồ',
  accentColor: AppColors.red,
  logoStyle: MusicSourceLogoStyle.youtube,
);

const _cachedSong = SongItem(
  id: 'cached-1',
  title: 'Bài hát trong cache',
  subtitle: 'Nguồn cache',
  duration: '03:11',
  thumbnailSeed: 7,
  badge: null,
);

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required FakeLocalStorageService storage,
  required FakeMusicSdkPlatform platform,
  bool settle = true,
}) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(storage),
      musicSdkPlatformProvider.overrideWithValue(platform),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const SongBrowserPage(source: _source),
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return container;
}

Future<void> _search(WidgetTester tester, String query) async {
  await tester.enterText(
    find.byKey(const ValueKey('songBrowserNativeSearchField')),
    query,
  );
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('suggestions_are_painted_from_the_cache_before_the_network', (
    tester,
  ) async {
    final storage = FakeLocalStorageService();
    storage.store['recommendations.v1.youtube'] = jsonEncode([
      _cachedSong.toJson(),
    ]);
    // Held open so the assertion below lands while the revalidation is still
    // in flight — that window is the whole point of the cache.
    final platform = FakeMusicSdkPlatform(
      searchDelay: const Duration(seconds: 2),
    );

    await _pump(tester, storage: storage, platform: platform, settle: false);
    await tester.pump();
    await tester.pump();

    expect(find.text('Bài hát trong cache'), findsOneWidget);
    expect(find.text('Đang tải gợi ý...'), findsNothing);

    // Then the live list takes over on its own.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Bài hát trong cache'), findsNothing);
    expect(find.byType(SuggestionTile), findsWidgets);
  });

  testWidgets('cached_suggestions_are_revalidated_in_the_background', (
    tester,
  ) async {
    final storage = FakeLocalStorageService();
    storage.store['recommendations.v1.youtube'] = jsonEncode([
      _cachedSong.toJson(),
    ]);
    final platform = FakeMusicSdkPlatform();

    await _pump(tester, storage: storage, platform: platform);

    // Stale-while-revalidate: the cache is shown AND the seed query still runs,
    // so the list is fresh next time even though nothing blocked on it.
    expect(
      platform.searchQueries,
      contains(recommendationSeedQuery(MusicSourceLogoStyle.youtube)),
    );
    // And the result is written back for the next open.
    expect(
      storage.store['recommendations.v1.youtube'],
      isNot(contains('cached-1')),
    );
  });

  testWidgets('searching_replaces_the_suggestions_with_the_results', (
    tester,
  ) async {
    await _pump(
      tester,
      storage: FakeLocalStorageService(),
      platform: FakeMusicSdkPlatform(),
    );
    expect(find.byType(SuggestionsPanel), findsOneWidget);

    await _search(tester, 'OFFICIAL');

    expect(find.byType(SuggestionsPanel), findsNothing);
    expect(find.byType(SearchResultsPanel), findsOneWidget);
    expect(find.text('Lạc Trôi - Sơn Tùng M-TP (Official MV)'), findsOneWidget);
  });

  testWidgets('a_suggestion_can_be_queued_without_searching_first', (
    tester,
  ) async {
    final storage = FakeLocalStorageService();
    storage.store['recommendations.v1.youtube'] = jsonEncode([
      _cachedSong.toJson(),
    ]);
    final container = await _pump(
      tester,
      storage: storage,
      platform: FakeMusicSdkPlatform(),
    );

    await tester.tap(
      find.descendant(
        of: find.byType(SuggestionTile),
        matching: find.byIcon(AppIcons.add),
      ),
    );
    await tester.pumpAndSettle();

    expect(container.read(queueProvider).items, hasLength(1));
  });
}
