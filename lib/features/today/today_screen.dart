import 'package:field_notes/features/mood/mood.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'today_date.dart';
import 'today_entry_feed.dart';
import 'today_header.dart';
import 'today_layout.dart';
import 'today_providers.dart';
import 'today_right_rail.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key, this.layout});

  final TodayLayout? layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime now = ref.watch(todayClockProvider)();
    final String date = ref.watch(todayDateProvider);
    final TodayLayout resolved =
        layout ?? resolveTodayLayout(defaultTargetPlatform);

    final Widget main = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TodayHeader(greeting: greetingFor(now), longDate: longDateLabel(now)),
        const SizedBox(height: 20),
        MoodBannerForDate(date: date),
        const SizedBox(height: 20),
        TodayEntryFeed(date: date),
      ],
    );

    switch (resolved) {
      case TodayLayout.stacked:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: main,
        );
      case TodayLayout.withRail:
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: main),
              const SizedBox(width: 24),
              SizedBox(
                width: todayRailWidth,
                child: TodayRightRail(date: date),
              ),
            ],
          ),
        );
    }
  }
}
