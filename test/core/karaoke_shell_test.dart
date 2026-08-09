import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/shared/widgets/karaoke_shell.dart';

Future<void> _pump(WidgetTester tester, {required bool chromeVisible}) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      home: KaraokeShell(
        chromeVisible: chromeVisible,
        topBar: const Text('TOP BAR'),
        body: const Text('BODY'),
        bottomBar: const Text('BOTTOM BAR'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows_chrome_by_default', (tester) async {
    await _pump(tester, chromeVisible: true);

    expect(find.text('TOP BAR'), findsOneWidget);
    expect(find.text('BOTTOM BAR'), findsOneWidget);
    expect(find.text('BODY'), findsOneWidget);
  });

  testWidgets('removes_chrome_from_the_tree_when_hidden', (tester) async {
    // Absent, not merely invisible: an Offstage or Opacity would still cost
    // layout on a 2GB box.
    await _pump(tester, chromeVisible: false);

    expect(find.text('TOP BAR'), findsNothing);
    expect(find.text('BOTTOM BAR'), findsNothing);
    expect(find.text('BODY'), findsOneWidget);
  });

  testWidgets('body_is_taller_without_chrome', (tester) async {
    await _pump(tester, chromeVisible: true);
    final withChrome = tester.getSize(find.text('BODY'));

    await _pump(tester, chromeVisible: false);
    final withoutChrome = tester.getSize(find.text('BODY'));

    expect(withoutChrome.height, greaterThan(withChrome.height));
  });
}
