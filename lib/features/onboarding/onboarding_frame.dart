import 'dart:async';
import 'dart:math' as math;

import 'package:field_notes/app/shell/appearance_toggle.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/flowers/flower_bloom.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/motion/petal_drift.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/onboarding/chapters/day_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/moment_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/month_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/opening_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/reminder_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/theme_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/tour_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/week_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/year_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding_controller.dart';
import 'package:field_notes/features/onboarding/onboarding_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String onboardingBeginLabel = 'Begin';
const String onboardingNextLabel = 'Next';
const String onboardingStartLabelSidebar = 'Start journaling';
const String onboardingStartLabelBottomBar = 'Start';
const String onboardingDoneLabel = 'Done';
const String onboardingSkipToSetupLabel = 'Skip to setup';
const String onboardingSkipLabel = 'Skip';

const Key onboardingProgressKey = ValueKey<String>('onboarding-progress');
const Key onboardingPrimaryKey = ValueKey<String>('onboarding-primary');
const Key onboardingSkipKey = ValueKey<String>('onboarding-skip');

const Key _petalsKey = ValueKey<String>('onboarding-petals');
const Key _toggleSlotKey = ValueKey<String>('onboarding-appearance-toggle');

const Duration _petalFade = Duration(milliseconds: 1200);

const String _arrow = '→';
const double _target = 48;
const double _pillBorder = 1.5;
const double _pillAlpha = 0.85;
const double _currentRingAlpha = 0.22;
const double _errorGap = 6;
const double _errorMaxWidth = 320;

const List<Mood> _laterMarkMoods = <Mood>[
  Mood.love,
  Mood.warm,
  Mood.calm,
  Mood.hopeful,
  Mood.grateful,
  Mood.anxious,
  Mood.sad,
];

final Set<LogicalKeyboardKey> _forwardKeys = <LogicalKeyboardKey>{
  LogicalKeyboardKey.arrowRight,
  LogicalKeyboardKey.enter,
  LogicalKeyboardKey.numpadEnter,
};

class _FrameMetrics {
  const _FrameMetrics({
    required this.buttonHeight,
    required this.buttonRadius,
    required this.buttonPadding,
    required this.buttonLabelSize,
    required this.buttonRight,
    required this.buttonBottom,
    required this.slotWidth,
    required this.slotHeight,
    required this.slotGap,
    required this.pillPaddingX,
    required this.pillPaddingY,
    required this.pillRadius,
    required this.pillBottom,
    required this.flowerSize,
    required this.currentSize,
    required this.currentRing,
    required this.laterSize,
  });

  final double buttonHeight;
  final double buttonRadius;
  final double buttonPadding;
  final double buttonLabelSize;
  final double buttonRight;
  final double buttonBottom;
  final double slotWidth;
  final double slotHeight;
  final double slotGap;
  final double pillPaddingX;
  final double pillPaddingY;
  final double pillRadius;
  final double pillBottom;
  final double flowerSize;
  final double currentSize;
  final double currentRing;
  final double laterSize;

  double get buttonTargetBottom =>
      buttonBottom - math.max(0, _target - buttonHeight) / 2;

  double get pillHeight => slotHeight + 2 * pillPaddingY + 2 * _pillBorder;

  double pillWidth(int count) =>
      count * slotWidth +
      (count - 1) * slotGap +
      2 * pillPaddingX +
      2 * _pillBorder;

  double get firstCentre => _pillBorder + pillPaddingX + slotWidth / 2;

  double get overhang => math.max(0, _target / 2 - firstCentre);

  double get rowBottom => pillBottom - (_target - pillHeight) / 2;

  double centreOf(int index) =>
      overhang + firstCentre + index * (slotWidth + slotGap);
}

const _FrameMetrics _sidebarMetrics = _FrameMetrics(
  buttonHeight: 46,
  buttonRadius: 14,
  buttonPadding: 22,
  buttonLabelSize: 14,
  buttonRight: 28,
  buttonBottom: 20,
  slotWidth: 26,
  slotHeight: 26,
  slotGap: 6,
  pillPaddingX: 10,
  pillPaddingY: 5,
  pillRadius: 18,
  pillBottom: 20,
  flowerSize: 20,
  currentSize: 12,
  currentRing: 4,
  laterSize: 7,
);

const _FrameMetrics _bottomBarMetrics = _FrameMetrics(
  buttonHeight: 44,
  buttonRadius: 22,
  buttonPadding: 18,
  buttonLabelSize: 13.5,
  buttonRight: 14,
  buttonBottom: 16,
  slotWidth: 17,
  slotHeight: 24,
  slotGap: 0,
  pillPaddingX: 6,
  pillPaddingY: 3,
  pillRadius: 14,
  pillBottom: 20,
  flowerSize: 15,
  currentSize: 10,
  currentRing: 3,
  laterSize: 6,
);

const double _sidebarSkipTop = 8;
const double _sidebarSkipRight = 18;
const double _sidebarSkipHeight = 36;
const double _sidebarSkipRadius = 11;
const double _sidebarSkipPadding = 14;
const double _bottomBarSkipRight = 10;
const double _bottomBarProgressLeft = 12;
const double _bottomBarToggleTop = 0;
const double _bottomBarToggleRight = 4;

_FrameMetrics _metricsFor(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => _sidebarMetrics,
  ShellLayout.bottomBar => _bottomBarMetrics,
};

Mood _markMood(OnboardingChapter chapter, Mood chosen) => switch (chapter) {
  OnboardingChapter.opening => Mood.happy,
  OnboardingChapter.day => chosen,
  _ => _laterMarkMoods[chapter.index - OnboardingChapter.moment.index],
};

BoxDecoration _paper(FieldNotesColors colors, ShellLayout layout) =>
    switch (layout) {
      ShellLayout.sidebar => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[colors.panelTop, colors.panelBottom],
        ),
      ),
      ShellLayout.bottomBar => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[colors.paperShade, colors.hatchLight],
        ),
      ),
    };

const BoxDecoration _glow = BoxDecoration(
  gradient: RadialGradient(
    center: Alignment(-0.7, -1),
    radius: 1.2,
    colors: <Color>[Color(0x14C76A54), Color(0x00C76A54)],
    stops: <double>[0, 0.55],
  ),
);

class OnboardingFrame extends ConsumerStatefulWidget {
  const OnboardingFrame({super.key, required this.layout});

  final ShellLayout layout;

  @override
  ConsumerState<OnboardingFrame> createState() => _OnboardingFrameState();
}

class _OnboardingFrameState extends ConsumerState<OnboardingFrame> {
  final FocusNode _focus = FocusNode(
    debugLabel: 'onboarding-frame',
    skipTraversal: true,
  );

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted && !_focus.hasFocus) {
        _focus.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    _focus.dispose();
    super.dispose();
  }

  OnboardingController get _controller =>
      ref.read(onboardingControllerProvider.notifier);

  bool get _focusFellToScope {
    final FocusNode? focused = FocusManager.instance.primaryFocus;
    return focused == null || identical(focused, _focus.enclosingScope);
  }

  void _onFocusChanged() {
    if (!_focusFellToScope) {
      return;
    }
    scheduleMicrotask(() {
      if (mounted && _focusFellToScope) {
        _focus.requestFocus();
      }
    });
  }

  bool get _typing {
    final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
    return focused != null &&
        (focused.widget is EditableText ||
            focused.findAncestorWidgetOfExactType<EditableText>() != null);
  }

  bool get _modified {
    final HardwareKeyboard keyboard = HardwareKeyboard.instance;
    return keyboard.isMetaPressed ||
        keyboard.isControlPressed ||
        keyboard.isAltPressed ||
        keyboard.isShiftPressed;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (widget.layout != ShellLayout.sidebar ||
        event is! KeyDownEvent ||
        _typing ||
        _modified) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _controller.back();
      return KeyEventResult.handled;
    }
    if (_forwardKeys.contains(event.logicalKey)) {
      _controller.next();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final OnboardingFlow flow = ref.watch(onboardingControllerProvider);
    final Widget content = switch (flow) {
      OnboardingFlowHidden() => const SizedBox.expand(),
      OnboardingFlowRunning(
        :final OnboardingChapter chapter,
        :final OnboardingDraft draft,
      ) =>
        _running(chapter, draft),
      OnboardingFlowMap() => _map(),
    };
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: DecoratedBox(
        decoration: _paper(context.colors, widget.layout),
        child: DecoratedBox(
          decoration: widget.layout == ShellLayout.sidebar
              ? _glow
              : const BoxDecoration(),
          child: SafeArea(
            child: Material(type: MaterialType.transparency, child: content),
          ),
        ),
      ),
    );
  }

  Widget _chapter(OnboardingChapter chapter) {
    final ShellLayout layout = widget.layout;
    return switch (chapter) {
      OnboardingChapter.opening => OpeningChapter(layout: layout),
      OnboardingChapter.day => DayChapter(layout: layout),
      OnboardingChapter.moment => MomentChapter(layout: layout),
      OnboardingChapter.month => MonthChapter(layout: layout),
      OnboardingChapter.year => YearChapter(layout: layout),
      OnboardingChapter.theme => ThemeChapter(layout: layout),
      OnboardingChapter.reminder => ReminderChapter(layout: layout),
      OnboardingChapter.week => WeekChapter(layout: layout),
      OnboardingChapter.tour => TourChapter(layout: layout),
    };
  }

  String _primaryLabel(OnboardingChapter chapter) => switch (chapter) {
    OnboardingChapter.opening => onboardingBeginLabel,
    OnboardingChapter.tour => switch (widget.layout) {
      ShellLayout.sidebar => onboardingStartLabelSidebar,
      ShellLayout.bottomBar => onboardingStartLabelBottomBar,
    },
    _ => onboardingNextLabel,
  };

  Widget _running(OnboardingChapter chapter, OnboardingDraft draft) {
    final ShellLayout layout = widget.layout;
    final _FrameMetrics metrics = _metricsFor(layout);
    final OnboardingController controller = _controller;
    final bool ready = controller.canAdvance;
    final String? finishError = chapter == OnboardingChapter.tour
        ? draft.finishError
        : null;
    final Widget progress = _ProgressRow(
      key: onboardingProgressKey,
      layout: layout,
      current: chapter,
      mood: draft.mood,
      onOpen: controller.goTo,
    );
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        KeyedSubtree(
          key: ValueKey<OnboardingChapter>(chapter),
          child: _chapter(chapter),
        ),
        if (draft.planted)
          _PetalVeil(key: _petalsKey, shown: chapter != OnboardingChapter.year),
        switch (layout) {
          ShellLayout.sidebar => Positioned(
            left: 0,
            right: 0,
            bottom: metrics.rowBottom,
            child: Center(child: progress),
          ),
          ShellLayout.bottomBar => Positioned(
            left: _bottomBarProgressLeft - metrics.overhang,
            bottom: metrics.rowBottom,
            child: progress,
          ),
        },
        if (layout == ShellLayout.sidebar && chapter.isStory)
          Positioned(
            top: _sidebarSkipTop,
            right: _sidebarSkipRight,
            child: _SkipPill(onPressed: controller.skipToSetup),
          ),
        if (finishError != null)
          Positioned(
            right: metrics.buttonRight,
            bottom: metrics.buttonTargetBottom + _target + _errorGap,
            child: _FinishError(message: finishError),
          ),
        if (ready)
          _primary(metrics, _primaryLabel(chapter), controller.next)
        else if (layout == ShellLayout.bottomBar && chapter.isStory)
          Positioned(
            right: _bottomBarSkipRight,
            bottom: metrics.buttonTargetBottom,
            child: OnboardingTextButton(
              key: onboardingSkipKey,
              label: onboardingSkipLabel,
              onPressed: controller.skipToSetup,
              style: TextStyle(
                fontFamily: TypographyTokens.sans,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: chapter == OnboardingChapter.year
                    ? FieldNotesColors.light.composerPaper
                    : context.colors.ink,
              ),
            ),
          ),
        if (layout == ShellLayout.bottomBar)
          _appearanceToggle(overMeadow: chapter == OnboardingChapter.year),
      ],
    );
  }

  Widget _map() {
    final _FrameMetrics metrics = _metricsFor(widget.layout);
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        TourChapter(layout: widget.layout),
        _primary(metrics, onboardingDoneLabel, _controller.closeMap),
        if (widget.layout == ShellLayout.bottomBar)
          _appearanceToggle(overMeadow: false),
      ],
    );
  }

  Widget _appearanceToggle({required bool overMeadow}) {
    return Positioned(
      key: _toggleSlotKey,
      top: _bottomBarToggleTop,
      right: _bottomBarToggleRight,
      child: AppearanceToggle(
        ink: overMeadow ? FieldNotesColors.light.composerPaper : null,
      ),
    );
  }

  Widget _primary(_FrameMetrics metrics, String label, VoidCallback onPressed) {
    return Positioned(
      right: metrics.buttonRight,
      bottom: metrics.buttonTargetBottom,
      child: OnboardingPrimaryButton(
        key: onboardingPrimaryKey,
        label: label,
        onPressed: onPressed,
        height: metrics.buttonHeight,
        borderRadius: BorderRadius.all(Radius.circular(metrics.buttonRadius)),
        padding: EdgeInsets.symmetric(horizontal: metrics.buttonPadding),
        trailing: _arrow,
        labelStyle: TextStyle(
          fontFamily: TypographyTokens.sans,
          fontSize: metrics.buttonLabelSize,
          fontWeight: FontWeight.w600,
          color: Palette.onAccent,
        ),
      ),
    );
  }
}

class _PetalVeil extends StatefulWidget {
  const _PetalVeil({super.key, required this.shown});

  final bool shown;

  @override
  State<_PetalVeil> createState() => _PetalVeilState();
}

class _PetalVeilState extends State<_PetalVeil>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: _petalFade,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _follow();
  }

  @override
  void didUpdateWidget(_PetalVeil oldWidget) {
    super.didUpdateWidget(oldWidget);
    _follow();
  }

  void _follow() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _fade.value = widget.shown ? 1 : 0;
    } else if (widget.shown) {
      _fade.forward();
    } else {
      _fade.reverse();
    }
  }

  @override
  void dispose() {
    _fade.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _fade,
      child: const PetalDrift(),
      builder: (BuildContext context, Widget? petals) => _fade.isDismissed
          ? const SizedBox.shrink()
          : Opacity(opacity: Curves.ease.transform(_fade.value), child: petals),
    );
  }
}

class _FinishError extends StatelessWidget {
  const _FinishError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _errorMaxWidth),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          textAlign: TextAlign.end,
          style: TextStyle(
            fontFamily: TypographyTokens.sans,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: context.colors.dangerInk,
          ),
        ),
      ),
    );
  }
}

class _SkipPill extends StatelessWidget {
  const _SkipPill({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    const BorderRadius radius = BorderRadius.all(
      Radius.circular(_sidebarSkipRadius),
    );
    return Semantics(
      key: onboardingSkipKey,
      button: true,
      label: onboardingSkipToSetupLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _target,
            minHeight: _target,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: FocusRing(
              onPressed: onPressed,
              borderRadius: radius,
              child: SizedBox(
                height: _sidebarSkipHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.composerPaper.withValues(alpha: _pillAlpha),
                    border: Border.all(color: colors.ink16, width: _pillBorder),
                    borderRadius: radius,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _sidebarSkipPadding,
                    ),
                    child: Center(
                      widthFactor: 1,
                      child: ExcludeSemantics(
                        child: Text(
                          onboardingSkipToSetupLabel,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: TypographyTokens.sans,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: colors.ink,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _MarkState { past, current, later }

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    super.key,
    required this.layout,
    required this.current,
    required this.mood,
    required this.onOpen,
  });

  final ShellLayout layout;
  final OnboardingChapter current;
  final Mood mood;
  final ValueChanged<OnboardingChapter> onOpen;

  _MarkState _stateOf(OnboardingChapter chapter) {
    if (chapter.index < current.index) {
      return _MarkState.past;
    }
    return chapter == current ? _MarkState.current : _MarkState.later;
  }

  void _openNearest(_FrameMetrics metrics, Offset local) {
    final double step = metrics.slotWidth + metrics.slotGap;
    final int index =
        ((local.dx - metrics.overhang - metrics.firstCentre) / step)
            .round()
            .clamp(0, OnboardingChapter.values.length - 1);
    final OnboardingChapter chapter = OnboardingChapter.values[index];
    if (_stateOf(chapter) == _MarkState.past) {
      onOpen(chapter);
    }
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final _FrameMetrics metrics = _metricsFor(layout);
    final int count = OnboardingChapter.values.length;
    final double pillWidth = metrics.pillWidth(count);
    final double pillHeight = metrics.pillHeight;
    return SizedBox(
      width: pillWidth + 2 * metrics.overhang,
      height: _target,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapUp: (TapUpDetails details) =>
            _openNearest(metrics, details.localPosition),
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned(
              left: metrics.overhang,
              top: (_target - pillHeight) / 2,
              width: pillWidth,
              height: pillHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.composerPaper.withValues(alpha: _pillAlpha),
                  border: Border.all(color: colors.ink16, width: _pillBorder),
                  borderRadius: BorderRadius.all(
                    Radius.circular(metrics.pillRadius),
                  ),
                ),
              ),
            ),
            for (final OnboardingChapter chapter in OnboardingChapter.values)
              Positioned(
                left: metrics.centreOf(chapter.index) - _target / 2,
                top: 0,
                width: _target,
                height: _target,
                child: _ProgressMark(
                  chapter: chapter,
                  state: _stateOf(chapter),
                  mood: _markMood(chapter, mood),
                  metrics: metrics,
                  onOpen: () => onOpen(chapter),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProgressMark extends StatelessWidget {
  const _ProgressMark({
    required this.chapter,
    required this.state,
    required this.mood,
    required this.metrics,
    required this.onOpen,
  });

  final OnboardingChapter chapter;
  final _MarkState state;
  final Mood mood;
  final _FrameMetrics metrics;
  final VoidCallback onOpen;

  Widget _art(FieldNotesColors colors) => switch (state) {
    _MarkState.past => FlowerBloom.forMood(mood, size: metrics.flowerSize),
    _MarkState.current => Container(
      width: metrics.currentSize,
      height: metrics.currentSize,
      decoration: BoxDecoration(
        color: Palette.coral,
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Palette.coral.withValues(alpha: _currentRingAlpha),
            spreadRadius: metrics.currentRing,
          ),
        ],
      ),
    ),
    _MarkState.later => Container(
      width: metrics.laterSize,
      height: metrics.laterSize,
      decoration: BoxDecoration(color: colors.ink25, shape: BoxShape.circle),
    ),
  };

  @override
  Widget build(BuildContext context) {
    final bool past = state == _MarkState.past;
    final Widget slot = ExcludeSemantics(
      child: SizedBox(
        width: metrics.slotWidth,
        height: metrics.slotHeight,
        child: Center(child: _art(context.colors)),
      ),
    );
    return Semantics(
      container: true,
      button: past ? true : null,
      selected: state == _MarkState.current ? true : null,
      label: chapter.progressName,
      onTap: past ? onOpen : null,
      child: Center(
        child: past
            ? FocusRing(
                onPressed: onOpen,
                borderRadius: BorderRadius.all(
                  Radius.circular(metrics.slotHeight / 2),
                ),
                child: slot,
              )
            : slot,
      ),
    );
  }
}
