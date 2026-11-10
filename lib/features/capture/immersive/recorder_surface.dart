import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/app/shell/windows_caption_buttons.dart';
import 'package:field_notes/design/feedback/toast.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/focus/keyboard_focus_builder.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/motion/motion_tokens.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/domain/platform/desktop_platform.dart';
import 'package:field_notes/features/capture/core/capture_day_line.dart';
import 'package:field_notes/features/entry_cards/cards/video_controls_overlay.dart'
    show canAutoHideVideoControls, videoControlsVisible;
import 'package:field_notes/state/repository_providers.dart';

import 'recorder_chrome.dart';
import 'recorder_glass_button.dart';
import 'stage_phase.dart';

enum RecorderArrangement { voice, video }

const Key recorderLeaveKey = ValueKey<String>('recorder-leave');
const Key recorderTopBandKey = ValueKey<String>('recorder-top-band');
const Key recorderTitleFieldKey = ValueKey<String>('recorder-title-field');

const String recorderLeaveLabel = 'Leave';
const String recorderTitlePlaceholder = 'Add a title';
const String recorderTitleLabel = 'Title';
const String recorderTitleFailedMessage =
    'Could not save your title. Try again.';

const Color recorderStageColor = Palette.mediaGround;

const Color _chromeInk = Color(0xFFB7A58C);
const Color _dayLineLeadInk = Color(0xFFE692A0);
const Color _leaveGlyphInk = Color(0xCCFFFFFF);
const Color _leaveGlyphInkBottomBar = Color(0xBFFFFFFF);

const double _minTapTarget = 48;
const double _bandHeight = _minTapTarget;
const double _sidebarBandInset = 18;
const double _bottomBarBandInset = 8;
const double _bottomBarBandTop = 4;
const double _dayLineShare = 0.5;
const double _dayLineGap = 6;
const double _sidebarLeadSize = 17;
const double _bottomBarLeadSize = 15;
const double _sidebarChromeSize = 12;
const double _bottomBarChromeSize = 10;
const double _sidebarLeaveGlyph = 13;
const double _bottomBarLeaveGlyph = 18;
const double _glassLeaveGlyph = 15;
const double _leaveGap = 7;
const EdgeInsets _leavePadding = EdgeInsets.fromLTRB(9, 7, 12, 7);
const BorderRadius _leaveRadius = BorderRadius.all(Radius.circular(10));
const double _disabledOpacity = 0.5;

const double _voiceQuestionGapSidebar = 18;
const double _voiceQuestionGapBottomBar = 22;
const double _videoQuestionGapSidebar = 34;
const double _videoQuestionGapBottomBar = 10;
const double _sidebarQuestionMaxWidth = 720;
const double _sidebarQuestionGutter = 40;
const double _bottomBarQuestionGutter = 26;
const double _sidebarStatusGutter = 30;
const double _bottomBarStatusGutter = 28;
const double _videoStatusGutter = 20;

const double _voiceActionsHeight = 118;
const double _videoActionsHeightSidebar = 128;
const double _videoActionsHeightBottomBar = 124;
const double _sidebarActionsGutter = 18;
const double _bottomBarActionsGutter = 16;
const double _voiceActionsFootBottomBar = 26;
const double _videoActionsFootSidebar = 10;
const double _videoActionsFootBottomBar = 22;

const Color _titleInk = Color(0xFFF3E6D1);
const Color _titlePlaceholderOnStage = _chromeInk;
const Color _titlePlaceholderOverPicture = Color(0xFFE7D9C2);
const Color _titleCaret = Color(0xFFE3889A);
const Color _titleShadow = Color(0xB80E0B09);
const Offset _titleShadowOffset = Offset(0, 1);
const double _titleShadowBlur = 10;
const double _sidebarTitleSize = 24;
const double _bottomBarTitleSize = 20;
const double _titleLeading = 1.25;
const double _sidebarTitleHeight = 44;
const double _bottomBarTitleHeight = _minTapTarget;
const double _titleGutter = 24;
const double _titleMaxWidth = 560;
const double _titleRingOutset = 2;
const BorderRadius _titleRadius = BorderRadius.all(Radius.circular(8));
const Duration _titleSaveTimeout = Duration(seconds: 20);

const BoxDecoration _sidebarGlow = BoxDecoration(
  gradient: RadialGradient(
    center: Alignment(0, 0.2),
    radius: 1,
    colors: <Color>[Color(0x2BB8566A), Color(0x00B8566A)],
    stops: <double>[0, 0.72],
    transform: _EllipseToBox(
      focus: Alignment(0, 0.2),
      widthShare: 0.58,
      heightShare: 0.58,
    ),
  ),
);

const BoxDecoration _bottomBarGlow = BoxDecoration(
  gradient: RadialGradient(
    center: Alignment(0, 0.16),
    radius: 1,
    colors: <Color>[Color(0x2EB8566A), Color(0x00B8566A)],
    stops: <double>[0, 0.72],
    transform: _EllipseToBox(
      focus: Alignment(0, 0.16),
      widthShare: 0.85,
      heightShare: 0.48,
    ),
  ),
);

const BoxDecoration _veil = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[
      Color(0xCC14100C),
      Color(0x0014100C),
      Color(0x0014100C),
      Color(0xE014100C),
    ],
    stops: <double>[0, 0.34, 0.58, 1],
  ),
);

class RecorderSurface extends StatelessWidget {
  const RecorderSurface({
    super.key,
    required this.onLeave,
    this.dayLine,
    this.arrangement = RecorderArrangement.voice,
    this.glow = true,
    this.background,
    this.trailing,
    this.title,
    this.question,
    this.centre,
    this.status,
    this.actions,
    this.leaveKey = recorderLeaveKey,
    this.glassLeave = false,
    this.feedGestures,
    this.chromeOpacity = kAlwaysCompleteAnimation,
  });

  final CaptureDayLine? dayLine;
  final VoidCallback? onLeave;
  final RecorderArrangement arrangement;
  final bool glow;
  final Widget? background;
  final Widget? trailing;
  final Widget? title;
  final Widget? question;
  final Widget? centre;
  final Widget? status;
  final Widget? actions;
  final Key leaveKey;
  final bool glassLeave;
  final Widget? feedGestures;
  final Animation<double> chromeOpacity;

  @override
  Widget build(BuildContext context) {
    final bool sidebar = stageLayoutOf(context) == ShellLayout.sidebar;
    final Widget stage = _Stage(surface: this, sidebar: sidebar);
    if (sidebar) {
      return DarkCaptionSurface(child: stage);
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: stage,
    );
  }
}

class _Stage extends StatelessWidget {
  const _Stage({required this.surface, required this.sidebar});

  final RecorderSurface surface;
  final bool sidebar;

  bool get _voice => surface.arrangement == RecorderArrangement.voice;

  @override
  Widget build(BuildContext context) {
    final Widget? background = surface.background;
    final Widget? feedGestures = surface.feedGestures;
    return ColoredBox(
      color: recorderStageColor,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (background != null) ...<Widget>[
            background,
            FadeTransition(
              opacity: surface.chromeOpacity,
              child: const DecoratedBox(decoration: _veil),
            ),
          ],
          if (surface.glow)
            DecoratedBox(decoration: sidebar ? _sidebarGlow : _bottomBarGlow),
          if (feedGestures != null) _quietWhenHidden(feedGestures),
          Column(
            children: <Widget>[
              _band(context),
              _titleSlot(),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.paddingOf(context).bottom,
                  ),
                  child: _body(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _band(BuildContext context) {
    final Widget row = LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final CaptureDayLine? line = surface.dayLine;
        if (!sidebar) {
          return Row(
            children: <Widget>[
              _faded(_leave()),
              Expanded(
                child: line == null
                    ? const SizedBox.shrink()
                    : Center(child: _faded(_dayLine(context, line))),
              ),
              if (surface.trailing case final Widget trailing) trailing,
            ],
          );
        }
        return Row(
          children: <Widget>[
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _faded(_leave()),
              ),
            ),
            if (line != null)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: constraints.maxWidth * _dayLineShare,
                ),
                child: _faded(_dayLine(context, line)),
              ),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: surface.trailing,
              ),
            ),
          ],
        );
      },
    );
    if (!sidebar) {
      return Padding(
        padding: EdgeInsets.fromLTRB(
          _bottomBarBandInset,
          MediaQuery.paddingOf(context).top + _bottomBarBandTop,
          _bottomBarBandInset,
          0,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _bandHeight),
          child: row,
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const WindowDragBand(
          key: recorderTopBandKey,
          height: shellTitleBarHeight,
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _bandHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _sidebarBandInset),
            child: row,
          ),
        ),
      ],
    );
  }

  Widget _titleSlot() {
    final Widget? title = surface.title;
    if (title == null) {
      return const SizedBox.shrink();
    }
    return _faded(
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: _titleGutter),
        child: Center(
          heightFactor: 1,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _titleMaxWidth),
            child: title,
          ),
        ),
      ),
    );
  }

  Widget _faded(Widget child) {
    return FadeTransition(
      opacity: surface.chromeOpacity,
      child: _quietWhenHidden(child),
    );
  }

  Widget _quietWhenHidden(Widget child) {
    final Animation<double> opacity = surface.chromeOpacity;
    return AnimatedBuilder(
      animation: opacity,
      builder: (BuildContext context, Widget? quiet) => IgnorePointer(
        ignoring: opacity.value == 0,
        child: TickerMode(enabled: opacity.value > 0, child: quiet!),
      ),
      child: child,
    );
  }

  Widget _leave() {
    final VoidCallback? onLeave = surface.onLeave;
    final bool enabled = onLeave != null;
    if (surface.glassLeave) {
      return RecorderGlassButton(
        key: surface.leaveKey,
        label: recorderLeaveLabel,
        onPressed: onLeave,
        glyph: const IconStickerGlyphIcon(
          glyph: IconStickerGlyph.close,
          color: _leaveGlyphInkBottomBar,
          size: _glassLeaveGlyph,
        ),
      );
    }
    return Pressable(
      key: surface.leaveKey,
      label: recorderLeaveLabel,
      onPressed: onLeave,
      surface: FocusRingSurface.dark,
      borderRadius: _leaveRadius,
      child: Opacity(
        opacity: enabled ? 1.0 : _disabledOpacity,
        child: sidebar ? _leaveText() : _leaveGlyph(),
      ),
    );
  }

  Widget _leaveText() {
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minWidth: _minTapTarget,
        minHeight: _minTapTarget,
      ),
      child: const Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Padding(
          padding: _leavePadding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconStickerGlyphIcon(
                glyph: IconStickerGlyph.close,
                color: _leaveGlyphInk,
                size: _sidebarLeaveGlyph,
              ),
              SizedBox(width: _leaveGap),
              Text(
                recorderLeaveLabel,
                style: TextStyle(
                  fontFamily: TypographyTokens.sans,
                  fontSize: _sidebarChromeSize,
                  fontWeight: FontWeight.w500,
                  color: _chromeInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _leaveGlyph() {
    return const SizedBox.square(
      dimension: _minTapTarget,
      child: Center(
        child: IconStickerGlyphIcon(
          glyph: IconStickerGlyph.close,
          color: _leaveGlyphInkBottomBar,
          size: _bottomBarLeaveGlyph,
        ),
      ),
    );
  }

  Widget _dayLine(BuildContext context, CaptureDayLine line) {
    final List<Shadow>? shadows = surface.background == null
        ? null
        : const <Shadow>[
            Shadow(
              color: _titleShadow,
              offset: _titleShadowOffset,
              blurRadius: _titleShadowBlur,
            ),
          ];
    return Semantics(
      container: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: <Widget>[
          Text(
            line.lead,
            style: TextStyle(
              fontFamily: TypographyTokens.accent,
              fontSize: sidebar ? _sidebarLeadSize : _bottomBarLeadSize,
              fontWeight: FontWeight.w600,
              color: _dayLineLeadInk,
              shadows: shadows,
            ),
          ),
          const SizedBox(width: _dayLineGap),
          Flexible(
            child: Text(
              line.date,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TypographyTokens.sans,
                fontSize: sidebar ? _sidebarChromeSize : _bottomBarChromeSize,
                fontWeight: FontWeight.w500,
                color: _chromeInk,
                shadows: shadows,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double get _questionGap {
    if (_voice) {
      return sidebar ? _voiceQuestionGapSidebar : _voiceQuestionGapBottomBar;
    }
    return sidebar ? _videoQuestionGapSidebar : _videoQuestionGapBottomBar;
  }

  Widget _body() {
    final Widget? question = surface.question;
    final Widget? centre = _voice ? _voiceGroup() : surface.centre;
    final Widget? status = _voice ? null : surface.status;
    return CustomMultiChildLayout(
      delegate: _StageBodyDelegate(
        questionGap: _questionGap,
        reserveCentre: _voice,
      ),
      children: <Widget>[
        if (centre != null) LayoutId(id: _Slot.centre, child: centre),
        if (question != null)
          LayoutId(id: _Slot.question, child: _faded(_questionFrame(question))),
        if (status != null)
          LayoutId(
            id: _Slot.status,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: _videoStatusGutter,
              ),
              child: _faded(status),
            ),
          ),
        LayoutId(id: _Slot.actions, child: _faded(_actionsFrame())),
      ],
    );
  }

  Widget? _voiceGroup() {
    final Widget? centre = surface.centre;
    final Widget? status = surface.status;
    if (centre == null && status == null) {
      return null;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ?centre,
        if (status != null)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: sidebar
                  ? _sidebarStatusGutter
                  : _bottomBarStatusGutter,
            ),
            child: _faded(status),
          ),
      ],
    );
  }

  Widget _questionFrame(Widget question) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: sidebar ? _sidebarQuestionGutter : _bottomBarQuestionGutter,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: sidebar
              ? _sidebarQuestionMaxWidth - 2 * _sidebarQuestionGutter
              : double.infinity,
        ),
        child: question,
      ),
    );
  }

  Widget _actionsFrame() {
    final double height = _voice
        ? _voiceActionsHeight
        : (sidebar ? _videoActionsHeightSidebar : _videoActionsHeightBottomBar);
    final double foot = switch ((_voice, sidebar)) {
      (true, true) => 0,
      (true, false) => _voiceActionsFootBottomBar,
      (false, true) => _videoActionsFootSidebar,
      (false, false) => _videoActionsFootBottomBar,
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(
        sidebar ? _sidebarActionsGutter : _bottomBarActionsGutter,
        0,
        sidebar ? _sidebarActionsGutter : _bottomBarActionsGutter,
        foot,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: height),
        child: Center(heightFactor: 1, child: surface.actions),
      ),
    );
  }
}

class RecorderFadeSwitch extends StatefulWidget {
  const RecorderFadeSwitch({super.key, this.child, this.collapsing = false});

  final Widget? child;
  final bool collapsing;

  @override
  State<RecorderFadeSwitch> createState() => _RecorderFadeSwitchState();
}

class _RecorderFadeSwitchState extends State<RecorderFadeSwitch> {
  int _generation = 0;

  static Widget _fadeSlot(Widget child, Animation<double> animation) =>
      _FadeSlot(animation: animation, child: child);

  static Widget _collapsingFadeSlot(
    Widget child,
    Animation<double> animation,
  ) => SizeTransition(
    sizeFactor: animation,
    alignment: Alignment.topCenter,
    fixedCrossAxisSizeFactor: 1,
    child: _FadeSlot(animation: animation, child: child),
  );

  static bool _holdsSameContent(Widget? before, Widget? after) {
    if (before == null || after == null) {
      return before == after;
    }
    return Widget.canUpdate(before, after);
  }

  @override
  void didUpdateWidget(RecorderFadeSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_holdsSameContent(oldWidget.child, widget.child)) {
      _generation += 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : Motion.fade,
      switchInCurve: Motion.fadeCurve,
      switchOutCurve: Motion.fadeCurve,
      transitionBuilder: widget.collapsing ? _collapsingFadeSlot : _fadeSlot,
      child: KeyedSubtree(
        key: ValueKey<int>(_generation),
        child: widget.child ?? const SizedBox.shrink(),
      ),
    );
  }
}

class _FadeSlot extends StatelessWidget {
  const _FadeSlot({required this.animation, required this.child});

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: animation,
      child: AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? content) {
          final bool leaving = animation.status == AnimationStatus.reverse;
          return ExcludeFocus(
            excluding: leaving,
            child: IgnorePointer(ignoring: leaving, child: content),
          );
        },
        child: child,
      ),
    );
  }
}

mixin RecorderChromeFade<T extends StatefulWidget> on State<T>, TickerProvider {
  late final AnimationController _chrome = AnimationController(
    vsync: this,
    duration: Motion.fade,
    value: 1,
  );
  late final CurvedAnimation _chromeOpacity = CurvedAnimation(
    parent: _chrome,
    curve: Motion.fadeCurve,
  );
  late final Animation<double> _takeIndicatorOpacity = ReverseAnimation(
    _chromeOpacity,
  );
  Timer? _chromeTimer;
  bool _chromeHidden = false;
  bool _focusWithin = false;
  bool _accessibleNavigation = false;
  bool _autoHideArmed = false;

  bool get chromeControlsEnabled;

  bool get takeIsRunning;

  Animation<double> get chromeOpacity => _chromeOpacity;

  Animation<double> get takeIndicatorOpacity => _takeIndicatorOpacity;

  bool get showsTakeIndicator => _chromeHidden || !_chrome.isCompleted;

  @override
  void initState() {
    super.initState();
    _chrome.addStatusListener(_onChromeStatus);
    SemanticsBinding.instance.addSemanticsEnabledListener(
      _onSemanticsEnabledChanged,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _chrome.duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Motion.fade;
    _accessibleNavigation = _readAccessibleNavigation();
    followChrome();
  }

  @override
  void dispose() {
    SemanticsBinding.instance.removeSemanticsEnabledListener(
      _onSemanticsEnabledChanged,
    );
    _chromeTimer?.cancel();
    _chromeTimer = null;
    _chrome.removeStatusListener(_onChromeStatus);
    _chromeOpacity.dispose();
    _chrome.dispose();
    super.dispose();
  }

  bool _readAccessibleNavigation() {
    final bool navigation = MediaQuery.accessibleNavigationOf(context);
    if (isDesktopPlatform(Theme.of(context).platform)) {
      return navigation || SemanticsBinding.instance.semanticsEnabled;
    }
    return navigation;
  }

  void _onSemanticsEnabledChanged() {
    if (!mounted) {
      return;
    }
    setState(() => _accessibleNavigation = _readAccessibleNavigation());
    followChrome();
  }

  void _onChromeStatus(AnimationStatus status) {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _canAutoHideChrome => canAutoHideVideoControls(
    controlsEnabled: chromeControlsEnabled,
    isPlaying: takeIsRunning,
    focusWithin: _focusWithin,
    accessibleNavigation: _accessibleNavigation,
  );

  bool get _chromeVisible => videoControlsVisible(
    canAutoHide: _canAutoHideChrome,
    hidden: _chromeHidden,
  );

  void followChrome() {
    final bool canAutoHide = _canAutoHideChrome;
    if (canAutoHide && !_autoHideArmed) {
      _restartChromeTimer();
    }
    if (!canAutoHide) {
      _chromeTimer?.cancel();
      _chromeTimer = null;
      _chromeHidden = false;
    }
    _autoHideArmed = canAutoHide;
    _driveChrome();
  }

  void _driveChrome() {
    if (_chromeVisible) {
      _chrome.forward();
    } else {
      _chrome.reverse();
    }
  }

  void _restartChromeTimer() {
    _chromeTimer?.cancel();
    _chromeTimer = _canAutoHideChrome
        ? Timer(recorderChromeHold, _hideChrome)
        : null;
  }

  void _hideChrome() {
    _chromeTimer = null;
    if (!mounted || !_canAutoHideChrome) {
      return;
    }
    setState(() => _chromeHidden = true);
    _driveChrome();
  }

  void revealChrome() {
    if (_chromeHidden) {
      setState(() => _chromeHidden = false);
    }
    _restartChromeTimer();
    _driveChrome();
  }

  void _onFocusWithin(bool hasFocus) {
    if (!mounted || hasFocus == _focusWithin) {
      return;
    }
    setState(() => _focusWithin = hasFocus);
    followChrome();
  }

  KeyEventResult _onAnyKey(FocusNode node, KeyEvent event) {
    revealChrome();
    return KeyEventResult.ignored;
  }

  Widget revealsChromeOnActivity({required Widget child}) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (PointerDownEvent _) => revealChrome(),
      onPointerMove: (PointerMoveEvent _) => revealChrome(),
      child: MouseRegion(
        opaque: false,
        onHover: (PointerHoverEvent _) => revealChrome(),
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          includeSemantics: false,
          onKeyEvent: _onAnyKey,
          child: child,
        ),
      ),
    );
  }

  Widget holdsChromeWhileFocused({required Widget child}) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onFocusChange: _onFocusWithin,
      child: child,
    );
  }
}

class RecorderTitleField extends StatefulWidget {
  const RecorderTitleField({
    super.key,
    required this.controller,
    this.overPicture = false,
    this.readOnly = false,
  });

  final TextEditingController controller;
  final bool overPicture;
  final bool readOnly;

  @override
  State<RecorderTitleField> createState() => _RecorderTitleFieldState();
}

class _RecorderTitleFieldState extends State<RecorderTitleField> {
  final FocusNode _focus = FocusNode(debugLabel: 'recorder-title');

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _returnToStage() {
    _focus.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
  }

  bool get _composing {
    final TextRange composing = widget.controller.value.composing;
    return composing.isValid && !composing.isCollapsed;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.space) {
      return KeyEventResult.skipRemainingHandlers;
    }
    if (event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    if (_composing) {
      return KeyEventResult.skipRemainingHandlers;
    }
    if (event is KeyDownEvent) {
      _returnToStage();
    }
    return KeyEventResult.handled;
  }

  TextStyle _style(bool sidebar) => TextStyle(
    fontFamily: TypographyTokens.serif,
    fontSize: sidebar ? _sidebarTitleSize : _bottomBarTitleSize,
    fontWeight: FontWeight.w400,
    height: _titleLeading,
    color: _titleInk,
    shadows: widget.overPicture
        ? const <Shadow>[
            Shadow(
              color: _titleShadow,
              offset: _titleShadowOffset,
              blurRadius: _titleShadowBlur,
            ),
          ]
        : null,
  );

  @override
  Widget build(BuildContext context) {
    final bool sidebar = stageLayoutOf(context) == ShellLayout.sidebar;
    final TextStyle style = _style(sidebar);
    return Material(
      type: MaterialType.transparency,
      child: KeyboardFocusBuilder(
        focusNode: _focus,
        builder: (BuildContext context, bool shown) => Stack(
          fit: StackFit.passthrough,
          clipBehavior: Clip.none,
          children: <Widget>[
            _field(sidebar, style),
            if (shown) _keyboardRing(context),
          ],
        ),
      ),
    );
  }

  Widget _field(bool sidebar, TextStyle style) {
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      includeSemantics: false,
      onKeyEvent: _onKey,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: sidebar ? _sidebarTitleHeight : _bottomBarTitleHeight,
        ),
        child: Center(
          heightFactor: 1,
          child: Semantics(
            label: recorderTitleLabel,
            child: TextField(
              key: recorderTitleFieldKey,
              controller: widget.controller,
              focusNode: _focus,
              readOnly: widget.readOnly,
              maxLines: 1,
              textAlign: TextAlign.center,
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.sentences,
              cursorColor: _titleCaret,
              style: style,
              decoration: InputDecoration.collapsed(
                hintText: recorderTitlePlaceholder,
                hintStyle: style.copyWith(
                  color: widget.overPicture
                      ? _titlePlaceholderOverPicture
                      : _titlePlaceholderOnStage,
                ),
              ),
              onEditingComplete: _returnToStage,
              onTapOutside: (PointerDownEvent _) => _returnToStage(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _keyboardRing(BuildContext context) {
    const FocusRingSurface surface = FocusRingSurface.dark;
    return Positioned.fill(
      left: -_titleRingOutset,
      top: -_titleRingOutset,
      right: -_titleRingOutset,
      bottom: -_titleRingOutset,
      child: IgnorePointer(
        child: CustomPaint(
          key: focusRingKey,
          painter: _TitleRingPainter(
            color: surface.colorIn(context.colors),
            width: surface.width,
          ),
        ),
      ),
    );
  }
}

class _TitleRingPainter extends CustomPainter {
  const _TitleRingPainter({required this.color, required this.width});

  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    Border.all(
      color: color,
      width: width,
    ).paint(canvas, Offset.zero & size, borderRadius: _titleRadius);
  }

  @override
  bool hitTest(Offset position) => false;

  @override
  bool shouldRepaint(_TitleRingPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.width != width;
}

Future<bool> nameRecordedLog(
  ProviderContainer scope, {
  required String entryId,
  required String title,
  Duration timeout = _titleSaveTimeout,
}) async {
  final String trimmed = title.trim();
  if (trimmed.isEmpty) {
    return false;
  }
  try {
    await scope
        .read(journalRepositoryProvider)
        .setEntryTitle(entryId, trimmed)
        .timeout(timeout);
    return true;
  } catch (error, stackTrace) {
    debugPrint('Recorded log title failed: $error\n$stackTrace');
    return false;
  }
}

void showRecorderKeptToast(
  BuildContext context, {
  required String message,
  required String entryId,
  required String title,
  required bool named,
}) {
  final ProviderContainer scope = ProviderScope.containerOf(
    context,
    listen: false,
  );
  showTransientToast(
    context,
    message,
    after: ModalRoute.of(context)?.completed,
    titleOffer: named
        ? null
        : ToastTitleOffer(
            actionLabel: recorderTitlePlaceholder,
            fieldLabel: recorderTitleLabel,
            failureMessage: recorderTitleFailedMessage,
            initialTitle: title.trim(),
            onTitled: (String title) =>
                nameRecordedLog(scope, entryId: entryId, title: title),
          ),
  );
}

enum _Slot { centre, question, status, actions }

class _StageBodyDelegate extends MultiChildLayoutDelegate {
  _StageBodyDelegate({required this.questionGap, required this.reserveCentre});

  final double questionGap;
  final bool reserveCentre;

  @override
  void performLayout(Size size) {
    final double width = size.width;
    final Size actions = layoutChild(
      _Slot.actions,
      BoxConstraints(minWidth: width, maxWidth: width, maxHeight: size.height),
    );
    final double actionsTop = size.height - actions.height;
    positionChild(_Slot.actions, Offset(0, actionsTop));

    double floor = actionsTop;
    if (hasChild(_Slot.status)) {
      final Size status = layoutChild(
        _Slot.status,
        BoxConstraints(maxWidth: width, maxHeight: math.max(0, floor)),
      );
      floor -= status.height;
      positionChild(_Slot.status, Offset((width - status.width) / 2, floor));
    }

    Size centre = Size.zero;
    if (hasChild(_Slot.centre)) {
      centre = layoutChild(
        _Slot.centre,
        BoxConstraints(
          maxWidth: width,
          maxHeight: reserveCentre ? math.max(0, floor) : size.height,
        ),
      );
    }

    double ceiling = 0;
    if (hasChild(_Slot.question)) {
      final double reserved = reserveCentre ? centre.height : 0;
      final Size question = layoutChild(
        _Slot.question,
        BoxConstraints(
          maxWidth: width,
          maxHeight: math.max(0, floor - questionGap - reserved),
        ),
      );
      positionChild(
        _Slot.question,
        Offset((width - question.width) / 2, questionGap),
      );
      ceiling = questionGap + question.height;
    }

    if (hasChild(_Slot.centre)) {
      final double centred = ceiling + (floor - ceiling - centre.height) / 2;
      final double top = reserveCentre
          ? math.min(math.max(centred, ceiling), floor - centre.height)
          : centred;
      positionChild(_Slot.centre, Offset((width - centre.width) / 2, top));
    }
  }

  @override
  bool shouldRelayout(_StageBodyDelegate oldDelegate) =>
      oldDelegate.questionGap != questionGap ||
      oldDelegate.reserveCentre != reserveCentre;
}

class _EllipseToBox extends GradientTransform {
  const _EllipseToBox({
    required this.focus,
    required this.widthShare,
    required this.heightShare,
  });

  final Alignment focus;
  final double widthShare;
  final double heightShare;

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final double side = bounds.shortestSide;
    if (side <= 0) {
      return Matrix4.identity();
    }
    final Offset origin = focus.withinRect(bounds);
    return Matrix4.translationValues(origin.dx, origin.dy, 0)
        .multiplied(
          Matrix4.diagonal3Values(
            widthShare * bounds.width / side,
            heightShare * bounds.height / side,
            1,
          ),
        )
        .multiplied(Matrix4.translationValues(-origin.dx, -origin.dy, 0));
  }
}
