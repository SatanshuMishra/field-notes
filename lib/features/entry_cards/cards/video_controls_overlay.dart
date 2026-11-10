import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../../design/focus/focus_ring.dart';
import '../../../design/focus/keyboard_focus_builder.dart';
import '../../../design/interaction/pressable.dart';
import '../../../design/motion/motion.dart';
import '../../../design/tokens/tokens.dart';
import '../../../domain/platform/desktop_platform.dart';
import '../transport/transport.dart';
import '../transport/transport_bar.dart';
import '../transport/transport_keys.dart';

const Duration kVideoControlsHideDelay = Duration(milliseconds: 2600);

const String videoSurfacePointerLabel = 'Play or pause video';
const String videoSurfaceTouchLabel = 'Show or hide video controls';

const double _surfaceRingHairline = 1;
const double _surfaceRingWidth = 2;
const Duration _doubleTapWindow = Duration(milliseconds: 300);
const double _skipReadoutX = 0.52;
const double _skipReadoutY = -0.08;

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
    this.hideAfter = kVideoControlsHideDelay,
    this.model,
    this.onSkip,
    this.onFullScreen,
  });

  final bool controlsEnabled;
  final bool isPlaying;
  final VoidCallback? onToggle;
  final Widget child;
  final Duration hideAfter;
  final VideoControlModel? model;
  final ValueChanged<Duration>? onSkip;
  final VoidCallback? onFullScreen;

  @override
  State<VideoControlsOverlay> createState() => _VideoControlsOverlayState();
}

class _VideoControlsOverlayState extends State<VideoControlsOverlay> {
  Timer? _hideTimer;
  Timer? _tapTimer;
  Timer? _skipFlashTimer;
  ({String text, bool left})? _skipFlash;
  int _skipFlashSerial = 0;
  bool _hidden = false;
  bool _focusWithin = false;
  bool _accessibleNavigation = false;
  bool _visibleAtPointerDown = true;
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
        oldWidget.hideAfter == widget.hideAfter) {
      return;
    }
    _registerActivityBeforeBuild();
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _tapTimer?.cancel();
    _skipFlashTimer?.cancel();
    _surfaceFocus.dispose();
    super.dispose();
  }

  VideoControlModel get _model =>
      widget.model ?? resolveVideoControlModel(defaultTargetPlatform);

  bool get _canAutoHide => canAutoHideVideoControls(
    controlsEnabled: widget.controlsEnabled,
    isPlaying: widget.isPlaying,
    focusWithin: _focusWithin,
    accessibleNavigation: _accessibleNavigation,
  );

  bool get _visible =>
      videoControlsVisible(canAutoHide: _canAutoHide, hidden: _hidden);

  void _restartHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = _canAutoHide
        ? Timer(widget.hideAfter, _onHideDelayElapsed)
        : null;
  }

  void _registerActivityBeforeBuild() {
    _hidden = false;
    _restartHideTimer();
  }

  void _registerActivity() {
    if (_hidden) {
      setState(() => _hidden = false);
    }
    _restartHideTimer();
  }

  void _hideNow() {
    _hideTimer?.cancel();
    _hideTimer = null;
    if (_hidden) {
      return;
    }
    setState(() => _hidden = true);
  }

  void _onHideDelayElapsed() {
    _hideTimer = null;
    if (!mounted || !_canAutoHide) {
      return;
    }
    _hideNow();
  }

  void _onPointerDown(PointerDownEvent event) {
    _visibleAtPointerDown = _visible;
    _registerActivity();
  }

  void _onPointerMove(PointerMoveEvent event) => _registerActivity();

  void _onPointerEnter(PointerEnterEvent event) => _registerActivity();

  void _onPointerHover(PointerHoverEvent event) => _registerActivity();

  void _onPointerExit(PointerExitEvent event) => _registerActivity();

  void _onFocusWithin(bool hasFocus) {
    if (!mounted || hasFocus == _focusWithin) {
      return;
    }
    setState(() => _focusWithin = hasFocus);
    _registerActivity();
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
    widget.onToggle?.call();
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
    if (!visibleAtDown) {
      _registerActivity();
      return;
    }
    if (!_canAutoHide) {
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

  @override
  Widget build(BuildContext context) {
    final bool visible = _visible;
    final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final ({String text, bool left})? flash = _skipFlash;
    return MouseRegion(
      opaque: false,
      onEnter: _onPointerEnter,
      onHover: _onPointerHover,
      onExit: _onPointerExit,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
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
          builder: (BuildContext context, bool hovered) => Stack(
            fit: StackFit.passthrough,
            children: <Widget>[
              Actions(
                actions: _surfaceKeepsKeys,
                child: Focus(
                  canRequestFocus: false,
                  skipTraversal: true,
                  onFocusChange: _onFocusWithin,
                  child: AnimatedOpacity(
                    opacity: visible ? 1 : 0,
                    duration: still ? Duration.zero : Motion.fade,
                    curve: Motion.fadeCurve,
                    child: IgnorePointer(
                      ignoring: !visible,
                      child:
                          NotificationListener<TransportActivityNotification>(
                            onNotification: _onTransportActivity,
                            child: widget.child,
                          ),
                    ),
                  ),
                ),
              ),
              if (flash != null) _skipFlashLayer(flash),
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
