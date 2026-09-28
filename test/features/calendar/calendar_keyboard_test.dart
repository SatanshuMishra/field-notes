import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/calendar/calendar.dart';
import 'package:field_notes/features/calendar/widgets/calendar_day_cell.dart';
import 'package:field_notes/features/calendar/widgets/calendar_month_picker.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../accessibility/states/shell_states.dart';
import '../../accessibility/support/a11y_state.dart';
import '../../support/tab_reach.dart';

const int _tabPresses = 60;

const int _guardTabPresses = 24;

const List<String> _stateIds = <String>[
  'a4-calendar-month',
  'a5-calendar-picker',
  'a11-calendar-next-month',
];

Future<void> _pumpState(WidgetTester tester, String id) =>
    shellStates.singleWhere((A11yState state) => state.id == id).pump(tester);

Future<void> _pumpJuly(
  WidgetTester tester, {
  required ValueChanged<String> onOpenDay,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (int retryCount, Object error) => null,
      overrides: <Override>[
        weekStartProvider.overrideWithValue(WeekStart.sunday),
        journaledDatesProvider.overrideWith(
          (Ref ref) => Stream<List<String>>.value(const <String>[]),
        ),
        daysInMonthProvider.overrideWith(
          (Ref ref, ({int year, int month}) args) =>
              Stream<List<Day>>.value(const <Day>[]),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: CalendarScreen(
          initialMonth: const MonthRef(2026, 7),
          today: DateTime(2026, 7, 15),
          onOpenDay: (BuildContext context, {required String date}) async =>
              onOpenDay(date),
          onOpenToday: () {},
        ),
      ),
    ),
  );
  await tester.pump();
}

void _useKeyboardHighlight() {
  final FocusHighlightStrategy previous =
      FocusManager.instance.highlightStrategy;
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => FocusManager.instance.highlightStrategy = previous);
}

bool _focusIsWithin(Finder finder) {
  final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
  if (focused is! Element) {
    return false;
  }
  final List<Element> targets = finder.evaluate().toList();
  bool within = targets.any((Element target) => identical(focused, target));
  focused.visitAncestorElements((Element ancestor) {
    within =
        within || targets.any((Element target) => identical(ancestor, target));
    return !within;
  });
  return within;
}

Future<void> _tabTo(WidgetTester tester, Finder finder) async {
  for (int press = 0; press < _tabPresses && !_focusIsWithin(finder); press++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  expect(_focusIsWithin(finder), isTrue, reason: '$finder never took focus');
}

Finder _dayCell(String date) => find.byKey(ValueKey<String>('day-$date'));

Finder get _anyDayCell => find.byType(CalendarDayCell);

Future<void> _press(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

Iterable<RenderObject> _renderDepthFirst(RenderObject object) sync* {
  yield object;
  final List<RenderObject> children = <RenderObject>[];
  object.visitChildren(children.add);
  for (final RenderObject child in children) {
    yield* _renderDepthFirst(child);
  }
}

List<Rect> _paintedRects(WidgetTester tester) => List<Rect>.unmodifiable(<Rect>[
  for (final RenderView view in tester.binding.renderViews)
    for (final RenderObject object in _renderDepthFirst(view))
      if (object is RenderBox &&
          object.hasSize &&
          (object is RenderDecoratedBox || object is RenderParagraph))
        MatrixUtils.transformRect(
          object.getTransformTo(null),
          Offset.zero & object.size,
        ),
]);

void main() {
  group(
    'every tappable calendar control is reachable by Tab with a visible ring',
    () {
      for (final String id in _stateIds) {
        testWidgets(id, (WidgetTester tester) async {
          await _pumpState(tester, id);
          await expectEveryTapTargetReachableByTab(tester);
        });
      }
    },
  );

  testWidgets(
    'the calendar keeps its arrow and T keys while a day cell has focus',
    (WidgetTester tester) async {
      await _pumpState(tester, 'a4-calendar-month');
      _useKeyboardHighlight();

      await _tabTo(tester, _dayCell('2026-09-14'));
      await _press(tester, LogicalKeyboardKey.arrowLeft);
      expect(find.text('August 2026'), findsOneWidget);

      await _tabTo(tester, _anyDayCell);
      await _press(tester, LogicalKeyboardKey.keyT);
      expect(find.text('September 2026'), findsOneWidget);

      await _tabTo(tester, _anyDayCell);
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(find.text('October 2026'), findsOneWidget);
      await _press(tester, LogicalKeyboardKey.arrowRight);
      expect(find.text('November 2026'), findsOneWidget);
    },
  );

  testWidgets('Enter and Space open a focused day', (
    WidgetTester tester,
  ) async {
    final List<String> opened = <String>[];
    await _pumpJuly(tester, onOpenDay: opened.add);
    _useKeyboardHighlight();

    await _tabTo(tester, _dayCell('2026-07-14'));
    expect(
      find.descendant(
        of: _dayCell('2026-07-14'),
        matching: find.byKey(focusRingKey),
      ),
      findsOneWidget,
    );
    await _press(tester, LogicalKeyboardKey.enter);
    await _press(tester, LogicalKeyboardKey.space);

    expect(opened, <String>['2026-07-14', '2026-07-14']);
  });

  testWidgets(
    'the month picker opened from the focused title returns focus to the title',
    (WidgetTester tester) async {
      await _pumpState(tester, 'a4-calendar-month');
      _useKeyboardHighlight();
      final Finder title = find.byKey(calendarTitleKey);

      await _tabTo(tester, title);
      await _press(tester, LogicalKeyboardKey.enter);
      expect(find.byType(CalendarMonthPicker), findsOneWidget);
      await _press(tester, LogicalKeyboardKey.escape);
      expect(find.byType(CalendarMonthPicker), findsNothing);
      expect(_focusIsWithin(title), isTrue);

      await _press(tester, LogicalKeyboardKey.space);
      expect(find.byType(CalendarMonthPicker), findsOneWidget);
      await _tabTo(
        tester,
        find.ancestor(of: find.text('Mar'), matching: find.byType(FocusRing)),
      );
      await _press(tester, LogicalKeyboardKey.enter);
      expect(find.byType(CalendarMonthPicker), findsNothing);
      expect(find.text('March 2026'), findsOneWidget);
      expect(_focusIsWithin(title), isTrue);
      expect(
        find.descendant(of: title, matching: find.byKey(focusRingKey)),
        findsOneWidget,
      );
    },
  );

  testWidgets('a month picked with the mouse leaves no focus ring', (
    WidgetTester tester,
  ) async {
    await _pumpState(tester, 'a4-calendar-month');

    await tester.tap(
      find.byKey(calendarTitleKey),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mar'), kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();

    expect(find.text('March 2026'), findsOneWidget);
    expect(find.byKey(focusRingKey), findsNothing);
  });

  group('keyboard focus moves nothing painted on the calendar', () {
    for (final String id in _stateIds) {
      testWidgets(id, (WidgetTester tester) async {
        await _pumpState(tester, id);
        _useKeyboardHighlight();
        final List<Rect> unfocused = _paintedRects(tester);
        int ringed = 0;
        for (int press = 0; press < _guardTabPresses; press++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          ringed += find.byKey(focusRingKey).evaluate().length;
          expect(_paintedRects(tester), unfocused, reason: 'Tab $press');
        }
        expect(ringed, greaterThan(0));
      });
    }
  });
}
