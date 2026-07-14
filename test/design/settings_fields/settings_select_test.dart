import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/settings_fields/settings_fields.dart';

import 'settings_harness.dart';

const List<SettingsSelectOption<int>> _options = <SettingsSelectOption<int>>[
  SettingsSelectOption<int>(value: 0, label: 'Sunday'),
  SettingsSelectOption<int>(value: 1, label: 'Monday'),
];

void main() {
  group('SettingsSelect', () {
    testWidgets('shows the selected option label',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        settingsHarness(
          SettingsSelect<int>(
            options: _options,
            value: 0,
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Sunday'), findsOneWidget);
    });

    testWidgets('opens the menu and fires onChanged on selection',
        (WidgetTester tester) async {
      int? picked;
      await tester.pumpWidget(
        settingsHarness(
          SettingsSelect<int>(
            options: _options,
            value: 0,
            onChanged: (int v) => picked = v,
          ),
        ),
      );

      await tester.tap(find.text('Sunday'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Monday').last);
      await tester.pumpAndSettle();

      expect(picked, 1);
    });

    testWidgets('does not open when disabled',
        (WidgetTester tester) async {
      int? picked;
      await tester.pumpWidget(
        settingsHarness(
          SettingsSelect<int>(
            options: _options,
            value: 0,
            onChanged: (int v) => picked = v,
            enabled: false,
          ),
        ),
      );

      await tester.tap(find.text('Sunday'), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.text('Monday'), findsNothing);
      expect(picked, isNull);
    });
  });
}
