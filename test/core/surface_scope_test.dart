import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/providers/local_storage_provider.dart';
import 'package:viet_ktv/core/shared/widgets/liquid_glass.dart';
import 'package:viet_ktv/core/shared/widgets/panel_frame.dart';
import 'package:viet_ktv/core/shared/widgets/surface_scope.dart';
import 'package:viet_ktv/core/theme/app_icons.dart';
import 'package:viet_ktv/core/theme/app_spacing.dart';
import 'package:viet_ktv/features/playback/presentation/providers/now_playing_controller.dart';
import 'package:viet_ktv/features/song_browser/presentation/providers/music_sdk_repository_provider.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/native_song_search_field.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/preview_player.dart';
import 'package:viet_ktv/l10n/app_localizations.dart';

import '../support/fake_local_storage_service.dart';
import '../support/fake_music_sdk_platform.dart';

/// Counts panel-level surfaces only. Small repeated chips use
/// LiquidGlassDetail.simple and must not be swept up by these assertions.
int _panelSurfaces(WidgetTester tester) => tester
    .widgetList<LiquidGlass>(find.byType(LiquidGlass))
    .where((glass) => glass.detail == LiquidGlassDetail.full)
    .length;

/// Counts only the "whole framed player" surface — a full-detail LiquidGlass
/// wrapping a ClipRRect, the shape PreviewPlayer's normal/wide branch and
/// ContentSlab both use to frame an entire region. This deliberately ignores
/// small incidental full-detail surfaces inside the player (e.g. the status
/// chip), which are unrelated to whether the region itself is framed.
int _framedPlayerSurfaces(WidgetTester tester) => tester
    .widgetList<LiquidGlass>(find.byType(LiquidGlass))
    .where(
      (glass) =>
          glass.detail == LiquidGlassDetail.full && glass.child is ClipRRect,
    )
    .length;

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('scope_is_absent_by_default', (tester) async {
    late bool inScope;
    await _pump(
      tester,
      Builder(
        builder: (context) {
          inScope = SurfaceScope.of(context);
          return const SizedBox.shrink();
        },
      ),
    );

    expect(inScope, isFalse);
  });

  testWidgets('scope_is_visible_to_descendants', (tester) async {
    late bool inScope;
    await _pump(
      tester,
      SurfaceScope(
        child: Builder(
          builder: (context) {
            inScope = SurfaceScope.of(context);
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(inScope, isTrue);
  });

  testWidgets('panel_frame_paints_its_own_surface_outside_a_scope', (
    tester,
  ) async {
    await _pump(tester, const PanelFrame(child: Text('BODY')));

    expect(_panelSurfaces(tester), 1);
    expect(find.text('BODY'), findsOneWidget);
  });

  testWidgets('panel_frame_renders_bare_inside_a_scope', (tester) async {
    await _pump(
      tester,
      const SurfaceScope(child: PanelFrame(child: Text('BODY'))),
    );

    expect(_panelSurfaces(tester), 0);
    expect(find.text('BODY'), findsOneWidget);
  });

  testWidgets('content_slab_paints_exactly_one_surface_for_its_children', (
    tester,
  ) async {
    // Two panels that would each paint their own surface collapse into the
    // slab's single one — this is the whole point of the pairing. Each
    // PanelFrame is wrapped in Expanded: PanelFrame's own Column ends with a
    // tight Expanded(child: child), and a bare (non-flex) child of an
    // unbounded Column would assert against that tight fit. Giving the
    // Column's own children a flex (as every real caller does) keeps the
    // ambient height bounded for each PanelFrame.
    await _pump(
      tester,
      const ContentSlab(
        child: Column(
          children: [
            Expanded(child: PanelFrame(child: Text('ONE'))),
            Expanded(child: PanelFrame(child: Text('TWO'))),
          ],
        ),
      ),
    );

    expect(_panelSurfaces(tester), 1);
    expect(find.text('ONE'), findsOneWidget);
    expect(find.text('TWO'), findsOneWidget);
  });

  testWidgets('surface_divider_is_one_pixel_on_each_axis', (tester) async {
    await _pump(
      tester,
      const Column(
        children: [
          SurfaceDivider(),
          Expanded(
            child: Row(children: [SurfaceDivider(axis: Axis.vertical)]),
          ),
        ],
      ),
    );

    final dividers = tester.widgetList<SurfaceDivider>(
      find.byType(SurfaceDivider),
    );
    expect(dividers.length, 2);
    expect(tester.getSize(find.byType(SurfaceDivider).first).height, 1);
    expect(tester.getSize(find.byType(SurfaceDivider).last).width, 1);
  });

  testWidgets('surface_divider_fills_its_cross_axis', (tester) async {
    // Neither Column nor Row here uses CrossAxisAlignment.stretch — this is
    // the default alignment a real caller between two regions would use. A
    // childless ColoredBox is a RenderProxyBox that reports
    // constraints.smallest, so under the loose cross-axis constraint a
    // default Column/Row hands a non-stretched child, the divider collapses
    // to zero on its cross axis and paints nothing. Only a widget that
    // inserts its own expanding constraint (Container's childless
    // ConstrainedBox.expand) fills it.
    await _pump(
      tester,
      const Column(
        children: [
          SurfaceDivider(),
          Expanded(
            child: Row(children: [SurfaceDivider(axis: Axis.vertical)]),
          ),
        ],
      ),
    );

    final horizontalSize = tester.getSize(find.byType(SurfaceDivider).first);
    final verticalSize = tester.getSize(find.byType(SurfaceDivider).last);

    expect(
      horizontalSize.width,
      greaterThan(0),
      reason:
          'the horizontal hairline must span the full cross axis, not just '
          'be 1px tall with zero width',
    );
    expect(
      verticalSize.height,
      greaterThan(0),
      reason:
          'the vertical hairline must span the full cross axis, not just '
          'be 1px wide with zero height',
    );
  });

  testWidgets(
    'license_gate_panel_fills_the_loose_slot_instead_of_hugging_content',
    (tester) async {
      // Reproduces the real caller shape at license_gate_page.dart:351-358:
      // Center -> ConstrainedBox(maxWidth: 560) -> PanelFrame -> min-sized
      // Column. PanelFrame's own inner Column ends with `Expanded(child:
      // child)`, which is FlexFit.tight and must claim all of the ambient
      // height Center/ConstrainedBox hand down. A `Flexible` (FlexFit.loose)
      // there instead hugs the min-sized Column's intrinsic content height,
      // shrinking the whole licence-gate panel from ~640px tall to ~150px.
      tester.view.physicalSize = const Size(1280, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await _pump(
        tester,
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: PanelFrame(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [Icon(Icons.info, size: 64), Text('Title')],
              ),
            ),
          ),
        ),
      );

      final panelHeight = tester.getSize(find.byType(PanelFrame)).height;
      final bodyHeight = tester.getSize(find.byType(Scaffold)).height;

      // A hugging PanelFrame measures well under half the body height for
      // this tiny icon+text content; a filling one claims (almost) all of
      // it, matching the 640.4-tall measurement in the real shell.
      expect(
        panelHeight,
        greaterThan(bodyHeight * 0.8),
        reason:
            'PanelFrame must fill the loose slot Center/ConstrainedBox hand '
            'it, not hug its min-sized Column child',
      );
    },
  );

  testWidgets(
    'search_field_renders_no_full_surface_inside_a_scope_and_one_outside',
    (tester) async {
      await _pump(
        tester,
        const NativeSongSearchField(
          query: '',
          placeholder: 'placeholder',
          onChanged: _noopOnChanged,
          onSubmitted: _noopOnSubmitted,
        ),
      );
      expect(_panelSurfaces(tester), 1);

      await _pump(
        tester,
        const SurfaceScope(
          child: NativeSongSearchField(
            query: '',
            placeholder: 'placeholder',
            onChanged: _noopOnChanged,
            onSubmitted: _noopOnSubmitted,
          ),
        ),
      );
      expect(_panelSurfaces(tester), 0);
    },
  );

  testWidgets(
    'fullscreen_player_renders_no_surface_regardless_of_scope_presence',
    (tester) async {
      // Pins fullscreen as the first branch: even wrapped in a SurfaceScope
      // (which would otherwise make a normal/wide player render bare instead
      // of via its own LiquidGlass), fullscreen must still take the overlay
      // branch and paint no panel-level surface at all — not the scope's
      // "render bare" branch, not the LiquidGlass branch.
      Future<ProviderContainer> pumpPlayer({required bool inScope}) async {
        final container = ProviderContainer(
          overrides: [
            localStorageServiceProvider.overrideWithValue(
              FakeLocalStorageService(),
            ),
            musicSdkPlatformProvider.overrideWithValue(FakeMusicSdkPlatform()),
          ],
        );
        addTearDown(container.dispose);
        container.read(nowPlayingProvider.notifier).enterFullscreen();

        const player = PreviewPlayer();
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
              home: Scaffold(
                body: inScope ? const SurfaceScope(child: player) : player,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        return container;
      }

      await pumpPlayer(inScope: false);
      expect(
        _framedPlayerSurfaces(tester),
        0,
        reason: 'fullscreen must render no panel surface outside a scope',
      );

      await pumpPlayer(inScope: true);
      expect(
        _framedPlayerSurfaces(tester),
        0,
        reason: 'fullscreen must render no panel surface inside a scope too',
      );

      // Zero framed surfaces is also what a bare `framedPlayer` Column would
      // produce if the scope check were wrongly evaluated before the
      // fullscreen check, so the assertions above alone do not pin the
      // branch order. Only the overlay auto-hides its transport strip after
      // kControlsAutoHideDelay; framedPlayer's strip never hides. Advancing
      // past the delay and requiring the strip to be gone is what actually
      // discriminates the two branches.
      await tester.pump(kControlsAutoHideDelay + const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(
        find.byIcon(AppIcons.fullscreenExit),
        findsNothing,
        reason:
            'fullscreen inside a scope must still take the auto-hiding '
            'overlay branch, not the always-visible framedPlayer branch',
      );
    },
  );
}

void _noopOnChanged(String value) {}

Future<void> _noopOnSubmitted() async {}
