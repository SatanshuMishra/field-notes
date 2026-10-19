import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/calendar/calendar.dart';
import 'package:field_notes/features/calendar/widgets/calendar_day_cell.dart';
import 'package:field_notes/features/calendar/widgets/calendar_month_picker.dart';
import 'package:field_notes/features/calendar/widgets/month_year_sheet.dart';
import 'package:field_notes/features/calendar/widgets/phone_flower_month.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

const int _mousePointerId = 47;
const int _mouseDevice = 1;

const Offset _parked = Offset(-20, -20);
const Size _desktop = Size(1000, 700);
const Size _phone = Size(384, 832);

const Color _ink = Color(0xFF4A3B2E);
const Color _white = Color(0xFFFFFFFF);
const Color _coral = Color(0xFFB8566A);

final int _lightRow = _ink.withValues(alpha: 0.06).toARGB32();
final int _lightPill = _coral.withValues(alpha: 0.08).toARGB32();
final int _dark = _white.withValues(alpha: 0.12).toARGB32();

class _Row {
  const _Row(this.label, this.fill, this.radius);

  final String label;
  final int fill;
  final double radius;
}

Finder _labelled(String label) => find.byWidgetPredicate(
  (Widget widget) => widget is Pressable && widget.label == label,
);

MouseCursor? _cursor() =>
    RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(_mouseDevice);

Finder _hoverFill(Finder control, _Row row) => find.descendant(
  of: control,
  matchRoot: true,
  matching: find.byWidgetPredicate((Widget widget) {
    if (widget is! DecoratedBox) {
      return false;
    }
    final Decoration decoration = widget.decoration;
    return decoration is BoxDecoration &&
        decoration.color?.toARGB32() == row.fill &&
        decoration.shape == BoxShape.rectangle &&
        decoration.borderRadius == BorderRadius.circular(row.radius);
  }),
);

Future<void> _expectRows(
  WidgetTester tester,
  TestGesture mouse,
  List<_Row> rows,
) async {
  for (final _Row row in rows) {
    final Finder control = _labelled(row.label);
    await mouse.moveTo(_parked);
    await tester.pump();
    expect(control, findsOneWidget, reason: row.label);
    expect(_hoverFill(control, row), findsNothing, reason: row.label);

    await mouse.moveTo(tester.getCenter(control));
    await tester.pump();

    expect(_cursor(), SystemMouseCursors.click, reason: row.label);
    expect(_hoverFill(control, row), findsOneWidget, reason: row.label);
    final SemanticsData semantics = tester
        .getSemantics(control)
        .getSemanticsData();
    expect(semantics.label, row.label, reason: row.label);
    expect(semantics.flagsCollection.isButton, isTrue, reason: row.label);
  }
  await mouse.moveTo(_parked);
  await tester.pump(const Duration(seconds: 2));
}

Future<void> _pump(
  WidgetTester tester, {
  required Size surface,
  required TargetPlatform platform,
  required Widget child,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform),
      home: Scaffold(body: child),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

Day _day(String date) =>
    Day(id: 'id-$date', date: date, createdAt: 0, updatedAt: 0);

Widget _cell(Size size, Widget cell) =>
    SizedBox(width: size.width, height: size.height, child: cell);

void main() {
  testWidgets('every calendar control shows the click cursor and hover', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    addTearDown(tester.view.reset);
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
      pointer: _mousePointerId,
    );
    await mouse.addPointer(location: _parked);
    addTearDown(mouse.removePointer);

    await _pump(
      tester,
      surface: _desktop,
      platform: TargetPlatform.macOS,
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 900,
          child: CalendarHeader(
            month: const MonthRef(2026, 10),
            currentMonth: const MonthRef(2026, 9),
            onShowCurrentMonth: () {},
            onOpenPicker: () {},
            onPreviousMonth: () {},
            onNextMonth: () {},
          ),
        ),
      ),
    );
    await _expectRows(tester, mouse, <_Row>[
      _Row('Jump to a month', _lightRow, 10),
      _Row('This week', _dark, 11),
      _Row('Previous month', _lightRow, 10),
      _Row('Next month', _lightRow, 10),
    ]);

    await _pump(
      tester,
      surface: _desktop,
      platform: TargetPlatform.macOS,
      child: Align(
        alignment: Alignment.topLeft,
        child: CalendarMonthPicker(
          year: 2026,
          displayedMonth: const MonthRef(2026, 10),
          currentMonth: const MonthRef(2026, 9),
          onPreviousYear: () {},
          onNextYear: () {},
          onPickMonth: (MonthRef month) {},
          onBackToThisWeek: () {},
        ),
      ),
    );
    await _expectRows(tester, mouse, <_Row>[
      _Row('Previous year', _lightRow, 10),
      _Row('Next year', _lightRow, 10),
      _Row('October 2026', _dark, 9),
      _Row('September 2026', _lightRow, 9),
      _Row('January 2026', _lightRow, 9),
      _Row('Back to this week', _lightRow, 6),
    ]);

    await _pump(
      tester,
      surface: _desktop,
      platform: TargetPlatform.macOS,
      child: Align(
        alignment: Alignment.topLeft,
        child: Row(
          children: <Widget>[
            _cell(
              const Size(100, 90),
              CalendarDayCell(
                cell: const CalendarCell.day(
                  dayOfMonth: 15,
                  dateKey: '2026-10-15',
                ),
                day: _day('2026-10-15'),
                isToday: true,
                onTap: () {},
              ),
            ),
            _cell(
              const Size(100, 90),
              CalendarDayCell(
                cell: const CalendarCell.day(
                  dayOfMonth: 10,
                  dateKey: '2026-10-10',
                ),
                day: _day('2026-10-10'),
                hasEntries: true,
                onTap: () {},
              ),
            ),
            _cell(
              const Size(100, 90),
              CalendarDayCell(
                cell: const CalendarCell.day(
                  dayOfMonth: 3,
                  dateKey: '2026-10-03',
                ),
                onTap: () {},
              ),
            ),
            _cell(
              const Size(100, 90),
              CalendarDayCell(
                cell: const CalendarCell.day(
                  dayOfMonth: 30,
                  dateKey: '2026-09-30',
                  isInMonth: false,
                ),
                onTap: () {},
              ),
            ),
            _cell(
              const Size(50, 50),
              CalendarDayCell(
                cell: const CalendarCell.day(
                  dayOfMonth: 4,
                  dateKey: '2026-10-04',
                ),
                onTap: () {},
              ),
            ),
          ],
        ),
      ),
    );
    await _expectRows(tester, mouse, <_Row>[
      _Row('Day 15, today', _lightRow, 12),
      _Row('Day 10, has entries', _lightRow, 12),
      _Row('Day 3', _lightRow, 12),
      _Row('Day 30', _lightRow, 12),
      _Row('Day 4', _lightRow, 9),
    ]);

    await _pump(
      tester,
      surface: _phone,
      platform: TargetPlatform.android,
      child: PhoneFlowerMonth(
        month: const MonthRef(2026, 6),
        currentMonth: const MonthRef(2026, 7),
        daysByDate: const <String, Day>{},
        journaledDates: const <String>{'2026-06-10'},
        firstWeekday: DateTime.sunday,
        todayKey: '2026-07-15',
        onSelectDay: (String date) {},
        onPreviousMonth: () {},
        onNextMonth: () {},
        onShowCurrentMonth: () {},
        onOpenPicker: () {},
      ),
    );
    await _expectRows(tester, mouse, <_Row>[
      _Row('Previous month', _lightRow, 14),
      _Row('Jump to a month', _lightRow, 14),
      _Row('Next month', _lightRow, 14),
      _Row('This month', _lightPill, 18),
      _Row('Day 10, has entries', _lightRow, 14),
      _Row('Day 3', _lightRow, 14),
    ]);

    await _pump(
      tester,
      surface: _phone,
      platform: TargetPlatform.android,
      child: Column(
        children: <Widget>[
          MonthYearSheet(
            displayedMonth: const MonthRef(2026, 6),
            currentMonth: const MonthRef(2026, 7),
            onPick: (MonthRef month) {},
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: MonthYearBackButton(onPressed: () {}),
          ),
        ],
      ),
    );
    await _expectRows(tester, mouse, <_Row>[
      _Row('Previous year', _lightRow, 14),
      _Row('Next year', _lightRow, 14),
      _Row('June 2026', _dark, 12),
      _Row('July 2026', _lightRow, 12),
      _Row('March 2026', _lightRow, 12),
      _Row('Back to this month', _lightRow, 14),
    ]);

    handle.dispose();
  });
}
