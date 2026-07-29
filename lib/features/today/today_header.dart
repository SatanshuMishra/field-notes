import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/widgets.dart';

class TodayHeader extends StatelessWidget {
  const TodayHeader({
    super.key,
    required this.greeting,
    required this.longDate,
  });

  final String greeting;
  final String longDate;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(greeting, style: TypographyTokens.pageEyebrowAccent),
        const SizedBox(height: 1),
        Text(longDate, style: TypographyTokens.displaySerifToday),
      ],
    );
  }
}
