import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';

class CalendarWeekdayBar extends StatelessWidget {
  const CalendarWeekdayBar({super.key, required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        for (final String label in labels)
          Expanded(
            child: Center(
              child: Text(label, style: TypographyTokens.captionSans),
            ),
          ),
      ],
    );
  }
}
