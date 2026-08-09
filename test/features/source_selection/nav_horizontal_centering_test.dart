import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/shared/widgets/app_top_nav.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/features/song_browser/presentation/pages/song_browser_page.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/source_selection/data/models/music_source.dart';
import 'package:viet_ktv/features/source_selection/presentation/pages/source_selection_page.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';

const _source = MusicSource(
  id: 'youtube',
  subtitle: 'Kho nhạc & Video\nkhổng lồ',
  accentColor: AppColors.red,
  logoStyle: MusicSourceLogoStyle.youtube,
);

const _viewportSize = Size(1920, 1080);

// Small tolerance for the nav's centre vs. the viewport's centre. The
// regression this guards against shifted the nav by ~120-140px at this
// width, so a few pixels of slack is generous without masking the bug.
const _centerToleranceX = 4.0;

Future<void> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = _viewportSize;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStorageServiceProvider.overrideWithValue(
          FakeLocalStorageService(),
        ),
        musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
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
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('source_picker_nav_is_horizontally_centered_on_screen', (
    tester,
  ) async {
    await _pump(tester, const SourceSelectionPage());

    final navCenterX = tester.getCenter(find.byType(AppTopNav)).dx;
    final screenCenterX = _viewportSize.width / 2;

    expect(
      navCenterX,
      closeTo(screenCenterX, _centerToleranceX),
      reason:
          'Source picker nav centre ($navCenterX) should match the screen '
          'centre ($screenCenterX), matching the browser page nav.',
    );
  });

  testWidgets('browser_page_nav_is_horizontally_centered_on_screen', (
    tester,
  ) async {
    await _pump(tester, const SongBrowserPage(source: _source));

    final navCenterX = tester.getCenter(find.byType(AppTopNav)).dx;
    final screenCenterX = _viewportSize.width / 2;

    expect(
      navCenterX,
      closeTo(screenCenterX, _centerToleranceX),
      reason:
          'Browser page nav centre ($navCenterX) should match the screen '
          'centre ($screenCenterX).',
    );
  });

  testWidgets('source_picker_nav_center_matches_browser_page_nav_center', (
    tester,
  ) async {
    await _pump(tester, const SourceSelectionPage());
    final sourcePickerNavCenterX = tester.getCenter(find.byType(AppTopNav)).dx;

    await _pump(tester, const SongBrowserPage(source: _source));
    final browserNavCenterX = tester.getCenter(find.byType(AppTopNav)).dx;

    expect(
      sourcePickerNavCenterX,
      closeTo(browserNavCenterX, _centerToleranceX),
      reason:
          'The nav must not visibly move when navigating between the '
          'source picker and the browser page.',
    );
  });
}
