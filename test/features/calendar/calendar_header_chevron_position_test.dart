import 'package:field_notes/features/calendar/calendar.dart';
import 'package:field_notes/features/calendar/widgets/calendar_chevron_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Finder _chevron(String label) => find.byWidgetPredicate(
  (Widget widget) =>
      widget is CalendarChevronButton && widget.semanticLabel == label,
);

Rect _painted(WidgetTester tester, String label) => tester.getRect(
  find
      .descendant(of: _chevron(label), matching: find.byType(DecoratedBox))
      .first,
);

Rect _semanticRect(WidgetTester tester, Finder finder) {
  final SemanticsNode node = tester.getSemantics(finder);
  final Rect physical =
      <SemanticsNode>[
        for (
          SemanticsNode? current = node;
          current != null;
          current = current.parent
        )
          current,
      ].fold(
        node.rect,
        (Rect rect, SemanticsNode current) => switch (current.transform) {
          final Matrix4 transform => MatrixUtils.transformRect(transform, rect),
          null => rect,
        },
      );
  final double ratio = tester.view.devicePixelRatio;
  return Rect.fromLTRB(
    physical.left / ratio,
    physical.top / ratio,
    physical.right / ratio,
    physical.bottom / ratio,
  );
}

bool _overlaps(Rect a, Rect b) => a.deflate(0.01).overlaps(b);

void main() {
  testWidgets('the next-month chevron keeps its painted position', (
    WidgetTester tester,
  ) async {
    const Key header = ValueKey<String>('header');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 371,
              child: CalendarHeader(
                key: header,
                month: const MonthRef(2026, 10),
                currentMonth: const MonthRef(2026, 9),
                onShowCurrentMonth: () {},
                onPreviousMonth: () {},
                onNextMonth: () {},
              ),
            ),
          ),
        ),
      ),
    );
    final Rect bounds = tester.getRect(find.byKey(header));
    final Rect next = _painted(tester, 'Next month');
    final Rect previous = _painted(tester, 'Previous month');
    expect(next.right, moreOrLessEquals(bounds.right - 14, epsilon: 0.01));
    expect(next.left - previous.right, moreOrLessEquals(6, epsilon: 0.01));
  });

  testWidgets(
    'the chevrons and This week keep their painted positions with 48 dp tap areas',
    (WidgetTester tester) async {
      const Key header = ValueKey<String>('header');
      const Key thisWeek = ValueKey<String>('this-week');
      int previousTaps = 0;
      int nextTaps = 0;
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 385,
                child: CalendarHeader(
                  key: header,
                  month: const MonthRef(2026, 10),
                  currentMonth: const MonthRef(2026, 9),
                  onShowCurrentMonth: () {},
                  onPreviousMonth: () => previousTaps++,
                  onNextMonth: () => nextTaps++,
                  thisWeekKey: thisWeek,
                ),
              ),
            ),
          ),
        ),
      );

      final Rect previous = _painted(tester, 'Previous month');
      final Rect next = _painted(tester, 'Next month');
      final Rect week = tester.getRect(
        find
            .descendant(
              of: find.byKey(thisWeek),
              matching: find.byType(DecoratedBox),
            )
            .first,
      );
      expect(next.left - previous.right, moreOrLessEquals(6, epsilon: 0.01));
      expect(week.right, moreOrLessEquals(previous.left - 8, epsilon: 0.01));

      final Rect previousArea = _semanticRect(
        tester,
        _chevron('Previous month'),
      );
      final Rect nextArea = _semanticRect(tester, _chevron('Next month'));
      final Rect weekArea = _semanticRect(tester, find.byKey(thisWeek));
      for (final Rect area in <Rect>[previousArea, nextArea]) {
        expect(area.width, greaterThanOrEqualTo(47.99), reason: '$area');
        expect(area.height, greaterThanOrEqualTo(47.99), reason: '$area');
        expect(_overlaps(area, weekArea), isFalse, reason: '$area $weekArea');
      }
      expect(
        _overlaps(previousArea, nextArea),
        isFalse,
        reason: '$previousArea $nextArea',
      );

      await tester.tapAt(previousArea.topLeft + const Offset(1, 1));
      await tester.tapAt(nextArea.topRight + const Offset(-1, 1));
      expect(previousTaps, 1);
      expect(nextTaps, 1);
      handle.dispose();
    },
  );
}
