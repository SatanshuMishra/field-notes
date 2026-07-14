import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';

import 'settings_harness.dart';

Color _trackColor(WidgetTester tester) {
  final DecoratedBox box = tester
      .widgetList<DecoratedBox>(
        find.descendant(
          of: find.byType(SettingsToggle),
          matching: find.byType(DecoratedBox),
        ),
      )
      .first;
  return (box.decoration as BoxDecoration).color!;
}

void main() {
  group('SettingsToggle', () {
    testWidgets('fills coral when on and panel colour when off',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        settingsHarness(
          SettingsToggle(value: true, onChanged: (_) {}),
        ),
      );
      expect(_trackColor(tester), Palette.coral);

      await tester.pumpWidget(
        settingsHarness(
          SettingsToggle(value: false, onChanged: (_) {}),
        ),
      );
      expect(_trackColor(tester), Palette.panelTop);
    });

    testWidgets('toggles the value on tap when enabled',
        (WidgetTester tester) async {
      bool? next;
      await tester.pumpWidget(
        settingsHarness(
          SettingsToggle(value: false, onChanged: (bool v) => next = v),
        ),
      );

      await tester.tap(find.byType(SettingsToggle));
      expect(next, isTrue);
    });

    testWidgets('is inert and dimmed when disabled',
        (WidgetTester tester) async {
      bool? next;
      await tester.pumpWidget(
        settingsHarness(
          SettingsToggle(
            value: false,
            onChanged: (bool v) => next = v,
            enabled: false,
          ),
        ),
      );

      final double opacity = tester
          .widget<Opacity>(
            find.descendant(
              of: find.byType(SettingsToggle),
              matching: find.byType(Opacity),
            ),
          )
          .opacity;
      expect(opacity, 0.5);

      await tester.tap(find.byType(SettingsToggle), warnIfMissed: false);
      expect(next, isNull);
    });
  });
}
