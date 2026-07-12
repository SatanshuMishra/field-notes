import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/widgets/widgets.dart';

import 'settings_harness.dart';

void main() {
  group('SettingsSection', () {
    testWidgets('renders its title, subtitle, and child rows inside a card',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        settingsHarness(
          const SizedBox(
            width: 360,
            child: SettingsSection(
              title: 'Reminders & sound',
              subtitle: 'Nudges and audio cues',
              children: <Widget>[
                Text('row-a'),
                Text('row-b'),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(StickerCard), findsOneWidget);
      expect(find.text('Reminders & sound'), findsOneWidget);
      expect(find.text('Nudges and audio cues'), findsOneWidget);
      expect(find.text('row-a'), findsOneWidget);
      expect(find.text('row-b'), findsOneWidget);
    });

    testWidgets('separates rows with one dashed divider per row',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        settingsHarness(
          const SizedBox(
            width: 360,
            child: SettingsSection(
              title: 'Journal',
              children: <Widget>[
                Text('row-a'),
                Text('row-b'),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(DashedDivider), findsNWidgets(2));
    });
  });
}
