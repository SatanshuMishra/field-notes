import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/calendar/model/calendar_month.dart';
import 'package:field_notes/features/calendar/widgets/calendar_chevron_button.dart';
import 'package:field_notes/features/calendar/widgets/calendar_day_cell.dart';
import 'package:field_notes/features/calendar/widgets/calendar_grid.dart';
import 'package:field_notes/features/calendar/widgets/calendar_header.dart';

import '../../support/theme_harness.dart';

const Color _cardLight = Color(0xFF312A2A);
const Color _cardWarm = Color(0xFF272222);
const Color _coral = Color(0xFFB8566A);
const Color _accentInk = Color(0xFFE692A0);
const Color _ink = Color(0xFFEDE1E1);
const Color _ink25 = Color(0x40EDE1E1);
const Color _mutedDeep = Color(0xFFB9A9A9);
const Color _sage = Color(0xFFA0B9A0);
const Color _line = Color(0xFF968888);

const Size _surface = Size(900, 700);

Day _day(String date, {Mood? mood}) =>
    Day(id: 'id-$date', date: date, mood: mood, createdAt: 0, updatedAt: 0);

Finder _dayCell(String date) => find.byKey(ValueKey<String>('day-$date'));

List<BoxDecoration> _decorationsIn(WidgetTester tester, Finder owner) => tester
    .widgetList<DecoratedBox>(
      find.descendant(of: owner, matching: find.byType(DecoratedBox)),
    )
    .map((DecoratedBox box) => box.decoration)
    .whereType<BoxDecoration>()
    .where((BoxDecoration decoration) => decoration.color != null)
    .toList();

BoxDecoration _surfaceOf(WidgetTester tester, Finder owner) =>
    _decorationsIn(tester, owner).single;

Color _borderColour(BoxDecoration decoration) =>
    (decoration.border! as Border).top.color;

Color? _numberColour(WidgetTester tester, String date, String number) => tester
    .widget<Text>(
      find.descendant(of: _dayCell(date), matching: find.text(number)),
    )
    .style
    ?.color;

void main() {
  test('calendar names no light-only colour', () {
    expect(lightOnlyTokenUses(<String>['lib/features/calendar']), isEmpty);
  });

  testWidgets('calendar day cells draw their dark colours', (
    WidgetTester tester,
  ) async {
    await pumpThemed(
      tester,
      CalendarGrid(
        month: const MonthRef(2026, 7),
        daysByDate: <String, Day>{
          '2026-07-14': _day('2026-07-14', mood: Mood.happy),
          '2026-07-10': _day('2026-07-10'),
        },
        todayKey: '2026-07-15',
        onSelectDay: (_) {},
      ),
      brightness: Brightness.dark,
      size: _surface,
    );

    final BoxDecoration today = _surfaceOf(tester, _dayCell('2026-07-15'));
    expect(today.color, _cardLight);
    expect(_borderColour(today), _coral);
    expect(_numberColour(tester, '2026-07-15', '15'), _accentInk);

    final BoxDecoration mood = _surfaceOf(tester, _dayCell('2026-07-14'));
    expect(mood.color, _cardWarm);
    expect(_borderColour(mood), _ink25);

    expect(_numberColour(tester, '2026-07-14', '14'), _mutedDeep);
    expect(_numberColour(tester, '2026-07-09', '9'), _mutedDeep);
    expect(_numberColour(tester, '2026-07-10', '10'), _mutedDeep);

    expect(_surfaceOf(tester, find.byKey(calendarActivityDotKey)).color, _sage);
  });

  testWidgets('calendar header draws its dark title', (
    WidgetTester tester,
  ) async {
    await pumpThemed(
      tester,
      CalendarHeader(
        month: const MonthRef(2026, 7),
        onPreviousMonth: () {},
        onNextMonth: () {},
      ),
      brightness: Brightness.dark,
      size: _surface,
    );

    expect(tester.widget<Text>(find.text('July 2026')).style?.color, _ink);

    final Finder chevrons = find.byType(CalendarChevronButton);
    expect(chevrons, findsNWidgets(2));
    for (int index = 0; index < 2; index++) {
      final BoxDecoration face = _surfaceOf(tester, chevrons.at(index));
      expect(face.color, _cardWarm);
      expect(_borderColour(face), _line);
    }
  });
}
