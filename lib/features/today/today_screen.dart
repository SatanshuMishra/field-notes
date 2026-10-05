import 'package:field_notes/data/sync/engine/sync_engine.dart'
    show FirstPullProgress;
import 'package:field_notes/data/sync/engine/sync_status.dart';
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
import 'today_mood_dock.dart';
import 'today_providers.dart';
import 'today_right_rail.dart';

const EdgeInsets _feedEyebrowMargin = EdgeInsets.only(top: 18, bottom: 12);

const double _railSeamThickness = 1.0;

const double todayFeedCacheExtent = 600;

const EdgeInsets _stackedPagePadding = EdgeInsets.all(20);
const EdgeInsets _railPagePadding = EdgeInsets.all(24);

const EdgeInsets _syncLinesMargin = EdgeInsets.only(top: 12);
const double _syncLineGap = 4;

String firstPullProgressLabel(FirstPullProgress progress) =>
    'Bringing your journal over · ${progress.done} of ${progress.total}';

class TodaySyncLines extends ConsumerWidget {
  const TodaySyncLines({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(syncEnabledProvider).value != true) {
      return const SizedBox.shrink();
    }
    final FirstPullProgress? progress = ref
        .watch(firstPullProgressProvider)
        .value;
    final SyncStatus? status = defaultTargetPlatform == TargetPlatform.android
        ? ref.watch(syncStatusProvider).value
        : null;
    final FieldNotesTextStyles textStyles = context.textStyles;
    final FieldNotesColors colors = context.colors;
    final List<Widget> lines = <Widget>[
      if (status is AttentionStatus) ...<Widget>[
        Text(
          status.label(DateTime.now().toUtc()),
          style: textStyles.labelSans.copyWith(color: colors.dangerInk),
        ),
        if (status.fix case final String fix)
          Text(
            fix,
            style: textStyles.captionSans.copyWith(color: colors.muted),
          ),
      ],
      if (progress != null)
        Text(
          firstPullProgressLabel(progress),
          style: textStyles.captionSans.copyWith(color: colors.accentInk),
        ),
    ];
    if (lines.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: _syncLinesMargin,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (int index = 0; index < lines.length; index++) ...<Widget>[
            if (index > 0) const SizedBox(height: _syncLineGap),
            lines[index],
          ],
        ],
      ),
    );
  }
}

String todayFeedEyebrowLabel(int count) =>
    'today · $count log${count == 1 ? '' : 's'}';

class TodayFeedEyebrow extends ConsumerWidget {
  const TodayFeedEyebrow({super.key, required this.date});

  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<Entry>> entriesAsync = ref.watch(
      entriesForDateProvider(date),
    );
    final bool counted = entriesAsync.hasValue && !entriesAsync.hasError;
    return Padding(
      padding: _feedEyebrowMargin,
      child: counted
          ? Text(
              todayFeedEyebrowLabel(entriesAsync.requireValue.length),
              style: context.textStyles.sectionHeaderAccent,
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
        final double gestureBar = MediaQuery.viewPaddingOf(context).bottom;
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            _scrollView(
              now: now,
              date: date,
              padding: _stackedPagePadding.copyWith(
                top:
                    _stackedPagePadding.top + MediaQuery.paddingOf(context).top,
                bottom: gestureBar + todayMoodDockFeedClearance,
              ),
              inlineMood: false,
            ),
            Positioned(
              left: todayMoodDockSideInset,
              right: todayMoodDockSideInset,
              bottom: gestureBar + todayMoodDockLift,
              child: const TodayMoodDock(),
            ),
          ],
        );
      case TodayLayout.withRail:
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(
              child: _scrollView(
                now: now,
                date: date,
                padding: _railPagePadding,
                inlineMood: true,
              ),
            ),
            DashedDivider(
              axis: Axis.vertical,
              thickness: _railSeamThickness,
              color: context.colors.ink22,
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
    required bool inlineMood,
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
              const SliverToBoxAdapter(child: TodaySyncLines()),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              if (inlineMood)
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
