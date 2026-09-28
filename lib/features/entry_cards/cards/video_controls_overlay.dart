import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../../design/motion/motion.dart';

const Duration kVideoControlsHideDelay = Duration(seconds: 3);
const double videoControlInset = 8;

enum VideoControlModel { pointer, touch }

VideoControlModel resolveVideoControlModel(TargetPlatform platform) =>
    platform == TargetPlatform.macOS
        ? VideoControlModel.pointer
        : VideoControlModel.touch;

bool canAutoHideVideoControls({
  required bool controlsEnabled,
  required bool isPlaying,
  required bool focusWithin,
  required bool accessibleNavigation,
}) =>
    controlsEnabled && isPlaying && !focusWithin && !accessibleNavigation;

bool videoControlsVisible({
  required bool canAutoHide,
  required bool hidden,
}) =>
    !canAutoHide || !hidden;

class VideoControlsOverlay extends StatefulWidget {
  const VideoControlsOverlay({
    super.key,
    required this.controlsEnabled,
    required this.isPlaying,
    required this.onToggle,
    required this.transport,
    required this.controlBar,
    this.hideAfter = kVideoControlsHideDelay,
    this.model,
  });

  final bool controlsEnabled;
  final bool isPlaying;
  final VoidCallback? onToggle;
  final Widget transport;
  final Widget controlBar;
  final Duration hideAfter;
  final VideoControlModel? model;

  @override
  State<VideoControlsOverlay> createState() => _VideoControlsOverlayState();
}

class _VideoControlsOverlayState extends State<VideoControlsOverlay> {
  Timer? _hideTimer;
  bool _hidden = false;
  bool _focusWithin = false;
  bool _accessibleNavigation = false;
  bool _visibleAtPointerDown = true;

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
    _hideTimer =
        _canAutoHide ? Timer(widget.hideAfter, _onHideDelayElapsed) : null;
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

  void _onSurfaceTap() {
    if (_model == VideoControlModel.pointer) {
      _registerActivity();
      widget.onToggle?.call();
      return;
    }
    if (!_visibleAtPointerDown) {
      _registerActivity();
      return;
    }
    if (!_canAutoHide) {
      return;
    }
    _hideNow();
  }

  @override
  Widget build(BuildContext context) {
    final bool visible = _visible;
    return MouseRegion(
      onEnter: _onPointerEnter,
      onHover: _onPointerHover,
      onExit: _onPointerExit,
      child: Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        child: GestureDetector(
          key: const ValueKey<String>('video-surface-tap'),
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: _onSurfaceTap,
          child: Focus(
            canRequestFocus: false,
            skipTraversal: true,
            onFocusChange: _onFocusWithin,
            child: AnimatedOpacity(
              opacity: visible ? 1 : 0,
              duration: Motion.fade,
              curve: Motion.fadeCurve,
              child: IgnorePointer(
                ignoring: !visible,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Center(child: widget.transport),
                    Positioned(
                      left: videoControlInset,
                      right: videoControlInset,
                      bottom: videoControlInset,
                      child: widget.controlBar,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
