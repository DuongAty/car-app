import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:viet_ktv/core/shared/widgets/surface_scope.dart';
import 'package:viet_ktv/core/theme/app_colors.dart';
import 'package:viet_ktv/core/theme/app_theme.dart';
import 'package:viet_ktv/features/song_browser/presentation/widgets/native_song_search_field.dart';

/// Verifies the search field flattens onto the browser's merged
/// [ContentSlab] instead of reading as its own floating pill, while staying
/// completely unchanged on the six other screens that still use the
/// app-wide pill look.
///
/// The theme merges into [InputDecoration] at build time (see
/// [InputDecoration.applyDefaults]), so tests read the *effective* decoration
/// — the field's own explicit values layered onto the theme — rather than
/// the raw widget-level decoration alone.
void main() {
  Future<InputDecoration> pumpAndReadDecoration(
    WidgetTester tester, {
    required bool inScope,
  }) async {
    Widget field = NativeSongSearchField(
      query: '',
      placeholder: 'Tìm bài hát',
      onChanged: (_) {},
      onSubmitted: () async {},
    );
    if (inScope) {
      field = SurfaceScope(child: field);
    }

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(body: field),
      ),
    );

    final context = tester.element(find.byType(TextField));
    final textField = tester.widget<TextField>(find.byType(TextField));
    final theme = Theme.of(context).inputDecorationTheme;
    return textField.decoration!.applyDefaults(theme);
  }

  testWidgets('inside_a_scope_the_field_has_no_fill_and_no_pill_at_rest', (
    tester,
  ) async {
    final decoration = await pumpAndReadDecoration(tester, inScope: true);

    expect(decoration.filled, isFalse);
    expect(decoration.enabledBorder, isNot(isA<OutlineInputBorder>()));
  });

  testWidgets('inside_a_scope_focus_shows_a_green_underline', (tester) async {
    final decoration = await pumpAndReadDecoration(tester, inScope: true);

    final focusedBorder = decoration.focusedBorder;
    expect(focusedBorder, isA<UnderlineInputBorder>());
    final side = (focusedBorder as UnderlineInputBorder).borderSide;
    expect(side.color, AppColors.green);
    expect(side.width, 1.5);
  });

  testWidgets('outside_a_scope_the_filled_pill_decoration_is_intact', (
    tester,
  ) async {
    final decoration = await pumpAndReadDecoration(tester, inScope: false);

    expect(decoration.filled, isTrue);
    expect(decoration.fillColor, AppColors.panelStrong);
    expect(decoration.enabledBorder, isA<OutlineInputBorder>());
    final enabledShape =
        (decoration.enabledBorder as OutlineInputBorder).borderRadius;
    expect(enabledShape, BorderRadius.circular(999));

    expect(decoration.focusedBorder, isA<OutlineInputBorder>());
    final focusedSide =
        (decoration.focusedBorder as OutlineInputBorder).borderSide;
    expect(focusedSide.color, AppColors.green);
    expect(focusedSide.width, 1.5);
  });
}
