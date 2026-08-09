import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/shared/widgets/glow_card.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/source_selection/presentation/pages/source_selection_page.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import '../../support/fake_local_storage_service.dart';
import '../../support/fake_music_sdk_platform.dart';

const _viewportSize = Size(1920, 1080);

// A few pixels of slack. The regression this guards against left a whole
// empty column on the right — roughly 580px of offset at this width — so
// this tolerance is generous without masking it.
const _centerToleranceX = 4.0;

Future<void> _pump(WidgetTester tester) async {
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
        home: const SourceSelectionPage(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<Rect> _cardRects(WidgetTester tester) {
  final finder = find.byType(GlowCard);
  return List<Rect>.generate(
    finder.evaluate().length,
    (i) => tester.getRect(finder.at(i)),
  );
}

void main() {
  testWidgets('source_cards_are_horizontally_centered_as_a_group', (
    tester,
  ) async {
    await _pump(tester);

    final rects = _cardRects(tester);
    expect(rects, isNotEmpty);

    final left = rects.map((r) => r.left).reduce((a, b) => a < b ? a : b);
    final right = rects.map((r) => r.right).reduce((a, b) => a > b ? a : b);

    expect(
      (left + right) / 2,
      closeTo(_viewportSize.width / 2, _centerToleranceX),
    );
  });

  testWidgets('source_cards_keep_their_size_instead_of_stretching', (
    tester,
  ) async {
    // Centring must not be achieved by widening the cards to fill the row.
    // The grid sizes cards for its responsive column count (3 at this
    // width, ~580px each); collapsing to a 2-column grid would make each
    // card ~890px. 768 sits cleanly between the two, so this fails if a
    // future change centres by stretching rather than by moving.
    await _pump(tester);

    for (final rect in _cardRects(tester)) {
      expect(rect.width, lessThan(768));
    }
  });
}
