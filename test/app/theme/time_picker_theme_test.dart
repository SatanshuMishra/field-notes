import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Color? _fillBehind(WidgetTester tester, Finder text) {
  final Material material = tester.widget<Material>(
    find.ancestor(of: text, matching: find.byType(Material)).first,
  );
  return material.color;
}

void main() {
  for (final Brightness brightness in Brightness.values) {
    testWidgets(
      'the ${brightness.name} time picker marks the chosen AM or PM in the app accent',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: fieldNotesTheme(brightness: brightness),
            home: MediaQuery(
              data: const MediaQueryData(alwaysUse24HourFormat: false),
              child: Builder(
                builder: (BuildContext context) => TextButton(
                  onPressed: () => showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 20, minute: 30),
                  ),
                  child: const Text('pick'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('pick'));
        await tester.pumpAndSettle();

        final Finder pm = find.text('PM');
        final Finder am = find.text('AM');
        expect(pm, findsOneWidget);
        expect(_fillBehind(tester, pm), Palette.coral);
        expect(
          tester.widget<Text>(pm).style?.color ??
              DefaultTextStyle.of(tester.element(pm)).style.color,
          Palette.onAccent,
        );
        expect(_fillBehind(tester, am), isNot(Palette.coral));
      },
    );
  }
}
