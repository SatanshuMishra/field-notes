import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/interaction/hover_fill.dart';
import 'package:field_notes/design/interaction/hover_style.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const BorderRadius _radius = BorderRadius.all(Radius.circular(12));

Future<DecoratedBox> _fill(
  WidgetTester tester, {
  required bool hovered,
  DecorationPosition position = DecorationPosition.foreground,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: fieldNotesTheme(platform: TargetPlatform.macOS),
      home: Center(
        child: HoverFill(
          hovered: hovered,
          surface: FocusRingSurface.dark,
          borderRadius: _radius,
          position: position,
          child: const SizedBox.square(dimension: 40),
        ),
      ),
    ),
  );
  return tester.widget<DecoratedBox>(
    find.descendant(
      of: find.byType(HoverFill),
      matching: find.byType(DecoratedBox),
    ),
  );
}

void main() {
  testWidgets('a hovered fill paints the shared hover style over its child', (
    WidgetTester tester,
  ) async {
    final DecoratedBox box = await _fill(tester, hovered: true);
    final BuildContext context = tester.element(find.byType(HoverFill));

    expect(box.position, DecorationPosition.foreground);
    expect(
      box.decoration,
      HoverStyle.decoration(
        color: HoverStyle.of(
          context,
          FocusRingSurface.dark,
          HoverShape.rounded,
        ),
        shape: HoverShape.rounded,
        borderRadius: _radius,
      ),
    );
  });

  testWidgets('a fill at rest paints nothing and keeps its position', (
    WidgetTester tester,
  ) async {
    final DecoratedBox box = await _fill(
      tester,
      hovered: false,
      position: DecorationPosition.background,
    );

    expect(box.position, DecorationPosition.background);
    expect((box.decoration as BoxDecoration).color, isNull);
  });
}
