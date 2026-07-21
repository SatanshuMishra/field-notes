import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/day_detail.dart';
import 'package:field_notes/state/journal_providers.dart';

import 'model/calendar_month.dart';
import 'widgets/calendar_grid.dart';
import 'widgets/calendar_header.dart';

typedef OpenDayDetail = Future<void> Function(
  BuildContext context, {
  required String date,
});

const String calendarLoadingMessage = 'Opening your calendar…';
const String calendarErrorMessage =
    'Your calendar could not be loaded right now.';

class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({
    super.key,
    this.initialMonth,
    this.today,
    this.firstWeekday = DateTime.sunday,
    this.onOpenDay = showDayDetail,
  });

  final MonthRef? initialMonth;
  final DateTime? today;
  final int firstWeekday;
  final OpenDayDetail onOpenDay;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late MonthRef _month =
      widget.initialMonth ?? MonthRef.forDate(widget.today ?? DateTime.now());

  void _showPreviousMonth() => setState(() => _month = _month.previous);

  void _showNextMonth() => setState(() => _month = _month.next);

  void _openDay(String date) {
    widget.onOpenDay(context, date: date);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<Day>> daysAsync = ref.watch(
      daysInMonthProvider(year: _month.year, month: _month.month),
    );
    final DateTime today = widget.today ?? DateTime.now();
    final String todayKey = MonthRef.forDate(today).dateKey(today.day);
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          CalendarHeader(
            month: _month,
            onPreviousMonth: _showPreviousMonth,
            onNextMonth: _showNextMonth,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: daysAsync.when(
              data: (List<Day> days) => CalendarGrid(
                month: _month,
                daysByDate: <String, Day>{
                  for (final Day day in days) day.date: day,
                },
                firstWeekday: widget.firstWeekday,
                todayKey: todayKey,
                onSelectDay: _openDay,
              ),
              loading: () =>
                  const _CalendarMessage(text: calendarLoadingMessage),
              error: (Object error, StackTrace stackTrace) =>
                  const _CalendarError(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarMessage extends StatelessWidget {
  const _CalendarMessage({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(text, style: TypographyTokens.captionSans),
    );
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
