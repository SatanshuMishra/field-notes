import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/widgets/widgets.dart';

import 'settings_harness.dart';

void main() {
  group('SettingsFieldRow', () {
    testWidgets('renders the label, description, and control',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        settingsHarness(
          const SizedBox(
            width: 360,
            child: SettingsFieldRow(
              label: 'Daily reminder',
              description: 'Get a nudge to write',
              control: Text('control-slot'),
            ),
          ),
        ),
      );

      expect(find.text('Daily reminder'), findsOneWidget);
      expect(find.text('Get a nudge to write'), findsOneWidget);
      expect(find.text('control-slot'), findsOneWidget);
    });

    testWidgets('omits the description when none is given',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        settingsHarness(
          const SizedBox(
            width: 360,
            child: SettingsFieldRow(
              label: 'Storage mode',
              control: Text('c'),
            ),
          ),
        ),
      );

      expect(find.text('Storage mode'), findsOneWidget);
    });

    testWidgets('hosts a trailing danger StickerButton and forwards taps',
        (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        settingsHarness(
          SizedBox(
            width: 360,
            child: SettingsFieldRow(
              label: 'Delete all',
              control: StickerButton(
                label: 'Delete all…',
                variant: StickerButtonVariant.danger,
                onPressed: () => taps++,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Delete all…'), findsOneWidget);
      await tester.tap(find.byType(StickerButton));
      expect(taps, 1);
    });
  });
}
