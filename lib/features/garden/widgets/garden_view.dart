import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SliverConstraints;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/flowers/garden_art_colors.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/garden/model/meadow_view_state.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_palette.dart';
import 'package:field_notes/features/garden/scene/meadow_stage.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/scene/meadow_world.dart';
import 'package:field_notes/features/garden/widgets/meadow_header.dart';
import 'package:field_notes/features/garden/widgets/meadow_study_controls.dart';
import 'package:field_notes/features/garden/widgets/meadow_tabs.dart';
import 'package:field_notes/features/garden/widgets/meadow_year_picker.dart';

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

const String meadowWaitingMessage =
    'Your meadow is waiting. Every day you journal plants a bloom here.';
const double meadowSceneAspectRatio = meadowWorldWidth / meadowWorldHeight;
const double meadowCompactSceneHeight = 300;

const EdgeInsets _sidebarPagePadding = EdgeInsets.fromLTRB(34, 26, 34, 30);
const EdgeInsets _compactPagePadding = EdgeInsets.fromLTRB(16, 12, 16, 12);
const double _sceneGap = 16;
const double _sidebarSceneRadius = 20;
const double _compactSceneRadius = 16;
const Offset _insetShadowOffset = Offset(0, 3);
const double _insetShadowBlur = 14;
const int _insetShadowAlpha = 0x1F;
const Alignment _waitingAlignment = Alignment(0, 0.29);
const EdgeInsets _waitingPadding = EdgeInsets.symmetric(horizontal: 24);

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
          motion: motionOverride,
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
      color: GardenArtColors.soilCaption,
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

bool meadowIsCompact(BuildContext context) =>
    resolveShellLayout(Theme.of(context).platform) == ShellLayout.bottomBar;

DateTime _todayAt(DateTime today, int minutes) {
  final DateTime local = today.toLocal();
  return DateTime(
    local.year,
    local.month,
    local.day,
    minutes ~/ 60,
    minutes % 60,
  );
}

class MeadowPage extends StatefulWidget {
  const MeadowPage({
    super.key,
    required this.year,
    required this.years,
    required this.currentYear,
    required this.seed,
    required this.moment,
    required this.today,
    required this.location,
    required this.onPickYear,
    required this.onBack,
    required this.onFullScreen,
    this.debugControls = false,
    this.onNow,
    this.onFastForward,
    this.motion,
  });

  final MeadowYear year;
  final List<MeadowYear> years;
  final int currentYear;
  final int seed;
  final SkyMoment moment;
  final DateTime today;
  final SkyLocation location;
  final ValueChanged<int> onPickYear;
  final VoidCallback onBack;
  final ValueChanged<MeadowFullScreenRequest> onFullScreen;
  final bool debugControls;
  final VoidCallback? onNow;
  final VoidCallback? onFastForward;
  final GardenMotionProfile? motion;

  bool get isCurrentYear => year.year == currentYear;

  @override
  State<MeadowPage> createState() => _MeadowPageState();
}

class _MeadowPageState extends State<MeadowPage> {
  MeadowRange? _highlight;
  int? _hourMinutes;
  int? _growthPoint;
  bool _growAnimated = false;

  @override
  void didUpdateWidget(MeadowPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.year.year != widget.year.year) {
      _highlight = null;
      _hourMinutes = null;
      _growthPoint = null;
      _growAnimated = false;
    }
  }

  void _setHighlight(MeadowRange? range) {
    setState(() => _highlight = range);
  }

  void _setHour(int? minutes) {
    setState(() => _hourMinutes = minutes);
  }

  void _setGrowth(int point, bool growAnimated) {
    setState(() {
      _growthPoint = point;
      _growAnimated = growAnimated;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool compact = meadowIsCompact(context);
    final MeadowYear year = widget.year;
    final bool current = widget.isCurrentYear;
    final SkyLocation location = widget.location;
    final SkyMoment moment = widget.moment;
    final int? hour = current ? null : _hourMinutes;
    final int growthPoint = current ? year.limit : _growthPoint ?? year.limit;
    final DateTime instant = hour == null
        ? moment.instant
        : _todayAt(widget.today, hour);
    final SkyScene sky = skySceneAt(
      instant,
      location.latitude,
      location.longitude,
    );
    final bool morning =
        sunPosition(instant, location.latitude, location.longitude).azimuth < 0;
    final MeadowSceneMode mode = current
        ? MeadowSceneMode.page
        : MeadowSceneMode.study;
    final Widget? clock = current
        ? GardenSkyClock(
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
            debugControls: widget.debugControls,
            onNow: widget.onNow,
            onFastForward: widget.onFastForward,
          )
        : null;
    final bool empty = year.blooms + year.sprouts == 0;
    return _MeadowPageLayout(
      compact: compact,
      header: MeadowHeader(
        compact: compact,
        mode: mode,
        year: year.year,
        blooms: year.blooms,
        sprouts: year.sprouts,
        weather: year.weather,
        onBack: current ? null : widget.onBack,
        controls: MeadowHeaderControls(
          compact: compact,
          clock: clock,
          picker: MeadowYearPicker(
            years: widget.years,
            openYear: year.year,
            onPick: widget.onPickYear,
            compact: compact,
          ),
          onFullScreen: () => widget.onFullScreen(
            MeadowFullScreenRequest(
              year: year.year,
              hourMinutes: hour,
              growthPoint: growthPoint,
            ),
          ),
        ),
      ),
      study: current
          ? null
          : MeadowStudyControls(
              compact: compact,
              hourMinutes: hour,
              onHour: _setHour,
              limit: year.limit,
              daysInYear: year.daysInYear,
              year: year.year,
              growthPoint: growthPoint,
              onGrowth: _setGrowth,
              moment: hour == null ? moment : SkyMoment(instant: instant),
              debugControls: widget.debugControls,
              onNow: widget.onNow,
            ),
      scene: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MeadowStage(
            year: year,
            seed: widget.seed,
            sky: sky,
            morning: morning,
            mode: mode,
            compact: compact,
            growthPoint: current ? null : growthPoint,
            growAnimated: _growAnimated,
            highlight: _highlight,
            motion: widget.motion,
          ),
          if (empty)
            _WaitingMessage(
              colour: MeadowPalette.from(
                sky: sky,
                morning: morning,
                heavyShare: year.heavyShare,
              ).captionColour,
            ),
        ],
      ),
      tabs: MeadowTabs(
        year: year,
        isCurrentYear: current,
        compact: compact,
        growthPoint: growthPoint,
        highlight: _highlight,
        onHighlight: _setHighlight,
      ),
    );
  }
}

class MeadowPageNotice extends StatelessWidget {
  const MeadowPageNotice({
    super.key,
    required this.year,
    required this.study,
    required this.child,
  });

  final int year;
  final bool study;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool compact = meadowIsCompact(context);
    return _MeadowPageLayout(
      compact: compact,
      header: _NoticeHeader(compact: compact, year: year, study: study),
      scene: child,
    );
  }
}

class _MeadowPageLayout extends StatelessWidget {
  const _MeadowPageLayout({
    required this.compact,
    required this.header,
    required this.scene,
    this.study,
    this.tabs,
  });

  final bool compact;
  final Widget header;
  final Widget scene;
  final Widget? study;
  final Widget? tabs;

  @override
  Widget build(BuildContext context) {
    final Widget card = _SceneCard(compact: compact, child: scene);
    final Widget? panel = tabs;
    return SingleChildScrollView(
      padding: compact ? _compactPagePadding : _sidebarPagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          header,
          ?study,
          if (compact)
            SizedBox(height: meadowCompactSceneHeight, child: card)
          else
            AspectRatio(aspectRatio: meadowSceneAspectRatio, child: card),
          if (panel != null) ...<Widget>[
            const SizedBox(height: _sceneGap),
            panel,
          ],
        ],
      ),
    );
  }
}

class _SceneCard extends StatelessWidget {
  const _SceneCard({required this.compact, required this.child});

  final bool compact;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final Radius corner = Radius.circular(
      compact ? _compactSceneRadius : _sidebarSceneRadius,
    );
    final BorderRadius radius = BorderRadius.all(corner);
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(color: colors.ink22, width: Shapes.outlineWidth),
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: ColoredBox(
          color: colors.cardWarm,
          child: compact
              ? child
              : CustomPaint(
                  painter: _InsetShadowPainter(
                    colour: colors.shadowTint(_insetShadowAlpha),
                    corner: corner,
                  ),
                  child: child,
                ),
        ),
      ),
    );
  }
}

class _InsetShadowPainter extends CustomPainter {
  const _InsetShadowPainter({required this.colour, required this.corner});

  final Color colour;
  final Radius corner;

  @override
  void paint(Canvas canvas, Size size) {
    final RRect inner = RRect.fromRectAndRadius(Offset.zero & size, corner);
    final double sigma = Shadow.convertRadiusToSigma(_insetShadowBlur);
    canvas.save();
    canvas.clipRRect(inner);
    canvas.drawPath(
      Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(inner.outerRect.inflate(_insetShadowBlur * 3))
        ..addRRect(inner.shift(_insetShadowOffset)),
      Paint()
        ..color = colour
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, sigma),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_InsetShadowPainter oldDelegate) =>
      oldDelegate.colour != colour || oldDelegate.corner != corner;
}

class _WaitingMessage extends StatelessWidget {
  const _WaitingMessage({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: _waitingAlignment,
      child: Padding(
        padding: _waitingPadding,
        child: IgnorePointer(
          child: Text(
            meadowWaitingMessage,
            textAlign: TextAlign.center,
            style: context.textStyles.bodySerif.copyWith(color: colour),
          ),
        ),
      ),
    );
  }
}

class _NoticeHeader extends StatelessWidget {
  const _NoticeHeader({
    required this.compact,
    required this.year,
    required this.study,
  });

  final bool compact;
  final int year;
  final bool study;

  @override
  Widget build(BuildContext context) {
    final FieldNotesTextStyles styles = context.textStyles;
    final String kicker = study ? 'meadow study' : 'your meadow';
    final String title = study ? 'Your meadow, $year' : 'Every day, a bloom';
    return Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(2, 4, 2, 9)
          : const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            kicker,
            style: compact
                ? styles.pageEyebrowAccent.copyWith(fontSize: 14)
                : styles.pageEyebrowAccent,
          ),
          Semantics(
            header: true,
            child: Text(
              title,
              style: compact
                  ? styles.headlineSerif.copyWith(height: 1.05)
                  : styles.displaySerif,
            ),
          ),
        ],
      ),
    );
  }
}
