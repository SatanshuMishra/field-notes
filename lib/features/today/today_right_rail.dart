import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'on_this_day_card.dart';
import 'this_week_garden.dart';
import 'today_capture_buttons.dart';
import 'today_providers.dart';
import 'today_week.dart';

const EdgeInsets todayRailPadding =
    EdgeInsets.symmetric(vertical: 24, horizontal: 20);

const double _railGap = 18;
const double _railRuleThickness = 1;

class TodayRightRail extends ConsumerWidget {
  const TodayRightRail({super.key, required this.date});

  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TodayWeekCell> cells = ref.watch(thisWeekCellsProvider);
    return SingleChildScrollView(
      padding: todayRailPadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          ThisWeekGarden(cells: cells),
          const SizedBox(height: _railGap),
          const TodayRailRule(),
          const SizedBox(height: _railGap),
          TodayCaptureButtons(date: date),
          const SizedBox(height: _railGap),
          const TodayRailRule(),
          const SizedBox(height: _railGap),
          const OnThisDayRailCard(),
        ],
      ),
    );
  }
}

class TodayRailRule extends StatelessWidget {
  const TodayRailRule({super.key});

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: _railRuleThickness,
      child: ColoredBox(color: Palette.ink16),
    );
  }
}
