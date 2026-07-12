import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/settings_fields/settings_fields.dart';
import 'package:field_notes/design/tokens/tokens.dart';

import 'settings_harness.dart';

Color _fillBehind(WidgetTester tester, String label) {
  final DecoratedBox box = tester.widget<DecoratedBox>(
    find.ancestor(of: find.text(label), matching: find.byType(DecoratedBox)).first,
  );
  return (box.decoration as BoxDecoration).color!;
}

const List<SettingsSegment<String>> _segments = <SettingsSegment<String>>[
  SettingsSegment<String>(value: 'device', label: 'On this device'),
  SettingsSegment<String>(value: 'server', label: 'Sync to server'),
];

void main() {
  group('SettingsSegmented', () {
    testWidgets('renders each segment label',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        settingsHarness(
          SettingsSegmented<String>(
            segments: _segments,
            value: 'device',
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('On this device'), findsOneWidget);
      expect(find.text('Sync to server'), findsOneWidget);
    });

    testWidgets('raises the selected segment and leaves others transparent',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        settingsHarness(
          SettingsSegmented<String>(
            segments: _segments,
            value: 'device',
            onChanged: (_) {},
          ),
        ),
      );

      expect(_fillBehind(tester, 'On this device'), Palette.cardBright);
      expect(_fillBehind(tester, 'Sync to server'), const Color(0x00000000));
    });

    testWidgets('fires onChanged with the tapped value when enabled',
        (WidgetTester tester) async {
      String? picked;
      await tester.pumpWidget(
        settingsHarness(
          SettingsSegmented<String>(
            segments: _segments,
            value: 'device',
            onChanged: (String v) => picked = v,
          ),
        ),
      );

      await tester.tap(find.text('Sync to server'));
      expect(picked, 'server');
    });

    testWidgets('is inert and dimmed when disabled',
        (WidgetTester tester) async {
      String? picked;
      await tester.pumpWidget(
        settingsHarness(
          SettingsSegmented<String>(
            segments: _segments,
            value: 'device',
            onChanged: (String v) => picked = v,
            enabled: false,
          ),
        ),
      );

      final double opacity = tester
          .widget<Opacity>(
            find.descendant(
              of: find.byType(SettingsSegmented<String>),
              matching: find.byType(Opacity),
            ),
          )
          .opacity;
      expect(opacity, 0.5);

      await tester.tap(find.text('Sync to server'), warnIfMissed: false);
      expect(picked, isNull);
    });
  });
}
