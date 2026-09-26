import 'package:field_notes/features/calendar/calendar.dart';
import 'package:field_notes/features/calendar/widgets/calendar_chevron_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Rect _painted(WidgetTester tester, String label) => tester.getRect(
  find
      .descendant(
        of: find.byWidgetPredicate(
          (Widget widget) =>
              widget is CalendarChevronButton && widget.semanticLabel == label,
        ),
        matching: find.byType(DecoratedBox),
      )
      .first,
);

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
    expect(next.right, moreOrLessEquals(bounds.right, epsilon: 0.01));
    expect(
      next.left - previous.right,
      moreOrLessEquals(
        calendarMinTapTarget - calendarChevronButtonSize,
        epsilon: 0.01,
      ),
    );
  });
}
