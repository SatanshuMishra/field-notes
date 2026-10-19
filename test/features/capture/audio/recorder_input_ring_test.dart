import 'dart:async';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/features/capture/audio/input_panel.dart';
import 'package:field_notes/features/capture/audio/recorder_input_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const Duration _settle = Duration(milliseconds: 120);

RecorderInputRingPainter _painter(WidgetTester tester) =>
    tester.widget<CustomPaint>(find.byKey(recorderInputRingKey)).painter!
        as RecorderInputRingPainter;

Future<void> _hear(
  WidgetTester tester,
  StreamController<double> levels,
  double level,
) async {
  levels.add(level);
  await tester.pump();
  await tester.pump(_settle);
}

void main() {
  testWidgets(
    "the microphone button's ring grows with the level and hides at silence",
    (WidgetTester tester) async {
      final StreamController<double> levels =
          StreamController<double>.broadcast();
      addTearDown(levels.close);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: fieldNotesTheme(platform: TargetPlatform.macOS),
            home: Scaffold(
              body: Center(
                child: RecorderInputButton(ringLevels: levels.stream),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      await _hear(tester, levels, 0);
      expect(find.byKey(recorderInputRingKey), findsNothing);

      await _hear(tester, levels, 0.5);
      expect(find.byKey(recorderInputRingKey), findsOneWidget);
      final RecorderInputRingPainter half = _painter(tester);

      await _hear(tester, levels, 1);
      final RecorderInputRingPainter full = _painter(tester);
      expect(full.spread, greaterThan(half.spread));
      expect(full.opacity, greaterThan(half.opacity));

      final Rect button = tester.getRect(find.byKey(recorderInputKey));
      final Rect ring = tester.getRect(find.byKey(recorderInputRingKey));
      expect(ring, button.inflate(recorderInputRingReach));
      expect(
        full.outerRadius(ring.size),
        lessThanOrEqualTo(button.shortestSide / 2 + recorderInputRingReach),
      );
      expect(
        full.innerRadius(ring.size),
        greaterThanOrEqualTo(button.shortestSide / 2),
      );

      await tester.pump(recorderInputRingSilence);
      expect(find.byKey(recorderInputRingKey), findsNothing);
    },
  );
}
