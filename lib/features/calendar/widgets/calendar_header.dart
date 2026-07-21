import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';

import '../model/calendar_month.dart';
import 'calendar_chevron_button.dart';

class CalendarHeader extends StatelessWidget {
  const CalendarHeader({
    super.key,
    required this.month,
    required this.onPreviousMonth,
    required this.onNextMonth,
  });

  final MonthRef month;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('explore', style: TypographyTokens.eyebrowAccent),
              const SizedBox(height: 2),
              Text(month.title, style: TypographyTokens.titleSerif),
            ],
          ),
        ),
        CalendarChevronButton(
          direction: ChevronDirection.previous,
          semanticLabel: 'Previous month',
          onPressed: onPreviousMonth,
        ),
        const SizedBox(width: 10),
        CalendarChevronButton(
          direction: ChevronDirection.next,
          semanticLabel: 'Next month',
          onPressed: onNextMonth,
        ),
      ],
    );
  }
}
