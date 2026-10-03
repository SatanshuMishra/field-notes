import 'dart:async';

import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/calendar/calendar.dart';
import 'package:field_notes/features/calendar/widgets/calendar_chevron_button.dart';
import 'package:field_notes/features/calendar/widgets/month_year_sheet.dart';
import 'package:field_notes/features/calendar/widgets/phone_flower_month.dart';
import 'package:field_notes/features/day_detail/day_detail.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/features/today/today.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:field_notes/state/shell_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../app/support/app_shell_harness.dart';
import '../day_detail/support/day_detail_harness.dart' show FakeMediaResolver;

const Size _phone = Size(384, 832);
const double _statusBar = 34;
const double _gestureBar = 24;
const double _headerBottom = _statusBar + 44;
const MonthRef _july = MonthRef(2026, 7);

const List<String> _monthAbbreviations = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  tester.view.viewPadding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  addTearDown(tester.view.reset);
}

Day _day(String date, {Mood? mood}) =>
    Day(id: 'id-$date', date: date, mood: mood, createdAt: 0, updatedAt: 0);

Finder _dayCell(String date) => find.byKey(ValueKey<String>('day-$date'));

Finder _inCell(String date, Finder matching) =>
    find.descendant(of: _dayCell(date), matching: matching);

Finder get _thisMonth => find.byKey(phoneThisMonthKey);

Stream<List<Day>> _daysOf(
  List<Day> days, {
  required int year,
  required int month,
}) {
  final String prefix = MonthRef(year, month).dateKey(1).substring(0, 8);
  return Stream<List<Day>>.value(<Day>[
    for (final Day day in days)
      if (day.date.startsWith(prefix)) day,
  ]);
}

Future<void> _pumpMonth(
  WidgetTester tester, {
  List<Day> days = const <Day>[],
  List<String> journaled = const <String>[],
  List<String>? openedDays,
  List<String>? openedToday,
  Override? monthDays,
}) async {
  _usePhone(tester);
  await tester.pumpWidget(
    ProviderScope(
      retry: (int retryCount, Object error) => null,
      overrides: <Override>[
        weekStartProvider.overrideWithValue(WeekStart.sunday),
        journaledDatesProvider.overrideWith(
          (Ref ref) => Stream<List<String>>.value(journaled),
        ),
        monthDays ??
            daysInMonthProvider.overrideWith(
              (Ref ref, ({int year, int month}) args) =>
                  _daysOf(days, year: args.year, month: args.month),
            ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.android),
        home: BottomBarShell(
          destinations: ShellDestination.primary,
          selected: ShellDestination.calendar,
          onSelect: (ShellDestination destination) {},
          onCapture: () {},
          body: CalendarScreen(
            initialMonth: _july,
            today: DateTime(2026, 7, 15),
            onOpenDay: (BuildContext context, {required String date}) async {
              openedDays?.add(date);
            },
            onOpenToday: () => openedToday?.add('today'),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void _expectMonth(String title) {
  expect(find.text(title), findsNWidgets(2));
}

Iterable<int> _fillsIn(WidgetTester tester, Finder finder) => tester
    .widgetList<DecoratedBox>(
      find.descendant(of: finder, matching: find.byType(DecoratedBox)),
    )
    .map((DecoratedBox box) => box.decoration)
    .whereType<BoxDecoration>()
    .map((BoxDecoration decoration) => decoration.color)
    .whereType<Color>()
    .map((Color color) => color.toARGB32());

Iterable<DashedBorderPainter> _dashesIn(WidgetTester tester, Finder finder) =>
    tester
        .widgetList<CustomPaint>(
          find.descendant(of: finder, matching: find.byType(CustomPaint)),
        )
        .expand(
          (CustomPaint paint) => <CustomPainter?>[
            paint.painter,
            paint.foregroundPainter,
          ],
        )
        .whereType<DashedBorderPainter>();

ChevronDirection _pillChevron(WidgetTester tester) => tester
    .widget<CalendarChevronGlyph>(
      find.descendant(
        of: _thisMonth,
        matching: find.byType(CalendarChevronGlyph),
      ),
    )
    .direction;

void main() {
  testWidgets(
    "the phone calendar shows flowers, dots, rings and today's pill in a full-height month",
    (WidgetTester tester) async {
      await _pumpMonth(
        tester,
        days: <Day>[
          _day('2026-07-03', mood: Mood.calm),
          _day('2026-07-10'),
          _day('2026-07-14', mood: Mood.happy),
        ],
        journaled: const <String>['2026-07-03', '2026-07-10', '2026-07-14'],
      );

      expect(find.byType(PhoneFlowerMonth), findsOneWidget);
      expect(find.byType(CalendarGrid), findsNothing);
      expect(find.byType(CalendarHeader), findsNothing);
      expect(find.text('explore'), findsOneWidget);
      expect(find.text('2 blooms this month'), findsOneWidget);
      final Finder title = find.byWidgetPredicate(
        (Widget widget) =>
            widget is Text &&
            widget.data == 'July 2026' &&
            widget.style?.fontSize == 30,
      );
      expect(title, findsOneWidget);
      expect(tester.widget<Text>(title).style!.height, 1.05);
      expect(
        tester
            .widgetList<Text>(
              find.descendant(
                of: find.byKey(phoneMonthWeekdaysKey),
                matching: find.byType(Text),
              ),
            )
            .map((Text text) => text.data)
            .toList(),
        <String>['S', 'M', 'T', 'W', 'T', 'F', 'S'],
      );

      final Finder flower = _inCell('2026-07-14', find.byType(FlowerBloom));
      expect(flower, findsOneWidget);
      expect(tester.getSize(flower), const Size(40, 40));
      expect(
        tester
            .widget<Text>(_inCell('2026-07-14', find.text('14')))
            .style!
            .color!
            .toARGB32(),
        FieldNotesColors.light.ink.toARGB32(),
      );

      final Finder dot = _inCell('2026-07-10', find.byKey(phoneMonthDotKey));
      expect(dot, findsOneWidget);
      expect(_inCell('2026-07-10', find.byType(FlowerBloom)), findsNothing);
      final Finder dotFace = find.descendant(
        of: dot,
        matching: find.byType(DecoratedBox),
      );
      expect(tester.getSize(dotFace), const Size(8, 8));
      expect(_fillsIn(tester, dot), <int>[0xFF7D8450]);
      expect(
        tester
            .widget<Text>(_inCell('2026-07-10', find.text('10')))
            .style!
            .color!
            .toARGB32(),
        FieldNotesColors.light.muted.toARGB32(),
      );

      final Finder ring = _inCell('2026-07-08', find.byKey(phoneMonthRingKey));
      expect(ring, findsOneWidget);
      expect(_inCell('2026-07-08', find.byKey(phoneMonthDotKey)), findsNothing);
      expect(
        tester.getSize(
          find.descendant(of: ring, matching: find.byType(CustomPaint)),
        ),
        const Size(22, 22),
      );
      final DashedBorderPainter ringPainter = _dashesIn(tester, ring).single;
      expect(
        ringPainter.color.toARGB32(),
        FieldNotesColors.light.ink30.toARGB32(),
      );
      expect(ringPainter.strokeWidth, 1.5);

      expect(_inCell('2026-07-20', find.byType(FlowerBloom)), findsNothing);
      expect(_inCell('2026-07-20', find.byKey(phoneMonthDotKey)), findsNothing);
      expect(
        _inCell('2026-07-20', find.byKey(phoneMonthRingKey)),
        findsNothing,
      );
      expect(
        tester
            .widget<Opacity>(_inCell('2026-07-20', find.byType(Opacity)))
            .opacity,
        0.45,
      );
      expect(_inCell('2026-07-08', find.byType(Opacity)), findsNothing);
      expect(
        find.byKey(const ValueKey<String>('day-2026-06-30')),
        findsNothing,
      );

      final Finder todayPill = _inCell(
        '2026-07-15',
        find.byKey(phoneMonthTodayPillKey),
      );
      expect(todayPill, findsOneWidget);
      expect(find.byKey(phoneMonthTodayPillKey), findsOneWidget);
      expect(
        (tester.widget<DecoratedBox>(todayPill).decoration as BoxDecoration)
            .color!
            .toARGB32(),
        Palette.coral.toARGB32(),
      );
      final Text todayNumber = tester.widget<Text>(
        find.descendant(of: todayPill, matching: find.text('15')),
      );
      expect(todayNumber.style!.color!.toARGB32(), Palette.onAccent.toARGB32());
      expect(todayNumber.style!.fontWeight, FontWeight.w700);

      final int tint = Palette.coral.withValues(alpha: 0.08).toARGB32();
      final Finder tinted = find.descendant(
        of: find.byType(PhoneFlowerMonth),
        matching: find.byWidgetPredicate(
          (Widget widget) =>
              widget is DecoratedBox &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).color?.toARGB32() == tint,
        ),
      );
      expect(tinted, findsOneWidget);
      expect(
        find.descendant(of: tinted, matching: _dayCell('2026-07-12')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tinted, matching: _dayCell('2026-07-15')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: tinted, matching: _dayCell('2026-07-19')),
        findsNothing,
      );

      expect(find.byKey(phoneMonthWeekKey(5)), findsNothing);
      final List<Rect> rows = <Rect>[
        for (int index = 0; index < 5; index++)
          tester.getRect(find.byKey(phoneMonthWeekKey(index))),
      ];
      final Rect weekdays = tester.getRect(find.byKey(phoneMonthWeekdaysKey));
      final Rect previous = tester.getRect(find.byKey(phoneMonthPreviousKey));
      final Rect month = tester.getRect(find.byKey(phoneMonthPickerButtonKey));
      final Rect next = tester.getRect(find.byKey(phoneMonthNextKey));
      final double controlsTop = _phone.height - _gestureBar - 94 - 48;
      expect(previous, Rect.fromLTWH(12, controlsTop, 48, 48));
      expect(month, Rect.fromLTRB(68, controlsTop, 316, controlsTop + 48));
      expect(next, Rect.fromLTWH(324, controlsTop, 48, 48));
      expect(tester.getRect(find.text('explore')).top, _headerBottom + 4);
      expect(rows.first.top, closeTo(weekdays.bottom + 4, 0.01));
      expect(rows.first.left, 14);
      expect(rows.first.right, _phone.width - 14);
      for (int index = 1; index < rows.length; index++) {
        expect(rows[index].top, closeTo(rows[index - 1].bottom + 2, 0.01));
        expect(rows[index].height, closeTo(rows.first.height, 0.01));
      }
      final double pillSlotTop = _phone.height - _gestureBar - 150 - 36;
      expect(rows.last.bottom, closeTo(pillSlotTop - 12, 0.01));
      expect(rows.last.bottom, lessThan(controlsTop));
      expect(rows.first.height, greaterThan(48));
    },
  );

  testWidgets(
    'swiping and the bottom controls change month and This month returns',
    (WidgetTester tester) async {
      final List<String> openedDays = <String>[];
      final List<String> openedToday = <String>[];
      await _pumpMonth(
        tester,
        openedDays: openedDays,
        openedToday: openedToday,
      );

      expect(find.byTooltip('Previous month'), findsOneWidget);
      expect(find.byTooltip('Jump to a month'), findsOneWidget);
      expect(find.byTooltip('Next month'), findsOneWidget);
      expect(_thisMonth, findsNothing);
      _expectMonth('July 2026');

      await tester.dragFrom(
        tester.getCenter(_dayCell('2026-07-08')),
        const Offset(-120, 0),
      );
      await tester.pump();
      _expectMonth('August 2026');
      expect(openedDays, isEmpty);
      expect(openedToday, isEmpty);

      final Offset grid = tester.getCenter(find.byKey(phoneMonthGridKey));
      await tester.dragFrom(grid, const Offset(-40, 0));
      await tester.pump();
      _expectMonth('August 2026');
      await tester.dragFrom(grid, const Offset(-70, 60));
      await tester.pump();
      _expectMonth('August 2026');

      await tester.dragFrom(grid, const Offset(120, 10));
      await tester.pump();
      _expectMonth('July 2026');

      await tester.tap(find.byKey(phoneMonthNextKey));
      await tester.pump();
      _expectMonth('August 2026');

      expect(_thisMonth, findsOneWidget);
      expect(tester.getSize(_thisMonth).height, greaterThanOrEqualTo(44));
      final Finder glass = find.descendant(
        of: _thisMonth,
        matching: find.byType(GlassSurface),
      );
      expect(tester.widget<GlassSurface>(glass).tone, GlassTone.paper);
      final Rect pill = tester.getRect(glass);
      expect(pill.height, 36);
      expect(pill.bottom, closeTo(_phone.height - _gestureBar - 150, 0.01));
      expect(pill.center.dx, closeTo(_phone.width / 2, 0.01));
      expect(tester.getSize(_thisMonth).width, lessThan(_phone.width / 2));
      expect(
        find.descendant(of: _thisMonth, matching: find.text('This month')),
        findsOneWidget,
      );
      expect(_pillChevron(tester), ChevronDirection.previous);

      await tester.tap(_thisMonth);
      await tester.pump();
      _expectMonth('July 2026');
      expect(_thisMonth, findsNothing);

      await tester.tap(find.byKey(phoneMonthPreviousKey));
      await tester.pump();
      _expectMonth('June 2026');
      expect(_pillChevron(tester), ChevronDirection.next);
      await tester.tap(_thisMonth);
      await tester.pump();
      _expectMonth('July 2026');

      await tester.tap(find.byKey(phoneMonthNextKey));
      await tester.pump();
      await tester.tap(find.byKey(phoneMonthPickerButtonKey));
      await tester.pumpAndSettle();

      final Finder sheet = find.byType(MonthYearSheet);
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: find.byType(PhoneSheet), matching: sheet),
        findsOneWidget,
      );
      expect(
        find.descendant(of: sheet, matching: find.text('2026')),
        findsOneWidget,
      );
      expect(
        tester.getSize(find.byKey(monthYearPreviousKey)),
        const Size(48, 48),
      );
      expect(tester.getSize(find.byKey(monthYearNextKey)), const Size(48, 48));
      for (final String name in _monthAbbreviations) {
        expect(
          find.descendant(of: sheet, matching: find.text(name)),
          findsOneWidget,
        );
      }
      final Rect january = tester.getRect(find.byKey(monthYearMonthKey(1)));
      expect(january.height, closeTo(48, 0.01));
      expect(
        tester.getRect(find.byKey(monthYearMonthKey(3))).top,
        closeTo(january.top, 0.01),
      );
      expect(
        tester.getRect(find.byKey(monthYearMonthKey(4))).top,
        closeTo(january.bottom + 8, 0.01),
      );
      expect(
        tester.getRect(find.byKey(monthYearMonthKey(12))).bottom,
        closeTo(january.top + 4 * 48 + 3 * 8, 0.01),
      );
      final Finder august = find.byKey(monthYearMonthKey(8));
      expect(_fillsIn(tester, august), contains(Palette.coral.toARGB32()));
      expect(_dashesIn(tester, august), isEmpty);
      final Finder july = find.byKey(monthYearMonthKey(7));
      expect(_fillsIn(tester, july), isNot(contains(Palette.coral.toARGB32())));
      expect(
        _dashesIn(tester, july).single.color.toARGB32(),
        Palette.coral.toARGB32(),
      );
      expect(_dashesIn(tester, find.byKey(monthYearMonthKey(9))), isEmpty);
      expect(tester.getSize(find.byKey(monthYearBackKey)).height, 48);

      await tester.tap(find.byKey(monthYearNextKey));
      await tester.pump();
      expect(
        find.descendant(of: sheet, matching: find.text('2027')),
        findsOneWidget,
      );
      await tester.tap(find.descendant(of: sheet, matching: find.text('Mar')));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      _expectMonth('March 2027');

      await tester.tap(find.byKey(phoneMonthPickerButtonKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(monthYearBackKey));
      await tester.pumpAndSettle();
      expect(sheet, findsNothing);
      _expectMonth('July 2026');
      expect(_thisMonth, findsNothing);
    },
  );

  testWidgets('tapping today opens Today and another day opens the day sheet', (
    WidgetTester tester,
  ) async {
    _usePhone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          ...shellOverrides(),
          dayDetailMediaResolverProvider.overrideWith(
            (Ref ref) => FakeMediaResolver(),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: fieldNotesTheme(platform: TargetPlatform.android),
          home: const AppShell(),
        ),
      ),
    );
    await tester.pump();
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(AppShell)),
    );
    final DateTime now = DateTime.now();
    final MonthRef current = MonthRef.forDate(now);
    final Finder calendarTab = find.byKey(
      const ValueKey<String>('tab-calendar'),
    );

    await tester.tap(calendarTab, warnIfMissed: false);
    await tester.pump();
    await tester.pump();
    expect(find.byType(PhoneFlowerMonth), findsOneWidget);

    await tester.tap(_dayCell(current.dateKey(now.day)));
    await tester.pump();
    await tester.pump();
    expect(container.read(shellNavigationProvider), ShellDestination.today);
    expect(find.byType(TodayScreen), findsOneWidget);
    expect(find.byType(CalendarScreen), findsNothing);
    expect(find.byType(PhoneSheet), findsNothing);

    await tester.tap(calendarTab, warnIfMissed: false);
    await tester.pump();
    await tester.pump();
    await tester.tap(find.byKey(phoneMonthPreviousKey));
    await tester.pump();
    final String pastDay = current.previous.dateKey(1);
    await tester.tap(_dayCell(pastDay));
    await tester.pump();
    await tester.pump(phoneSheetEntrance);

    expect(container.read(shellNavigationProvider), ShellDestination.calendar);
    expect(find.byType(PhoneSheet), findsOneWidget);
    final Finder panel = find.ancestor(
      of: find.byType(PhoneSheet),
      matching: find.byType(DayDetailPanel),
    );
    expect(panel, findsOneWidget);
    expect(tester.widget<DayDetailPanel>(panel).date, pastDay);
  });

  testWidgets('the phone month keeps its controls while it loads', (
    WidgetTester tester,
  ) async {
    final StreamController<List<Day>> loading = StreamController<List<Day>>();
    addTearDown(loading.close);
    await _pumpMonth(
      tester,
      monthDays: daysInMonthProvider(
        year: 2026,
        month: 7,
      ).overrideWith((Ref ref) => loading.stream),
    );

    expect(find.text(calendarLoadingMessage), findsOneWidget);
    expect(find.byKey(phoneMonthPreviousKey), findsOneWidget);
    expect(find.byKey(phoneMonthNextKey), findsOneWidget);
    _expectMonth('July 2026');
    expect(find.text('Nothing planted this month'), findsNothing);
    expect(find.byKey(phoneMonthWeekKey(0)), findsNothing);
  });

  testWidgets(
    'the phone month shows the calendar error in place of its weeks',
    (WidgetTester tester) async {
      await _pumpMonth(
        tester,
        monthDays: daysInMonthProvider(
          year: 2026,
          month: 7,
        ).overrideWith((Ref ref) => Stream<List<Day>>.error(Exception('boom'))),
      );

      expect(find.text(calendarErrorMessage), findsOneWidget);
      expect(find.byKey(phoneMonthPickerButtonKey), findsOneWidget);
      expect(find.byKey(phoneMonthWeekKey(0)), findsNothing);
    },
  );
}
