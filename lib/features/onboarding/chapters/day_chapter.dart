import 'dart:math' as math;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/flowers/flower_bloom.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/interaction/hover_fill.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/onboarding/chapters/garden_scene.dart';
import 'package:field_notes/features/onboarding/onboarding_controller.dart';
import 'package:field_notes/features/onboarding/onboarding_frame.dart';
import 'package:field_notes/features/onboarding/onboarding_swipe.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _kicker = 'a day';
const String _title = 'Every feeling grows its own flower.';
const String _subtitle = 'There are ten. Pick the one that fits today.';

const Key dayHeadingKey = ValueKey<String>('day-heading');
const Key dayMoodGridKey = ValueKey<String>('day-mood-grid');
const Key dayCardKey = gardenStakeKey;

Key dayMoodKey(Mood mood) => ValueKey<String>('day-mood-${mood.id}');

const double _tileBorder = 2;
const double _tileInset = 4;

const Duration _headingDelay = Duration(milliseconds: 600);
const Duration _headingRise = Duration(milliseconds: 600);
const Duration _tilesDelay = Duration(milliseconds: 900);
const Duration _tilesRise = Duration(milliseconds: 600);
const Duration _tileShift = Duration(milliseconds: 150);

const double _riseDistance = 14;

@immutable
class _DayMetrics {
  const _DayMetrics({
    required this.centred,
    required this.headingTop,
    required this.headingSide,
    required this.kickerSize,
    required this.titleSize,
    required this.titleHeight,
    required this.subtitleSize,
    required this.subtitleHeight,
    required this.subtitleGap,
    required this.tilesBottom,
    required this.tilesSide,
    required this.tileWidth,
    required this.tileHeight,
    required this.tileGap,
    required this.columns,
    required this.tileRadius,
    required this.flower,
    required this.labelGap,
    required this.labelSize,
  });

  static const _DayMetrics sidebar = _DayMetrics(
    centred: true,
    headingTop: onboardingTitleTop + 2,
    headingSide: 40,
    kickerSize: 21,
    titleSize: 44,
    titleHeight: 1.05,
    subtitleSize: 15,
    subtitleHeight: 1.5,
    subtitleGap: 8,
    tilesBottom: 74,
    tilesSide: 0,
    tileWidth: 76,
    tileHeight: 88,
    tileGap: 8,
    columns: 10,
    tileRadius: 16,
    flower: 40,
    labelGap: 6,
    labelSize: 11.5,
  );

  static const _DayMetrics bottomBar = _DayMetrics(
    centred: false,
    headingTop: onboardingPhoneTitleTop,
    headingSide: 20,
    kickerSize: 18,
    titleSize: 28,
    titleHeight: 1.08,
    subtitleSize: 13.5,
    subtitleHeight: 1.45,
    subtitleGap: 6,
    tilesBottom: onboardingControlBarReserve + 8,
    tilesSide: 12,
    tileWidth: null,
    tileHeight: 72,
    tileGap: 7,
    columns: 5,
    tileRadius: 14,
    flower: 34,
    labelGap: 4,
    labelSize: 10.5,
  );

  static _DayMetrics of(ShellLayout layout) => switch (layout) {
    ShellLayout.sidebar => sidebar,
    ShellLayout.bottomBar => bottomBar,
  };

  final bool centred;
  final double headingTop;
  final double headingSide;
  final double kickerSize;
  final double titleSize;
  final double titleHeight;
  final double subtitleSize;
  final double subtitleHeight;
  final double subtitleGap;
  final double tilesBottom;
  final double tilesSide;
  final double? tileWidth;
  final double tileHeight;
  final double tileGap;
  final int columns;
  final double tileRadius;
  final double flower;
  final double labelGap;
  final double labelSize;
}

class DayChapter extends ConsumerWidget {
  const DayChapter({super.key, required this.layout});

  final ShellLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingFlow flow = ref.watch(onboardingControllerProvider);
    if (flow is! OnboardingFlowRunning) {
      return const SizedBox.expand();
    }
    final Mood mood = flow.draft.mood;
    final OnboardingController controller = ref.read(
      onboardingControllerProvider.notifier,
    );
    final _DayMetrics metrics = _DayMetrics.of(layout);
    final EdgeInsets insets = layout == ShellLayout.bottomBar
        ? MediaQuery.paddingOf(context)
        : EdgeInsets.zero;
    final double gesture = layout == ShellLayout.bottomBar
        ? _gestureInset(context)
        : 0;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned(
          left: metrics.headingSide,
          right: metrics.headingSide,
          top: insets.top + metrics.headingTop,
          child: OnboardingSwipeLayer(
            child: _Rise(
              delay: _headingDelay,
              duration: _headingRise,
              child: _Heading(key: dayHeadingKey, metrics: metrics),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: gesture + metrics.tilesBottom,
          child: OnboardingSwipeLayer(
            child: _Rise(
              delay: _tilesDelay,
              duration: _tilesRise,
              child: _MoodTiles(
                key: dayMoodGridKey,
                metrics: metrics,
                selected: mood,
                onChoose: controller.chooseMood,
              ),
            ),
          ),
        ),
      ],
    );
  }

  double _gestureInset(BuildContext context) {
    final MediaQueryData media = MediaQuery.of(context);
    return math.max(media.padding.bottom, media.viewPadding.bottom);
  }
}

class _Heading extends StatelessWidget {
  const _Heading({super.key, required this.metrics});

  final _DayMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final TextAlign align = metrics.centred
        ? TextAlign.center
        : TextAlign.start;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: metrics.centred
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _kicker,
          textAlign: align,
          style: TextStyle(
            fontFamily: TypographyTokens.accent,
            fontSize: metrics.kickerSize,
            fontWeight: FontWeight.w600,
            color: colors.accentInk,
          ),
        ),
        Semantics(
          header: true,
          child: Text(
            _title,
            textAlign: align,
            style: TextStyle(
              fontFamily: TypographyTokens.serif,
              fontSize: metrics.titleSize,
              fontWeight: FontWeight.w500,
              height: metrics.titleHeight,
              color: colors.ink,
            ),
          ),
        ),
        SizedBox(height: metrics.subtitleGap),
        Text(
          _subtitle,
          textAlign: align,
          style: TextStyle(
            fontFamily: TypographyTokens.sans,
            fontSize: metrics.subtitleSize,
            fontWeight: FontWeight.w400,
            height: metrics.subtitleHeight,
            color: colors.mutedDeep,
          ),
        ),
      ],
    );
  }
}

class _MoodTiles extends StatelessWidget {
  const _MoodTiles({
    super.key,
    required this.metrics,
    required this.selected,
    required this.onChoose,
  });

  final _DayMetrics metrics;
  final Mood selected;
  final ValueChanged<Mood> onChoose;

  Widget _tile(Mood mood) => _MoodTile(
    mood: mood,
    selected: mood == selected,
    metrics: metrics,
    onTap: () => onChoose(mood),
  );

  double _widestLabel(BuildContext context) {
    final TextStyle style = DefaultTextStyle.of(context).style
        .merge(_labelStyle(metrics, context.colors.ink));
    final TextScaler scaler = MediaQuery.textScalerOf(context);
    final TextDirection direction = Directionality.of(context);
    return moodOrder.fold(0.0, (double widest, Mood mood) {
      final TextPainter painter = TextPainter(
        text: TextSpan(text: mood.label, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final double width = painter.width;
      painter.dispose();
      return math.max(widest, width);
    });
  }

  @override
  Widget build(BuildContext context) {
    final double needed =
        _widestLabel(context).ceilToDouble() + 2 * (_tileBorder + _tileInset);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints area) {
        final _TileGrid grid = _TileGrid.fit(
          metrics: metrics,
          room: area.maxWidth - 2 * metrics.tilesSide,
          needed: needed,
        );
        final List<List<Mood>> rows = <List<Mood>>[
          for (int start = 0; start < moodOrder.length; start += grid.columns)
            moodOrder.skip(start).take(grid.columns).toList(),
        ];
        final Widget tiles = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: metrics.centred
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: <Widget>[
            for (final (int row, List<Mood> moods) in rows.indexed) ...<Widget>[
              if (row > 0) SizedBox(height: metrics.tileGap),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final (int column, Mood mood)
                      in moods.indexed) ...<Widget>[
                    if (column > 0) SizedBox(width: metrics.tileGap),
                    SizedBox(width: grid.tileWidth, child: _tile(mood)),
                  ],
                ],
              ),
            ],
          ],
        );
        final EdgeInsets side = EdgeInsets.symmetric(
          horizontal: metrics.tilesSide,
        );
        return grid.scrolls
            ? NoSwipe(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: side,
                  child: tiles,
                ),
              )
            : Padding(padding: side, child: tiles);
      },
    );
  }
}

@immutable
class _TileGrid {
  const _TileGrid({
    required this.columns,
    required this.tileWidth,
    required this.scrolls,
  });

  factory _TileGrid.fit({
    required _DayMetrics metrics,
    required double room,
    required double needed,
  }) {
    double spanOf(int columns, double width) =>
        columns * width + (columns - 1) * metrics.tileGap;
    final double? fixed = metrics.tileWidth;
    if (fixed == null) {
      final int columns = metrics.columns;
      final double share = (room - (columns - 1) * metrics.tileGap) / columns;
      return share >= needed
          ? _TileGrid(columns: columns, tileWidth: share, scrolls: false)
          : _TileGrid(columns: columns, tileWidth: needed, scrolls: true);
    }
    final double width = math.max(fixed, needed);
    int columns = metrics.columns;
    while (columns > 1 && spanOf(columns, width) > room) {
      columns--;
    }
    return _TileGrid(columns: columns, tileWidth: width, scrolls: false);
  }

  final int columns;
  final double tileWidth;
  final bool scrolls;
}

TextStyle _labelStyle(_DayMetrics metrics, Color color) => TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: metrics.labelSize,
  fontWeight: FontWeight.w600,
  color: color,
);

class _MoodTile extends StatelessWidget {
  const _MoodTile({
    required this.mood,
    required this.selected,
    required this.metrics,
    required this.onTap,
  });

  final Mood mood;
  final bool selected;
  final _DayMetrics metrics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final BorderRadius radius = BorderRadius.circular(metrics.tileRadius);
    final Widget face = AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : _tileShift,
      constraints: BoxConstraints(minHeight: metrics.tileHeight),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? colors.cardLight : colors.cardWarm,
        border: Border.all(
          color: selected ? Palette.coral : colors.ink18,
          width: _tileBorder,
        ),
        borderRadius: radius,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: selected
                ? colors.shadow
                : colors.shadow.withValues(alpha: 0),
            offset: const Offset(2, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: _tileInset),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FlowerBloom.forMood(mood, size: metrics.flower),
            SizedBox(height: metrics.labelGap),
            Text(
              mood.label,
              maxLines: 1,
              softWrap: false,
              style: _labelStyle(
                metrics,
                selected ? colors.accentInk : colors.ink,
              ),
            ),
          ],
        ),
      ),
    );
    return Pressable(
      key: dayMoodKey(mood),
      label: mood.label,
      selected: selected,
      onPressed: onTap,
      borderRadius: radius,
      surface: FocusRingSurface.dark,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) =>
          HoverFill(hovered: hovered, borderRadius: radius, child: face),
    );
  }
}

class _Rise extends StatefulWidget {
  const _Rise({
    required this.delay,
    required this.duration,
    required this.child,
  });

  final Duration delay;
  final Duration duration;
  final Widget child;

  @override
  State<_Rise> createState() => _RiseState();
}

class _RiseState extends State<_Rise> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: widget.delay + widget.duration,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _clock.value = 1;
    } else if (_clock.isDismissed) {
      _clock.forward();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  double get _progress {
    final int delay = widget.delay.inMicroseconds;
    final int duration = widget.duration.inMicroseconds;
    final double elapsed = _clock.value * (delay + duration);
    return ((elapsed - delay) / duration).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _clock,
      child: widget.child,
      builder: (BuildContext context, Widget? child) {
        final double eased = Curves.ease.transform(_progress);
        return Opacity(
          opacity: eased,
          alwaysIncludeSemantics: true,
          child: Transform.translate(
            offset: Offset(0, _riseDistance * (1 - eased)),
            child: child,
          ),
        );
      },
    );
  }
}
