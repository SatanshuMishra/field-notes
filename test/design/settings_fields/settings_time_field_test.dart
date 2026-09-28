import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/settings_fields/settings_fields.dart';

import 'settings_harness.dart';

void _useClockFormat(WidgetTester tester, {required bool twentyFourHour}) {
  tester.platformDispatcher.alwaysUse24HourFormatTestValue = twentyFourHour;
  tester.binding.handleMetricsChanged();
  addTearDown(() {
    tester.platformDispatcher.clearAlwaysUse24HourTestValue();
    tester.binding.handleMetricsChanged();
  });
}

void main() {
  group('SettingsTimeField', () {
    testWidgets('the time follows the system 12 or 24 hour setting',
        (WidgetTester tester) async {
      final Widget field = settingsHarness(
        SettingsTimeField(
          value: const TimeOfDay(hour: 20, minute: 30),
          onTap: () {},
        ),
      );

      _useClockFormat(tester, twentyFourHour: false);
      await tester.pumpWidget(field);

      expect(find.text('8:30 PM'), findsOneWidget);

      _useClockFormat(tester, twentyFourHour: true);
      await tester.pumpWidget(field);

      expect(find.text('20:30'), findsOneWidget);
    });

    testWidgets('pads single-digit hours and minutes',
        (WidgetTester tester) async {
      _useClockFormat(tester, twentyFourHour: true);
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
