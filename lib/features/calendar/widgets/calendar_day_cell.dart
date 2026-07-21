import 'package:flutter/widgets.dart';

import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';

import '../model/calendar_month.dart';

class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    super.key,
    required this.cell,
    this.day,
    this.isToday = false,
    this.onTap,
  });

  final CalendarCell cell;
  final Day? day;
  final bool isToday;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    if (cell.isPadding) {
      return const SizedBox.shrink();
    }
    final Mood? mood = day?.mood;
    final bool journaled = day != null;
    return Semantics(
      button: true,
      label: 'Day ${cell.dayOfMonth}',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isToday ? Palette.cardBright : null,
            border: isToday ? Shapes.outline : null,
            borderRadius: Shapes.buttonBorderRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  height: 28,
                  child: mood != null
                      ? FlowerBloom.forMood(mood, size: 28)
                      : (journaled
                          ? const _ActivityDot()
                          : const SizedBox.shrink()),
                ),
                const SizedBox(height: 2),
                Text(
                  '${cell.dayOfMonth}',
                  style: TypographyTokens.captionSans.copyWith(
                    color: journaled ? Palette.ink : Palette.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityDot extends StatelessWidget {
  const _ActivityDot();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 8,
        height: 8,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Palette.sage,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}
