import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'on_this_day_card.dart';
import 'this_week_garden.dart';
import 'today_capture_buttons.dart';
import 'today_providers.dart';
import 'today_week.dart';

class TodayRightRail extends ConsumerWidget {
  const TodayRightRail({super.key, required this.date});

  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<TodayWeekCell> cells = ref.watch(thisWeekCellsProvider);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        ThisWeekGarden(cells: cells),
        const SizedBox(height: 16),
        TodayCaptureButtons(date: date),
        const SizedBox(height: 16),
        const OnThisDayRailCard(),
      ],
    );
  }
}
