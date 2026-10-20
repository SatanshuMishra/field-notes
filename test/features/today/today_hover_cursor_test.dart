import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/mood/mood_banner.dart';
import 'package:field_notes/features/mood/mood_picker_grid.dart';
import 'package:field_notes/features/today/on_this_day_card.dart';
import 'package:field_notes/features/today/this_week_garden.dart';
import 'package:field_notes/features/today/today_memory.dart';
import 'package:field_notes/features/today/today_mood_dock.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/features/today/today_week.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/today_harness.dart';

const Offset _offEveryControl = Offset(419, 779);

const int _mousePointerId = 53;
const int _mouseDevice = 1;

const Color _ink = Color(0xFF4A3B2E);
const Color _coral = Color(0xFFB8566A);
const Color _white = Color(0xFFFFFFFF);

final int _row = _ink.withValues(alpha: 0.06).toARGB32();
final int _pill = _coral.withValues(alpha: 0.08).toARGB32();
final int _dark = _white.withValues(alpha: 0.12).toARGB32();

final DateTime _evening = DateTime(2026, 7, 19, 20);

class _Row {
  const _Row(this.name, this.text, this.label, this.fill, this.radius);

  final String name;
  final String text;
  final String label;
  final int fill;
  final double radius;

  Finder get control => find
      .ancestor(of: find.text(text), matching: find.byType(Pressable))
      .first;
}

MouseCursor? _cursor() =>
    RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(_mouseDevice);

Finder _hoverFill(_Row row) => find.descendant(
  of: row.control,
  matching: find.byWidgetPredicate((Widget widget) {
    if (widget is! DecoratedBox) {
      return false;
    }
    final Decoration decoration = widget.decoration;
    return decoration is BoxDecoration &&
        decoration.color?.toARGB32() == row.fill &&
        decoration.borderRadius == BorderRadius.circular(row.radius);
  }),
);

Future<void> _expectRows(
  WidgetTester tester,
  TestGesture mouse,
  List<_Row> rows,
) async {
  for (final _Row row in rows) {
    await mouse.moveTo(_offEveryControl);
    await tester.pump();
    expect(row.control, findsOneWidget, reason: row.name);
    expect(_hoverFill(row), findsNothing, reason: row.name);

    await mouse.moveTo(tester.getCenter(row.control));
    await tester.pump();

    expect(_cursor(), SystemMouseCursors.click, reason: row.name);
    expect(_hoverFill(row), findsOneWidget, reason: row.name);
    final SemanticsData semantics = tester
        .getSemantics(row.control)
        .getSemanticsData();
    expect(semantics.label, row.label, reason: row.name);
    expect(semantics.flagsCollection.isButton, isTrue, reason: row.name);
  }
  await mouse.moveTo(_offEveryControl);
  await tester.pump();
}

List<TodayWeekCell> _week() => const <TodayWeekCell>[
  TodayWeekCell(
    date: '2026-07-19',
    weekdayLabel: 'Sun',
    isToday: false,
    mood: Mood.happy,
  ),
  TodayWeekCell(date: '2026-07-20', weekdayLabel: 'Mon', isToday: false),
  TodayWeekCell(
    date: '2026-07-21',
    weekdayLabel: 'Tue',
    isToday: false,
    mood: Mood.warm,
  ),
  TodayWeekCell(date: '2026-07-22', weekdayLabel: 'Wed', isToday: true),
  TodayWeekCell(
    date: '2026-07-23',
    weekdayLabel: 'Thu',
    isToday: false,
    mood: Mood.hopeful,
  ),
  TodayWeekCell(date: '2026-07-24', weekdayLabel: 'Fri', isToday: false),
  TodayWeekCell(
    date: '2026-07-25',
    weekdayLabel: 'Sat',
    isToday: false,
    mood: Mood.anxious,
  ),
];

List<Override> _dockOverrides(Mood? mood) => <Override>[
  todayClockProvider.overrideWithValue(() => _evening),
  dayForDateProvider.overrideWith(
    (Ref ref, String date) =>
        Stream<Day?>.value(todayTestDay(date: date, mood: mood)),
  ),
  todayMediaResolverProvider.overrideWith(
    (Ref ref) async => const StubMediaResolver(),
  ),
];

void main() {
  testWidgets('every today and mood control shows the click cursor and hover', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: _mousePointerId,
    );
    await mouse.addPointer(location: _offEveryControl);
    addTearDown(mouse.removePointer);

    await pumpToday(tester, MoodBanner(mood: null, onChangeMood: () {}));
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'mood banner prompt',
        'How are you feeling today?',
        "How are you feeling today?\ntap to plant today's bloom",
        _row,
        16,
      ),
    ]);

    await pumpToday(tester, MoodBanner(mood: Mood.calm, onChangeMood: () {}));
    await _expectRows(tester, mouse, <_Row>[
      _Row('mood banner change pill', 'change', 'change', _pill, 13),
    ]);

    await pumpToday(
      tester,
      DayMoodCard(mood: Mood.grateful, onChangeMood: () {}),
    );
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'day mood card change mood',
        'Change mood',
        'Change mood',
        _pill,
        11,
      ),
    ]);

    await pumpToday(
      tester,
      MoodPickerGrid(selected: Mood.calm, onMoodSelected: (Mood mood) {}),
    );
    await _expectRows(tester, mouse, <_Row>[
      _Row('mood tile happy', 'Happy', 'Happy', _row, 14),
      _Row('mood tile loved', 'Loved', 'Loved', _row, 14),
      _Row('mood tile warm', 'Warm', 'Warm', _row, 14),
      _Row('mood tile grateful', 'Grateful', 'Grateful', _row, 14),
      _Row('mood tile hopeful', 'Hopeful', 'Hopeful', _row, 14),
      _Row('mood tile calm', 'Calm', 'Calm', _row, 14),
      _Row('mood tile anxious', 'Anxious', 'Anxious', _row, 14),
      _Row('mood tile tired', 'Tired', 'Tired', _row, 14),
      _Row('mood tile sad', 'Sad', 'Sad', _row, 14),
      _Row('mood tile angry', 'Angry', 'Angry', _row, 14),
    ]);

    await pumpToday(
      tester,
      OnThisDayCard(
        memory: OnThisDayMemory(
          day: todayTestDay(
            id: 'day-2024',
            date: '2024-07-19',
            mood: Mood.calm,
          ),
          yearsAgo: 2,
        ),
        preview: 'sun on the deck',
        onOpen: () {},
      ),
    );
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'on this day card',
        'sun on the deck',
        'sun on the deck, Jul 19, 2024 · felt Calm, memory · 2 years ago',
        _row,
        13,
      ),
    ]);

    await pumpToday(tester, ThisWeekGarden(cells: _week()));
    await _expectRows(tester, mouse, <_Row>[
      _Row('week cell sunday', 'Sun', 'Sun, Happy', _row, 10),
      _Row('week cell monday', 'Mon', 'Mon, no mood', _row, 10),
      _Row('week cell tuesday', 'Tue', 'Tue, Warm', _row, 10),
      _Row('week cell wednesday', 'Wed', 'Wed, no mood', _row, 10),
      _Row('week cell thursday', 'Thu', 'Thu, Hopeful', _row, 10),
      _Row('week cell friday', 'Fri', 'Fri, no mood', _row, 10),
      _Row('week cell saturday', 'Sat', 'Sat, Anxious', _row, 10),
    ]);

    await tester.pumpWidget(const SizedBox());
    await pumpToday(
      tester,
      const TodayMoodDock(),
      overrides: _dockOverrides(null),
    );

    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'mood dock card without a mood',
        'How are you feeling?',
        "How are you feeling?\ntap to plant today's bloom",
        _row,
        20,
      ),
      _Row('mood dock choose', 'Choose', 'Choose', _dark, 12),
    ]);

    await tester.pumpWidget(const SizedBox());
    await pumpToday(
      tester,
      const TodayMoodDock(),
      overrides: _dockOverrides(Mood.calm),
    );
    await _expectRows(tester, mouse, <_Row>[
      _Row(
        'mood dock card with a mood',
        'Feeling Calm',
        "Feeling Calm\nLavender · today's bloom",
        _row,
        20,
      ),
      _Row('mood dock change', 'Change', 'Change', _pill, 12),
    ]);

    handle.dispose();
  });
}
