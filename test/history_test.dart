import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:viet_ktv/core/models/persisted_song_entry.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/features/history/presentation/pages/history_page.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import 'support/fake_local_storage_service.dart';
import 'support/fake_music_sdk_platform.dart';

Future<void> _pumpHistoryPage(
  WidgetTester tester,
  FakeLocalStorageService storage,
) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
        localStorageServiceProvider.overrideWithValue(storage),
      ],
      child: MaterialApp(
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const HistoryPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('history_page_shows_empty_state_with_nothing_played', (
    tester,
  ) async {
    await _pumpHistoryPage(tester, FakeLocalStorageService());

    expect(
      find.textContaining('Chưa có bài hát nào trong lịch sử'),
      findsOneWidget,
    );
  });

  testWidgets('history_page_shows_a_previously_recorded_play', (tester) async {
    final storage = FakeLocalStorageService();
    final entry = PersistedSongEntry(
      song: const SongItem(
        id: '9',
        title: 'Lạc Trôi - Sơn Tùng M-TP (Karaoke)',
        subtitle: 'Karaoke 4 You',
        duration: '4:32',
        thumbnailSeed: 9,
        badge: null,
      ),
      source: MusicSourceLogoStyle.youtube,
      at: DateTime.now(),
    );
    storage.store['history.v1'] = jsonEncode([entry.toJson()]);

    await _pumpHistoryPage(tester, storage);

    expect(find.text('Lạc Trôi - Sơn Tùng M-TP (Karaoke)'), findsOneWidget);
  });
}
