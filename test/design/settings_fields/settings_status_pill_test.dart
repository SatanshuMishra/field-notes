import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';

import 'settings_harness.dart';

void main() {
  group('SettingsStatusPill', () {
    testWidgets('renders its label',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        settingsHarness(const SettingsStatusPill(label: 'Not connected')),
      );

      expect(find.text('Not connected'), findsOneWidget);
    });

    testWidgets('defaults the status dot to the amber status colour',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        settingsHarness(const SettingsStatusPill(label: 'Not connected')),
      );

      final DecoratedBox dot = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(SettingsStatusPill),
              matching: find.byType(DecoratedBox),
            ),
          )
          .last;
      expect((dot.decoration as BoxDecoration).color, Palette.statusAmber);
    });

    testWidgets('honours a custom dot colour',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        settingsHarness(
          const SettingsStatusPill(
            label: 'Connected',
            dotColor: Palette.sage,
          ),
        ),
      );

      final DecoratedBox dot = tester
          .widgetList<DecoratedBox>(
            find.descendant(
              of: find.byType(SettingsStatusPill),
              matching: find.byType(DecoratedBox),
            ),
          )
          .last;
      expect((dot.decoration as BoxDecoration).color, Palette.sage);
    });
  });
}
