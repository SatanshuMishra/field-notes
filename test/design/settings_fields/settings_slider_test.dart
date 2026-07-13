import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/settings_fields/settings_fields.dart';

import 'settings_harness.dart';

void main() {
  group('SettingsSlider', () {
    testWidgets('reflects its value on the underlying slider',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        settingsHarness(
          SizedBox(
            width: 300,
            child: SettingsSlider(value: 2, onChanged: (_) {}),
          ),
        ),
      );

      final Slider slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 2.0);
      expect(slider.min, 1.0);
      expect(slider.max, 3.0);
      expect(slider.divisions, 2);
    });

    testWidgets('reports a rounded int when dragged to the maximum',
        (WidgetTester tester) async {
      int? picked;
      await tester.pumpWidget(
        settingsHarness(
          SizedBox(
            width: 300,
            child: SettingsSlider(
              value: 1,
              onChanged: (int v) => picked = v,
            ),
          ),
        ),
      );

      final Offset right = tester.getTopRight(find.byType(Slider));
      final Offset center = tester.getCenter(find.byType(Slider));
      await tester.tapAt(Offset(right.dx - 2, center.dy));

      expect(picked, 3);
    });

    testWidgets('is disabled (null onChanged) when not enabled',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        settingsHarness(
          SizedBox(
            width: 300,
            child: SettingsSlider(
              value: 2,
              onChanged: (_) {},
              enabled: false,
            ),
          ),
        ),
      );

      final Slider slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.onChanged, isNull);
    });
  });
}
