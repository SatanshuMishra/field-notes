import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/entry_cards/cards/note_body.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/features/today/today_screen.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/today_harness.dart';

const String _yesterday = '2026-11-09';
const String _today = '2026-11-10';
const String _lateNote = 'a late night note';
const String _morningNote = 'an early morning note';

Finder _note(String text) => find.byWidgetPredicate(
  (Widget widget) => widget is NoteBody && widget.text == text,
);

List<Override> _overrides(DateTime Function() clock) {
  final Map<String, List<Entry>> entriesByDate = <String, List<Entry>>{
    _yesterday: <Entry>[todayTestEntry(id: 'late', textContent: _lateNote)],
    _today: <Entry>[todayTestEntry(id: 'early', textContent: _morningNote)],
  };
  return <Override>[
    todayClockProvider.overrideWithValue(clock),
    weekStartProvider.overrideWithValue(WeekStart.monday),
    allDaysProvider.overrideWith(
      (Ref ref) => Stream<List<Day>>.value(const <Day>[]),
    ),
    dayForDateProvider.overrideWith(
      (Ref ref, String date) => Stream<Day?>.value(todayTestDay(date: date)),
    ),
    entriesForDateProvider.overrideWith(
      (Ref ref, String date) =>
          Stream<List<Entry>>.value(entriesByDate[date] ?? const <Entry>[]),
    ),
    entriesForDayProvider.overrideWith(
      (Ref ref, String dayId) => Stream<List<Entry>>.value(const <Entry>[]),
    ),
    photosForEntryProvider.overrideWith(
      (Ref ref, String entryId) =>
          Stream<List<EntryPhoto>>.value(const <EntryPhoto>[]),
    ),
    todayMediaResolverProvider.overrideWith(
      (Ref ref) async => const StubMediaResolver(),
    ),
    onThisDayMemoryProvider.overrideWith((Ref ref) async => null),
  ];
}

void main() {
  testWidgets('Today shows the new day\'s logs once the app stays open past '
      'midnight', (WidgetTester tester) async {
    DateTime now = DateTime(2026, 11, 9, 23, 58);
    await pumpToday(
      tester,
      const TodayScreen(),
      overrides: _overrides(() => now),
    );
    expect(find.text('Monday, November 9'), findsOneWidget);
    expect(_note(_lateNote), findsOneWidget);

    now = DateTime(2026, 11, 10, 0, 3);
    await tester.pump(const Duration(minutes: 5));
    tester.view.physicalSize = const Size(430, 780);
    await tester.pump();
    await tester.pump();

    expect(find.text('Tuesday, November 10'), findsOneWidget);
    expect(_note(_lateNote), findsNothing);
    expect(_note(_morningNote), findsOneWidget);
  });
}
