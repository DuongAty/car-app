import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/theme/app_icons.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/features/favorites/presentation/providers/favorites_controller.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/settings/presentation/pages/settings_page.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';
import 'package:viet_ktv/features/source_selection/presentation/pages/source_selection_page.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';
import 'package:viet_ktv/routes/app_router.dart';

import 'support/fake_audio_track_player.dart';
import 'support/fake_local_storage_service.dart';
import 'support/fake_music_sdk_platform.dart';
import 'support/fake_video_player_platform.dart';

const _source = MusicSource(
  id: 'youtube',
  subtitle: 'Kho nhạc & Video\nkhổng lồ',
  accentColor: AppColors.red,
  logoStyle: MusicSourceLogoStyle.youtube,
);

void main() {
  setUpAll(() {
    VideoPlayerPlatform.instance = FakeVideoPlayerPlatform();
  });

  testWidgets('settings_button_on_preview_player_navigates_to_settings', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
          audioTrackPlayerFactoryProvider.overrideWithValue(
            FakeAudioTrackPlayer.new,
          ),
          localStorageServiceProvider.overrideWithValue(
            FakeLocalStorageService(),
          ),
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
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const SongBrowserPage(source: _source),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(AppIcons.settings).first);
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
  });

  testWidgets('settings_button_on_home_navigates_to_settings', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
          audioTrackPlayerFactoryProvider.overrideWithValue(
            FakeAudioTrackPlayer.new,
          ),
          localStorageServiceProvider.overrideWithValue(
            FakeLocalStorageService(),
          ),
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
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const SourceSelectionPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('CÀI ĐẶT'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
  });

  testWidgets('exit_button_on_home_requests_app_close', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
          audioTrackPlayerFactoryProvider.overrideWithValue(
            FakeAudioTrackPlayer.new,
          ),
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
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const SourceSelectionPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('THOÁT'));
    await tester.pump();
    await tester.tap(find.text('Thoát'));
    await tester.pump();

    expect(
      calls.where((call) => call.method == 'SystemNavigator.pop'),
      isNotEmpty,
    );
  });

  testWidgets('exit_button_on_main_top_bar_requests_app_close', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
          audioTrackPlayerFactoryProvider.overrideWithValue(
            FakeAudioTrackPlayer.new,
          ),
          localStorageServiceProvider.overrideWithValue(
            FakeLocalStorageService(),
          ),
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
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: const SongBrowserPage(source: _source),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('THOÁT'));
    await tester.pump();
    await tester.tap(find.text('Thoát'));
    await tester.pump();

    expect(
      calls.where((call) => call.method == 'SystemNavigator.pop'),
      isNotEmpty,
    );
  });

  testWidgets('tapping_miniplayer_on_settings_returns_to_song_browser', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        musicSdkPlatformProvider.overrideWithValue(
          FakeMusicSdkPlatform(failLink: true),
        ),
        audioTrackPlayerFactoryProvider.overrideWithValue(
          FakeAudioTrackPlayer.new,
        ),
        localStorageServiceProvider.overrideWithValue(
          FakeLocalStorageService(),
        ),
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
          onGenerateRoute: AppRouter.onGenerateRoute,
          home: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () => Navigator.of(
                  context,
                ).pushNamed(AppRouter.songBrowser, arguments: _source),
                child: const Text('Open browser'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open browser'));
    await tester.pumpAndSettle();
    await container
        .read(nowPlayingProvider.notifier)
        .play(
          const SongItem(
            id: 'mini',
            title: 'Mini Tap Song',
            subtitle: 'Test',
            duration: '3:00',
            thumbnailSeed: 1,
            badge: null,
          ),
          MusicSourceLogoStyle.soundcloud,
        );
    await tester.pumpAndSettle();

    Navigator.of(
      tester.element(find.byType(SongBrowserPage)),
    ).pushNamed(AppRouter.settings);
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.text('Mini Tap Song'), findsOneWidget);

    await tester.tap(find.text('Mini Tap Song'));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsNothing);
    expect(find.byType(SongBrowserPage), findsOneWidget);
  });

  testWidgets('clear_favorites_requires_a_second_tap_to_confirm', (
    tester,
  ) async {
    final storage = FakeLocalStorageService();
    final container = ProviderContainer(
      overrides: [localStorageServiceProvider.overrideWithValue(storage)],
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
          home: const SettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Toggled after the controller's initial (empty) load has already
    // settled via the pump above — toggling before that would race the
    // pending load, which resolves later and overwrites this mutation.
    container
        .read(favoritesControllerProvider.notifier)
        .toggle(
          const SongItem(
            id: '1',
            title: 'Song',
            subtitle: 'Sub',
            duration: '3:00',
            thumbnailSeed: 1,
            badge: null,
          ),
          MusicSourceLogoStyle.youtube,
        );
    await tester.pump();

    expect(container.read(favoritesControllerProvider), hasLength(1));

    await tester.tap(find.text('Quản lý bài hát'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Xóa danh sách yêu thích'));
    await tester.pump();
    expect(container.read(favoritesControllerProvider), hasLength(1));

    await tester.tap(find.text('Nhấn lần nữa để xác nhận xóa'));
    await tester.pump();
    expect(container.read(favoritesControllerProvider), isEmpty);
  });
}
