import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/shared/widgets/liquid_glass.dart';
import 'package:viet_ktv/core/shared/widgets/surface_scope.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/queue/presentation/pages/selected_queue_page.dart';
import 'package:viet_ktv/features/queue/presentation/widgets/selected_queue_panel.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/preview_player.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import '../../support/fake_local_storage_service.dart';

Future<ProviderContainer> _pump(WidgetTester tester, Widget home) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final container = ProviderContainer(
    overrides: [
      localStorageServiceProvider.overrideWithValue(FakeLocalStorageService()),
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

void main() {
  testWidgets('normal_mode_has_one_panel_surface_for_the_content', (
    tester,
  ) async {
    await _pump(tester, const SelectedQueuePage());

    // Exactly one panel-level surface for the whole content area: the
    // ContentSlab itself, with the queue panel and the player both inside
    // it. A nested panel coming back (the queue panel painting its own
    // surface again) turns this red.
    expect(find.byType(ContentSlab), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ContentSlab),
        matching: find.byType(PreviewPlayer),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ContentSlab),
        matching: find.byType(SelectedQueuePanel),
      ),
      findsOneWidget,
    );
    final queuePanelSurfaces = tester
        .widgetList<LiquidGlass>(
          find.descendant(
            of: find.byType(SelectedQueuePanel),
            matching: find.byType(LiquidGlass),
          ),
        )
        .where((glass) => glass.detail == LiquidGlassDetail.full);
    expect(queuePanelSurfaces, isEmpty);

    final vertical = tester
        .widgetList<SurfaceDivider>(find.byType(SurfaceDivider))
        .where((divider) => divider.axis == Axis.vertical);
    expect(vertical.length, 1);
  });

  testWidgets('wide_mode_drops_the_vertical_hairline_with_the_column', (
    tester,
  ) async {
    final container = await _pump(tester, const SelectedQueuePage());

    // Normal mode must have the hairline to begin with — otherwise "it's
    // gone in wide mode" is true for the wrong reason (there was never one).
    final verticalNormal = tester
        .widgetList<SurfaceDivider>(find.byType(SurfaceDivider))
        .where((divider) => divider.axis == Axis.vertical);
    expect(verticalNormal.length, 1);

    container.read(nowPlayingProvider.notifier).toggleWide();
    await tester.pumpAndSettle();

    final vertical = tester
        .widgetList<SurfaceDivider>(find.byType(SurfaceDivider))
        .where((divider) => divider.axis == Axis.vertical);
    expect(vertical, isEmpty);
  });

  testWidgets('fullscreen_builds_no_slab_around_the_player', (tester) async {
    final container = await _pump(tester, const SelectedQueuePage());

    container.read(nowPlayingProvider.notifier).enterFullscreen();
    await tester.pumpAndSettle();

    expect(find.byType(ContentSlab), findsNothing);

    // The collapsed queue column is still mounted underneath in fullscreen
    // (its state survives an instant return to normal). Without a bare
    // SurfaceScope wrapping it there, PanelFrame would paint its own
    // LiquidGlass surface with no slab behind it.
    final queuePanelSurfaces = tester
        .widgetList<LiquidGlass>(
          find.descendant(
            of: find.byType(SelectedQueuePanel),
            matching: find.byType(LiquidGlass),
          ),
        )
        .where((glass) => glass.detail == LiquidGlassDetail.full);
    expect(queuePanelSurfaces, isEmpty);
  });
}
