import 'dart:math' as math;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/flowers/flower_bloom.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
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
const int _phoneColumns = 5;

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
          left: metrics.tilesSide,
          right: metrics.tilesSide,
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

  @override
  Widget build(BuildContext context) {
    final double? width = metrics.tileWidth;
    if (width != null) {
      return Center(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final (int index, Mood mood) in moodOrder.indexed) ...<Widget>[
              if (index > 0) SizedBox(width: metrics.tileGap),
              SizedBox(width: width, child: _tile(mood)),
            ],
          ],
        ),
      );
    }
    final List<List<Mood>> rows = <List<Mood>>[
      for (int start = 0; start < moodOrder.length; start += _phoneColumns)
        moodOrder.skip(start).take(_phoneColumns).toList(),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final (int row, List<Mood> moods) in rows.indexed) ...<Widget>[
          if (row > 0) SizedBox(height: metrics.tileGap),
          Row(
            children: <Widget>[
              for (
                int column = 0;
                column < _phoneColumns;
                column++
              ) ...<Widget>[
                if (column > 0) SizedBox(width: metrics.tileGap),
                Expanded(
                  child: column < moods.length
                      ? _tile(moods[column])
                      : const SizedBox.shrink(),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

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
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            FlowerBloom.forMood(mood, size: metrics.flower),
            SizedBox(height: metrics.labelGap),
            Text(
              mood.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: TypographyTokens.sans,
                fontSize: metrics.labelSize,
                fontWeight: FontWeight.w600,
                color: selected ? colors.accentInk : colors.ink,
              ),
            ),
          ],
        ),
      ),
    );
    return Semantics(
      key: dayMoodKey(mood),
      container: true,
      button: true,
      selected: selected,
      label: mood.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: FocusRing(
          onPressed: onTap,
          borderRadius: radius,
          child: SizedBox(
            height: metrics.tileHeight,
            child: ExcludeSemantics(child: face),
          ),
        ),
      ),
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
