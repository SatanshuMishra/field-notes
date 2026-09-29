import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/day_detail/day_detail.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show isTextInputFocused;
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:field_notes/state/shell_navigation.dart';

import 'model/calendar_month.dart';
import 'widgets/calendar_grid.dart';
import 'widgets/calendar_header.dart';
import 'widgets/month_picker_route.dart';

typedef OpenDayDetail =
    Future<void> Function(BuildContext context, {required String date});

const String calendarLoadingMessage = 'Opening your calendar…';
const String calendarErrorMessage =
    'Your calendar could not be loaded right now.';

const Key calendarTitleKey = Key('calendar-title');
const Key calendarThisWeekKey = Key('calendar-this-week');
const Key calendarPickerKey = Key('calendar-month-picker');

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({
    super.key,
    this.initialMonth,
    this.today,
    this.firstWeekday,
    this.onOpenDay = showDayDetail,
    this.onOpenToday,
  });

  final MonthRef? initialMonth;
  final DateTime? today;
  final int? firstWeekday;
  final OpenDayDetail onOpenDay;
  final VoidCallback? onOpenToday;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late MonthRef _month = widget.initialMonth ?? MonthRef.forDate(_today);
  final FocusNode _focusNode = FocusNode(debugLabel: 'calendar');
  final FocusNode _titleFocusNode = FocusNode(debugLabel: 'calendar title');
  final LayerLink _pickerLink = LayerLink();

  DateTime get _today => widget.today ?? DateTime.now();

  MonthRef get _currentMonth => MonthRef.forDate(_today);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _showMonth(MonthRef month) {
    setState(() => _month = month);
  }

  void _showPreviousMonth() => _showMonth(_month.previous);

  void _showNextMonth() => _showMonth(_month.next);

  void _showCurrentMonth() => _showMonth(_currentMonth);

  Future<void> _openPicker() async {
    if (ModalRoute.isCurrentOf(context) == false) {
      return;
    }
    final FocusNode returnFocus = _titleFocusNode.hasPrimaryFocus
        ? _titleFocusNode
        : _focusNode;
    final MonthRef? picked = await showCalendarMonthPicker(
      context,
      titleLink: _pickerLink,
      displayedMonth: _month,
      currentMonth: _currentMonth,
      pickerKey: calendarPickerKey,
    );
    if (!mounted) {
      return;
    }
    if (picked != null) {
      _showMonth(picked);
    }
    returnFocus.requestFocus();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || !_acceptsShortcuts()) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowLeft) {
      _showPreviousMonth();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _showNextMonth();
      return KeyEventResult.handled;
    }
    if (event is KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    if (key == LogicalKeyboardKey.keyT) {
      _showCurrentMonth();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  bool _acceptsShortcuts() {
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    if (keyboard.isShiftPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isMetaPressed) {
      return false;
    }
    if (ModalRoute.of(context)?.isCurrent == false) {
      return false;
    }
    return !isTextInputFocused();
  }

  void _selectDay(String date, {required String todayKey}) {
    if (date == todayKey) {
      _openToday();
      return;
    }
    widget.onOpenDay(context, date: date);
  }

  void _openToday() {
    final VoidCallback? onOpenToday = widget.onOpenToday;
    if (onOpenToday != null) {
      onOpenToday();
      return;
    }
    ref.read(shellNavigationProvider.notifier).select(ShellDestination.today);
  }

  int _firstWeekday() {
    final int? firstWeekday = widget.firstWeekday;
    if (firstWeekday != null) {
      return firstWeekday;
    }
    return switch (ref.watch(weekStartProvider)) {
      WeekStart.sunday => DateTime.sunday,
      WeekStart.monday => DateTime.monday,
      WeekStart.saturday => DateTime.saturday,
    };
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Day>> daysAsync = ref.watch(
      daysInMonthProvider(year: _month.year, month: _month.month),
    );
    final Set<String> journaledDates =
        ref.watch(journaledDatesProvider).value?.toSet() ?? const <String>{};
    final DateTime today = _today;
    final String todayKey = MonthRef.forDate(today).dateKey(today.day);
    final int firstWeekday = _firstWeekday();
    return Focus(
      focusNode: _focusNode,
      skipTraversal: true,
      onKeyEvent: _handleKey,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          20,
          20,
          20 - calendarHeaderTrailingReach,
          20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            CalendarHeader(
              month: _month,
              currentMonth: _currentMonth,
              onPreviousMonth: _showPreviousMonth,
              onNextMonth: _showNextMonth,
              onShowCurrentMonth: _showCurrentMonth,
              onOpenPicker: _openPicker,
              titleKey: calendarTitleKey,
              thisWeekKey: calendarThisWeekKey,
              pickerLink: _pickerLink,
              titleFocusNode: _titleFocusNode,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(
                  right: calendarHeaderTrailingReach,
                ),
                child: daysAsync.when(
                  data: (List<Day> days) => CalendarGrid(
                    month: _month,
                    daysByDate: <String, Day>{
                      for (final Day day in days) day.date: day,
                    },
                    firstWeekday: firstWeekday,
                    todayKey: todayKey,
                    journaledDates: journaledDates,
                    onSelectDay: (String date) =>
                        _selectDay(date, todayKey: todayKey),
                  ),
                  loading: () =>
                      const _CalendarMessage(text: calendarLoadingMessage),
                  error: (Object error, StackTrace stackTrace) =>
                      const _CalendarError(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CalendarMessage extends StatelessWidget {
  const _CalendarMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(text, style: TypographyTokens.captionSans));
  }
}

class _CalendarError extends StatelessWidget {
  const _CalendarError();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: EmptyStatePlaceholder(
          message: calendarErrorMessage,
          messageStyle: TypographyTokens.bodySerif,
        ),
      ),
    );
  }
}
