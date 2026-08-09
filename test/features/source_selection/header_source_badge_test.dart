import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/models/persisted_song_entry.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/shared/widgets/brand_logos.dart';
import 'package:viet_ktv/core/shared/widgets/persisted_song_tile.dart';
import 'package:viet_ktv/features/favorites/presentation/pages/favorites_page.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/main_top_bar.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';
import 'package:viet_ktv/features/source_selection/presentation/pages/source_selection_page.dart';
import 'package:viet_ktv/features/source_selection/presentation/providers/source_selection_provider.dart';
import 'package:viet_ktv/features/source_selection/presentation/widgets/source_badge.dart';
import 'package:viet_ktv/features/source_selection/presentation/widgets/source_card_content.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';

const _youtubeSource = MusicSource(
  id: 'youtube',
  subtitle: 'Kho nhạc & Video\nkhổng lồ',
  accentColor: Color(0xFFFF0000),
  logoStyle: MusicSourceLogoStyle.youtube,
);

const _soundcloudSource = MusicSource(
  id: 'soundcloud',
  subtitle: 'Nhạc cộng đồng',
  accentColor: Color(0xFFFF7700),
  logoStyle: MusicSourceLogoStyle.soundcloud,
);

// Narrowest real layout: below AppLayout.minimumLandscapeWidth (1366),
// KaraokeShell scales its content into a fixed 1366x768 canvas, so that
// canvas size is the narrowest case that actually renders in the app.
const _narrowCanvasSize = Size(1366, 768);

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget home, {
  List<Override> extraOverrides = const [],
}) async {
  tester.view.physicalSize = _narrowCanvasSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(FakeLocalStorageService()),
      musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
      ...extraOverrides,
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
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Finder _headerMark() => find.descendant(
  of: find.byType(MainTopBar),
  matching: find.byType(SourceMark),
);

void main() {
  testWidgets('browser page header shows the YouTube mark when YouTube '
      'was selected', (tester) async {
    final container = await _pump(
      tester,
      const SongBrowserPage(source: _youtubeSource),
    );
    container
        .read(sourceSelectionProvider.notifier)
        .selectSource(0, _youtubeSource);
    await tester.pumpAndSettle();

    expect(_headerMark(), findsOneWidget);
    expect(
      find.descendant(of: _headerMark(), matching: find.byType(YoutubeMark)),
      findsOneWidget,
    );
  });

  testWidgets('browser page header shows the SoundCloud mark when '
      'SoundCloud was selected', (tester) async {
    final container = await _pump(
      tester,
      const SongBrowserPage(source: _soundcloudSource),
    );
    container
        .read(sourceSelectionProvider.notifier)
        .selectSource(1, _soundcloudSource);
    await tester.pumpAndSettle();

    expect(_headerMark(), findsOneWidget);
    expect(
      find.descendant(of: _headerMark(), matching: find.byType(YoutubeMark)),
      findsNothing,
    );
    expect(
      find.descendant(of: _headerMark(), matching: find.byType(SoundCloudMark)),
      findsOneWidget,
    );
  });

  testWidgets('header badge is header-wide: favorites page shows it too', (
    tester,
  ) async {
    final container = await _pump(tester, const FavoritesPage());
    container
        .read(sourceSelectionProvider.notifier)
        .selectSource(1, _soundcloudSource);
    await tester.pumpAndSettle();

    expect(_headerMark(), findsOneWidget);
    expect(
      find.descendant(of: _headerMark(), matching: find.byType(SoundCloudMark)),
      findsOneWidget,
    );
  });

  testWidgets('source picker header shows no mark', (tester) async {
    await _pump(tester, const SourceSelectionPage());

    expect(find.byType(SourceMark), findsNothing);
  });

  testWidgets('mark sits in the left half of the screen', (tester) async {
    await _pump(tester, const SongBrowserPage(source: _youtubeSource));

    final markCenterX = tester.getCenter(_headerMark()).dx;
    expect(markCenterX, lessThan(_narrowCanvasSize.width / 2));
  });

  testWidgets(
    'header shows no wordmark text when YouTube is selected, just the mark',
    (tester) async {
      final container = await _pump(
        tester,
        const SongBrowserPage(source: _youtubeSource),
      );
      container
          .read(sourceSelectionProvider.notifier)
          .selectSource(0, _youtubeSource);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: _headerMark(), matching: find.text('YouTube')),
        findsNothing,
      );
      expect(
        find.descendant(of: _headerMark(), matching: find.text('SoundCloud')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'header shows no wordmark text when SoundCloud is selected, just the '
    'mark',
    (tester) async {
      final container = await _pump(
        tester,
        const SongBrowserPage(source: _soundcloudSource),
      );
      container
          .read(sourceSelectionProvider.notifier)
          .selectSource(1, _soundcloudSource);
      await tester.pumpAndSettle();

      expect(
        find.descendant(of: _headerMark(), matching: find.text('SoundCloud')),
        findsNothing,
      );
      expect(
        find.descendant(of: _headerMark(), matching: find.text('YouTube')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'favorites row (PersistedSongTile) still shows the full SourceBadge '
    'wordmark chip, unaffected by the mark-only header',
    (tester) async {
      final entry = PersistedSongEntry(
        song: const SongItem(
          id: 's1',
          title: 'Some Song',
          subtitle: 'Some Artist',
          duration: '03:20',
          thumbnailSeed: 1,
          badge: null,
        ),
        source: MusicSourceLogoStyle.soundcloud,
        at: DateTime(2026, 1, 1),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PersistedSongTile(
              entry: entry,
              selected: false,
              onPressed: () {},
              onRemove: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SourceBadge), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SourceBadge),
          matching: find.text('SoundCloud'),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('YouTube source card stacks its mark above the "YouTube" label', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 600,
              height: 600,
              child: SourceCardContent(source: _youtubeSource),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final markRect = tester.getRect(
      find.descendant(
        of: find.byType(YoutubeLogo),
        matching: find.byType(Container),
      ),
    );
    final textRect = tester.getRect(
      find.descendant(
        of: find.byType(YoutubeLogo),
        matching: find.text('YouTube'),
      ),
    );

    expect(markRect.bottom, lessThanOrEqualTo(textRect.top));
  });

  testWidgets(
    'SoundCloud source card stacks its mark above the "SOUNDCLOUD" label',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 600,
                height: 600,
                child: SourceCardContent(source: _soundcloudSource),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final markRect = tester.getRect(
        find.descendant(
          of: find.byType(SoundCloudLogo),
          matching: find.byType(CustomPaint),
        ),
      );
      final textRect = tester.getRect(
        find.descendant(
          of: find.byType(SoundCloudLogo),
          matching: find.text('SOUNDCLOUD'),
        ),
      );

      expect(markRect.bottom, lessThanOrEqualTo(textRect.top));
    },
  );
}
