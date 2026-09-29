import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SliverConstraints;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/tokens/tokens.dart';

import '../model/garden_data.dart';
import '../model/garden_motion.dart';
import '../sky/sky_astronomy.dart';
import '../sky/sky_location.dart';
import '../sky/sky_scene.dart';
import '../sky/sky_time.dart';
import 'garden_header.dart';
import 'meadow_scene.dart';
import 'mood_tally_chips.dart';

const double gardenCardMinHeight = 452;
const double gardenCardMinHeightCompact = 320;

const String gardenWaitingMessage =
    'Your meadow is waiting. Every day you journal plants a bloom here.';

const List<String> _shortMonths = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

bool gardenIsCompact(BuildContext context) =>
    resolveShellLayout(Theme.of(context).platform) == ShellLayout.bottomBar;

String gardenMonthCaption(DateTime instant) {
  final DateTime local = instant.toLocal();
  return '${_shortMonths[local.month - 1]} ${local.year} · still growing';
}

String gardenSkyCaption(SkyLocation location, SkyScene scene) =>
    'sky over ${location.placeName} · ${scene.phaseName}';

class GardenPage extends StatelessWidget {
  const GardenPage({
    super.key,
    required this.moment,
    required this.location,
    required this.card,
    this.dayCount,
    this.year,
    this.chips,
    this.debugControls = false,
    this.onNow,
    this.onFastForward,
  });

  final SkyMoment moment;
  final SkyLocation location;
  final Widget card;
  final int? dayCount;
  final int? year;
  final Widget? chips;
  final bool debugControls;
  final VoidCallback? onNow;
  final VoidCallback? onFastForward;

  @override
  Widget build(BuildContext context) {
    final bool compact = gardenIsCompact(context);
    final EdgeInsets padding = compact
        ? const EdgeInsets.fromLTRB(16, 12, 16, 12)
        : const EdgeInsets.fromLTRB(34, 26, 34, 30);
    final double minCard = compact
        ? gardenCardMinHeightCompact
        : gardenCardMinHeight;
    final Widget clock = GardenSkyClock(
      moment: moment,
      compact: compact,
      sunEvent: nextSkyEvent(
        SkyBody.sun,
        moment.instant,
        location.latitude,
        location.longitude,
      ),
      moonEvent: compact
          ? null
          : nextSkyEvent(
              SkyBody.moon,
              moment.instant,
              location.latitude,
              location.longitude,
            ),
      debugControls: debugControls,
      onNow: onNow,
      onFastForward: onFastForward,
    );
    final Widget? tally = chips;
    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: padding,
          sliver: SliverMainAxisGroup(
            slivers: <Widget>[
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    GardenHeader(
                      compact: compact,
                      dayCount: dayCount,
                      year: year,
                      clock: compact ? null : clock,
                    ),
                    if (tally != null)
                      Padding(
                        padding: EdgeInsets.only(bottom: compact ? 10 : 18),
                        child: tally,
                      ),
                    if (compact) clock,
                  ],
                ),
              ),
              SliverLayoutBuilder(
                builder: (BuildContext context, SliverConstraints constraints) {
                  final double remaining =
                      constraints.viewportMainAxisExtent -
                      constraints.precedingScrollExtent -
                      padding.bottom;
                  return SliverToBoxAdapter(
                    child: SizedBox(
                      height: math.max(minCard, remaining),
                      child: card,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class GardenView extends StatelessWidget {
  const GardenView({
    super.key,
    required this.blooms,
    required this.tally,
    required this.year,
    required this.moment,
    required this.location,
    this.sprouts = const <String>[],
    this.motionOverride,
    this.debugControls = false,
    this.onNow,
    this.onFastForward,
  });

  final List<GardenBloomData> blooms;
  final List<MoodTallyEntry> tally;
  final int year;
  final SkyMoment moment;
  final SkyLocation location;
  final List<String> sprouts;
  final GardenMotionProfile? motionOverride;
  final bool debugControls;
  final VoidCallback? onNow;
  final VoidCallback? onFastForward;

  @override
  Widget build(BuildContext context) {
    final bool compact = gardenIsCompact(context);
    final bool empty = blooms.isEmpty && sprouts.isEmpty;
    final SkyScene scene = skySceneAt(
      moment.instant,
      location.latitude,
      location.longitude,
    );
    return GardenPage(
      moment: moment,
      location: location,
      dayCount: blooms.length + sprouts.length,
      year: year,
      debugControls: debugControls,
      onNow: onNow,
      onFastForward: onFastForward,
      chips: empty
          ? null
          : MoodTallyChips(entries: tally, sproutCount: sprouts.length),
      card: _SkyCard(
        compact: compact,
        scene: scene,
        caption: gardenSkyCaption(location, scene),
        monthCaption: compact ? null : gardenMonthCaption(moment.instant),
        waiting: empty,
        meadow: MeadowScene(
          blooms: blooms,
          sprouts: sprouts,
          sky: scene,
          seed: year,
          compact: compact,
          motion: empty ? GardenMotionProfile.reduced : motionOverride,
        ),
      ),
    );
  }
}

class _SkyCard extends StatelessWidget {
  const _SkyCard({
    required this.compact,
    required this.scene,
    required this.caption,
    required this.monthCaption,
    required this.waiting,
    required this.meadow,
  });

  final bool compact;
  final SkyScene scene;
  final String caption;
  final String? monthCaption;
  final bool waiting;
  final Widget meadow;

  @override
  Widget build(BuildContext context) {
    final FieldNotesTextStyles styles = context.textStyles;
    final BorderRadius radius = BorderRadius.all(
      Radius.circular(compact ? 16 : 20),
    );
    final TextStyle captionStyle = styles.pageEyebrowAccent.copyWith(
      fontSize: compact ? 10 : 12,
      color: scene.captionColour,
    );
    final String? month = monthCaption;
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: context.colors.ink22,
          width: Shapes.outlineWidth,
        ),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            meadow,
            if (waiting)
              Align(
                alignment: const Alignment(0, 0.29),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    gardenWaitingMessage,
                    textAlign: TextAlign.center,
                    style: styles.bodySerif.copyWith(
                      color: scene.captionColour,
                    ),
                  ),
                ),
              ),
            if (month != null)
              Positioned(
                left: 16,
                bottom: 12,
                child: Text(month, style: captionStyle),
              ),
            Positioned(
              left: compact ? 12 : null,
              right: compact ? 12 : 16,
              bottom: compact ? 9 : 12,
              child: Text(
                caption,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: captionStyle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
