import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/shared/widgets/liquid_glass.dart';
import 'package:viet_ktv/core/shared/widgets/surface_scope.dart';
import 'package:viet_ktv/features/settings/data/models/app_settings.dart';
import 'package:viet_ktv/features/settings/presentation/pages/settings_page.dart'
    show SettingsPage;
import 'package:viet_ktv/features/settings/presentation/widgets/settings_content_panel.dart';
import 'package:viet_ktv/features/settings/presentation/widgets/settings_preview_panel.dart';
import 'package:viet_ktv/features/settings/presentation/providers/settings_controller.dart';
import 'package:viet_ktv/features/settings/presentation/widgets/settings_sidebar.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import '../../support/fake_local_storage_service.dart';

Future<ProviderContainer> _pump(
  WidgetTester tester,
  Widget home, {
  Size size = const Size(1920, 1080),
}) async {
  tester.view.physicalSize = size;
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
  testWidgets('wide_layout_has_one_panel_surface_for_the_content_area', (
    tester,
  ) async {
    // 1920x1080 clears both the 1040px compact breakpoint and the 1040px
    // preview breakpoint, so sidebar + content + preview are all built.
    await _pump(tester, const SettingsPage());

    expect(find.byType(ContentSlab), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ContentSlab),
        matching: find.byType(SettingsSidebar),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ContentSlab),
        matching: find.byType(SettingsContentPanel),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(ContentSlab),
        matching: find.byType(SettingsPreviewPanel),
      ),
      findsOneWidget,
    );

    // Sidebar|content and content|preview hairlines.
    final vertical = tester
        .widgetList<SurfaceDivider>(find.byType(SurfaceDivider))
        .where((divider) => divider.axis == Axis.vertical);
    expect(vertical.length, 2);
  });

  testWidgets(
    'wide_layout_holds_its_widths_at_the_real_floor_and_at_a_large_size',
    (tester) async {
      // KaraokeShell guarantees an outer landscape canvas of at least
      // 1366x768, but subtracts its own horizontal padding
      // (AppLayout.shellHorizontalPaddingFor) before handing width to the
      // body, so the body's real floor is ~1270 wide, not 1366. That is
      // still comfortably above the 1040 sidebar/preview-visibility
      // breakpoint (always true/false), but it lands BELOW the 1320
      // preview-width breakpoint, so a device at the 1366x768 minimum
      // renders a 320-wide preview column, not 430. At 1920x1080 the body
      // clears 1320 and the preview column is 430 wide.
      final cases = <Size, double>{
        const Size(1366, 768): 320.0,
        const Size(1920, 1080): 430.0,
      };
      for (final entry in cases.entries) {
        await _pump(tester, const SettingsPage(), size: entry.key);

        expect(find.byType(ContentSlab), findsOneWidget);

        final sidebarBox = tester.getSize(find.byType(SettingsSidebar));
        expect(sidebarBox.width, 330.0);

        final previewBox = tester.getSize(find.byType(SettingsPreviewPanel));
        expect(previewBox.width, entry.value);

        final vertical = tester
            .widgetList<SurfaceDivider>(find.byType(SurfaceDivider))
            .where((divider) => divider.axis == Axis.vertical);
        expect(vertical.length, 2);
      }
    },
  );

  testWidgets('preview_column_draws_a_horizontal_hairline_between_its_cards', (
    tester,
  ) async {
    // Isolated: no ContentSlab/SurfaceScope ancestor, matching how the widget
    // must still behave if built outside a converted screen.
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('vi'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(
          body: SizedBox(
            width: 360,
            height: 700,
            child: SettingsPreviewPanel(settings: AppSettings()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final horizontal = tester
        .widgetList<SurfaceDivider>(find.byType(SurfaceDivider))
        .where((divider) => divider.axis == Axis.horizontal);
    expect(horizontal.length, 1);
  });

  testWidgets(
    'quality_tiles_and_toggle_chips_keep_their_own_surface_inside_the_slab',
    (tester) async {
      // The language row's VI/EN toggle is the one reusable "chip" in
      // settings that already paints its own LiquidGlassDetail.simple
      // surface (video-category quality tiles and switch rows use plain
      // Container decoration, not LiquidGlass, so they aren't at risk of
      // silently being absorbed by a SurfaceScope the way this chip is).
      final container = await _pump(tester, const SettingsPage());

      // Switched after the initial build settles, not via the constructor's
      // initialCategory — applying that during the first
      // didChangeDependencies modifies the provider mid-build, which
      // UncontrolledProviderScope's container rejects.
      container
          .read(settingsControllerProvider.notifier)
          .selectCategory(SettingsCategory.language);
      await tester.pumpAndSettle();

      expect(find.byType(ContentSlab), findsOneWidget);

      final chipSurfaces = tester
          .widgetList<LiquidGlass>(
            find.descendant(
              of: find.byType(ContentSlab),
              matching: find.byType(LiquidGlass),
            ),
          )
          .where((glass) => glass.detail == LiquidGlassDetail.simple);
      expect(chipSurfaces, isNotEmpty);
    },
  );
}
