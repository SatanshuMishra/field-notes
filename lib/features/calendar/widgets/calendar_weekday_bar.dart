import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';

const double calendarRowPadding = 5;
const double calendarColumnGap = 8;

class CalendarWeekdayBar extends StatelessWidget {
  const CalendarWeekdayBar({super.key, required this.labels});

  final List<String> labels;

  static const TextStyle _labelStyle = TextStyle(
    fontFamily: TypographyTokens.sans,
    fontSize: 10,
    fontWeight: FontWeight.w600,
    letterSpacing: 1,
    color: Palette.muted,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: calendarRowPadding),
      child: Row(
        children: <Widget>[
          for (int index = 0; index < labels.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(width: calendarColumnGap),
            Expanded(
              child: Center(child: Text(labels[index], style: _labelStyle)),
            ),
          ],
        ],
      ),
    );
  }
}
