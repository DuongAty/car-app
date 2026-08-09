import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/core/theme/app_icons.dart';
import 'package:viet_ktv/features/playback/data/audio_track_player.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/song_browser/data/models/song_item.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/preview_player.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import '../../support/fake_audio_track_player.dart';
import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';

const _source = MusicSource(
  id: 'youtube',
  subtitle: 'Kho nhạc & Video\nkhổng lồ',
  accentColor: AppColors.red,
  logoStyle: MusicSourceLogoStyle.youtube,
);

const _song = SongItem(
  id: 'track-1',
  title: 'Test Song',
  subtitle: 'SoundCloud',
  duration: '00:30',
  thumbnailSeed: 1,
  badge: null,
);

/// Builds the page. The badge only appears when a player is actually live, so
/// [playing] starts real playback on the audio path (SoundCloud, which the
/// [FakeAudioTrackPlayer] stands in for) — see now_playing_seek_test.dart for
/// the same pattern.
Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required bool playing,
}) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(FakeLocalStorageService()),
      musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
      audioTrackPlayerFactoryProvider.overrideWithValue(
        FakeAudioTrackPlayer.new,
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
        home: const SongBrowserPage(source: _source),
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (playing) {
    unawaited(
      container
          .read(nowPlayingProvider.notifier)
          .play(_song, MusicSourceLogoStyle.soundcloud),
    );
    await tester.pumpAndSettle();
    expect(
      container.read(nowPlayingProvider).audioPlayer,
      isNotNull,
      reason: 'the badge tests need a genuinely live player',
    );
  }

  return container;
}

Future<void> _doubleTapAt(WidgetTester tester, double fraction) async {
  final rect = tester.getRect(find.byType(PreviewPlayer));
  final point = Offset(
    rect.left + rect.width * fraction,
    rect.top + rect.height * 0.3,
  );
  await tester.tapAt(point);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(point);
  await tester.pump(const Duration(milliseconds: 50));
}

/// Horizontal centre of the picture, used to assert which half the badge
/// lands on.
double _playerMidX(WidgetTester tester) =>
    tester.getRect(find.byType(PreviewPlayer)).center.dx;

void main() {
  testWidgets('seeking_forward_shows_the_forward_badge', (tester) async {
    await _pump(tester, playing: true);

    await _doubleTapAt(tester, 0.85);

    expect(find.text('10s'), findsOneWidget);
    // Counted, not just "present": the transport strip below already shows one
    // of each arrow, so an unqualified finder passes even with the direction
    // inverted. Two fast-forwards (strip + badge) and one lone rewind (strip)
    // is the only shape a correct forward badge can produce.
    expect(find.byIcon(AppIcons.fastForward), findsNWidgets(2));
    expect(find.byIcon(AppIcons.rewind), findsOneWidget);
    // The spec puts the badge over the half of the picture that was tapped.
    expect(
      tester.getCenter(find.text('10s')).dx,
      greaterThan(_playerMidX(tester)),
    );
  });

  testWidgets('seeking_backward_shows_the_backward_badge', (tester) async {
    await _pump(tester, playing: true);

    await _doubleTapAt(tester, 0.15);

    expect(find.text('10s'), findsOneWidget);
    expect(find.byIcon(AppIcons.rewind), findsNWidgets(2));
    expect(find.byIcon(AppIcons.fastForward), findsOneWidget);
    expect(
      tester.getCenter(find.text('10s')).dx,
      lessThan(_playerMidX(tester)),
    );
  });

  testWidgets('the_badge_disappears_after_the_hold', (tester) async {
    await _pump(tester, playing: true);
    await _doubleTapAt(tester, 0.85);
    expect(find.text('10s'), findsOneWidget);

    await tester.pump(kSeekBadgeDuration + const Duration(milliseconds: 400));
    await tester.pumpAndSettle();

    expect(find.text('10s'), findsNothing);
  });

  testWidgets('seeking_with_nothing_playing_shows_no_badge', (tester) async {
    // The controller's seek is a silent no-op with no player, so a badge
    // would be claiming a jump that never happened.
    await _pump(tester, playing: false);

    await _doubleTapAt(tester, 0.85);
    expect(find.text('10s'), findsNothing);

    await _doubleTapAt(tester, 0.15);
    expect(find.text('10s'), findsNothing);
  });

  testWidgets('the_centre_zone_shows_no_badge', (tester) async {
    // Entering fullscreen is its own evidence; a badge there would be noise.
    await _pump(tester, playing: true);

    await _doubleTapAt(tester, 0.5);

    expect(find.text('10s'), findsNothing);
  });

  testWidgets('disposing_while_the_badge_is_up_cancels_the_hide_timer', (
    tester,
  ) async {
    await _pump(tester, playing: true);
    await _doubleTapAt(tester, 0.85);
    expect(find.text('10s'), findsOneWidget);

    // Unmount well inside the hold, then advance by much less than
    // kSeekBadgeDuration so the hide timer has NOT fired. If dispose failed to
    // cancel it, it is still pending at teardown and the test binding's
    // pending-timer assertion fails the test — that check, not takeException,
    // is what actually guards the cancel.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 50));

    expect(tester.takeException(), isNull);
  });
}
