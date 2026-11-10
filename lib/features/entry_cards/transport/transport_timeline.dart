import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../design/focus/focus_ring.dart';
import '../../../design/interaction/pressable.dart';
import '../../../design/motion/motion.dart';
import '../../../design/tokens/tokens.dart';
import '../../../domain/platform/desktop_platform.dart';
import '../util/duration_format.dart';

const double transportRailHeight = 4;
const double transportRailHotHeight = 6;
const double transportThumbRadius = 7;
const Duration transportSeekStep = Duration(seconds: 5);
const Size transportCardFrameSize = Size(128, 72);
const Size transportViewerFrameSize = Size(160, 90);

const Key transportGhostKey = ValueKey<String>('transport-ghost');
const Key transportBubbleKey = ValueKey<String>('transport-bubble');
const Key transportFrameKey = ValueKey<String>('transport-frame');

const double _ghostWidth = 2;
const double _ghostRailHeight = 16;
const double _ghostAlpha = 0.72;
const double _bubbleGap = 6;
const double _frameGap = 6;
const double _timeHalfWidth = 26;
const double _frameHalfOutset = 2;
const double _bubbleBorder = 1;
const double _disabledAlpha = 0.5;
const double _stageRailAlpha = 0.24;
const double _stageEdgeAlpha = 0.22;
const EdgeInsets _timePadding = EdgeInsets.symmetric(
  horizontal: 8,
  vertical: 4,
);
const BorderRadius _pressRadius = BorderRadius.all(Radius.circular(2));
const BorderRadius _ghostRadius = BorderRadius.all(Radius.circular(2));
const BorderRadius _timeRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusFull),
);
const BorderRadius _frameRadius = BorderRadius.all(
  Radius.circular(Shapes.radius8),
);

Duration clampPlaybackPosition(Duration value, Duration total) {
  if (value < Duration.zero) {
    return Duration.zero;
  }
  if (value > total) {
    return total;
  }
  return value;
}

@immutable
final class TransportPalette {
  const TransportPalette({
    required this.rail,
    required this.played,
    required this.thumb,
    required this.ghost,
    required this.bubble,
    required this.bubbleInk,
    required this.bubbleEdge,
    required this.wave,
    required this.waveTall,
  });

  factory TransportPalette.card(FieldNotesColors colors) => TransportPalette(
    rail: colors.mediaRail,
    played: colors.mediaPlayed,
    thumb: colors.mediaPlayed,
    ghost: colors.ink.withValues(alpha: _ghostAlpha),
    bubble: colors.mediaBubble,
    bubbleInk: colors.mediaBubbleInk,
    bubbleEdge: colors.ink22,
    wave: colors.waveLight,
    waveTall: colors.waveMid,
  );

  factory TransportPalette.viewer(FieldNotesColors colors) => TransportPalette(
    rail: colors.viewerRail,
    played: colors.mediaPlayed,
    thumb: colors.mediaPlayed,
    ghost: colors.ink.withValues(alpha: _ghostAlpha),
    bubble: colors.mediaBubble,
    bubbleInk: colors.mediaBubbleInk,
    bubbleEdge: colors.ink22,
    wave: colors.viewerWaveform,
    waveTall: colors.viewerWaveform,
  );

  factory TransportPalette.stage() => TransportPalette(
    rail: Palette.mediaInk.withValues(alpha: _stageRailAlpha),
    played: Palette.mediaPlayed,
    thumb: Palette.mediaInk,
    ghost: Palette.mediaInk.withValues(alpha: _ghostAlpha),
    bubble: FieldNotesColors.dark.mediaBubble,
    bubbleInk: FieldNotesColors.dark.mediaBubbleInk,
    bubbleEdge: Palette.mediaInk.withValues(alpha: _stageEdgeAlpha),
    wave: FieldNotesColors.dark.viewerWaveform,
    waveTall: FieldNotesColors.dark.viewerWaveform,
  );

  final Color rail;
  final Color played;
  final Color thumb;
  final Color ghost;
  final Color bubble;
  final Color bubbleInk;
  final Color bubbleEdge;
  final Color wave;
  final Color waveTall;
}

typedef TransportFrameLookup = Future<Uint8List?> Function(Duration position);

typedef TransportTimelineFace = Widget Function(
  BuildContext context,
  double width,
  double fraction,
);

class TransportTimeline extends StatefulWidget {
  const TransportTimeline({
    super.key,
    required this.label,
    required this.position,
    required this.total,
    required this.onSeek,
    required this.palette,
    required this.height,
    this.onScrubUpdate,
    this.onScrubEnd,
    this.face,
    this.pressKey,
    this.frameAt,
    this.frameSize = transportViewerFrameSize,
    this.surface = FocusRingSurface.light,
    this.alwaysShowThumb = false,
    this.unboundedWidth = 0,
  });

  final String label;
  final Duration position;
  final Duration? total;
  final ValueChanged<Duration>? onSeek;
  final TransportPalette palette;
  final double height;
  final ValueChanged<Duration>? onScrubUpdate;
  final VoidCallback? onScrubEnd;
  final TransportTimelineFace? face;
  final Key? pressKey;
  final TransportFrameLookup? frameAt;
  final Size frameSize;
  final FocusRingSurface surface;
  final bool alwaysShowThumb;
  final double unboundedWidth;

  @override
  State<TransportTimeline> createState() => _TransportTimelineState();
}

class _TransportTimelineState extends State<TransportTimeline> {
  final FocusNode _pressFocus = FocusNode(
    debugLabel: 'transport timeline press',
    skipTraversal: true,
  );
  Duration? _dragPosition;
  double? _pointerFraction;
  Uint8List? _frame;
  int _frameTicket = 0;
  bool _pointerInside = false;
  bool _focused = false;

  @override
  void dispose() {
    _pressFocus.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TransportTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled) {
      _dragPosition = null;
      _forgetPointer();
    }
  }

  Duration? get _total {
    final Duration? total = widget.total;
    if (total == null || total <= Duration.zero) {
      return null;
    }
    return total;
  }

  bool get _enabled => widget.onSeek != null && _total != null;

  bool get _hot => _pointerFraction != null || _focused;

  Duration get _shownPosition {
    final Duration? total = _total;
    if (total == null) {
      return Duration.zero;
    }
    return clampPlaybackPosition(_dragPosition ?? widget.position, total);
  }

  double get _shownFraction {
    final Duration? total = _total;
    if (total == null) {
      return 0;
    }
    return _shownPosition.inMilliseconds / total.inMilliseconds;
  }

  double _fractionAt(double dx, double width) =>
      width <= 0 ? 0 : (dx / width).clamp(0.0, 1.0);

  Duration? _positionAt(double fraction) {
    final Duration? total = _total;
    if (total == null) {
      return null;
    }
    return Duration(milliseconds: (total.inMilliseconds * fraction).round());
  }

  void _emit(Duration? position) {
    final Duration? total = _total;
    final ValueChanged<Duration>? onSeek = widget.onSeek;
    if (position == null || total == null || onSeek == null) {
      return;
    }
    onSeek(clampPlaybackPosition(position, total));
  }

  void _forgetPointer() {
    _pointerFraction = null;
    _frame = null;
    _frameTicket += 1;
  }

  void _onFocusHighlight(bool focused) {
    if (!mounted || focused == _focused) {
      return;
    }
    setState(() => _focused = focused);
  }

  void _lookUpFrame(Duration? position) {
    final TransportFrameLookup? frameAt = widget.frameAt;
    if (position == null || frameAt == null) {
      return;
    }
    final int ticket = ++_frameTicket;
    unawaited(_loadFrame(frameAt, position, ticket));
  }

  Future<void> _loadFrame(
    TransportFrameLookup frameAt,
    Duration position,
    int ticket,
  ) async {
    final Uint8List? frame = await frameAt(position);
    if (!mounted || ticket != _frameTicket || _pointerFraction == null) {
      return;
    }
    setState(() => _frame = frame);
  }

  void _onHover(PointerHoverEvent event, double width) {
    _pointerInside = true;
    if (!_enabled || _dragPosition != null) {
      return;
    }
    final double fraction = _fractionAt(event.localPosition.dx, width);
    setState(() => _pointerFraction = fraction);
    _lookUpFrame(_positionAt(fraction));
  }

  void _onExit(PointerExitEvent event) {
    _pointerInside = false;
    if (_dragPosition != null || _pointerFraction == null) {
      return;
    }
    setState(_forgetPointer);
  }

  void _onDrag(double dx, double width) {
    final double fraction = _fractionAt(dx, width);
    final Duration? position = _positionAt(fraction);
    if (position == null) {
      return;
    }
    setState(() {
      _dragPosition = position;
      _pointerFraction = fraction;
    });
    widget.onScrubUpdate?.call(position);
    _lookUpFrame(position);
  }

  void _endDrag() {
    final Duration? position = _dragPosition;
    setState(() {
      _dragPosition = null;
      if (!_pointerInside) {
        _forgetPointer();
      }
    });
    _emit(position);
    widget.onScrubEnd?.call();
  }

  Duration _stepped(int steps) => _shownPosition + transportSeekStep * steps;

  String _phrase(Duration position) {
    final Duration? total = _total;
    final Duration shown = total == null
        ? Duration.zero
        : clampPlaybackPosition(position, total);
    return '${formatMediaDuration(shown.inMilliseconds)}'
        ' of ${formatMediaDuration(total?.inMilliseconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = _enabled;
    return FocusableActionDetector(
      enabled: enabled,
      includeFocusSemantics: false,
      onShowFocusHighlight: _onFocusHighlight,
      child: Semantics(
        container: true,
        slider: true,
        enabled: enabled,
        label: widget.label,
        value: _phrase(_shownPosition),
        increasedValue: _phrase(_stepped(1)),
        decreasedValue: _phrase(_stepped(-1)),
        onIncrease: () => _emit(_stepped(1)),
        onDecrease: () => _emit(_stepped(-1)),
        child: SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final double width = constraints.hasBoundedWidth
                  ? constraints.maxWidth
                  : widget.unboundedWidth;
              return ExcludeSemantics(child: _pressable(context, width));
            },
          ),
        ),
      ),
    );
  }

  Widget _pressable(BuildContext context, double width) {
    final bool enabled = _enabled;
    return Pressable(
      key: widget.pressKey,
      label: widget.label,
      onPressedAt: enabled
          ? (Offset local) => _emit(_positionAt(_fractionAt(local.dx, width)))
          : null,
      surface: widget.surface,
      borderRadius: _pressRadius,
      paintsHover: false,
      focusNode: _pressFocus,
      child: MouseRegion(
        opaque: false,
        onEnter: (PointerEnterEvent event) => _pointerInside = true,
        onHover: (PointerHoverEvent event) => _onHover(event, width),
        onExit: _onExit,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onHorizontalDragStart: enabled
              ? (DragStartDetails details) =>
                    _onDrag(details.localPosition.dx, width)
              : null,
          onHorizontalDragUpdate: enabled
              ? (DragUpdateDetails details) =>
                    _onDrag(details.localPosition.dx, width)
              : null,
          onHorizontalDragEnd: enabled
              ? (DragEndDetails details) => _endDrag()
              : null,
          onHorizontalDragCancel: enabled ? _endDrag : null,
          child: _stack(context, width),
        ),
      ),
    );
  }

  Widget _stack(BuildContext context, double width) {
    final double? pointer = _pointerFraction;
    return SizedBox(
      width: width,
      height: widget.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Positioned.fill(child: _face(context, width)),
          if (pointer != null) _ghost(width * pointer),
          if (pointer != null) _bubble(context, width, pointer),
          if (_focused)
            Positioned.fill(child: IgnorePointer(child: _ring(context))),
        ],
      ),
    );
  }

  Widget _face(BuildContext context, double width) {
    final TransportTimelineFace? face = widget.face;
    if (face != null) {
      return face(context, width, _shownFraction);
    }
    final TransportPalette palette = widget.palette;
    final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final bool thumbAlways =
        widget.alwaysShowThumb ||
        !isDesktopPlatform(Theme.of(context).platform);
    return Opacity(
      opacity: _enabled ? 1 : _disabledAlpha,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: _hot ? 1 : 0),
        duration: still ? Duration.zero : Motion.press,
        builder: (BuildContext context, double heat, Widget? child) =>
            CustomPaint(
              painter: _RailPainter(
                fraction: _shownFraction,
                heat: heat,
                thumbScale: thumbAlways ? 1 : heat,
                rail: palette.rail,
                played: palette.played,
                thumb: palette.thumb,
              ),
            ),
      ),
    );
  }

  Widget _ghost(double centre) {
    final double height = widget.face == null
        ? _ghostRailHeight
        : widget.height;
    return Positioned(
      key: transportGhostKey,
      left: centre - _ghostWidth / 2,
      top: (widget.height - height) / 2,
      width: _ghostWidth,
      height: height,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: widget.palette.ghost,
            borderRadius: _ghostRadius,
          ),
        ),
      ),
    );
  }

  Widget _bubble(BuildContext context, double width, double fraction) {
    final Uint8List? frame = _frame;
    final double halfWidth = math.min(
      width / 2,
      frame == null
          ? _timeHalfWidth
          : widget.frameSize.width / 2 + _frameHalfOutset,
    );
    final double centre = (fraction * width).clamp(
      halfWidth,
      width - halfWidth,
    );
    return Positioned(
      key: transportBubbleKey,
      left: centre,
      bottom: widget.height + _bubbleGap,
      child: FractionalTranslation(
        translation: const Offset(-0.5, 0),
        child: IgnorePointer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (frame != null) ...<Widget>[
                _frameFace(context, frame),
                const SizedBox(height: _frameGap),
              ],
              _timeFace(context, _positionAt(fraction) ?? Duration.zero),
            ],
          ),
        ),
      ),
    );
  }

  Widget _frameFace(BuildContext context, Uint8List frame) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _frameRadius,
        border: context.shadows.outline,
        boxShadow: context.shadows.emphasis,
      ),
      child: ClipRRect(
        borderRadius: _frameRadius,
        child: Image.memory(
          frame,
          key: transportFrameKey,
          width: widget.frameSize.width,
          height: widget.frameSize.height,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
      ),
    );
  }

  Widget _timeFace(BuildContext context, Duration at) {
    final TransportPalette palette = widget.palette;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.bubble,
        borderRadius: _timeRadius,
        border: Border.all(color: palette.bubbleEdge, width: _bubbleBorder),
      ),
      child: Padding(
        padding: _timePadding,
        child: Text(
          formatMediaDuration(at.inMilliseconds),
          maxLines: 1,
          softWrap: false,
          style: context.textStyles.captionSans.copyWith(
            color: palette.bubbleInk,
            fontWeight: FontWeight.w500,
            height: 1,
            fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  Widget _ring(BuildContext context) {
    return DecoratedBox(
      key: focusRingKey,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(Shapes.radius8),
        border: Border.all(
          color: widget.surface.colorIn(context.colors),
          width: widget.surface.width,
        ),
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  const _RailPainter({
    required this.fraction,
    required this.heat,
    required this.thumbScale,
    required this.rail,
    required this.played,
    required this.thumb,
  });

  final double fraction;
  final double heat;
  final double thumbScale;
  final Color rail;
  final Color played;
  final Color thumb;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) {
      return;
    }
    final double height = lerpDouble(
      transportRailHeight,
      transportRailHotHeight,
      heat,
    )!;
    final Radius radius = Radius.circular(height / 2);
    final double centreY = size.height / 2;
    final double top = centreY - height / 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, top, size.width, height),
        radius,
      ),
      Paint()..color = rail,
    );
    final double filled = size.width * fraction.clamp(0.0, 1.0);
    if (filled > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(0, top, filled, height), radius),
        Paint()..color = played,
      );
    }
    final double thumbRadius = transportThumbRadius * thumbScale;
    if (thumbRadius > 0) {
      canvas.drawCircle(
        Offset(filled, centreY),
        thumbRadius,
        Paint()..color = thumb,
      );
    }
  }

  @override
  bool shouldRepaint(_RailPainter oldDelegate) =>
      fraction != oldDelegate.fraction ||
      heat != oldDelegate.heat ||
      thumbScale != oldDelegate.thumbScale ||
      rail != oldDelegate.rail ||
      played != oldDelegate.played ||
      thumb != oldDelegate.thumb;
}
