import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/providers/volume_provider.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/features/navigation/presentation/widgets/main_nav_rail.dart';
import 'package:viet_ktv/features/navigation/presentation/widgets/volume_rail_entry.dart';
import 'package:viet_ktv/features/settings/data/models/app_settings.dart';
import 'package:viet_ktv/features/settings/presentation/pages/settings_page.dart';
import 'package:viet_ktv/features/settings/presentation/providers/settings_controller.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';
import 'package:viet_ktv/routes/app_router.dart';

import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';
import '../../support/fake_volume_service.dart';

const _source = MusicSource(
  id: 'youtube',
  subtitle: 'Kho nhạc & Video\nkhổng lồ',
  accentColor: AppColors.red,
  logoStyle: MusicSourceLogoStyle.youtube,
);

Future<ProviderContainer> _pumpBrowser(
  WidgetTester tester,
  FakeVolumeService volume,
) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      volumeServiceProvider.overrideWithValue(volume),
      localStorageServiceProvider.overrideWithValue(FakeLocalStorageService()),
      musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
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
        home: const SongBrowserPage(source: _source),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Finder _volumeEntry() => find.byType(VolumeRailEntry);

void main() {
  testWidgets('rail_shows_the_volume_percent_as_its_label', (tester) async {
    await _pumpBrowser(tester, FakeVolumeService(initial: 0.42));

    expect(
      find.descendant(of: _volumeEntry(), matching: find.text('42%')),
      findsOneWidget,
    );
  });

  testWidgets('rail_volume_label_follows_the_hardware_keys', (tester) async {
    final volume = FakeVolumeService(initial: 0.2);
    await _pumpBrowser(tester, volume);
    expect(
      find.descendant(of: _volumeEntry(), matching: find.text('20%')),
      findsOneWidget,
    );

    volume.emitExternalChange(0.75);
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: _volumeEntry(), matching: find.text('75%')),
      findsOneWidget,
    );
  });

  testWidgets('slider_popup_is_hidden_until_the_icon_is_activated', (
    tester,
  ) async {
    await _pumpBrowser(tester, FakeVolumeService(initial: 0.3));

    expect(find.byKey(volumeSliderPopupKey), findsNothing);

    await tester.tap(_volumeEntry());
    await tester.pumpAndSettle();
    expect(find.byKey(volumeSliderPopupKey), findsOneWidget);

    await tester.tap(_volumeEntry());
    await tester.pumpAndSettle();
    expect(find.byKey(volumeSliderPopupKey), findsNothing);
  });

  testWidgets('popup_floats_above_the_icon_without_moving_the_rail', (
    tester,
  ) async {
    await _pumpBrowser(tester, FakeVolumeService(initial: 0.3));
    final railBefore = tester.getRect(find.byType(MainNavRail));
    final iconBefore = tester.getRect(_volumeEntry());

    await tester.tap(_volumeEntry());
    await tester.pumpAndSettle();

    // An overlay, not an inline expansion: nothing in the rail shifts.
    expect(tester.getRect(find.byType(MainNavRail)), railBefore);
    expect(tester.getRect(_volumeEntry()), iconBefore);
    expect(
      tester.getRect(find.byKey(volumeSliderPopupKey)).bottom,
      lessThanOrEqualTo(iconBefore.top),
    );
  });

  testWidgets('dragging_the_popup_track_sets_the_device_volume', (
    tester,
  ) async {
    final volume = FakeVolumeService(initial: 0.3);
    final container = await _pumpBrowser(tester, volume);

    await tester.tap(_volumeEntry());
    await tester.pumpAndSettle();

    // Top of the track is full, bottom is silent. Start at the popup's centre,
    // which is inside the track (it dominates the panel's height), and drag
    // past the top.
    final popup = tester.getRect(find.byKey(volumeSliderPopupKey));
    await tester.dragFrom(popup.center, const Offset(0, -200));
    await tester.pumpAndSettle();

    expect(volume.written, isNotEmpty);
    expect(volume.written.last, closeTo(1.0, 0.001));
    // Persisted too, so Settings → Âm thanh agrees with the rail.
    expect(
      container.read(settingsControllerProvider).masterVolume,
      closeTo(1.0, 0.001),
    );
  });

  testWidgets('tapping_outside_closes_the_popup', (tester) async {
    await _pumpBrowser(tester, FakeVolumeService(initial: 0.3));

    await tester.tap(_volumeEntry());
    await tester.pumpAndSettle();
    expect(find.byKey(volumeSliderPopupKey), findsOneWidget);

    await tester.tapAt(const Offset(1600, 200));
    await tester.pumpAndSettle();

    expect(find.byKey(volumeSliderPopupKey), findsNothing);
  });

  testWidgets('entry_is_inert_when_the_device_has_no_volume_service', (
    tester,
  ) async {
    final volume = FakeVolumeService(initial: null);
    await _pumpBrowser(tester, volume);

    await tester.tap(_volumeEntry());
    await tester.pumpAndSettle();

    expect(find.byKey(volumeSliderPopupKey), findsNothing);
    expect(volume.written, isEmpty);
  });

  testWidgets('connect_entry_opens_settings_on_the_device_section', (
    tester,
  ) async {
    final container = await _pumpBrowser(tester, FakeVolumeService());

    await tester.tap(
      find.descendant(
        of: find.byType(MainNavRail),
        matching: find.text('KẾT NỐI ĐT'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SettingsPage), findsOneWidget);
    final page = tester.widget<SettingsPage>(find.byType(SettingsPage));
    expect(page.initialCategory, SettingsCategory.device);
    // The deep-link must actually switch the visible section, not just carry
    // the argument.
    expect(
      container.read(settingsControllerProvider).selectedCategory,
      SettingsCategory.device,
    );
  });
}
