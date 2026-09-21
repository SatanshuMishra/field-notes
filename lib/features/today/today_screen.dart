import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/mood/mood.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'today_date.dart';
import 'today_entry_feed.dart';
import 'today_header.dart';
import 'today_layout.dart';
import 'today_providers.dart';
import 'today_right_rail.dart';

const EdgeInsets _feedEyebrowMargin = EdgeInsets.only(top: 18, bottom: 12);

const double _railSeamThickness = 1.0;

const double todayFeedCacheExtent = 600;

const EdgeInsets _stackedPagePadding = EdgeInsets.all(20);
const EdgeInsets _railPagePadding = EdgeInsets.all(24);

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

    switch (resolved) {
      case TodayLayout.stacked:
        return _scrollView(now: now, date: date, padding: _stackedPagePadding);
      case TodayLayout.withRail:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: _scrollView(
                now: now,
                date: date,
                padding: _railPagePadding,
              ),
            ),
            const DashedDivider(
              axis: Axis.vertical,
              thickness: _railSeamThickness,
              color: Palette.ink22,
            ),
            SizedBox(
              width: todayRailWidth,
              child: TodayRightRail(date: date),
            ),
          ],
        );
    }
  }

  Widget _scrollView({
    required DateTime now,
    required String date,
    required EdgeInsets padding,
  }) {
    return CustomScrollView(
      scrollCacheExtent: const ScrollCacheExtent.pixels(todayFeedCacheExtent),
      slivers: <Widget>[
        SliverPadding(
          padding: padding,
          sliver: SliverMainAxisGroup(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: TodayHeader(
                  greeting: greetingFor(now),
                  longDate: headerDateLabel(now),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(child: MoodBannerForDate(date: date)),
              SliverToBoxAdapter(child: TodayFeedEyebrow(date: date)),
              TodayEntryFeed(date: date),
            ],
          ),
        ),
      ],
    );
  }
}
