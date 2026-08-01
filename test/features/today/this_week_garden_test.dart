import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/today/this_week_garden.dart';
import 'package:field_notes/features/today/today_week.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/today_harness.dart';

const List<String> _labels = <String>[
  'Sun',
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
];

List<TodayWeekCell> _cells() {
  return <TodayWeekCell>[
    for (int index = 0; index < 7; index++)
      TodayWeekCell(
        date: '2026-07-${(19 + index).toString().padLeft(2, '0')}',
        weekdayLabel: _labels[index],
        isToday: index == 3,
        mood: index.isEven ? Mood.values[index] : null,
      ),
  ];
}

void main() {
  testWidgets('renders one cell per day with blooms only for moods',
      (WidgetTester tester) async {
    await pumpToday(tester, ThisWeekGarden(cells: _cells()));

    expect(find.text("this week's garden"), findsOneWidget);
    for (final String label in _labels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(FlowerBloom), findsNWidgets(4));
  });

  testWidgets('labels each cell for screen readers', (WidgetTester tester) async {
    await pumpToday(tester, ThisWeekGarden(cells: _cells()));

    expect(find.bySemanticsLabel('Sun, ${Mood.values[0].label}'), findsOneWidget);
    expect(find.bySemanticsLabel('Mon, no mood'), findsOneWidget);
  });

  testWidgets('marks today with the coral accent', (WidgetTester tester) async {
    await pumpToday(tester, ThisWeekGarden(cells: _cells()));

    final Text todayLabel = tester.widget<Text>(find.text('Wed'));
    final Text otherLabel = tester.widget<Text>(find.text('Mon'));
    expect(todayLabel.style?.color, isNot(otherLabel.style?.color));
  });

  testWidgets('opens the calendar on the tapped day when a handler is wired',
      (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final List<String> opened = <String>[];

    await pumpToday(
      tester,
      ThisWeekGarden(cells: _cells(), onOpenCalendar: opened.add),
    );

    expect(
      tester.getSemantics(find.bySemanticsLabel('Mon, no mood')),
      isSemantics(
        label: 'Mon, no mood',
        isButton: true,
        hasTapAction: true,
      ),
    );

    await tester.tap(find.bySemanticsLabel('Mon, no mood'));
    await tester.pump();

    expect(opened, <String>['2026-07-20']);
    handle.dispose();
  });
}
