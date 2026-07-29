import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/mood/mood.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'today_date.dart';
import 'today_entry_feed.dart';
import 'today_header.dart';
import 'today_layout.dart';
import 'today_providers.dart';
import 'today_right_rail.dart';

const EdgeInsets _feedEyebrowMargin = EdgeInsets.only(top: 18, bottom: 12);

String todayFeedEyebrowLabel(int count) =>
    'today · $count log${count == 1 ? '' : 's'}';

class TodayFeedEyebrow extends ConsumerWidget {
  const TodayFeedEyebrow({super.key, required this.date});

  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Entry>> entriesAsync =
        ref.watch(entriesForDateProvider(date));
    final bool counted = entriesAsync.hasValue && !entriesAsync.hasError;
    return Padding(
      padding: _feedEyebrowMargin,
      child: counted
          ? Text(
              todayFeedEyebrowLabel(entriesAsync.requireValue.length),
              style: TypographyTokens.sectionHeaderAccent,
            )
          : const SizedBox.shrink(),
    );
  }
}

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
        TodayFeedEyebrow(date: date),
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
