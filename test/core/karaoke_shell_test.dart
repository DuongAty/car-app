import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/shared/widgets/karaoke_shell.dart';
import 'package:viet_ktv/core/theme/app_layout.dart';

Future<void> _pump(
  WidgetTester tester, {
  required bool chromeVisible,
  Size size = const Size(1920, 1080),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: KaraokeShell(
        chromeVisible: chromeVisible,
        navRail: const Text('NAV RAIL'),
        body: const Text('BODY'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows_chrome_by_default', (tester) async {
    await _pump(tester, chromeVisible: true);

    expect(find.text('NAV RAIL'), findsOneWidget);
    expect(find.text('BODY'), findsOneWidget);
  });

  testWidgets('removes_chrome_from_the_tree_when_hidden', (tester) async {
    // Absent, not merely invisible: an Offstage or Opacity would still cost
    // layout on a 2GB box.
    await _pump(tester, chromeVisible: false);

    expect(find.text('NAV RAIL'), findsNothing);
    expect(find.text('BODY'), findsOneWidget);
  });

  testWidgets('body_is_wider_without_chrome', (tester) async {
    await _pump(tester, chromeVisible: true);
    final withChrome = tester.getSize(find.text('BODY'));

    await _pump(tester, chromeVisible: false);
    final withoutChrome = tester.getSize(find.text('BODY'));

    expect(withoutChrome.width, greaterThan(withChrome.width));
  });

  testWidgets('rail_sits_left_of_the_body', (tester) async {
    await _pump(tester, chromeVisible: true);

    expect(
      tester.getRect(find.text('NAV RAIL')).right,
      lessThanOrEqualTo(tester.getRect(find.text('BODY')).left),
    );
  });

  testWidgets('chrome_costs_the_body_no_height', (tester) async {
    // The whole point of moving navigation into a left rail: the video stage
    // keeps the full screen height whether the chrome is up or not.
    await _pump(tester, chromeVisible: true);
    final withChrome = tester.getSize(find.text('BODY'));

    await _pump(tester, chromeVisible: false);
    final withoutChrome = tester.getSize(find.text('BODY'));

    // Only the shell's own top/bottom padding separates the two.
    expect(withChrome.height, greaterThan(withoutChrome.height * 0.9));
  });

  testWidgets('scales_down_without_letterboxing_below_the_landscape_floor', (
    tester,
  ) async {
    // 1280x720 is below the 1366x768 floor AND a wider ratio than it. Fitting
    // a fixed 1366x768 canvas into it left ~30px black bars down both sides,
    // which read on a head unit as the nav rail floating away from the screen
    // edge. The canvas must take the display's own ratio instead.
    const size = Size(1280, 720);
    await _pump(tester, chromeVisible: true, size: size);

    final rail = tester.getRect(find.text('NAV RAIL'));
    final body = tester.getRect(find.text('BODY'));

    // The rail sits at exactly the shell's own inset; a letterboxed canvas
    // pushed it ~31px inward here, five times further.
    final scale = math.min(
      size.width / AppLayout.minimumLandscapeWidth,
      size.height / AppLayout.minimumLandscapeHeight,
    );
    expect(
      rail.left,
      closeTo(AppLayout.navRailInset * scale, 1),
      reason: 'left black bar',
    );
    // Only the shell's own right gutter is left over — not a gutter plus a bar.
    expect(
      size.width - body.right,
      lessThan(AppLayout.shellHorizontalPaddingFor(size.width)),
      reason: 'right black bar',
    );
  });
}
