import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/icons/chevron_glyph.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart'
    show logViewerEarlierKey;
import 'package:field_notes/features/log_viewer/note_reading.dart'
    show LogStepFooter;

const double _fillBleed = 12;

Entry _entry(String id, int hour) => Entry(
  id: id,
  dayId: 'day-1',
  type: EntryType.text,
  textContent: 'Watered the roses.',
  createdAt: DateTime(2026, 7, 19, hour, 12).millisecondsSinceEpoch,
  updatedAt: 0,
);

void main() {
  testWidgets(
    'the previous log button fills 12 px past its arrow and words and rings '
    'the same fill',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1140, 726);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: fieldNotesTheme(platform: TargetPlatform.macOS),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 560,
                child: LogStepFooter(
                  index: 1,
                  count: 3,
                  earlier: _entry('earlier', 9),
                  later: _entry('later', 11),
                  onEarlier: () {},
                  onLater: () {},
                ),
              ),
            ),
          ),
        ),
      );
      final Finder previous = find.byKey(logViewerEarlierKey);
      final Finder fill = find.descendant(
        of: previous,
        matching: find.byKey(pressableHoverFillKey),
      );
      final Rect arrow = tester.getRect(
        find.descendant(of: previous, matching: find.byType(ChevronGlyph)),
      );
      final Rect words = tester.getRect(
        find.descendant(of: previous, matching: find.byType(Text)),
      );
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(words.center);
      await tester.pump();

      final BoxDecoration painted =
          tester.widget<DecoratedBox>(fill).decoration as BoxDecoration;
      expect(
        painted.color?.toARGB32(),
        FieldNotesColors.light.ink.withValues(alpha: 0.06).toARGB32(),
      );
      final Rect fillRect = tester.getRect(fill);
      expect(arrow.left - fillRect.left, greaterThanOrEqualTo(_fillBleed));
      expect(fillRect.right - words.right, greaterThanOrEqualTo(_fillBleed));

      await mouse.removePointer();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final Finder ring = find.descendant(
        of: previous,
        matching: find.byKey(focusRingKey),
      );
      expect(ring, findsOneWidget);
      expect(tester.getRect(ring), fillRect);
      expect(tester.takeException(), isNull);
    },
  );
}
