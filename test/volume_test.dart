import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:viet_ktv/core/providers/volume_provider.dart';
import 'package:viet_ktv/core/services/volume_service.dart';
import 'package:viet_ktv/core/shared/widgets/volume_indicator.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';
import 'package:viet_ktv/features/source_selection/presentation/pages/source_selection_page.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import 'support/fake_music_sdk_platform.dart';

const _source = MusicSource(
  id: 'youtube',
  subtitle: 'Kho nhạc & Video\nkhổng lồ',
  accentColor: AppColors.red,
  logoStyle: MusicSourceLogoStyle.youtube,
);

/// Stands in for the platform audio service.
class FakeVolumeService implements VolumeService {
  FakeVolumeService({this.initial = 0.25});

  final double? initial;
  final List<double> written = [];
  final StreamController<double> _changes =
      StreamController<double>.broadcast();

  /// Simulates the hardware volume keys.
  void emitExternalChange(double level) => _changes.add(level);

  @override
  Future<double?> read() async => initial;

  @override
  Future<void> write(double level) async => written.add(level);

  @override
  Stream<double> get changes => _changes.stream;

  @override
  Future<void> dispose() async => _changes.close();
}

Future<void> _pump(
  WidgetTester tester,
  Widget home,
  FakeVolumeService service, {
  Locale locale = const Locale('vi'),
}) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        volumeServiceProvider.overrideWithValue(service),
        // SongBrowserPage kicks off a real recommendations search as soon as
        // it mounts; without this it hits the real platform channel, which
        // has no test handler and hangs pumpAndSettle().
        musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
      ],
      child: MaterialApp(
        locale: locale,
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
}

void main() {
  testWidgets('shows_the_volume_reported_by_the_device', (tester) async {
    final service = FakeVolumeService(initial: 0.42);
    await _pump(tester, const SourceSelectionPage(), service);

    expect(find.text('42'), findsOneWidget);
  });

  testWidgets('shows_volume_control_on_song_browser', (tester) async {
    final service = FakeVolumeService(initial: 0.25);
    await _pump(tester, const SongBrowserPage(source: _source), service);

    expect(find.byType(VolumeIndicator), findsOneWidget);
    expect(find.text('25'), findsOneWidget);
  });

  testWidgets('writes_to_the_device_when_the_track_is_tapped', (tester) async {
    final service = FakeVolumeService(initial: 0.1);
    await _pump(tester, const SourceSelectionPage(), service);

    final track = tester.getRect(find.byType(VolumeIndicator));
    // Tap near the right end of the 118px track, which starts after the icon
    // and the readout.
    await tester.tapAt(Offset(track.right - 12, track.center.dy));
    await tester.pumpAndSettle();

    expect(service.written, isNotEmpty);
    expect(service.written.last, greaterThan(0.8));
    expect(find.text('10'), findsNothing);
  });

  testWidgets('follows_volume_changed_outside_the_app', (tester) async {
    final service = FakeVolumeService(initial: 0.2);
    await _pump(tester, const SourceSelectionPage(), service);
    expect(find.text('20'), findsOneWidget);

    // The hardware keys moved the volume; the bar must follow.
    service.emitExternalChange(0.8);
    await tester.pumpAndSettle();

    expect(find.text('80'), findsOneWidget);
    expect(service.written, isEmpty);
  });

  testWidgets('bottom_bar_fits_both_locales', (tester) async {
    // The browser bar packs the volume control plus five hints; Vietnamese and
    // English labels differ enough in length to clip one of them.
    for (final locale in const [Locale('vi'), Locale('en')]) {
      for (final home in [
        const SourceSelectionPage(),
        const SongBrowserPage(source: _source),
      ]) {
        await _pump(tester, home, FakeVolumeService(), locale: locale);
        expect(
          tester.takeException(),
          isNull,
          reason: 'overflowed for $locale on ${home.runtimeType}',
        );
      }
    }
  });

  testWidgets('disables_control_when_device_has_no_volume_service', (
    tester,
  ) async {
    final service = FakeVolumeService(initial: null);
    await _pump(tester, const SourceSelectionPage(), service);

    final track = tester.getRect(find.byType(VolumeIndicator));
    await tester.tapAt(Offset(track.right - 12, track.center.dy));
    await tester.pumpAndSettle();

    expect(service.written, isEmpty);
  });
}
