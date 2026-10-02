import 'dart:math' as math;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/flowers/flower_bloom.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/onboarding/onboarding_controller.dart';
import 'package:field_notes/features/onboarding/onboarding_surface.dart';
import 'package:field_notes/features/onboarding/reminder_choice.dart';
import 'package:field_notes/features/reminders/local_notifications_reminder_scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String _kicker = 'and you';
const String _title = 'When should we check in?';
const String _noTime = '—';
const String _offClock = 'off';
const String _offBody = 'No nudges. Your meadow waits quietly.';

const Key reminderTimeKey = ValueKey<String>('reminder-time');
const Key reminderPreviewKey = ValueKey<String>('reminder-preview');

Key reminderChoiceKey(ReminderChoice choice) =>
    ValueKey<String>('reminder-choice-${choice.name}');

const List<ReminderChoice> _choices = ReminderChoice.values;

const double _sidebarBodyGap = 62;
const double _sidebarBottom = 72;
const double _sidebarMargin = 16;
const double _sidebarTimeSize = 88;
const double _sidebarTimeTracking = -1.76;
const double _sidebarTimeGap = 22;
const double _sidebarPreviewWidth = 380;
const double _sidebarPreviewHeight = 62;
const double _sidebarChoicesGap = 30;
const double _sidebarChoiceWidth = 104;
const double _sidebarChoiceHeight = 58;
const double _sidebarChoiceGap = 8;

const double _bottomBarSide = 18;
const double _bottomBarBottom = 76;
const double _bottomBarMiddlePadding = 10;
const double _bottomBarTimeSize = 46;
const double _bottomBarTimeGap = 10;
const double _bottomBarPreviewHeight = 56;
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
const double _rowRule = 1;
const BorderRadius _choiceRadius = BorderRadius.all(Radius.circular(12));
const BorderRadius _cardRadius = BorderRadius.all(Radius.circular(16));
const BorderRadius _cardInnerRadius = BorderRadius.all(
  Radius.circular(16 - _outline),
);

const BorderRadius _previewRadius = BorderRadius.all(Radius.circular(14));
const EdgeInsets _previewPadding = EdgeInsets.symmetric(
  horizontal: 12,
  vertical: 8,
);
const double _previewGap = 10;
const double _previewIcon = 34;
const double _previewIconPadding = 4;
const double _previewFlower =
    _previewIcon - 2 * (_previewIconPadding + _outline);
const BorderRadius _previewIconRadius = BorderRadius.all(Radius.circular(9));
const double _previewAlpha = 0.96;
const int _previewShadowAlpha = 0x73;
const Offset _previewShadowOffset = Offset(0, 12);
const double _previewShadowBlur = 26;
const double _previewShadowSpread = -12;
const double _offOpacity = 0.35;
const double _onAccentCaption = 0.88;

const ColorFilter _quiet = ColorFilter.matrix(<double>[
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0.2126,
  0.7152,
  0.0722,
  0,
  0,
  0,
  0,
  0,
  _offOpacity,
  0,
]);

const Duration _headingRise = Duration(milliseconds: 500);
const Duration _rowsRise = Duration(milliseconds: 500);
const Duration _rowsDelay = Duration(milliseconds: 200);
const Duration _previewDrop = Duration(milliseconds: 450);
const Duration _selectFade = Duration(milliseconds: 150);
const Duration _dotPop = Duration(milliseconds: 200);

const double _travel = 14;
const Cubic _dropCurve = Cubic(0.2, 0.9, 0.3, 1.2);
const Cubic _dotCurve = Cubic(0.2, 0.9, 0.3, 1.3);

const List<FontFeature> _tabular = <FontFeature>[FontFeature.tabularFigures()];

String _bigTime(ReminderChoice choice) =>
    choice.time == null ? _noTime : choice.clock;

String _previewClock(ReminderChoice choice) =>
    choice.time == null ? _offClock : choice.clock;

String _previewBody(ReminderChoice choice) =>
    choice.time == null ? _offBody : reminderNotificationBody;

String _sidebarCaption(ReminderChoice choice) => switch (choice) {
  ReminderChoice.morning => 'morning',
  ReminderChoice.midday => 'midday',
  ReminderChoice.evening => 'evening',
  ReminderChoice.off => 'no nudge',
};

String _rowLabel(ReminderChoice choice) => switch (choice) {
  ReminderChoice.morning ||
  ReminderChoice.midday ||
  ReminderChoice.evening => choice.clock,
  ReminderChoice.off => 'No reminder',
};

String _rowCaption(ReminderChoice choice) => switch (choice) {
  ReminderChoice.morning => 'Morning · start the day',
  ReminderChoice.midday => 'Midday · a pause',
  ReminderChoice.evening => 'Evening · look back',
  ReminderChoice.off => "You'll open it when you want",
};

class ReminderChapter extends ConsumerWidget {
  const ReminderChapter({super.key, required this.layout});

  final ShellLayout layout;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final OnboardingFlow flow = ref.watch(onboardingControllerProvider);
    if (flow is! OnboardingFlowRunning) {
      return const SizedBox.expand();
    }
    final ReminderChoice choice = flow.draft.reminder;
    final ValueChanged<ReminderChoice> onChoose = ref
        .read(onboardingControllerProvider.notifier)
        .chooseReminder;
    return SizedBox.expand(
      child: switch (layout) {
        ShellLayout.sidebar => _SidebarReminder(
          choice: choice,
          onChoose: onChoose,
        ),
        ShellLayout.bottomBar => _BottomBarReminder(
          choice: choice,
          onChoose: onChoose,
        ),
      },
    );
  }
}

class _SidebarReminder extends StatelessWidget {
  const _SidebarReminder({required this.choice, required this.onChoose});

  final ReminderChoice choice;
  final ValueChanged<ReminderChoice> onChoose;

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
            child: Column(
              children: <Widget>[
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topCenter,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _BigTime(
                          choice: choice,
                          size: _sidebarTimeSize,
                          tracking: _sidebarTimeTracking,
                        ),
                        const SizedBox(height: _sidebarTimeGap),
                        SizedBox(
                          width: _sidebarPreviewWidth,
                          child: _Preview(
                            choice: choice,
                            height: _sidebarPreviewHeight,
                            bodySize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: _sidebarChoicesGap),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (final (int index, ReminderChoice option)
                          in _choices.indexed) ...<Widget>[
                        if (index > 0) const SizedBox(width: _sidebarChoiceGap),
                        _ChoiceButton(
                          key: reminderChoiceKey(option),
                          choice: option,
                          selected: option == choice,
                          onPressed: () => onChoose(option),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomBarReminder extends StatelessWidget {
  const _BottomBarReminder({required this.choice, required this.onChoose});

  final ReminderChoice choice;
  final ValueChanged<ReminderChoice> onChoose;

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
                          child: SizedBox(
                            width: width,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                _BigTime(
                                  choice: choice,
                                  size: _bottomBarTimeSize,
                                ),
                                const SizedBox(height: _bottomBarTimeGap),
                                _Preview(
                                  choice: choice,
                                  height: _bottomBarPreviewHeight,
                                  bodySize: 11.5,
                                ),
                              ],
                            ),
                          ),
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
                        child: _Rise(
                          duration: _rowsRise,
                          delay: _rowsDelay,
                          child: _ChoiceRows(
                            choice: choice,
                            onChoose: onChoose,
                          ),
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

class _BigTime extends StatelessWidget {
  const _BigTime({required this.choice, required this.size, this.tracking});

  final ReminderChoice choice;
  final double size;
  final double? tracking;

  @override
  Widget build(BuildContext context) {
    return Text(
      _bigTime(choice),
      key: reminderTimeKey,
      textAlign: TextAlign.center,
      maxLines: 1,
      style: TextStyle(
        fontFamily: TypographyTokens.serif,
        fontSize: size,
        fontWeight: FontWeight.w500,
        height: 1,
        letterSpacing: tracking,
        fontFeatures: _tabular,
        color: context.colors.ink,
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.choice,
    required this.height,
    required this.bodySize,
  });

  final ReminderChoice choice;
  final double height;
  final double bodySize;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final bool quiet = choice.time == null;
    final Widget banner = Container(
      constraints: BoxConstraints(minHeight: height),
      padding: _previewPadding,
      decoration: BoxDecoration(
        color: colors.cardBright.withValues(alpha: _previewAlpha),
        borderRadius: _previewRadius,
        border: Border.all(color: colors.ink20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: colors.shadowTint(_previewShadowAlpha),
            offset: _previewShadowOffset,
            blurRadius: _previewShadowBlur,
            spreadRadius: _previewShadowSpread,
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          ExcludeSemantics(
            child: Container(
              width: _previewIcon,
              height: _previewIcon,
              padding: const EdgeInsets.all(_previewIconPadding),
              decoration: BoxDecoration(
                color: colors.cardWarm,
                borderRadius: _previewIconRadius,
                border: Border.all(color: colors.line, width: _outline),
              ),
              child: FlowerBloom.forMood(Mood.happy, size: _previewFlower),
            ),
          ),
          const SizedBox(width: _previewGap),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        reminderNotificationTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: TypographyTokens.sans,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: colors.ink,
                        ),
                      ),
                    ),
                    Text(
                      _previewClock(choice),
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: TypographyTokens.sans,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        fontFeatures: _tabular,
                        color: colors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 1),
                Text(
                  _previewBody(choice),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: TypographyTokens.sans,
                    fontSize: bodySize,
                    fontWeight: FontWeight.w400,
                    color: colors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return MergeSemantics(
      key: reminderPreviewKey,
      child: _Drop(
        key: ValueKey<ReminderChoice>(choice),
        child: quiet
            ? ColorFiltered(colorFilter: _quiet, child: banner)
            : banner,
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    super.key,
    required this.choice,
    required this.selected,
    required this.onPressed,
  });

  final ReminderChoice choice;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final String caption = _sidebarCaption(choice);
    return Semantics(
      button: true,
      selected: selected,
      label: '${choice.clock}, $caption',
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
            width: _sidebarChoiceWidth,
            constraints: const BoxConstraints(minHeight: _sidebarChoiceHeight),
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    choice.clock,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: TypographyTokens.sans,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFeatures: _tabular,
                      color: selected ? Palette.onAccent : colors.ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    caption,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: TypographyTokens.sans,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? Palette.onAccent.withValues(alpha: _onAccentCaption)
                          : colors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ChoiceRows extends StatelessWidget {
  const _ChoiceRows({required this.choice, required this.onChoose});

  final ReminderChoice choice;
  final ValueChanged<ReminderChoice> onChoose;

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
            for (final (int index, ReminderChoice option) in _choices.indexed)
              _ChoiceRow(
                key: reminderChoiceKey(option),
                choice: option,
                selected: option == choice,
                last: index == _choices.length - 1,
                onPressed: () => onChoose(option),
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
    required this.choice,
    required this.selected,
    required this.last,
    required this.onPressed,
  });

  final ReminderChoice choice;
  final bool selected;
  final bool last;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final bool still = MediaQuery.disableAnimationsOf(context);
    final String label = _rowLabel(choice);
    final String caption = _rowCaption(choice);
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      label: '$label, ${caption.replaceAll(' · ', ', ')}',
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
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: TypographyTokens.sans,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            fontFeatures: _tabular,
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

class _Drop extends StatelessWidget {
  const _Drop({super.key, required this.child});

  final Widget child;

  static Widget _frame(double progress, Widget child) {
    final double eased = _dropCurve.transform(progress);
    return Opacity(
      opacity: eased.clamp(0.0, 1.0),
      alwaysIncludeSemantics: true,
      child: Transform.translate(
        offset: Offset(0, -_travel * (1 - eased)),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _Entrance(
      duration: _previewDrop,
      delay: Duration.zero,
      frame: _frame,
      child: child,
    );
  }
}
