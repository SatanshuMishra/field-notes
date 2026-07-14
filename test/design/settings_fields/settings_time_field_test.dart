import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/settings_fields/settings_fields.dart';

import 'settings_harness.dart';

void main() {
  group('SettingsTimeField', () {
    testWidgets('renders the time as zero-padded 24h HH:mm',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        settingsHarness(
          SettingsTimeField(
            value: const TimeOfDay(hour: 20, minute: 30),
            onTap: () {},
          ),
        ),
      );

      expect(find.text('20:30'), findsOneWidget);
    });

    testWidgets('pads single-digit hours and minutes',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        settingsHarness(
          SettingsTimeField(
            value: const TimeOfDay(hour: 9, minute: 5),
            onTap: () {},
          ),
        ),
      );

      expect(find.text('09:05'), findsOneWidget);
    });

    testWidgets('invokes onTap when enabled, stays inert when disabled',
        (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        settingsHarness(
          SettingsTimeField(
            value: const TimeOfDay(hour: 20, minute: 30),
            onTap: () => taps++,
          ),
        ),
      );
      await tester.tap(find.byType(SettingsTimeField));
      expect(taps, 1);

      await tester.pumpWidget(
        settingsHarness(
          SettingsTimeField(
            value: const TimeOfDay(hour: 20, minute: 30),
            onTap: () => taps++,
            enabled: false,
          ),
        ),
      );
      await tester.tap(find.byType(SettingsTimeField), warnIfMissed: false);
      expect(taps, 1);
    });
  });
}
