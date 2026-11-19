import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../design/focus/focus_ring.dart';
import '../../../design/focus/keyboard_focus_builder.dart';
import '../../../design/interaction/pressable.dart';
import '../../../design/tokens/tokens.dart';
import '../../../domain/platform/desktop_platform.dart';
import '../transport/transport.dart';
import '../transport/transport_bar.dart';
import '../transport/transport_keys.dart';

const Duration kVideoControlsHideDelay = Duration(milliseconds: 2600);
const Duration videoControlsMouseIdle = Duration(seconds: 3);
const Duration videoControlsTouchIdle = Duration(seconds: 4);
const Duration videoControlsLeaveDelay = Duration(milliseconds: 600);
const Key videoControlsCursorKey = ValueKey<String>('video-controls-cursor');
const Key videoPlayMarkKey = ValueKey<String>('video-play-mark');

const String videoSurfacePointerLabel = 'Play or pause video';
const String videoSurfaceTouchLabel = 'Show or hide video controls';

const double _surfaceRingHairline = 1;
const double _surfaceRingWidth = 2;
const Duration _doubleTapWindow = Duration(milliseconds: 300);
const double _skipReadoutX = 0.52;
const double _skipReadoutY = -0.08;
const Duration _controlsRise = Duration(milliseconds: 250);
const Duration _controlsFade = Duration(milliseconds: 320);
const Curve _controlsRiseCurve = Curves.easeOutCubic;
const Curve _controlsFadeCurve = Curves.linear;
const double _controlsRiseDistance = 6;
const double _playMarkSize = 68;
const double _playMarkGlyph = 26;
const Color _playMarkFace = Color(0x80000000);
const Color _playMarkInk = Color(0xFFFFFFFF);
const Duration _playMarkLife = Duration(milliseconds: 560);
const double _playMarkSwell = 1.3;
const Curve _playMarkSwellCurve = Curves.easeOutCubic;
const Curve _playMarkFadeCurve = Curves.easeIn;

enum VideoControlModel { pointer, touch }

VideoControlModel resolveVideoControlModel(TargetPlatform platform) =>
    isDesktopPlatform(platform)
    ? VideoControlModel.pointer
    : VideoControlModel.touch;

bool canAutoHideVideoControls({
  required bool controlsEnabled,
  required bool isPlaying,
  required bool focusWithin,
  required bool accessibleNavigation,
}) => controlsEnabled && isPlaying && !focusWithin && !accessibleNavigation;

bool videoControlsVisible({required bool canAutoHide, required bool hidden}) =>
    !canAutoHide || !hidden;

class VideoControlsOverlay extends StatefulWidget {
  const VideoControlsOverlay({
    super.key,
    required this.controlsEnabled,
    required this.isPlaying,
    required this.onToggle,
    required this.child,
    this.hideAfter = videoControlsMouseIdle,
    this.touchHideAfter = videoControlsTouchIdle,
    this.model,
    this.onSkip,
    this.onFullScreen,
  });

  final bool controlsEnabled;
  final bool isPlaying;
  final VoidCallback? onToggle;
  final Widget child;
  final Duration hideAfter;
  final Duration touchHideAfter;
  final VideoControlModel? model;
  final ValueChanged<Duration>? onSkip;
  final VoidCallback? onFullScreen;

  @override
  State<VideoControlsOverlay> createState() => _VideoControlsOverlayState();
}

class _VideoControlsOverlayState extends State<VideoControlsOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shown = AnimationController(
    vsync: this,
    value: 1,
    duration: _controlsRise,
    reverseDuration: _controlsFade,
  );
  late final CurvedAnimation _shownCurve = CurvedAnimation(
    parent: _shown,
    curve: _controlsRiseCurve,
    reverseCurve: _controlsFadeCurve,
  );
  final GlobalKey _controlsKey = GlobalKey(debugLabel: 'video controls');
  final FocusNode _within = FocusNode(
    debugLabel: 'video controls',
    canRequestFocus: false,
    skipTraversal: true,
  );
  Timer? _idle;
  Timer? _tapTimer;
  Timer? _skipFlashTimer;
  ({String text, bool left})? _skipFlash;
  int _skipFlashSerial = 0;
  ({bool paused, int serial})? _playMark;
  int _playMarkSerial = 0;
  bool _hidden = false;
  bool _focusOnControl = false;
  bool _accessibleNavigation = false;
  bool _visibleAtPointerDown = true;
  PointerDeviceKind? _lastKind;
  Offset? _hoverAt;
  Set<int> _pressed = const <int>{};
  final FocusNode _surfaceFocus = FocusNode(
    debugLabel: 'video surface',
    skipTraversal: true,
  );
  final Map<Type, Action<Intent>> _surfaceKeepsKeys = <Type, Action<Intent>>{
    ActivateIntent: DoNothingAction(consumesKey: false),
  };

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusMoved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _accessibleNavigation =
        MediaQuery.maybeAccessibleNavigationOf(context) ?? false;
    _registerActivityBeforeBuild();
  }

  @override
  void didUpdateWidget(VideoControlsOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controlsEnabled == widget.controlsEnabled &&
        oldWidget.isPlaying == widget.isPlaying &&
        oldWidget.hideAfter == widget.hideAfter &&
        oldWidget.touchHideAfter == widget.touchHideAfter) {
      return;
    }
    _registerActivityBeforeBuild();
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusMoved);
    _idle?.cancel();
    _idle = null;
    _tapTimer?.cancel();
    _skipFlashTimer?.cancel();
    _shownCurve.dispose();
    _shown.dispose();
    _within.dispose();
    _surfaceFocus.dispose();
    super.dispose();
  }

  VideoControlModel get _model =>
      widget.model ?? resolveVideoControlModel(defaultTargetPlatform);

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  bool get _canAutoHide => canAutoHideVideoControls(
    controlsEnabled: widget.controlsEnabled,
    isPlaying: widget.isPlaying,
    focusWithin: _focusOnControl,
    accessibleNavigation: _accessibleNavigation,
  );

  bool get _visible =>
      videoControlsVisible(canAutoHide: _canAutoHide, hidden: _hidden);

  Duration get _modelIdle => switch (_model) {
    VideoControlModel.pointer => widget.hideAfter,
    VideoControlModel.touch => widget.touchHideAfter,
  };

  Duration get _idleDelay => switch (_lastKind) {
    PointerDeviceKind.touch ||
    PointerDeviceKind.stylus ||
    PointerDeviceKind.invertedStylus => widget.touchHideAfter,
    PointerDeviceKind.mouse || PointerDeviceKind.trackpad => widget.hideAfter,
    PointerDeviceKind.unknown || null => _modelIdle,
  };

  bool get _hovers =>
      _lastKind == PointerDeviceKind.mouse ||
      _lastKind == PointerDeviceKind.trackpad;

  bool get _pointerOnControl {
    final Offset? at = _hoverAt;
    final RenderObject? controls = _controlsKey.currentContext
        ?.findRenderObject();
    if (at == null ||
        !_hovers ||
        controls is! RenderBox ||
        !controls.attached) {
      return false;
    }
    final BoxHitTestResult result = BoxHitTestResult();
    controls.hitTest(result, position: controls.globalToLocal(at));
    return result.path.any(
      (HitTestEntry entry) =>
          entry.target is RenderMouseRegion &&
          (entry.target as RenderMouseRegion).cursor != MouseCursor.defer,
    );
  }

  void _syncShown() {
    final double target = _visible ? 1 : 0;
    if (_still) {
      _shown.value = target;
      return;
    }
    if (target == 1) {
      if (_shown.status != AnimationStatus.completed &&
          _shown.status != AnimationStatus.forward) {
        _shown.forward();
      }
      return;
    }
    if (_shown.status != AnimationStatus.dismissed &&
        _shown.status != AnimationStatus.reverse) {
      _shown.reverse();
    }
  }

  void _restartIdle([Duration? delay]) {
    _idle?.cancel();
    _idle = _canAutoHide ? Timer(delay ?? _idleDelay, _onIdle) : null;
  }

  void _registerActivityBeforeBuild() {
    _hidden = false;
    _restartIdle();
    _syncShown();
  }

  void _registerActivity() {
    if (_hidden) {
      setState(() => _hidden = false);
    }
    _restartIdle();
    _syncShown();
  }

  void _hideNow() {
    _idle?.cancel();
    _idle = null;
    if (!_hidden) {
      setState(() => _hidden = true);
    }
    _syncShown();
  }

  void _onIdle() {
    _idle = null;
    if (!mounted || !_canAutoHide) {
      return;
    }
    if (_pressed.isNotEmpty || _pointerOnControl) {
      _restartIdle();
      return;
    }
    _hideNow();
  }

  void _onFocusMoved() {
    if (!mounted) {
      return;
    }
    final FocusNode? focus = FocusManager.instance.primaryFocus;
    final bool onControl =
        _within.hasFocus &&
        focus != null &&
        focus is! FocusScopeNode &&
        !focus.skipTraversal;
    if (onControl == _focusOnControl) {
      return;
    }
    setState(() => _focusOnControl = onControl);
    _registerActivity();
  }

  void _onPointerDown(PointerDownEvent event) {
    _lastKind = event.kind;
    _visibleAtPointerDown = _visible;
    _pressed = <int>{..._pressed, event.pointer};
    _registerActivity();
  }

  void _onPointerMove(PointerMoveEvent event) {
    _lastKind = event.kind;
    _registerActivity();
  }

  void _onPointerEnd(PointerEvent event) {
    _pressed = _pressed.difference(<int>{event.pointer});
    if (!_hidden) {
      _restartIdle();
    }
  }

  void _onPointerEnter(PointerEnterEvent event) {
    _lastKind = event.kind;
    _hoverAt = event.position;
    _registerActivity();
  }

  void _onPointerHover(PointerHoverEvent event) {
    _lastKind = event.kind;
    _hoverAt = event.position;
    _registerActivity();
  }

  void _onPointerExit(PointerExitEvent event) {
    _lastKind = event.kind;
    _hoverAt = null;
    if (!_hidden && _pressed.isEmpty) {
      _restartIdle(videoControlsLeaveDelay);
    }
  }

  void _onSurfacePressedAt(Offset local) {
    if (_model == VideoControlModel.pointer) {
      _onPointerClick();
      return;
    }
    final ValueChanged<Duration>? skip = widget.onSkip;
    if (skip == null) {
      _onTouchTap(_visibleAtPointerDown);
      return;
    }
    if (_takePendingTap()) {
      _skipFromSide(local, skip);
      return;
    }
    final bool visibleAtDown = _visibleAtPointerDown;
    _tapTimer = Timer(_doubleTapWindow, () {
      _tapTimer = null;
      if (mounted) {
        _onTouchTap(visibleAtDown);
      }
    });
  }

  bool _takePendingTap() {
    final Timer? pending = _tapTimer;
    _tapTimer = null;
    pending?.cancel();
    return pending != null;
  }

  void _onPointerClick() {
    _registerActivity();
    final VoidCallback? toggle = widget.onToggle;
    if (toggle != null) {
      final bool pausing = widget.isPlaying;
      toggle();
      _playMarkSerial += 1;
      setState(() => _playMark = (paused: pausing, serial: _playMarkSerial));
    }
    final VoidCallback? fullScreen = widget.onFullScreen;
    if (fullScreen == null) {
      return;
    }
    if (_takePendingTap()) {
      fullScreen();
      return;
    }
    _tapTimer = Timer(_doubleTapWindow, () => _tapTimer = null);
  }

  void _onTouchTap(bool visibleAtDown) {
    if (!visibleAtDown || !_canAutoHide) {
      return;
    }
    _hideNow();
  }

  void _skipFromSide(Offset local, ValueChanged<Duration> skip) {
    final bool left = local.dx < (context.size?.width ?? 0) / 2;
    final Duration delta = left ? -transportSkipStep : transportSkipStep;
    skip(delta);
    _skipFlashTimer?.cancel();
    setState(() {
      _skipFlash = (text: transportSeekReadout(delta), left: left);
      _skipFlashSerial += 1;
    });
    _skipFlashTimer = Timer(transportReadoutHold, _clearSkipFlash);
  }

  void _clearSkipFlash() {
    if (mounted) {
      setState(() => _skipFlash = null);
    }
  }

  void _clearPlayMark(int serial) {
    if (mounted && _playMark?.serial == serial) {
      setState(() => _playMark = null);
    }
  }

  Widget _playMarkLayer(({bool paused, int serial}) mark) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ExcludeSemantics(
          child: Center(
            child: _PlayMark(
              key: ValueKey<int>(mark.serial),
              paused: mark.paused,
              onDone: () => _clearPlayMark(mark.serial),
            ),
          ),
        ),
      ),
    );
  }

  bool get _surfaceTapActs => widget.onToggle != null || _canAutoHide;

  bool _onTransportActivity(TransportActivityNotification notification) {
    _registerActivity();
    return false;
  }

  Widget _skipFlashLayer(({String text, bool left}) flash) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Align(
          alignment: Alignment(
            flash.left ? -_skipReadoutX : _skipReadoutX,
            _skipReadoutY,
          ),
          child: TransportReadout(
            key: ValueKey<int>(_skipFlashSerial),
            text: flash.text,
          ),
        ),
      ),
    );
  }

  Widget _rising(Widget child) {
    if (_still) {
      return child;
    }
    return AnimatedBuilder(
      animation: _shownCurve,
      builder: (BuildContext context, Widget? child) => Transform.translate(
        offset: Offset(0, (1 - _shownCurve.value) * _controlsRiseDistance),
        child: child,
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool visible = _visible;
    final ({String text, bool left})? flash = _skipFlash;
    final ({bool paused, int serial})? mark = _playMark;
    return MouseRegion(
      opaque: false,
      onEnter: _onPointerEnter,
      onHover: _onPointerHover,
      onExit: _onPointerExit,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerEnd,
        onPointerCancel: _onPointerEnd,
        child: Pressable(
          key: const ValueKey<String>('video-surface-tap'),
          label: _model == VideoControlModel.pointer
              ? videoSurfacePointerLabel
              : videoSurfaceTouchLabel,
          onPressedAt: _surfaceTapActs ? _onSurfacePressedAt : null,
          surface: FocusRingSurface.dark,
          placement: FocusRingPlacement.edge,
          ringsFace: true,
          paintsHover: false,
          excludeSemantics: false,
          focusNode: _surfaceFocus,
          behavior: HitTestBehavior.translucent,
          builder: (BuildContext context, bool hovered) => MouseRegion(
            key: videoControlsCursorKey,
            opaque: false,
            cursor: visible ? MouseCursor.defer : SystemMouseCursors.none,
            child: Stack(
              fit: StackFit.passthrough,
              children: <Widget>[
                Actions(
                  actions: _surfaceKeepsKeys,
                  child: Focus(
                    focusNode: _within,
                    includeSemantics: false,
                    child: FadeTransition(
                      opacity: _shownCurve,
                      child: _rising(
                        IgnorePointer(
                          ignoring: !visible,
                          child:
                              NotificationListener<
                                TransportActivityNotification
                              >(
                                onNotification: _onTransportActivity,
                                child: KeyedSubtree(
                                  key: _controlsKey,
                                  child: widget.child,
                                ),
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (flash != null) _skipFlashLayer(flash),
                if (mark != null) _playMarkLayer(mark),
                Positioned.fill(
                  child: IgnorePointer(
                    child: KeyboardFocusBuilder(
                      focusNode: _surfaceFocus,
                      builder: (BuildContext context, bool ringed) => ringed
                          ? const _SurfaceFocusRing()
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayMark extends StatefulWidget {
  const _PlayMark({super.key, required this.paused, required this.onDone});

  final bool paused;
  final VoidCallback onDone;

  @override
  State<_PlayMark> createState() => _PlayMarkState();
}

class _PlayMarkState extends State<_PlayMark>
    with SingleTickerProviderStateMixin {
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: _playMarkLife,
  );

  bool _done = false;

  @override
  void initState() {
    super.initState();
    _life.addListener(_onTick);
    _life.forward();
  }

  @override
  void dispose() {
    _life.removeListener(_onTick);
    _life.dispose();
    super.dispose();
  }

  void _onTick() {
    if (_done || _life.value < 1) {
      return;
    }
    _done = true;
    widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return AnimatedBuilder(
      animation: _life,
      builder: (BuildContext context, Widget? child) {
        final double t = _life.value;
        final double scale = still
            ? 1
            : 1 + (_playMarkSwell - 1) * _playMarkSwellCurve.transform(t);
        return Opacity(
          opacity: 1 - _playMarkFadeCurve.transform(t),
          child: Transform.scale(scale: scale, child: child),
        );
      },
      child: Container(
        key: videoPlayMarkKey,
        width: _playMarkSize,
        height: _playMarkSize,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: _playMarkFace,
          shape: BoxShape.circle,
        ),
        child: PlayPauseGlyph(
          playing: widget.paused,
          color: _playMarkInk,
          size: _playMarkGlyph,
        ),
      ),
    );
  }
}

class _SurfaceFocusRing extends StatelessWidget {
  const _SurfaceFocusRing();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      key: focusRingKey,
      decoration: BoxDecoration(
        border: Border.fromBorderSide(
          BorderSide(color: Palette.mediaBlack, width: _surfaceRingHairline),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(_surfaceRingHairline),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.fromBorderSide(
              BorderSide(color: Palette.mediaInk, width: _surfaceRingWidth),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(_surfaceRingWidth),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.fromBorderSide(
                  BorderSide(
                    color: Palette.mediaBlack,
                    width: _surfaceRingHairline,
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
