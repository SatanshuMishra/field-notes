import 'dart:async';

import 'package:flutter/widgets.dart';

import 'package:field_notes/design/glass/glass_surface.dart';
import 'package:field_notes/design/tokens/tokens.dart';

import 'video_recorder.dart';

const Key cameraGestureLayerKey = ValueKey<String>('camera-gesture-layer');
const Key cameraFocusRingKey = ValueKey<String>('camera-focus-ring');
const Key cameraZoomLevelKey = ValueKey<String>('camera-zoom-level');

const double cameraFlipDistance = 72;
const double cameraFlipVelocity = 600;
const double cameraFlipMinimumDistance = 24;
const Duration cameraFocusRingTime = Duration(milliseconds: 1100);
const Duration cameraZoomLevelTime = Duration(milliseconds: 1200);

const double _zoomStep = 0.01;
const double _focusRingSize = 68;
const double _focusRingStroke = 1.6;
const Color _focusRingInk = Color(0xE6FFFFFF);
const Color _zoomInk = Color(0xFFFFFFFF);
const double _zoomTextSize = 13;
const EdgeInsets _zoomPadding = EdgeInsets.symmetric(
  horizontal: 12,
  vertical: 6,
);
const BorderRadius _zoomRadius = BorderRadius.all(Radius.circular(14));
const Alignment _zoomPlace = Alignment(0, -0.62);
const Duration _fade = Duration(milliseconds: 180);

String cameraZoomLabel(double zoom) =>
    zoom < 10 ? '${zoom.toStringAsFixed(1)}×' : '${zoom.round()}×';

class CameraGestureLayer extends StatefulWidget {
  const CameraGestureLayer({super.key, required this.controls, this.onFlip});

  final CameraControls controls;
  final VoidCallback? onFlip;

  @override
  State<CameraGestureLayer> createState() => _CameraGestureLayerState();
}

class _CameraGestureLayerState extends State<CameraGestureLayer> {
  ZoomRange? _range;
  double _zoom = 1;
  double _startZoom = 1;
  Offset _travel = Offset.zero;
  int _touching = 0;
  bool _pinched = false;
  Offset? _focus;
  bool _showZoom = false;
  Timer? _focusTimer;
  Timer? _zoomTimer;

  @override
  void dispose() {
    _focusTimer?.cancel();
    _zoomTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadRange() async {
    if (_range != null) {
      return;
    }
    final ZoomRange? range = await widget.controls.zoomRange();
    if (!mounted || range == null) {
      return;
    }
    _range = range;
    _zoom = range.clamp(_zoom);
  }

  void _pointerDown(PointerDownEvent _) {
    if (_touching == 0) {
      _pinched = false;
    }
    _touching += 1;
    if (_touching > 1) {
      _pinched = true;
    }
  }

  void _pointerUp(PointerEvent _) {
    _touching = _touching > 0 ? _touching - 1 : 0;
  }

  void _scaleStart(ScaleStartDetails details) {
    _travel = Offset.zero;
    _zoom = widget.controls.zoom;
    _startZoom = _zoom;
    _zoomTimer?.cancel();
    unawaited(_loadRange());
  }

  void _scaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2) {
      _travel += details.focalPointDelta;
      return;
    }
    final ZoomRange? range = _range;
    if (range == null) {
      return;
    }
    final double zoom = range.clamp(_startZoom * details.scale);
    if ((zoom - _zoom).abs() < _zoomStep) {
      return;
    }
    setState(() {
      _zoom = zoom;
      _showZoom = true;
    });
    unawaited(widget.controls.setZoom(zoom));
  }

  void _scaleEnd(ScaleEndDetails details) {
    if (_showZoom) {
      _zoomTimer?.cancel();
      _zoomTimer = Timer(cameraZoomLevelTime, () {
        if (mounted) {
          setState(() => _showZoom = false);
        }
      });
    }
    final VoidCallback? onFlip = widget.onFlip;
    if (_pinched || onFlip == null) {
      return;
    }
    final double rise = _travel.dy.abs();
    final double speed = details.velocity.pixelsPerSecond.dy.abs();
    final bool vertical = rise > _travel.dx.abs() * 1.5;
    final bool far = rise >= cameraFlipDistance;
    final bool flung =
        speed >= cameraFlipVelocity && rise >= cameraFlipMinimumDistance;
    if (vertical && (far || flung)) {
      onFlip();
    }
  }

  void _tapUp(TapUpDetails details) {
    final Size? size = context.size;
    if (size == null) {
      return;
    }
    final Rect? preview = widget.controls.previewRectIn(size);
    final Offset at = details.localPosition;
    if (preview == null || !preview.contains(at)) {
      return;
    }
    setState(() => _focus = at);
    _focusTimer?.cancel();
    _focusTimer = Timer(cameraFocusRingTime, () {
      if (mounted) {
        setState(() => _focus = null);
      }
    });
    unawaited(
      widget.controls.focusAt(
        Offset(
          (at.dx - preview.left) / preview.width,
          (at.dy - preview.top) / preview.height,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Offset? focus = _focus;
    return Listener(
      onPointerDown: _pointerDown,
      onPointerUp: _pointerUp,
      onPointerCancel: _pointerUp,
      child: GestureDetector(
        key: cameraGestureLayerKey,
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTapUp: _tapUp,
        onScaleStart: _scaleStart,
        onScaleUpdate: _scaleUpdate,
        onScaleEnd: _scaleEnd,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (focus != null)
              Positioned(
                left: focus.dx - _focusRingSize / 2,
                top: focus.dy - _focusRingSize / 2,
                width: _focusRingSize,
                height: _focusRingSize,
                child: const IgnorePointer(
                  child: DecoratedBox(
                    key: cameraFocusRingKey,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(
                          color: _focusRingInk,
                          width: _focusRingStroke,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Align(
              alignment: _zoomPlace,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _showZoom ? 1 : 0,
                  duration: _fade,
                  child: _zoomLevel(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _zoomLevel() {
    return Semantics(
      container: true,
      liveRegion: true,
      child: GlassSurface(
        tone: GlassTone.scene,
        borderRadius: _zoomRadius,
        padding: _zoomPadding,
        child: Text(
          cameraZoomLabel(_zoom),
          key: cameraZoomLevelKey,
          style: const TextStyle(
            fontFamily: TypographyTokens.sans,
            fontSize: _zoomTextSize,
            fontWeight: FontWeight.w600,
            color: _zoomInk,
            fontFeatures: <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}
