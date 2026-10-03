import 'dart:math' as math;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/flowers/flower_bloom.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/calendar/model/calendar_month.dart';
import 'package:field_notes/features/onboarding/onboarding_controller.dart';
import 'package:field_notes/features/onboarding/onboarding_frame.dart';
import 'package:field_notes/features/onboarding/onboarding_swipe.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _kicker = 'a month';
const String _title = 'Give it a few weeks.';
const String monthSliderLabelSidebar = 'Drag to see the weeks ahead';
const String monthSliderLabelBottomBar = 'drag to see the weeks ahead';
const String _todayEnd = 'today';
const String _lookAhead = 'drag to look ahead →';
const String _noWords = "No words yet. That's fine.";
const String _caption =
    'Every day stays open. Tap one to look back, or add to it.';

const Key monthLettersKey = ValueKey<String>('month-letters');
const Key monthSliderKey = ValueKey<String>('month-slider');
const Key monthNoteCardKey = ValueKey<String>('month-note-card');
const Key monthRingKey = ValueKey<String>('month-ring');
const Key monthPetalKey = ValueKey<String>('month-petal');

Key monthDayKey(int day) => ValueKey<String>('month-day-$day');

Key monthBlankKey(int slot) => ValueKey<String>('month-blank-$slot');

const int _mask = 0xFFFFFFFF;
const int _sampleStep = 0x6D2B79F5;
const double _sampleRange = 4294967296;
const double _skipChance = 0.16;
const double _glowFill = 0.2;
const int _daysPerWeek = 7;

const double _sidebarBodyGap = 38;
const double _sidebarBottom = 72;
const double _sidebarMargin = 16;
const double _sidebarCalendarWidth = 524;
const double _sidebarSideWidth = 270;
const double _sidebarColumnGap = 36;
const double _sidebarCellGap = 8;
const double _sidebarHeaderGap = 8;
const double _sidebarLettersHeight = 22;
const double _sidebarLettersGap = 6;
const double _sidebarSideGap = 22;
const double _sidebarSideTightGap = 10;

const double _sidebarHeadingSide = 40;
const double _bottomBarHeadingSide = 20;
const double _bottomBarSide = 14;
const double _bottomBarClearance = 12;
const double _bottomBarCellGap = 5;
const double _bottomBarLettersHeight = 18;
const double _bottomBarLettersGap = 5;
const double _bottomBarValueGap = 8;
const EdgeInsets _bottomBarHeaderPadding = EdgeInsets.fromLTRB(4, 0, 4, 8);
const EdgeInsets _bottomBarFillPadding = EdgeInsets.fromLTRB(10, 8, 10, 0);
const double _bottomBarSliderHeight = 36;
const double _bottomBarSliderReach = 4;

const double _target = 48;
const double _numberFloor = 7.5;
const double _thumbRadius = 8;
const double _trackHeight = 4;
const BorderRadius _sliderFocusRadius = BorderRadius.all(Radius.circular(9));
const BorderRadius _boxRadius = BorderRadius.all(Radius.circular(14));

const double _pastOpacity = 0.45;
const double _laterOpacity = 0.65;
const double _todayBorder = 2;
const double _cardBorder = 2;
const double _glowSpread = 6;
const double _glowAlpha = 0.28;
const double _restingGlow = 0.5;

const Color _petalFill = Color(0xFFF2A9B2);
const Color _petalEdge = Color(0x808A4A4A);

const Duration _cellFade = Duration(milliseconds: 250);
const Duration _headingRise = Duration(milliseconds: 500);
const Duration _cardRise = Duration(milliseconds: 450);
const Duration _cardDelay = Duration(milliseconds: 1200);
const Duration _todayPop = Duration(milliseconds: 500);
const Duration _todayPopDelay = Duration(milliseconds: 350);
const Duration _samplePop = Duration(milliseconds: 350);
const int _sampleStaggerMs = 20;
const Duration _petalLand = Duration(milliseconds: 1800);
const Duration _petalDelay = Duration(seconds: 1);
const Duration _todayGlowDelay = Duration(milliseconds: 2200);
const Duration _todayGlowPeriod = Duration(milliseconds: 2400);
const Duration _boxGlowDelay = Duration(milliseconds: 1600);
const Duration _boxGlowPeriod = Duration(milliseconds: 2600);

const double _riseDistance = 14;
const Cubic _popCurve = Cubic(0.2, 0.9, 0.3, 1.2);
const Cubic _landCurve = Cubic(0.3, 0.6, 0.4, 1);
const double _popPeak = 0.6;
const double _popFrom = 0.2;
const double _popOver = 1.08;
const double _landShow = 0.15;
const Offset _landFrom = Offset(-90, -130);
const double _landFromTurn = -220;
const double _landRestTurn = 24;

int _imul(int a, int b) => (a * b) & _mask;

double _draw(int seed, int index) {
  final int state = (seed + (index + 1) * _sampleStep) & _mask;
  final int mixed = _imul(state ^ (state >> 15), 1 | state);
  final int folded =
      ((mixed + _imul(mixed ^ (mixed >> 7), 61 | mixed)) & _mask) ^ mixed;
  return ((folded ^ (folded >> 14)) & _mask) / _sampleRange;
}

int _daysIn(MonthRef month) => DateTime(month.year, month.month + 1, 0).day;

List<Mood?> monthSampleMoods(MonthRef month) {
  final int seed = (month.month - 1) * 31 + 7;
  return List<Mood?>.unmodifiable(<Mood?>[
    for (int index = 0; index < _daysIn(month); index++)
      if (_draw(seed, index * 2 + 1) < _skipChance)
        null
      else
        moodOrder[(_draw(seed, index * 2) * moodOrder.length).floor()],
  ]);
}

DateTime _entryDay(String entryDate) {
  final DateTime parsed = DateTime.tryParse(entryDate) ?? DateTime.now();
  return DateTime(parsed.year, parsed.month, parsed.day);
}

enum _DayState { past, today, sample, later }

@immutable
class _MonthPlan {
  const _MonthPlan({
    required this.month,
    required this.today,
    required this.daysInMonth,
    required this.span,
    required this.reach,
    required this.fill,
    required this.mood,
    required this.cells,
    required this.samples,
    required this.letters,
  });

  factory _MonthPlan.of(OnboardingDraft draft) {
    final DateTime day = _entryDay(draft.entryDate);
    final MonthRef month = MonthRef.forDate(day);
    final int daysInMonth = _daysIn(month);
    final int span = math.max(1, daysInMonth - day.day);
    final double fill = draft.monthFill.clamp(0.0, 1.0);
    final int firstWeekday = draft.week.weekday;
    return _MonthPlan(
      month: month,
      today: day.day,
      daysInMonth: daysInMonth,
      span: span,
      reach: day.day + (fill * span).round(),
      fill: fill,
      mood: draft.mood,
      cells: monthGridCells(month, firstWeekday: firstWeekday),
      samples: monthSampleMoods(month),
      letters: weekdayHeaders(firstWeekday: firstWeekday),
    );
  }

  final MonthRef month;
  final int today;
  final int daysInMonth;
  final int span;
  final int reach;
  final double fill;
  final Mood mood;
  final List<CalendarCell> cells;
  final List<Mood?> samples;
  final List<String> letters;

  int get ahead => reach - today;

  int get rows => cells.length ~/ _daysPerWeek;

  int get leading => cells.indexWhere((CalendarCell cell) => cell.isInMonth);

  int get todayRow => (leading + today - 1) ~/ _daysPerWeek;

  bool get glowing => fill < _glowFill;

  _DayState stateOf(int day) {
    if (day < today) {
      return _DayState.past;
    }
    if (day == today) {
      return _DayState.today;
    }
    return day <= reach ? _DayState.sample : _DayState.later;
  }

  int get flowers =>
      1 +
      <int>[
        for (int day = today + 1; day <= math.min(reach, daysInMonth); day++)
          if (samples[day - 1] != null) day,
      ].length;

  String get countLabel =>
      flowers == 1 ? '1 flower so far' : '$flowers flowers';

  String get fillLabel => ahead <= 0 ? _lookAhead : describe(ahead);

  String get summary =>
      '${monthName(month.month)} $today, today, ${mood.label}';

  String describe(int days) {
    if (days <= 0) {
      return _todayEnd;
    }
    if (today + days >= daysInMonth) {
      return 'by the end of ${monthAbbreviation(month.month)}';
    }
    return days == 1 ? '1 day from now' : '$days days from now';
  }

  double fillFor(int days) => (days / span).clamp(0.0, 1.0);
}

@immutable
class _CellMetrics {
  const _CellMetrics({
    required this.width,
    required this.height,
    required this.radius,
    required this.numberLeft,
    required this.numberTop,
    required this.numberSize,
    required this.art,
    required this.artLift,
    required this.ring,
    required this.petal,
    required this.petalInset,
  });

  static const _CellMetrics sidebar = _CellMetrics(
    width: 68,
    height: 56,
    radius: 11,
    numberLeft: 6,
    numberTop: 4,
    numberSize: 9,
    art: 32,
    artLift: 6,
    ring: 14,
    petal: Size(10, 7),
    petalInset: 4,
  );

  static const _CellMetrics bottomBar = _CellMetrics(
    width: 44,
    height: 50,
    radius: 8,
    numberLeft: 3,
    numberTop: 2,
    numberSize: 9,
    art: 30,
    artLift: 5,
    ring: 10,
    petal: Size(7, 5),
    petalInset: 2,
  );

  final double width;
  final double height;
  final double radius;
  final double numberLeft;
  final double numberTop;
  final double numberSize;
  final double art;
  final double artLift;
  final double ring;
  final Size petal;
  final double petalInset;

  _CellMetrics fit({required double width, required double height}) {
    final double factor = math.min(width / this.width, height / this.height);
    return _CellMetrics(
      width: width,
      height: height,
      radius: radius,
      numberLeft: numberLeft * factor,
      numberTop: numberTop * factor,
      numberSize: math.max(_numberFloor, numberSize * factor),
      art: art * factor,
      artLift: artLift * factor,
      ring: ring * factor,
      petal: petal * factor,
      petalInset: petalInset * factor,
    );
  }
}

class MonthChapter extends ConsumerWidget {
  const MonthChapter({super.key, required this.layout});

  final ShellLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingFlow flow = ref.watch(onboardingControllerProvider);
    if (flow is! OnboardingFlowRunning) {
      return const SizedBox.expand();
    }
    final OnboardingDraft draft = flow.draft;
    final _MonthPlan plan = _MonthPlan.of(draft);
    final ValueChanged<double> onFill = ref
        .read(onboardingControllerProvider.notifier)
        .setMonthFill;
    return SizedBox.expand(
      child: switch (layout) {
        ShellLayout.sidebar => _SidebarMonth(
          plan: plan,
          line: draft.noteText.trim(),
          onFill: onFill,
        ),
        ShellLayout.bottomBar => _BottomBarMonth(plan: plan, onFill: onFill),
      },
    );
  }
}

enum _Part { header, letters, grid, card, fill, caption }

class _SidebarMonth extends StatelessWidget {
  const _SidebarMonth({
    required this.plan,
    required this.line,
    required this.onFill,
  });

  final _MonthPlan plan;
  final String line;
  final ValueChanged<double> onFill;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Column(
      children: <Widget>[
        const _Rise(
          duration: _headingRise,
          child: _Heading(layout: ShellLayout.sidebar),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _sidebarMargin,
              0,
              _sidebarMargin,
              _sidebarBottom,
            ),
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double sideWidth = MediaQuery.textScalerOf(context)
                    .scale(_sidebarSideWidth);
                final double sideRoom = _sidebarColumnGap + sideWidth;
                final double calendarWidth = math.min(
                  _sidebarCalendarWidth,
                  math.max(0.0, constraints.maxWidth - sideRoom),
                );
                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: calendarWidth + sideRoom,
                    child: CustomMultiChildLayout(
                      delegate: _SidebarBody(
                        calendarWidth: calendarWidth,
                        sideWidth: sideWidth,
                        rows: plan.rows,
                        todayRow: plan.todayRow,
                      ),
                      children: <Widget>[
                        LayoutId(
                          id: _Part.header,
                          child: _MonthHeader(
                            plan: plan,
                            nameStyle: TextStyle(
                              fontFamily: TypographyTokens.serif,
                              fontSize: 22,
                              fontWeight: FontWeight.w500,
                              color: colors.ink,
                            ),
                            countStyle: TextStyle(
                              fontFamily: TypographyTokens.sans,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: colors.muted,
                            ),
                          ),
                        ),
                        LayoutId(
                          id: _Part.letters,
                          child: _Letters(
                            letters: plan.letters,
                            gap: _sidebarCellGap,
                            height: _sidebarLettersHeight,
                            style: TextStyle(
                              fontFamily: TypographyTokens.sans,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                              color: colors.muted,
                            ),
                          ),
                        ),
                        LayoutId(
                          id: _Part.grid,
                          child: LayoutBuilder(builder: _grid(calendarWidth)),
                        ),
                        LayoutId(
                          id: _Part.card,
                          child: _ShrinkToFit(
                            width: sideWidth,
                            child: _Rise(
                              duration: _cardRise,
                              delay: _cardDelay,
                              child: _NoteCard(mood: plan.mood, line: line),
                            ),
                          ),
                        ),
                        LayoutId(
                          id: _Part.fill,
                          child: _SideFill(plan: plan, onFill: onFill),
                        ),
                        LayoutId(
                          id: _Part.caption,
                          child: _ShrinkToFit(
                            width: sideWidth,
                            child: Text(
                              _caption,
                              style: TextStyle(
                                fontFamily: TypographyTokens.accent,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                height: 1.2,
                                color: colors.sage,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  LayoutWidgetBuilder _grid(
    double calendarWidth,
  ) => (BuildContext context, BoxConstraints area) {
    final int rows = plan.rows;
    final double cellWidth =
        (calendarWidth - (_daysPerWeek - 1) * _sidebarCellGap) / _daysPerWeek;
    final double cellHeight = math.max(
      0.0,
      math.min(
        _CellMetrics.sidebar.height,
        (area.maxHeight - (rows - 1) * _sidebarCellGap) / rows,
      ),
    );
    return _Grid(
      plan: plan,
      gap: _sidebarCellGap,
      metrics: _CellMetrics.sidebar.fit(width: cellWidth, height: cellHeight),
    );
  };
}

class _SidebarBody extends MultiChildLayoutDelegate {
  _SidebarBody({
    required this.calendarWidth,
    required this.sideWidth,
    required this.rows,
    required this.todayRow,
  });

  final double calendarWidth;
  final double sideWidth;
  final int rows;
  final int todayRow;

  @override
  void performLayout(Size size) {
    final BoxConstraints calendar = BoxConstraints.tightFor(
      width: calendarWidth,
    );
    final Size header = layoutChild(_Part.header, calendar);
    final Size letters = layoutChild(_Part.letters, calendar);
    final double lettersTop =
        _sidebarBodyGap + header.height + _sidebarHeaderGap;
    final double gridTop = lettersTop + letters.height + _sidebarLettersGap;
    final Size grid = layoutChild(
      _Part.grid,
      BoxConstraints(
        maxWidth: calendarWidth,
        maxHeight: math.max(0.0, size.height - gridTop),
      ),
    );
    final Size fill = layoutChild(
      _Part.fill,
      BoxConstraints.tightFor(width: sideWidth),
    );
    final double room = math.max(
      0.0,
      size.height - fill.height - 2 * _sidebarSideTightGap,
    );
    final Size card = layoutChild(
      _Part.card,
      BoxConstraints(maxWidth: sideWidth, maxHeight: room),
    );
    final Size caption = layoutChild(
      _Part.caption,
      BoxConstraints(
        maxWidth: sideWidth,
        maxHeight: math.max(0.0, room - card.height),
      ),
    );
    final double content = card.height + fill.height + caption.height;
    final double gap = ((size.height - content) / 2).clamp(
      _sidebarSideTightGap,
      _sidebarSideGap,
    );
    final double side = content + 2 * gap;
    final double rowStep = (grid.height + _sidebarCellGap) / math.max(1, rows);
    final double besideToday = gridTop + todayRow * rowStep;
    final double sideLeft = calendarWidth + _sidebarColumnGap;
    final double sideTop = besideToday.clamp(
      0.0,
      math.max(0.0, size.height - side),
    );
    positionChild(_Part.header, const Offset(0, _sidebarBodyGap));
    positionChild(_Part.letters, Offset(0, lettersTop));
    positionChild(_Part.grid, Offset(0, gridTop));
    positionChild(_Part.card, Offset(sideLeft, sideTop));
    positionChild(_Part.fill, Offset(sideLeft, sideTop + card.height + gap));
    positionChild(
      _Part.caption,
      Offset(sideLeft, sideTop + card.height + gap + fill.height + gap),
    );
  }

  @override
  bool shouldRelayout(_SidebarBody oldDelegate) =>
      oldDelegate.calendarWidth != calendarWidth ||
      oldDelegate.sideWidth != sideWidth ||
      oldDelegate.rows != rows ||
      oldDelegate.todayRow != todayRow;
}

class _ShrinkToFit extends StatelessWidget {
  const _ShrinkToFit({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.topLeft,
      child: SizedBox(width: width, child: child),
    );
  }
}

class _SideFill extends StatelessWidget {
  const _SideFill({required this.plan, required this.onFill});

  final _MonthPlan plan;
  final ValueChanged<double> onFill;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return _FillBox(
      plan: plan,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      sliderHeight: _target,
      sliderReach: 0,
      onFill: onFill,
      label: monthSliderLabelSidebar,
      top: Text(
        monthSliderLabelSidebar,
        style: TextStyle(
          fontFamily: TypographyTokens.accent,
          fontSize: 21,
          fontWeight: FontWeight.w600,
          height: 1.1,
          color: colors.ink,
        ),
      ),
      bottom: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Text(
            _todayEnd,
            style: TextStyle(
              fontFamily: TypographyTokens.accent,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.mutedDeep,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              plan.fillLabel,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontFamily: TypographyTokens.accent,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.accentInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  const _NoteCard({required this.mood, required this.line});

  final Mood mood;
  final String line;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Semantics(
      key: monthNoteCardKey,
      container: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.composerPaper,
          border: Border.all(color: colors.line, width: _cardBorder),
          borderRadius: _boxRadius,
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: colors.shadowTint(0x40),
              offset: const Offset(3, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          child: Row(
            children: <Widget>[
              ExcludeSemantics(child: FlowerBloom.forMood(mood, size: 36)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      line.isEmpty ? _noWords : line,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: TypographyTokens.serif,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                        color: colors.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Today · ${mood.label}',
                      style: TextStyle(
                        fontFamily: TypographyTokens.sans,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: colors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomBarMonth extends StatelessWidget {
  const _BottomBarMonth({required this.plan, required this.onFill});

  final _MonthPlan plan;
  final ValueChanged<double> onFill;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final EdgeInsets insets = MediaQuery.paddingOf(context);
    final double gesture = math.max(
      insets.bottom,
      MediaQuery.viewPaddingOf(context).bottom,
    );
    return Padding(
      padding: EdgeInsets.only(
        top: insets.top + onboardingPhoneTitleTop,
        bottom: gesture + onboardingControlBarReserve + _bottomBarClearance,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const _Rise(
            duration: _headingRise,
            child: _Heading(layout: ShellLayout.bottomBar),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: _bottomBarSide),
              child: LayoutBuilder(builder: _calendar),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _bottomBarSide),
            child: NoSwipe(
              child: _FillBox(
                plan: plan,
                padding: _bottomBarFillPadding,
                sliderHeight: _bottomBarSliderHeight,
                sliderReach: _bottomBarSliderReach,
                onFill: onFill,
                label: monthSliderLabelBottomBar,
                top: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        monthSliderLabelBottomBar,
                        style: TextStyle(
                          fontFamily: TypographyTokens.accent,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: colors.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: _bottomBarValueGap),
                    Text(
                      plan.fillLabel,
                      style: TextStyle(
                        fontFamily: TypographyTokens.accent,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: colors.accentInk,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _calendar(BuildContext context, BoxConstraints area) {
    final FieldNotesColors colors = context.colors;
    final double width = math.min(
      area.maxWidth,
      _CellMetrics.bottomBar.width * _daysPerWeek +
          _bottomBarCellGap * (_daysPerWeek - 1),
    );
    return Center(
      child: SizedBox(
        width: width,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: _bottomBarHeaderPadding,
              child: _MonthHeader(
                plan: plan,
                nameStyle: TextStyle(
                  fontFamily: TypographyTokens.serif,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                  color: colors.ink,
                ),
                countStyle: TextStyle(
                  fontFamily: TypographyTokens.sans,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colors.muted,
                ),
              ),
            ),
            _Letters(
              letters: plan.letters,
              gap: _bottomBarCellGap,
              height: _bottomBarLettersHeight,
              style: TextStyle(
                fontFamily: TypographyTokens.sans,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: colors.muted,
              ),
            ),
            const SizedBox(height: _bottomBarLettersGap),
            Flexible(child: LayoutBuilder(builder: _grid)),
          ],
        ),
      ),
    );
  }

  Widget _grid(BuildContext context, BoxConstraints area) {
    final int rows = plan.rows;
    final double cellWidth =
        (area.maxWidth - (_daysPerWeek - 1) * _bottomBarCellGap) / _daysPerWeek;
    final double cellHeight = math.max(
      0.0,
      math.min(
        _CellMetrics.bottomBar.height,
        (area.maxHeight - (rows - 1) * _bottomBarCellGap) / rows,
      ),
    );
    return _Grid(
      plan: plan,
      gap: _bottomBarCellGap,
      metrics: _CellMetrics.bottomBar.fit(width: cellWidth, height: cellHeight),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading({required this.layout});

  final ShellLayout layout;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final bool sidebar = layout == ShellLayout.sidebar;
    final TextAlign align = sidebar ? TextAlign.center : TextAlign.start;
    return Padding(
      padding: sidebar
          ? const EdgeInsets.fromLTRB(
              _sidebarHeadingSide,
              onboardingTitleTop,
              _sidebarHeadingSide,
              0,
            )
          : const EdgeInsets.symmetric(horizontal: _bottomBarHeadingSide),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: sidebar
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _kicker,
            textAlign: align,
            style: TextStyle(
              fontFamily: TypographyTokens.accent,
              fontSize: sidebar ? 21 : 18,
              fontWeight: FontWeight.w600,
              color: colors.accentInk,
            ),
          ),
          Semantics(
            header: true,
            child: Text(
              _title,
              textAlign: align,
              style: TextStyle(
                fontFamily: TypographyTokens.serif,
                fontSize: sidebar ? 44 : 28,
                fontWeight: FontWeight.w500,
                height: sidebar ? 1.05 : 1.08,
                color: colors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthHeader extends StatelessWidget {
  const _MonthHeader({
    required this.plan,
    required this.nameStyle,
    required this.countStyle,
  });

  final _MonthPlan plan;
  final TextStyle nameStyle;
  final TextStyle countStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: <Widget>[
        Expanded(
          child: Text(
            monthName(plan.month.month),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: nameStyle,
          ),
        ),
        const SizedBox(width: 8),
        Text(plan.countLabel, maxLines: 1, style: countStyle),
      ],
    );
  }
}

class _Letters extends StatelessWidget {
  const _Letters({
    required this.letters,
    required this.gap,
    required this.height,
    required this.style,
  });

  final List<String> letters;
  final double gap;
  final double height;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        child: Row(
          key: monthLettersKey,
          children: <Widget>[
            for (int index = 0; index < letters.length; index++) ...<Widget>[
              if (index > 0) SizedBox(width: gap),
              Expanded(
                child: Center(
                  child: Text(letters[index], maxLines: 1, style: style),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.plan, required this.gap, required this.metrics});

  final _MonthPlan plan;
  final double gap;
  final _CellMetrics metrics;

  Widget _cell(int index) {
    final CalendarCell cell = plan.cells[index];
    if (!cell.isInMonth) {
      return SizedBox(
        key: index < plan.leading ? monthBlankKey(index) : null,
        width: metrics.width,
        height: metrics.height,
      );
    }
    final int day = cell.dayOfMonth;
    return SizedBox(
      width: metrics.width,
      height: metrics.height,
      child: _DayCell(
        key: monthDayKey(day),
        day: day,
        state: plan.stateOf(day),
        mood: plan.mood,
        sample: plan.samples[day - 1],
        stagger: Duration(milliseconds: (day - plan.today) * _sampleStaggerMs),
        metrics: metrics,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: plan.summary,
      child: ExcludeSemantics(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int row = 0; row < plan.rows; row++)
              Padding(
                padding: EdgeInsets.only(top: row == 0 ? 0 : gap),
                child: Row(
                  children: <Widget>[
                    for (
                      int column = 0;
                      column < _daysPerWeek;
                      column++
                    ) ...<Widget>[
                      if (column > 0) SizedBox(width: gap),
                      _cell(row * _daysPerWeek + column),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    super.key,
    required this.day,
    required this.state,
    required this.mood,
    required this.sample,
    required this.stagger,
    required this.metrics,
  });

  final int day;
  final _DayState state;
  final Mood mood;
  final Mood? sample;
  final Duration stagger;
  final _CellMetrics metrics;

  Widget? _art(FieldNotesColors colors) {
    final Mood? sampled = sample;
    return switch (state) {
      _DayState.today => _Pop(
        duration: _todayPop,
        delay: _todayPopDelay,
        child: FlowerBloom.forMood(mood, size: metrics.art),
      ),
      _DayState.sample => _Pop(
        duration: _samplePop,
        delay: stagger,
        child: sampled == null
            ? SizedBox.square(
                key: monthRingKey,
                dimension: metrics.ring,
                child: CustomPaint(
                  painter: DashedBorderPainter(
                    color: colors.ink35,
                    radius: metrics.ring / 2,
                    dashLength: 3,
                    dashGap: 2,
                  ),
                ),
              )
            : FlowerBloom.forMood(sampled, size: metrics.art),
      ),
      _DayState.past || _DayState.later => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final BorderRadius radius = BorderRadius.circular(metrics.radius);
    final Widget? art = _art(colors);
    final Widget face = Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: <Widget>[
        if (art != null)
          Center(
            child: Padding(
              padding: EdgeInsets.only(top: metrics.artLift),
              child: art,
            ),
          ),
        Positioned(
          left: metrics.numberLeft,
          top: metrics.numberTop,
          child: Text(
            '$day',
            style: TextStyle(
              fontFamily: TypographyTokens.sans,
              fontSize: metrics.numberSize,
              fontWeight: FontWeight.w600,
              height: 1,
              color: state == _DayState.today ? colors.accentInk : colors.muted,
            ),
          ),
        ),
        if (state == _DayState.today)
          Positioned(
            right: metrics.petalInset,
            top: metrics.petalInset,
            child: _Land(
              child: _Petal(key: monthPetalKey, size: metrics.petal),
            ),
          ),
      ],
    );
    final Widget cell = switch (state) {
      _DayState.today => _Glow(
        delay: _todayGlowDelay,
        period: _todayGlowPeriod,
        active: true,
        borderRadius: radius,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.cardLight,
            border: Border.all(color: Palette.coral, width: _todayBorder),
            borderRadius: radius,
          ),
          child: face,
        ),
      ),
      _DayState.sample => DecoratedBox(
        decoration: BoxDecoration(
          color: colors.cardWarm,
          border: Border.all(color: colors.ink20, width: Shapes.outlineWidth),
          borderRadius: radius,
        ),
        child: face,
      ),
      _DayState.past => DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: colors.ink08, width: Shapes.outlineWidth),
          borderRadius: radius,
        ),
        child: face,
      ),
      _DayState.later => CustomPaint(
        foregroundPainter: DashedBorderPainter(
          color: colors.ink22,
          radius: metrics.radius,
        ),
        child: face,
      ),
    };
    return AnimatedOpacity(
      opacity: switch (state) {
        _DayState.past => _pastOpacity,
        _DayState.later => _laterOpacity,
        _DayState.today || _DayState.sample => 1,
      },
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : _cellFade,
      child: cell,
    );
  }
}

class _Petal extends StatelessWidget {
  const _Petal({super.key, required this.size});

  final Size size;

  @override
  Widget build(BuildContext context) {
    final double width = size.width;
    final double height = size.height;
    final Radius wide = Radius.elliptical(width * 0.6, height * 0.6);
    final Radius narrow = Radius.elliptical(width * 0.4, height * 0.4);
    return SizedBox.fromSize(
      size: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: _petalFill,
          border: Border.all(color: _petalEdge),
          borderRadius: BorderRadius.only(
            topLeft: wide,
            topRight: narrow,
            bottomRight: wide,
            bottomLeft: narrow,
          ),
        ),
      ),
    );
  }
}

class _FillBox extends StatelessWidget {
  const _FillBox({
    required this.plan,
    required this.padding,
    required this.sliderHeight,
    required this.sliderReach,
    required this.onFill,
    required this.label,
    required this.top,
    this.bottom,
  });

  final _MonthPlan plan;
  final EdgeInsets padding;
  final double sliderHeight;
  final double sliderReach;
  final ValueChanged<double> onFill;
  final String label;
  final Widget top;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final Widget? end = bottom;
    return _Glow(
      delay: _boxGlowDelay,
      period: _boxGlowPeriod,
      active: plan.glowing,
      borderRadius: _boxRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.cardWarm,
          border: Border.all(
            color: plan.glowing ? Palette.coral : colors.ink25,
            width: Shapes.outlineWidth,
          ),
          borderRadius: _boxRadius,
        ),
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              ExcludeSemantics(child: top),
              _LookAhead(
                plan: plan,
                label: label,
                height: sliderHeight,
                reach: sliderReach,
                onFill: onFill,
              ),
              if (end != null) ExcludeSemantics(child: end),
            ],
          ),
        ),
      ),
    );
  }
}

class _NudgeIntent extends Intent {
  const _NudgeIntent(this.days);

  final int days;
}

class _EdgeIntent extends Intent {
  const _EdgeIntent({required this.toEnd});

  final bool toEnd;
}

const Map<ShortcutActivator, Intent> _sliderKeys = <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.arrowRight): _NudgeIntent(1),
  SingleActivator(LogicalKeyboardKey.arrowUp): _NudgeIntent(1),
  SingleActivator(LogicalKeyboardKey.arrowLeft): _NudgeIntent(-1),
  SingleActivator(LogicalKeyboardKey.arrowDown): _NudgeIntent(-1),
  SingleActivator(LogicalKeyboardKey.home): _EdgeIntent(toEnd: false),
  SingleActivator(LogicalKeyboardKey.end): _EdgeIntent(toEnd: true),
};

class _LookAhead extends StatelessWidget {
  const _LookAhead({
    required this.plan,
    required this.label,
    required this.height,
    required this.reach,
    required this.onFill,
  });

  final _MonthPlan plan;
  final String label;
  final double height;
  final double reach;
  final ValueChanged<double> onFill;

  void _seek(double dx, double width) {
    final double span = width - _thumbRadius * 2;
    if (!span.isFinite || span <= 0) {
      return;
    }
    onFill(((dx - _thumbRadius) / span).clamp(0.0, 1.0));
  }

  void _nudge(int days) => onFill(plan.fillFor(plan.ahead + days));

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final bool canGrow = plan.fill < 1;
    final bool canShrink = plan.fill > 0;
    return Shortcuts(
      shortcuts: _sliderKeys,
      child: Actions(
        actions: <Type, Action<Intent>>{
          _NudgeIntent: CallbackAction<_NudgeIntent>(
            onInvoke: (_NudgeIntent intent) {
              _nudge(intent.days);
              return null;
            },
          ),
          _EdgeIntent: CallbackAction<_EdgeIntent>(
            onInvoke: (_EdgeIntent intent) {
              onFill(intent.toEnd ? 1 : 0);
              return null;
            },
          ),
        },
        child: Semantics(
          container: true,
          slider: true,
          label: label,
          value: plan.describe(plan.ahead),
          increasedValue: canGrow ? plan.describe(plan.ahead + 1) : null,
          decreasedValue: canShrink
              ? plan.describe(math.max(0, plan.ahead - 1))
              : null,
          onIncrease: canGrow ? () => _nudge(1) : null,
          onDecrease: canShrink ? () => _nudge(-1) : null,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.maxWidth;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: true,
                onTapDown: (TapDownDetails details) =>
                    _seek(details.localPosition.dx, width),
                onHorizontalDragStart: (DragStartDetails details) =>
                    _seek(details.localPosition.dx, width),
                onHorizontalDragUpdate: (DragUpdateDetails details) =>
                    _seek(details.localPosition.dx, width),
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: reach),
                  child: FocusRing(
                    onPressed: null,
                    borderRadius: _sliderFocusRadius,
                    child: SizedBox(
                      key: monthSliderKey,
                      width: width,
                      height: height,
                      child: CustomPaint(
                        painter: _TrackPainter(
                          fraction: plan.fill,
                          track: colors.ink16,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TrackPainter extends CustomPainter {
  const _TrackPainter({required this.fraction, required this.track});

  final double fraction;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const double left = _thumbRadius;
    final double right = size.width - _thumbRadius;
    if (right <= left) {
      return;
    }
    final double centre = size.height / 2;
    const Radius round = Radius.circular(_trackHeight / 2);
    canvas.drawRRect(
      RRect.fromLTRBR(
        left,
        centre - _trackHeight / 2,
        right,
        centre + _trackHeight / 2,
        round,
      ),
      Paint()..color = track,
    );
    final double thumb = left + (right - left) * fraction.clamp(0.0, 1.0);
    canvas.drawRRect(
      RRect.fromLTRBR(
        left,
        centre - _trackHeight / 2,
        thumb,
        centre + _trackHeight / 2,
        round,
      ),
      Paint()..color = Palette.coral,
    );
    canvas.drawCircle(
      Offset(thumb, centre),
      _thumbRadius,
      Paint()..color = Palette.coral,
    );
  }

  @override
  bool shouldRepaint(_TrackPainter oldDelegate) =>
      oldDelegate.fraction != fraction || oldDelegate.track != track;
}

typedef _EntranceFrame = Widget Function(double progress, Widget child);

class _Entrance extends StatefulWidget {
  const _Entrance({
    required this.duration,
    required this.delay,
    required this.frame,
    required this.child,
  });

  final Duration duration;
  final Duration delay;
  final _EntranceFrame frame;
  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.value = 1;
    } else if (_clock.isDismissed) {
      _clock.forward();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  double get _progress {
    final int delay = widget.delay.inMicroseconds;
    final int duration = widget.duration.inMicroseconds;
    final double elapsed = _clock.value * (delay + duration);
    return duration == 0 ? 1 : ((elapsed - delay) / duration).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _clock,
      child: widget.child,
      builder: (BuildContext context, Widget? child) =>
          widget.frame(_progress, child!),
    );
  }
}

class _Rise extends StatelessWidget {
  const _Rise({
    required this.duration,
    this.delay = Duration.zero,
    required this.child,
  });

  final Duration duration;
  final Duration delay;
  final Widget child;

  static Widget _frame(double progress, Widget child) {
    final double eased = Curves.ease.transform(progress);
    return Opacity(
      opacity: eased,
      alwaysIncludeSemantics: true,
      child: Transform.translate(
        offset: Offset(0, _riseDistance * (1 - eased)),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Entrance(
      duration: duration,
      delay: delay,
      frame: _frame,
      child: child,
    );
  }
}

class _Pop extends StatelessWidget {
  const _Pop({
    required this.duration,
    required this.delay,
    required this.child,
  });

  final Duration duration;
  final Duration delay;
  final Widget child;

  static Widget _frame(double progress, Widget child) {
    final bool rising = progress < _popPeak;
    final double eased = rising
        ? _popCurve.transform(progress / _popPeak)
        : _popCurve.transform((progress - _popPeak) / (1 - _popPeak));
    final double scale = rising
        ? _popFrom + (_popOver - _popFrom) * eased
        : _popOver + (1 - _popOver) * eased;
    return Opacity(
      opacity: rising ? eased.clamp(0.0, 1.0) : 1,
      alwaysIncludeSemantics: true,
      child: Transform.scale(scale: scale, child: child),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Entrance(
      duration: duration,
      delay: delay,
      frame: _frame,
      child: child,
    );
  }
}

class _Land extends StatelessWidget {
  const _Land({required this.child});

  final Widget child;

  static Widget _frame(double progress, Widget child) {
    final double eased = _landCurve.transform(progress);
    final double turn = _landFromTurn + (_landRestTurn - _landFromTurn) * eased;
    return Opacity(
      opacity: progress < _landShow
          ? _landCurve.transform(progress / _landShow)
          : 1,
      alwaysIncludeSemantics: true,
      child: Transform.translate(
        offset: _landFrom * (1 - eased),
        child: Transform.rotate(angle: turn * math.pi / 180, child: child),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Entrance(
      duration: _petalLand,
      delay: _petalDelay,
      frame: _frame,
      child: child,
    );
  }
}

class _Glow extends StatefulWidget {
  const _Glow({
    required this.delay,
    required this.period,
    required this.active,
    required this.borderRadius,
    required this.child,
  });

  final Duration delay;
  final Duration period;
  final bool active;
  final BorderRadius borderRadius;
  final Widget child;

  @override
  State<_Glow> createState() => _GlowState();
}

class _GlowState extends State<_Glow> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: widget.delay + widget.period,
  )..addStatusListener(_onStatus);

  bool _still = false;

  double get _delayShare =>
      widget.delay.inMicroseconds /
      (widget.delay + widget.period).inMicroseconds;

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && widget.active && !_still) {
      _clock.repeat(min: _delayShare, max: 1, period: widget.period);
    }
  }

  void _sync() {
    if (_still || !widget.active) {
      _clock.stop();
      return;
    }
    if (!_clock.isAnimating) {
      _clock.forward(from: 0);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
    _sync();
  }

  @override
  void didUpdateWidget(_Glow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      _sync();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  double get _strength {
    if (!widget.active) {
      return 0;
    }
    if (_still) {
      return _restingGlow;
    }
    if (_clock.value < _delayShare) {
      return 0;
    }
    final double phase = (_clock.value - _delayShare) / (1 - _delayShare);
    return phase < 0.5
        ? Curves.ease.transform(phase * 2)
        : 1 - Curves.ease.transform(phase * 2 - 1);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _clock,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double strength = _strength;
        return DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Palette.coral.withValues(alpha: _glowAlpha * strength),
                spreadRadius: _glowSpread * strength,
              ),
            ],
          ),
          child: child,
        );
      },
    );
  }
}
