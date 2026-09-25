import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Scaffold(body: child),
  );
}

void main() {
  testWidgets('a settings toggle is a labelled switch', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        Center(
          child: SettingsToggle(
            value: false,
            semanticLabel: 'Spell check',
            onChanged: (bool _) {},
          ),
        ),
      ),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Spell check')),
      isSemantics(
        label: 'Spell check',
        hasToggledState: true,
        isToggled: false,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
      ),
    );
    handle.dispose();
  });

  testWidgets('two settings rows in one section are two nodes', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        ListView(
          children: const <Widget>[
            SettingsSection(
              title: 'Section',
              children: <Widget>[
                SettingsFieldRow(
                  label: 'A',
                  description: 'first row',
                  control: Text('control a'),
                ),
                SettingsFieldRow(
                  label: 'B',
                  description: 'second row',
                  control: Text('control b'),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final SemanticsNode a = tester.getSemantics(
      find.bySemanticsLabel(RegExp('^A')),
    );
    final SemanticsNode b = tester.getSemantics(
      find.bySemanticsLabel(RegExp('^B')),
    );
    expect(a.id, isNot(b.id));
    handle.dispose();
  });
}
