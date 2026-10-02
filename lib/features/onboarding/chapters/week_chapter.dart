import 'dart:math' as math;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/flowers/flower_bloom.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/domain/settings/week_start.dart';
import 'package:field_notes/features/calendar/model/calendar_month.dart';
import 'package:field_notes/features/onboarding/onboarding_controller.dart';
import 'package:field_notes/features/onboarding/onboarding_surface.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _kicker = 'and you';
const String _title = 'Your week starts on…';
const String _regionDefault = "Your region's default";
const String _privacy = 'Your stories stay private, on this device.';

const Key weekStripKey = ValueKey<String>('week-strip');
const Key weekPrivacyKey = ValueKey<String>('week-privacy');

Key weekChoiceKey(WeekStart start) =>
    ValueKey<String>('week-choice-${start.name}');

Key weekDayKey(int weekday) => ValueKey<String>('week-day-$weekday');

const List<WeekStart> _choiceOrder = <WeekStart>[
  WeekStart.monday,
  WeekStart.sunday,
  WeekStart.saturday,
];

const Map<int, Mood> _dayFlowers = <int, Mood>{
  DateTime.sunday: Mood.calm,
  DateTime.monday: Mood.happy,
  DateTime.tuesday: Mood.warm,
  DateTime.wednesday: Mood.tired,
  DateTime.thursday: Mood.love,
  DateTime.friday: Mood.hopeful,
  DateTime.saturday: Mood.grateful,
};

const int _daysPerWeek = 7;

const double _sidebarMargin = 16;
const double _sidebarStripWidth = 524;
const double _sidebarBodyGap = 82;
const double _sidebarBottom = 72;
const double _sidebarStripGap = 30;
const double _sidebarChoiceGap = 10;
const double _sidebarButtonPadding = 22;
const double _sidebarPrivacyGap = 56;

const double _bottomBarSide = 18;
const double _bottomBarBottom = 76;
const double _bottomBarMiddlePadding = 10;
const double _bottomBarPrivacyGap = 12;

const double _target = 48;
const double _rowHeight = 56;
const EdgeInsets _rowPadding = EdgeInsets.symmetric(
  horizontal: 14,
  vertical: 8,
);
const double _rowGap = 12;
const double _radioSize = 22;
const double _radioRing = 2;
const double _radioDot = 10;

const double _outline = 1.5;
const double _firstOutline = 2;
const double _rowRule = 1;
const double _tracking = 0.06;
const BorderRadius _choiceRadius = BorderRadius.all(Radius.circular(12));
const BorderRadius _cardRadius = BorderRadius.all(Radius.circular(16));
const BorderRadius _cardInnerRadius = BorderRadius.all(
  Radius.circular(16 - _outline),
);

const Duration _headingRise = Duration(milliseconds: 500);
const Duration _rowsRise = Duration(milliseconds: 500);
const Duration _rowsDelay = Duration(milliseconds: 200);
const Duration _privacyFade = Duration(milliseconds: 500);
const Duration _privacyDelay = Duration(milliseconds: 600);
const Duration _slide = Duration(milliseconds: 550);
const Duration _cardFade = Duration(milliseconds: 200);
const Duration _selectFade = Duration(milliseconds: 150);
const Duration _dotPop = Duration(milliseconds: 200);

const double _travel = 14;
const Cubic _slideCurve = Cubic(0.3, 0.9, 0.3, 1.1);
const Cubic _dotCurve = Cubic(0.2, 0.9, 0.3, 1.3);

class _StripSize {
  const _StripSize({
    required this.width,
    required this.height,
    required this.spacing,
    required this.card,
    required this.radius,
    required this.gap,
    required this.flower,
    required this.letter,
  });

  final double width;
  final double height;
  final double spacing;
  final double card;
  final double radius;
  final double gap;
  final double flower;
  final double letter;
}

const _StripSize _sidebarStrip = _StripSize(
  width: _sidebarStripWidth,
  height: 118,
  spacing: 75,
  card: 64,
  radius: 16,
  gap: 12,
  flower: 34,
  letter: 13,
);

const _StripSize _bottomBarStrip = _StripSize(
  width: 259,
  height: 84,
  spacing: 37,
  card: 33,
  radius: 11,
  gap: 8,
  flower: 24,
  letter: 10,
);

List<WeekStart> _choicesFor(WeekStart region) => <WeekStart>[
  region,
  for (final WeekStart start in _choiceOrder)
    if (start != region) start,
];

int _slotOf(int weekday, WeekStart week) =>
    (weekday - week.weekday + _daysPerWeek) % _daysPerWeek;

String _usedIn(WeekStart start) => switch (start) {
  WeekStart.monday => 'Most of Europe',
  WeekStart.sunday => 'US, Canada, Japan',
  WeekStart.saturday => 'Parts of the Middle East',
};

class WeekChapter extends ConsumerWidget {
  const WeekChapter({super.key, required this.layout});

  final ShellLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingFlow flow = ref.watch(onboardingControllerProvider);
    if (flow is! OnboardingFlowRunning) {
      return const SizedBox.expand();
    }
    final OnboardingDraft draft = flow.draft;
    final ValueChanged<WeekStart> onChoose = ref
        .read(onboardingControllerProvider.notifier)
        .chooseWeek;
    final List<WeekStart> choices = _choicesFor(draft.regionWeek);
    return SizedBox.expand(
      child: switch (layout) {
        ShellLayout.sidebar => _SidebarWeek(
          week: draft.week,
          choices: choices,
          onChoose: onChoose,
        ),
        ShellLayout.bottomBar => _BottomBarWeek(
          week: draft.week,
          region: draft.regionWeek,
          choices: choices,
          onChoose: onChoose,
        ),
      },
    );
  }
}

class _SidebarWeek extends StatelessWidget {
  const _SidebarWeek({
    required this.week,
    required this.choices,
    required this.onChoose,
  });

  final WeekStart week;
  final List<WeekStart> choices;
  final ValueChanged<WeekStart> onChoose;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const _Rise(
          duration: _headingRise,
          child: OnboardingHeading(
            layout: ShellLayout.sidebar,
            kicker: _kicker,
            title: _title,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _sidebarMargin,
              _sidebarBodyGap,
              _sidebarMargin,
              _sidebarBottom,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _WeekStrip(week: week, size: _sidebarStrip),
                    const SizedBox(height: _sidebarStripGap),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        for (final (int index, WeekStart start)
                            in choices.indexed) ...<Widget>[
                          if (index > 0)
                            const SizedBox(width: _sidebarChoiceGap),
                          _WeekButton(
                            key: weekChoiceKey(start),
                            start: start,
                            selected: start == week,
                            onPressed: () => onChoose(start),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: _sidebarPrivacyGap),
                    const SizedBox(
                      width: _sidebarStripWidth,
                      child: _Fade(
                        duration: _privacyFade,
                        delay: _privacyDelay,
                        child: _Privacy(icon: 14, gap: 8, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomBarWeek extends StatelessWidget {
  const _BottomBarWeek({
    required this.week,
    required this.region,
    required this.choices,
    required this.onChoose,
  });

  final WeekStart week;
  final WeekStart region;
  final List<WeekStart> choices;
  final ValueChanged<WeekStart> onChoose;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const _Rise(
          duration: _headingRise,
          child: OnboardingHeading(
            layout: ShellLayout.bottomBar,
            kicker: _kicker,
            title: _title,
          ),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints area) {
              final double width = math.max(
                0.0,
                area.maxWidth - 2 * _bottomBarSide,
              );
              return Column(
                children: <Widget>[
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: _bottomBarMiddlePadding,
                      ),
                      child: Center(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: _WeekStrip(week: week, size: _bottomBarStrip),
                        ),
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: area.maxHeight),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: SizedBox(
                        width: width,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            _Rise(
                              duration: _rowsRise,
                              delay: _rowsDelay,
                              child: _ChoiceRows(
                                week: week,
                                region: region,
                                choices: choices,
                                onChoose: onChoose,
                              ),
                            ),
                            const SizedBox(height: _bottomBarPrivacyGap),
                            const _Privacy(icon: 13, gap: 7, fontSize: 11.5),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: _bottomBarBottom),
      ],
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.week, required this.size});

  final WeekStart week;
  final _StripSize size;

  @override
  Widget build(BuildContext context) {
    final bool still = MediaQuery.disableAnimationsOf(context);
    final List<String> letters = weekdayHeaders(firstWeekday: DateTime.monday);
    return ExcludeSemantics(
      child: SizedBox(
        key: weekStripKey,
        width: size.width,
        height: size.height,
        child: Stack(
          children: <Widget>[
            for (final MapEntry<int, Mood> day in _dayFlowers.entries)
              AnimatedPositioned(
                key: ValueKey<int>(day.key),
                duration: still ? Duration.zero : _slide,
                curve: _slideCurve,
                left: _slotOf(day.key, week) * size.spacing,
                top: 0,
                width: size.card,
                height: size.height,
                child: _DayCard(
                  key: weekDayKey(day.key),
                  letter: letters[day.key - DateTime.monday],
                  mood: day.value,
                  first: day.key == week.weekday,
                  size: size,
                  still: still,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  const _DayCard({
    super.key,
    required this.letter,
    required this.mood,
    required this.first,
    required this.size,
    required this.still,
  });

  final String letter;
  final Mood mood;
  final bool first;
  final _StripSize size;
  final bool still;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return AnimatedContainer(
      duration: still ? Duration.zero : _cardFade,
      decoration: BoxDecoration(
        color: first ? colors.cardLight : colors.cardWarm,
        borderRadius: BorderRadius.all(Radius.circular(size.radius)),
        border: Border.all(
          color: first ? Palette.coral : colors.ink20,
          width: first ? _firstOutline : _outline,
        ),
        boxShadow: first ? context.shadows.emphasis : const <BoxShadow>[],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text(
            letter,
            maxLines: 1,
            style: TextStyle(
              fontFamily: TypographyTokens.sans,
              fontSize: size.letter,
              fontWeight: FontWeight.w600,
              letterSpacing: size.letter * _tracking,
              color: first ? colors.accentInk : colors.muted,
            ),
          ),
          SizedBox(height: size.gap),
          FlowerBloom.forMood(mood, size: size.flower),
        ],
      ),
    );
  }
}

class _WeekButton extends StatelessWidget {
  const _WeekButton({
    super.key,
    required this.start,
    required this.selected,
    required this.onPressed,
  });

  final WeekStart start;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: start.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: FocusRing(
          onPressed: onPressed,
          borderRadius: _choiceRadius,
          child: AnimatedContainer(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : _selectFade,
            constraints: const BoxConstraints(
              minWidth: _target,
              minHeight: _target,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: _sidebarButtonPadding,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? Palette.coral : colors.cardWarm,
              borderRadius: _choiceRadius,
              border: Border.all(
                color: selected ? colors.line : colors.ink30,
                width: _outline,
              ),
              boxShadow: selected
                  ? context.shadows.emphasis
                  : const <BoxShadow>[],
            ),
            child: ExcludeSemantics(
              child: Text(
                start.label,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: TypographyTokens.sans,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Palette.onAccent : colors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceRows extends StatelessWidget {
  const _ChoiceRows({
    required this.week,
    required this.region,
    required this.choices,
    required this.onChoose,
  });

  final WeekStart week;
  final WeekStart region;
  final List<WeekStart> choices;
  final ValueChanged<WeekStart> onChoose;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Container(
      decoration: BoxDecoration(
        color: colors.cardWarm,
        borderRadius: _cardRadius,
        border: Border.all(color: colors.ink22, width: _outline),
      ),
      child: ClipRRect(
        borderRadius: _cardInnerRadius,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (final (int index, WeekStart start) in choices.indexed)
              _ChoiceRow(
                key: weekChoiceKey(start),
                start: start,
                caption: start == region ? _regionDefault : _usedIn(start),
                selected: start == week,
                last: index == choices.length - 1,
                onPressed: () => onChoose(start),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    super.key,
    required this.start,
    required this.caption,
    required this.selected,
    required this.last,
    required this.onPressed,
  });

  final WeekStart start;
  final String caption;
  final bool selected;
  final bool last;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final bool still = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      label: '${start.label}, $caption',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: FocusRing(
          onPressed: onPressed,
          placement: FocusRingPlacement.edge,
          child: AnimatedContainer(
            duration: still ? Duration.zero : _selectFade,
            constraints: const BoxConstraints(minHeight: _rowHeight),
            padding: _rowPadding,
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              color: selected
                  ? colors.cardLight
                  : colors.cardLight.withAlpha(0),
              border: last
                  ? null
                  : Border(
                      bottom: BorderSide(color: colors.ink12, width: _rowRule),
                    ),
            ),
            child: ExcludeSemantics(
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          start.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: TypographyTokens.sans,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: selected ? colors.accentInk : colors.ink,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          caption,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: TypographyTokens.sans,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: colors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: _rowGap),
                  _Radio(selected: selected, still: still),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Radio extends StatelessWidget {
  const _Radio({required this.selected, required this.still});

  final bool selected;
  final bool still;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _radioSize,
      height: _radioSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? Palette.coral : context.colors.ink35,
          width: _radioRing,
        ),
      ),
      child: AnimatedScale(
        scale: selected ? 1 : 0,
        duration: still ? Duration.zero : _dotPop,
        curve: _dotCurve,
        child: const SizedBox.square(
          dimension: _radioDot,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Palette.coral,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

class _Privacy extends StatelessWidget {
  const _Privacy({
    required this.icon,
    required this.gap,
    required this.fontSize,
  });

  final double icon;
  final double gap;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Row(
      key: weekPrivacyKey,
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        SizedBox.square(
          dimension: icon,
          child: CustomPaint(painter: _LockPainter(color: colors.ink)),
        ),
        SizedBox(width: gap),
        Flexible(
          child: Text(
            _privacy,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: TypographyTokens.sans,
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: colors.mutedDeep,
            ),
          ),
        ),
      ],
    );
  }
}

class _LockPainter extends CustomPainter {
  const _LockPainter({required this.color});

  final Color color;

  static const double _viewBox = 24;
  static const double _strokeWidth = 2;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.shortestSide / _viewBox);
    canvas.drawPath(
      Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(5, 11, 14, 9),
            const Radius.circular(2),
          ),
        )
        ..moveTo(8, 11)
        ..lineTo(8, 8)
        ..arcToPoint(const Offset(16, 8), radius: const Radius.circular(4))
        ..lineTo(16, 11),
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LockPainter oldDelegate) =>
      oldDelegate.color != color;
}

typedef _EntranceFrame = Widget Function(double progress, Widget child);

class _Entrance extends StatefulWidget {
  const _Entrance({
    required this.duration,
    required this.delay,
    required this.frame,
    required this.child,
  });

  final Duration duration;
  final Duration delay;
  final _EntranceFrame frame;
  final Widget child;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
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
    return duration == 0 ? 1 : ((elapsed - delay) / duration).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _clock,
      child: widget.child,
      builder: (BuildContext context, Widget? child) =>
          widget.frame(_progress, child!),
    );
  }
}

class _Rise extends StatelessWidget {
  const _Rise({
    required this.duration,
    this.delay = Duration.zero,
    required this.child,
  });

  final Duration duration;
  final Duration delay;
  final Widget child;

  static Widget _frame(double progress, Widget child) {
    final double eased = Curves.ease.transform(progress);
    return Opacity(
      opacity: eased,
      alwaysIncludeSemantics: true,
      child: Transform.translate(
        offset: Offset(0, _travel * (1 - eased)),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Entrance(
      duration: duration,
      delay: delay,
      frame: _frame,
      child: child,
    );
  }
}

class _Fade extends StatelessWidget {
  const _Fade({
    required this.duration,
    required this.delay,
    required this.child,
  });

  final Duration duration;
  final Duration delay;
  final Widget child;

  static Widget _frame(double progress, Widget child) => Opacity(
    opacity: Curves.ease.transform(progress),
    alwaysIncludeSemantics: true,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    return _Entrance(
      duration: duration,
      delay: delay,
      frame: _frame,
      child: child,
    );
  }
}
