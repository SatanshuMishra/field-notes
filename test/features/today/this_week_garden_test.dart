import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/day_detail_panel.dart';
import 'package:field_notes/features/day_detail/day_detail_providers.dart';
import 'package:field_notes/features/today/this_week_garden.dart';
import 'package:field_notes/features/today/today_week.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../day_detail/support/day_detail_harness.dart';
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

List<Override> _dayOverrides() {
  return <Override>[
    journalRepositoryProvider.overrideWithValue(FakeJournalRepository()),
    dayDetailMediaResolverProvider.overrideWith(
      (Ref ref) => FakeMediaResolver(),
    ),
  ];
}

void main() {
  testWidgets('renders one cell per day with blooms only for moods', (
    WidgetTester tester,
  ) async {
    await pumpToday(tester, ThisWeekGarden(cells: _cells()));

    expect(find.text("this week's garden"), findsOneWidget);
    for (final String label in _labels) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byType(FlowerBloom), findsNWidgets(4));
  });

  testWidgets('names only past days as buttons for screen readers', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await pumpToday(
      tester,
      ThisWeekGarden(cells: _cells()),
      overrides: _dayOverrides(),
    );

    expect(
      find.bySemanticsLabel(
        'Open Sunday, July 19, ${Mood.values[0].label.toLowerCase()}',
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('Open Monday, July 20, no mood'),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel(RegExp('^Open ')), findsNWidgets(3));
    expect(
      tester.getSemantics(
        find.bySemanticsLabel('Open Monday, July 20, no mood'),
      ),
      isSemantics(isButton: true),
    );
    for (final String label in <String>[
      'Wed, no mood',
      'Thu, ${Mood.values[4].label}',
      'Fri, no mood',
      'Sat, ${Mood.values[6].label}',
    ]) {
      expect(
        tester.getSemantics(find.bySemanticsLabel(label)),
        isNot(isSemantics(isButton: true)),
      );
    }
    handle.dispose();
  });

  testWidgets('tapping a past day opens its day modal and stays on today', (
    WidgetTester tester,
  ) async {
    await pumpToday(
      tester,
      ThisWeekGarden(cells: _cells()),
      overrides: _dayOverrides(),
    );

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(ThisWeekGarden)),
    );

    await tester.tap(find.text('Mon'));
    await tester.pumpAndSettle();

    expect(find.text('Monday, July 20'), findsOneWidget);
    expect(container.read(shellNavigationProvider), ShellDestination.today);
  });

  testWidgets('tapping today or a later day opens nothing', (
    WidgetTester tester,
  ) async {
    await pumpToday(
      tester,
      ThisWeekGarden(cells: _cells()),
      overrides: _dayOverrides(),
    );

    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(ThisWeekGarden)),
    );

    for (final String label in <String>['Wed', 'Thu', 'Sat']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
      expect(find.byType(DayDetailPanel), findsNothing);
    }
    expect(container.read(shellNavigationProvider), ShellDestination.today);
  });

  testWidgets('marks today with the coral accent', (WidgetTester tester) async {
    await pumpToday(tester, ThisWeekGarden(cells: _cells()));

    final Text todayLabel = tester.widget<Text>(find.text('Wed'));
    final Text otherLabel = tester.widget<Text>(find.text('Mon'));
    expect(todayLabel.style?.color, isNot(otherLabel.style?.color));
  });
}
