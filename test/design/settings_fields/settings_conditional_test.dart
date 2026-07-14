import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/settings_fields/settings_fields.dart';

import 'settings_harness.dart';

void main() {
  group('SettingsConditional', () {
    testWidgets('shows its child when visible',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        settingsHarness(
          const SettingsConditional(
            visible: true,
            child: Text('server-fields'),
          ),
        ),
      );

      expect(find.text('server-fields'), findsOneWidget);
    });

    testWidgets('hides its child when not visible',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        settingsHarness(
          const SettingsConditional(
            visible: false,
            child: Text('server-fields'),
          ),
        ),
      );

      expect(find.text('server-fields'), findsNothing);
    });
  });
}
