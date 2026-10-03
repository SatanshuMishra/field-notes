import 'dart:async';
import 'dart:math' as math;

import 'package:field_notes/app/shell/appearance_toggle.dart';
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/flowers/flower_bloom.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/motion/petal_drift.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/onboarding/chapters/day_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/garden_scene.dart';
import 'package:field_notes/features/onboarding/chapters/moment_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/month_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/opening_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/other_ways_panel.dart';
import 'package:field_notes/features/onboarding/chapters/reminder_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/theme_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/tour_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/week_chapter.dart';
import 'package:field_notes/features/onboarding/chapters/year_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding_chapter.dart';
import 'package:field_notes/features/onboarding/onboarding_controller.dart';
import 'package:field_notes/features/onboarding/onboarding_surface.dart';
import 'package:field_notes/features/onboarding/onboarding_swipe.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String onboardingBeginLabel = 'Begin';
const String onboardingNextLabel = 'Next';
const String onboardingStartLabelSidebar = 'Start journaling';
const String onboardingStartLabelBottomBar = 'Start';
const String onboardingDoneLabel = 'Done';
const String onboardingSkipToSetupLabel = 'Skip to setup';
const String onboardingSkipLabel = 'Skip';
const String onboardingBackLabel = 'Back';
const String onboardingBackTooltip = 'Back (←)';

const String onboardingSwipeOnLabel = 'swipe to continue';
const String onboardingSwipeLastLabel = 'swipe to start journaling';
const String onboardingGrowingLabel = 'growing…';
const String onboardingMomentCue = 'write a line or two';
const String onboardingMonthCue = 'drag the slider below';
const String onboardingYearCue = 'let the year grow';

const String onboardingPlantFirst = 'Tap anywhere to plant your seed first.';
const String onboardingMomentFirst = 'Write a line or two first.';
const String onboardingMonthFirst = 'Drag the slider to look ahead first.';
const String onboardingYearFirst = 'Let the year grow, or drag through it.';
const String onboardingStepFirst = 'One more step first.';

const Key onboardingProgressKey = ValueKey<String>('onboarding-progress');
const Key onboardingPrimaryKey = ValueKey<String>('onboarding-primary');
const Key onboardingSkipKey = ValueKey<String>('onboarding-skip');
const Key onboardingBackKey = ValueKey<String>('onboarding-back');
const Key onboardingToggleKey = ValueKey<String>('onboarding-toggle');
const Key onboardingControlBarKey = ValueKey<String>('onboarding-control-bar');
const Key onboardingCueKey = ValueKey<String>('onboarding-cue');
const Key onboardingCueTrackKey = ValueKey<String>('onboarding-cue-track');
const Key onboardingToastKey = ValueKey<String>('onboarding-toast');

const double onboardingTitleTop = 52;
const double onboardingPhoneTitleTop = 48;
const double onboardingControlBarReserve = 72;

const Duration onboardingBlockedToastLifetime = Duration(milliseconds: 2200);

const Key _petalsKey = ValueKey<String>('onboarding-petals');
const Key _sceneSlotKey = ValueKey<String>('onboarding-scene-slot');

const Duration _petalFade = Duration(milliseconds: 1200);
const Duration _cueLoop = Duration(milliseconds: 1800);
const Duration _toastRise = Duration(milliseconds: 300);

const String _arrow = '→';
const double _target = 48;
const double _errorGap = 6;
const double _errorMaxWidth = 320;
const double _pillRadius = 18;
const double _ringAlpha = 0.25;

const double _barSide = 12;
const double _barLift = 8;
const double _barHeight = 60;
const double _barPadding = 8;
const double _barRadius = 24;
const double _barGap = 8;
const double _phoneBack = 48;
const double _chevron = 18;
const double _chevronStroke = 2.4;
const double _phoneTopRow = 40;
const double _phoneTopGap = 4;
const double _phoneSkipHeight = 44;
const double _phoneSkipRight = 8;
const double _phoneSkipPadding = 12;
const double _phoneSkipAlpha = 0.8;
const double _phoneToggle = 44;
const double _phoneToggleTop = 2;
const double _phoneToggleLeft = 8;
const double _toastWidth = 270;
const double _toastLift = 86;
const double _toastRadius = 18;
const double _trackWidth = 34;
const double _trackHeight = 4;
const double _cueDot = 12;
const double _cueTravel = 22;
const double _cueGap = 5;

const double _macTop = 8;
const double _macSkipRight = 18;
const double _macSkipHeight = 36;
const double _macSkipPadding = 14;
const double _macBack = 46;
const double _macBackLeft = 28;
const double _macBackBottom = 20;
const double _macToggle = 36;
const double _macToggleTarget = _target;
const double _macToggleLeft = 18;

const Color _cream = Palette.creamOnSoil;
const Color _barScene = Color.fromRGBO(28, 22, 16, 0.38);
const Cubic _cueCurve = Cubic(0.5, 0, 0.3, 1);
const double _cueArrive = 0.7;
const double _cueShow = 0.15;
const List<Shadow> _creamShadow = <Shadow>[
  Shadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 1)),
];

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

class _ButtonMetrics {
  const _ButtonMetrics({
    required this.height,
    required this.radius,
    required this.padding,
    required this.labelSize,
    required this.right,
    required this.bottom,
  });

  final double height;
  final double radius;
  final double padding;
  final double labelSize;
  final double right;
  final double bottom;

  double get targetBottom => bottom - math.max(0, _target - height) / 2;
}

const _ButtonMetrics _sidebarButton = _ButtonMetrics(
  height: 46,
  radius: 14,
  padding: 22,
  labelSize: 14,
  right: 28,
  bottom: 20,
);

const _ButtonMetrics _bottomBarButton = _ButtonMetrics(
  height: 44,
  radius: 22,
  padding: 18,
  labelSize: 13.5,
  right: 14,
  bottom: 16,
);

class _MarkMetrics {
  const _MarkMetrics({
    required this.slotWidth,
    required this.slotHeight,
    required this.gap,
    required this.padding,
    required this.flowerSize,
    required this.currentSize,
    required this.currentRing,
    required this.laterSize,
  });

  final double slotWidth;
  final double slotHeight;
  final double gap;
  final EdgeInsets padding;
  final double flowerSize;
  final double currentSize;
  final double currentRing;
  final double laterSize;

  int get count => OnboardingChapter.values.length;

  double get pillWidth =>
      count * slotWidth + (count - 1) * gap + padding.horizontal;

  double get pillHeight => slotHeight + padding.vertical;

  double get overhang =>
      math.max(0, _target / 2 - padding.left - slotWidth / 2);

  double centreOf(int index) =>
      overhang + padding.left + slotWidth / 2 + index * (slotWidth + gap);
}

const _MarkMetrics _sidebarMarks = _MarkMetrics(
  slotWidth: 26,
  slotHeight: 26,
  gap: 4,
  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
  flowerSize: 20,
  currentSize: 12,
  currentRing: 4,
  laterSize: 7,
);

const _MarkMetrics _bottomBarMarks = _MarkMetrics(
  slotWidth: 22,
  slotHeight: 32,
  gap: 0,
  padding: EdgeInsets.symmetric(horizontal: 8),
  flowerSize: 15,
  currentSize: 10,
  currentRing: 3,
  laterSize: 6,
);

_MarkMetrics _marksFor(ShellLayout layout) => switch (layout) {
  ShellLayout.sidebar => _sidebarMarks,
  ShellLayout.bottomBar => _bottomBarMarks,
};

Mood _markMood(OnboardingChapter chapter, Mood chosen) => switch (chapter) {
  OnboardingChapter.opening => Mood.happy,
  OnboardingChapter.day => chosen,
  _ => _laterMarkMoods[chapter.index - OnboardingChapter.moment.index],
};

FlowerKind? _shedFlower(OnboardingChapter chapter, OnboardingDraft draft) =>
    switch (chapter) {
      OnboardingChapter.opening => draft.grown ? FlowerKind.peony : null,
      _ => draft.petalFlower,
    };

String _blockedMessage(OnboardingChapter chapter) => switch (chapter) {
  OnboardingChapter.opening => onboardingPlantFirst,
  OnboardingChapter.moment => onboardingMomentFirst,
  OnboardingChapter.month => onboardingMonthFirst,
  OnboardingChapter.year => onboardingYearFirst,
  _ => onboardingStepFirst,
};

String _waitingCue(OnboardingChapter chapter, OnboardingDraft draft) =>
    switch (chapter) {
      OnboardingChapter.opening => draft.planted ? onboardingGrowingLabel : '',
      OnboardingChapter.moment => onboardingMomentCue,
      OnboardingChapter.month => onboardingMonthCue,
      OnboardingChapter.year => onboardingYearCue,
      _ => '',
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

@immutable
class _Look {
  const _Look({required this.dark, required this.soil, required this.meadow});

  final bool dark;
  final bool soil;
  final bool meadow;

  bool get cream => dark || soil || meadow;

  GlassTone get glass => dark || meadow ? GlassTone.scene : GlassTone.paper;
}

class _OnboardingToastScope extends InheritedWidget {
  const _OnboardingToastScope({required this.show, required super.child});

  final void Function(String message, Duration lifetime) show;

  @override
  bool updateShouldNotify(_OnboardingToastScope oldWidget) =>
      show != oldWidget.show;
}

void showOnboardingToast(
  BuildContext context,
  String message, {
  Duration lifetime = onboardingBlockedToastLifetime,
}) => context.getInheritedWidgetOfExactType<_OnboardingToastScope>()?.show(
  message,
  lifetime,
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
  Timer? _toastTimer;
  String? _toast;
  int _toastCount = 0;

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
    _toastTimer?.cancel();
    FocusManager.instance.removeListener(_onFocusChanged);
    _focus.dispose();
    super.dispose();
  }

  OnboardingController get _controller =>
      ref.read(onboardingControllerProvider.notifier);

  bool get _phone => widget.layout == ShellLayout.bottomBar;

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

  void _showToast(String message, Duration lifetime) {
    _toastTimer?.cancel();
    setState(() {
      _toast = message;
      _toastCount++;
    });
    _toastTimer = Timer(lifetime, () {
      if (mounted) {
        setState(() => _toast = null);
      }
    });
  }

  OnboardingFlowRunning? get _runningFlow =>
      switch (ref.read(onboardingControllerProvider)) {
        final OnboardingFlowRunning running => running,
        OnboardingFlowHidden() || OnboardingFlowMap() => null,
      };

  bool _onOtherWays(OnboardingFlowRunning running) =>
      _phone &&
      running.chapter == OnboardingChapter.moment &&
      running.draft.showingOtherWays;

  bool _canSwipeBack() {
    final OnboardingFlowRunning? running = _runningFlow;
    return running != null &&
        (running.chapter != OnboardingChapter.opening || _onOtherWays(running));
  }

  void _forward() {
    final OnboardingFlowRunning? running = _runningFlow;
    if (running == null) {
      return;
    }
    if (_phone &&
        running.chapter == OnboardingChapter.moment &&
        !running.draft.showingOtherWays) {
      _controller.openOtherWays();
      return;
    }
    unawaited(_controller.next());
  }

  void _back() {
    final OnboardingFlowRunning? running = _runningFlow;
    if (running == null) {
      return;
    }
    if (_onOtherWays(running)) {
      _controller.closeOtherWays();
      return;
    }
    _controller.back();
    if (_phone && running.chapter == OnboardingChapter.month) {
      _controller.openOtherWays();
    }
  }

  void _blocked(OnboardingChapter chapter) {
    _showToast(_blockedMessage(chapter), onboardingBlockedToastLifetime);
  }

  _Look _lookOf(OnboardingChapter? chapter) => _Look(
    dark: Theme.of(context).brightness == Brightness.dark,
    soil:
        _phone &&
        (chapter == OnboardingChapter.opening ||
            chapter == OnboardingChapter.day),
    meadow: chapter == OnboardingChapter.year,
  );

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
    final Widget placed = Material(
      type: MaterialType.transparency,
      child: content,
    );
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Focus(
        focusNode: _focus,
        onKeyEvent: _onKey,
        child: DecoratedBox(
          decoration: _paper(context.colors, widget.layout),
          child: DecoratedBox(
            decoration: widget.layout == ShellLayout.sidebar
                ? _glow
                : const BoxDecoration(),
            child: _OnboardingToastScope(
              show: _showToast,
              child: _phone ? placed : SafeArea(child: placed),
            ),
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
    final OnboardingController controller = _controller;
    final bool ready = controller.canAdvance;
    final _Look look = _lookOf(chapter);
    final String? finishError = chapter == OnboardingChapter.tour
        ? draft.finishError
        : null;
    final Widget progress = _ProgressPill(
      key: onboardingProgressKey,
      layout: widget.layout,
      current: chapter,
      mood: draft.mood,
      look: look,
      onOpen: controller.goTo,
    );
    final bool otherWays =
        _phone && chapter == OnboardingChapter.moment && draft.showingOtherWays;
    final bool garden =
        chapter == OnboardingChapter.opening ||
        chapter == OnboardingChapter.day;
    return OnboardingSwipeArea(
      enabled: _phone,
      step: (chapter: chapter, otherWays: otherWays),
      canForward: () => _controller.canAdvance,
      canBack: _canSwipeBack,
      onForward: _forward,
      onBack: _back,
      onBlocked: () => _blocked(chapter),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          KeyedSubtree(
            key: _sceneSlotKey,
            child: garden
                ? GardenScene(key: gardenSceneKey, layout: widget.layout)
                : const SizedBox.shrink(),
          ),
          _InOrder(
            _Region.chapter,
            child: OnboardingSwipeContent(
              child: KeyedSubtree(
                key: ValueKey<({OnboardingChapter chapter, bool otherWays})>((
                  chapter: chapter,
                  otherWays: otherWays,
                )),
                child: otherWays
                    ? OtherWaysPanel(layout: widget.layout)
                    : _chapter(chapter),
              ),
            ),
          ),
          if (_shedFlower(chapter, draft) case final FlowerKind flower)
            _PetalVeil(
              key: _petalsKey,
              flower: flower,
              shown: chapter != OnboardingChapter.year,
            ),
          if (_phone)
            ..._phoneChrome(chapter, draft, look, progress, ready: ready)
          else
            ..._sidebarChrome(chapter, look, progress, ready: ready),
          if (finishError != null) _finishError(finishError),
          if (_toast case final String message)
            _ToastSlot(
              key: ValueKey<int>(_toastCount),
              message: message,
              bottom: _phone ? _gestureInset + _toastLift : _toastLift,
            ),
        ],
      ),
    );
  }

  double get _statusInset => MediaQuery.paddingOf(context).top;

  double get _gestureInset {
    final MediaQueryData media = MediaQuery.of(context);
    return math.max(media.padding.bottom, media.viewPadding.bottom);
  }

  List<Widget> _phoneChrome(
    OnboardingChapter chapter,
    OnboardingDraft draft,
    _Look look,
    Widget progress, {
    required bool ready,
  }) {
    final double status = _statusInset;
    final bool last = chapter == OnboardingChapter.tour;
    return <Widget>[
      Positioned(
        left: 0,
        right: 0,
        top: status + _phoneTopGap,
        height: _phoneTopRow,
        child: Center(child: _InOrder(_Region.progress, child: progress)),
      ),
      if (chapter.isStory)
        Positioned(
          top: status + _phoneTopGap,
          right: _phoneSkipRight,
          height: _phoneSkipHeight,
          child: _InOrder(
            _Region.skip,
            child: _PhoneSkip(
              ink: look.dark || look.meadow ? _cream : context.colors.ink,
              onPressed: _controller.skipToSetup,
            ),
          ),
        ),
      Positioned(
        top: status + _phoneToggleTop,
        left: _phoneToggleLeft,
        width: _phoneToggle,
        height: _phoneToggle,
        child: _InOrder(
          _Region.toggle,
          child: _GlassToggle(
            key: onboardingToggleKey,
            tone: look.glass,
            face: _phoneToggle,
            ink: look.meadow ? _cream : null,
          ),
        ),
      ),
      Positioned(
        key: onboardingControlBarKey,
        left: _barSide,
        right: _barSide,
        bottom: _gestureInset + _barLift,
        height: _barHeight,
        child: _ControlBar(
          look: look,
          back: _InOrder(
            _Region.back,
            child: _PhoneBack(
              look: look,
              shown: chapter != OnboardingChapter.opening,
              onPressed: _back,
            ),
          ),
          cue: _SwipeCue(
            key: onboardingCueKey,
            label: ready
                ? (last ? onboardingSwipeLastLabel : onboardingSwipeOnLabel)
                : _waitingCue(chapter, draft),
            track: ready,
            cream: look.cream,
          ),
        ),
      ),
    ];
  }

  List<Widget> _sidebarChrome(
    OnboardingChapter chapter,
    _Look look,
    Widget progress, {
    required bool ready,
  }) {
    return <Widget>[
      Positioned(
        left: 0,
        right: 0,
        top: _macTop - (_target - _sidebarMarks.pillHeight) / 2,
        child: Center(child: _InOrder(_Region.progress, child: progress)),
      ),
      if (chapter.isStory)
        Positioned(
          top: _macTop - (_target - _macSkipHeight) / 2,
          right: _macSkipRight,
          child: _InOrder(
            _Region.skip,
            child: _GlassSkip(
              tone: look.glass,
              ink: look.dark || look.meadow ? _cream : context.colors.ink,
              onPressed: _controller.skipToSetup,
            ),
          ),
        ),
      Positioned(
        top: _macTop - (_macToggleTarget - _macToggle) / 2,
        left: _macToggleLeft - (_macToggleTarget - _macToggle) / 2,
        width: _macToggleTarget,
        height: _macToggleTarget,
        child: _InOrder(
          _Region.toggle,
          child: _GlassToggle(
            key: onboardingToggleKey,
            tone: look.glass,
            face: _macToggle,
            ink: look.meadow ? _cream : null,
          ),
        ),
      ),
      if (chapter != OnboardingChapter.opening)
        Positioned(
          left: _macBackLeft - (_target - _macBack) / 2,
          bottom: _macBackBottom - (_target - _macBack) / 2,
          width: _target,
          height: _target,
          child: _InOrder(
            _Region.back,
            child: _GlassBack(
              tone: look.glass,
              ink: look.dark || look.meadow ? _cream : context.colors.ink,
              onPressed: _back,
            ),
          ),
        ),
      if (ready) _primary(_primaryLabel(chapter), _controller.next),
    ];
  }

  Widget _finishError(String message) {
    if (_phone) {
      return Positioned(
        left: _barSide + _barPadding,
        right: _barSide + _barPadding,
        bottom: _gestureInset + _barLift + _barHeight + _errorGap,
        child: _InOrder(
          _Region.problem,
          child: _FinishError(message: message, align: TextAlign.center),
        ),
      );
    }
    return Positioned(
      right: _sidebarButton.right,
      bottom: _sidebarButton.targetBottom + _target + _errorGap,
      child: _InOrder(
        _Region.problem,
        child: _FinishError(message: message, align: TextAlign.end),
      ),
    );
  }

  Widget _map() {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        _InOrder(_Region.chapter, child: TourChapter(layout: widget.layout)),
        _primary(onboardingDoneLabel, _controller.closeMap),
      ],
    );
  }

  Widget _primary(String label, VoidCallback onPressed) {
    final _ButtonMetrics metrics = _phone ? _bottomBarButton : _sidebarButton;
    return Positioned(
      right: metrics.right,
      bottom: metrics.targetBottom + (_phone ? _gestureInset : 0),
      child: _InOrder(
        _Region.action,
        child: OnboardingPrimaryButton(
          key: onboardingPrimaryKey,
          label: label,
          onPressed: onPressed,
          height: metrics.height,
          borderRadius: BorderRadius.all(Radius.circular(metrics.radius)),
          padding: EdgeInsets.symmetric(horizontal: metrics.padding),
          trailing: _arrow,
          labelStyle: TextStyle(
            fontFamily: TypographyTokens.sans,
            fontSize: metrics.labelSize,
            fontWeight: FontWeight.w600,
            color: Palette.onAccent,
          ),
        ),
      ),
    );
  }
}

enum _Region { toggle, skip, chapter, progress, problem, back, action }

class _InOrder extends StatelessWidget {
  const _InOrder(this.region, {required this.child});

  final _Region region;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double order = region.index.toDouble();
    return FocusTraversalOrder(
      order: NumericFocusOrder(order),
      child: FocusTraversalGroup(
        child: Semantics(
          container: true,
          sortKey: OrdinalSortKey(order),
          child: child,
        ),
      ),
    );
  }
}

class _PetalVeil extends StatefulWidget {
  const _PetalVeil({super.key, required this.flower, required this.shown});

  final FlowerKind flower;
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
      child: PetalDrift(flower: widget.flower),
      builder: (BuildContext context, Widget? petals) => _fade.isDismissed
          ? const SizedBox.shrink()
          : Opacity(opacity: Curves.ease.transform(_fade.value), child: petals),
    );
  }
}

class _FinishError extends StatelessWidget {
  const _FinishError({required this.message, required this.align});

  final String message;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _errorMaxWidth),
      child: Semantics(
        liveRegion: true,
        child: Text(
          message,
          textAlign: align,
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

class _ToastSlot extends StatefulWidget {
  const _ToastSlot({super.key, required this.message, required this.bottom});

  final String message;
  final double bottom;

  @override
  State<_ToastSlot> createState() => _ToastSlotState();
}

class _ToastSlotState extends State<_ToastSlot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rise = AnimationController(
    vsync: this,
    duration: _toastRise,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _rise.value = 1;
    } else if (_rise.isDismissed) {
      _rise.forward();
    }
  }

  @override
  void dispose() {
    _rise.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: widget.bottom,
      child: IgnorePointer(
        child: Center(
          child: AnimatedBuilder(
            animation: _rise,
            builder: (BuildContext context, Widget? child) {
              final double shown = Curves.easeOut.transform(_rise.value);
              return Transform.translate(
                offset: Offset(0, 10 * (1 - shown)),
                child: _toast(shown),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _toast(double shown) {
    return SizedBox(
      key: onboardingToastKey,
      width: _toastWidth,
      child: Semantics(
        liveRegion: true,
        container: true,
        child: GlassSurface(
          tone: GlassTone.toast,
          opacity: shown,
          borderRadius: const BorderRadius.all(Radius.circular(_toastRadius)),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Text(
            widget.message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: TypographyTokens.sans,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              height: 1.35,
              color: _cream,
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlBar extends StatelessWidget {
  const _ControlBar({
    required this.look,
    required this.back,
    required this.cue,
  });

  final _Look look;
  final Widget back;
  final Widget cue;

  @override
  Widget build(BuildContext context) {
    final Widget columns = Padding(
      padding: const EdgeInsets.symmetric(horizontal: _barPadding),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Align(alignment: Alignment.centerLeft, child: back),
          ),
          const SizedBox(width: _barGap),
          cue,
          const SizedBox(width: _barGap),
          const Expanded(child: SizedBox.shrink()),
        ],
      ),
    );
    if (!look.meadow) {
      return columns;
    }
    return GlassSurface(
      tone: GlassTone.scene,
      tint: _barScene,
      borderRadius: const BorderRadius.all(Radius.circular(_barRadius)),
      child: columns,
    );
  }
}

class _SwipeCue extends StatefulWidget {
  const _SwipeCue({
    super.key,
    required this.label,
    required this.track,
    required this.cream,
  });

  final String label;
  final bool track;
  final bool cream;

  @override
  State<_SwipeCue> createState() => _SwipeCueState();
}

class _SwipeCueState extends State<_SwipeCue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: _cueLoop,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _follow();
  }

  @override
  void didUpdateWidget(_SwipeCue oldWidget) {
    super.didUpdateWidget(oldWidget);
    _follow();
  }

  void _follow() {
    if (!widget.track || MediaQuery.disableAnimationsOf(context)) {
      _loop.stop();
      _loop.value = _cueArrive;
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color ink = widget.cream ? _cream : context.colors.ink;
    final Color text = widget.cream ? _cream : FieldNotesColors.light.mutedDeep;
    final String label = widget.label;
    return IgnorePointer(
      child: Semantics(
        container: true,
        label: label.isEmpty ? null : label,
        child: ExcludeSemantics(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (widget.track) ...<Widget>[
                SizedBox(
                  key: onboardingCueTrackKey,
                  width: _trackWidth,
                  height: _cueDot,
                  child: AnimatedBuilder(
                    animation: _loop,
                    builder: (BuildContext context, Widget? _) => CustomPaint(
                      painter: _CuePainter(ink: ink, progress: _loop.value),
                    ),
                  ),
                ),
                const SizedBox(width: _cueGap),
              ],
              Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontFamily: TypographyTokens.sans,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: text,
                  shadows: widget.cream ? _creamShadow : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CuePainter extends CustomPainter {
  const _CuePainter({required this.ink, required this.progress});

  final Color ink;
  final double progress;

  double get _left {
    final double travelled = _cueCurve.transform(
      (progress / _cueArrive).clamp(0.0, 1.0),
    );
    return _cueTravel * (1 - travelled);
  }

  double get _opacity {
    if (progress < _cueShow) {
      return _cueCurve.transform((progress / _cueShow).clamp(0.0, 1.0));
    }
    if (progress <= _cueArrive) {
      return 1;
    }
    return 1 -
        _cueCurve.transform(
          ((progress - _cueArrive) / (1 - _cueArrive)).clamp(0.0, 1.0),
        );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final double middle = size.height / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, middle - _trackHeight / 2, _trackWidth, _trackHeight),
        const Radius.circular(_trackHeight / 2),
      ),
      Paint()..color = ink.withValues(alpha: 0.22),
    );
    final double alpha = _opacity.clamp(0.0, 1.0);
    if (alpha <= 0) {
      return;
    }
    final Offset centre = Offset(_left + _cueDot / 2, middle);
    canvas.drawCircle(
      centre,
      _cueDot / 2 + 3,
      Paint()..color = ink.withValues(alpha: 0.18 * alpha),
    );
    canvas.drawCircle(
      centre,
      _cueDot / 2,
      Paint()..color = ink.withValues(alpha: 0.9 * alpha),
    );
  }

  @override
  bool shouldRepaint(_CuePainter oldDelegate) =>
      oldDelegate.ink != ink || oldDelegate.progress != progress;
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double scale = size.shortestSide / 24;
    canvas.save();
    canvas.scale(scale);
    canvas.drawPath(
      Path()
        ..moveTo(15, 5)
        ..lineTo(8, 12)
        ..lineTo(15, 19),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _chevronStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.color != color;
}

class _Chevron extends StatelessWidget {
  const _Chevron({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _chevron,
      child: CustomPaint(painter: _ChevronPainter(color)),
    );
  }
}

class _PhoneBack extends StatelessWidget {
  const _PhoneBack({
    required this.look,
    required this.shown,
    required this.onPressed,
  });

  final _Look look;
  final bool shown;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Color ink = look.cream ? _cream : context.colors.ink;
    final BoxBorder border = look.meadow
        ? Border.all(color: _cream.withValues(alpha: 0.28))
        : Border.all(
            color: look.dark || look.soil
                ? _cream.withValues(alpha: 0.5)
                : context.colors.ink.withValues(alpha: 0.35),
            width: 1.5,
          );
    const BorderRadius round = BorderRadius.all(
      Radius.circular(_phoneBack / 2),
    );
    return Visibility(
      visible: shown,
      maintainSize: true,
      maintainAnimation: true,
      maintainState: true,
      child: Semantics(
        key: onboardingBackKey,
        button: true,
        label: onboardingBackLabel,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: FocusRing(
            onPressed: onPressed,
            borderRadius: round,
            surface: look.cream
                ? FocusRingSurface.dark
                : FocusRingSurface.light,
            child: SizedBox.square(
              dimension: _phoneBack,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: look.meadow ? _cream.withValues(alpha: 0.14) : null,
                  border: border,
                ),
                child: Center(
                  child: ExcludeSemantics(child: _Chevron(color: ink)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassBack extends StatelessWidget {
  const _GlassBack({
    required this.tone,
    required this.ink,
    required this.onPressed,
  });

  final GlassTone tone;
  final Color ink;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const BorderRadius round = BorderRadius.all(Radius.circular(_macBack / 2));
    return Semantics(
      key: onboardingBackKey,
      button: true,
      label: onboardingBackLabel,
      child: Tooltip(
        message: onboardingBackTooltip,
        excludeFromSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: Center(
            child: FocusRing(
              onPressed: onPressed,
              borderRadius: round,
              child: GlassSurface(
                tone: tone,
                borderRadius: round,
                child: SizedBox.square(
                  dimension: _macBack,
                  child: Center(
                    child: ExcludeSemantics(child: _Chevron(color: ink)),
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

class _GlassToggle extends StatelessWidget {
  const _GlassToggle({
    super.key,
    required this.tone,
    required this.face,
    required this.ink,
  });

  final GlassTone tone;
  final double face;
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    final BorderRadius round = BorderRadius.all(Radius.circular(face / 2));
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Center(
          child: SizedBox.square(
            dimension: face,
            child: GlassSurface(
              tone: tone,
              borderRadius: round,
              child: const SizedBox.expand(),
            ),
          ),
        ),
        Positioned.fill(child: AppearanceToggle(ink: ink)),
      ],
    );
  }
}

class _PhoneSkip extends StatelessWidget {
  const _PhoneSkip({required this.ink, required this.onPressed});

  final Color ink;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: onboardingSkipKey,
      button: true,
      label: onboardingSkipLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: FocusRing(
          onPressed: onPressed,
          borderRadius: const BorderRadius.all(
            Radius.circular(_phoneSkipHeight / 2),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: _phoneSkipHeight,
              minHeight: _phoneSkipHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _phoneSkipPadding,
              ),
              child: Center(
                widthFactor: 1,
                child: ExcludeSemantics(
                  child: Text(
                    onboardingSkipLabel,
                    maxLines: 1,
                    style: TextStyle(
                      fontFamily: TypographyTokens.sans,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: ink.withValues(alpha: ink.a * _phoneSkipAlpha),
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

class _GlassSkip extends StatelessWidget {
  const _GlassSkip({
    required this.tone,
    required this.ink,
    required this.onPressed,
  });

  final GlassTone tone;
  final Color ink;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const BorderRadius radius = BorderRadius.all(Radius.circular(_pillRadius));
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
              child: GlassSurface(
                tone: tone,
                borderRadius: radius,
                padding: const EdgeInsets.symmetric(
                  horizontal: _macSkipPadding,
                ),
                child: SizedBox(
                  height: _macSkipHeight,
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
                          color: ink,
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

class _ProgressPill extends StatelessWidget {
  const _ProgressPill({
    super.key,
    required this.layout,
    required this.current,
    required this.mood,
    required this.look,
    required this.onOpen,
  });

  final ShellLayout layout;
  final OnboardingChapter current;
  final Mood mood;
  final _Look look;
  final ValueChanged<OnboardingChapter> onOpen;

  _MarkState _stateOf(OnboardingChapter chapter) {
    if (chapter.index < current.index) {
      return _MarkState.past;
    }
    return chapter == current ? _MarkState.current : _MarkState.later;
  }

  void _openNearest(_MarkMetrics metrics, Offset local) {
    final int index =
        ((local.dx - metrics.centreOf(0)) / (metrics.slotWidth + metrics.gap))
            .round()
            .clamp(0, metrics.count - 1);
    final OnboardingChapter chapter = OnboardingChapter.values[index];
    if (_stateOf(chapter) == _MarkState.past) {
      onOpen(chapter);
    }
  }

  Widget _pill(_MarkMetrics metrics, Color later, {required bool marks}) {
    return GlassSurface(
      tone: look.glass,
      borderRadius: const BorderRadius.all(Radius.circular(_pillRadius)),
      padding: metrics.padding,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final OnboardingChapter chapter
              in OnboardingChapter.values) ...<Widget>[
            if (chapter.index > 0 && metrics.gap > 0)
              SizedBox(width: metrics.gap),
            marks
                ? _ProgressMark(
                    chapter: chapter,
                    state: _stateOf(chapter),
                    mood: _markMood(chapter, mood),
                    metrics: metrics,
                    later: later,
                    onOpen: () => onOpen(chapter),
                  )
                : _MarkArt(
                    state: _stateOf(chapter),
                    mood: _markMood(chapter, mood),
                    metrics: metrics,
                    later: later,
                  ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final _MarkMetrics metrics = _marksFor(layout);
    final Color later = look.dark
        ? _cream.withValues(alpha: 0.45)
        : context.colors.ink.withValues(alpha: 0.28);
    if (layout == ShellLayout.bottomBar) {
      return _pill(metrics, later, marks: true);
    }
    return SizedBox(
      width: metrics.pillWidth + 2 * metrics.overhang,
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
              top: (_target - metrics.pillHeight) / 2,
              width: metrics.pillWidth,
              height: metrics.pillHeight,
              child: ExcludeSemantics(
                child: _pill(metrics, later, marks: false),
              ),
            ),
            for (final OnboardingChapter chapter in OnboardingChapter.values)
              Positioned(
                left: metrics.centreOf(chapter.index) - _target / 2,
                top: 0,
                width: _target,
                height: _target,
                child: _MarkTarget(
                  chapter: chapter,
                  state: _stateOf(chapter),
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

class _MarkArt extends StatelessWidget {
  const _MarkArt({
    required this.state,
    required this.mood,
    required this.metrics,
    required this.later,
  });

  final _MarkState state;
  final Mood mood;
  final _MarkMetrics metrics;
  final Color later;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox(
        width: metrics.slotWidth,
        height: metrics.slotHeight,
        child: Center(
          child: switch (state) {
            _MarkState.past => FlowerBloom.forMood(
              mood,
              size: metrics.flowerSize,
            ),
            _MarkState.current => Container(
              width: metrics.currentSize,
              height: metrics.currentSize,
              decoration: BoxDecoration(
                color: Palette.coral,
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Palette.coral.withValues(alpha: _ringAlpha),
                    spreadRadius: metrics.currentRing,
                  ),
                ],
              ),
            ),
            _MarkState.later => Container(
              width: metrics.laterSize,
              height: metrics.laterSize,
              decoration: BoxDecoration(color: later, shape: BoxShape.circle),
            ),
          },
        ),
      ),
    );
  }
}

class _MarkTarget extends StatelessWidget {
  const _MarkTarget({
    required this.chapter,
    required this.state,
    required this.metrics,
    required this.onOpen,
  });

  final OnboardingChapter chapter;
  final _MarkState state;
  final _MarkMetrics metrics;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final bool past = state == _MarkState.past;
    final Widget slot = SizedBox(
      width: metrics.slotWidth,
      height: metrics.slotHeight,
    );
    return Semantics(
      container: true,
      button: past ? true : null,
      selected: state == _MarkState.current ? true : null,
      label: chapter.progressName,
      onTap: past ? onOpen : null,
      child: Listener(
        behavior: HitTestBehavior.opaque,
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
    required this.later,
    required this.onOpen,
  });

  final OnboardingChapter chapter;
  final _MarkState state;
  final Mood mood;
  final _MarkMetrics metrics;
  final Color later;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final bool past = state == _MarkState.past;
    final Widget slot = _MarkArt(
      state: state,
      mood: mood,
      metrics: metrics,
      later: later,
    );
    return Semantics(
      container: true,
      button: past ? true : null,
      selected: state == _MarkState.current ? true : null,
      label: chapter.progressName,
      onTap: past ? onOpen : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: past ? onOpen : null,
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
