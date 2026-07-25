import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../util/duration_format.dart';

const double scrubberHeight = 48;
const double _trackHeight = 8;
const double _trackRadius = _trackHeight / 2;
const double scrubberHandleRadius = 7.0;
const double _focusStroke = 3;
const Duration scrubberKeyboardStep = Duration(seconds: 5);

Duration clampPlaybackPosition(Duration value, Duration total) {
  if (value < Duration.zero) {
    return Duration.zero;
  }
  if (value > total) {
    return total;
  }
  return value;
}

class _SeekStepIntent extends Intent {
  const _SeekStepIntent(this.steps);

  final int steps;
}

class _SeekEdgeIntent extends Intent {
  const _SeekEdgeIntent(this.toEnd);

  final bool toEnd;
}

const Map<ShortcutActivator, Intent> _scrubberShortcuts =
    <ShortcutActivator, Intent>{
  SingleActivator(LogicalKeyboardKey.arrowRight): _SeekStepIntent(1),
  SingleActivator(LogicalKeyboardKey.arrowLeft): _SeekStepIntent(-1),
  SingleActivator(LogicalKeyboardKey.arrowUp): _SeekStepIntent(1),
  SingleActivator(LogicalKeyboardKey.arrowDown): _SeekStepIntent(-1),
  SingleActivator(LogicalKeyboardKey.home): _SeekEdgeIntent(false),
  SingleActivator(LogicalKeyboardKey.end): _SeekEdgeIntent(true),
};

class VideoScrubber extends StatefulWidget {
  const VideoScrubber({
    super.key,
    required this.position,
    required this.total,
    required this.onSeek,
    required this.onScrubUpdate,
    required this.onScrubEnd,
  });

  final Duration position;
  final Duration? total;
  final ValueChanged<Duration>? onSeek;
  final ValueChanged<Duration>? onScrubUpdate;
  final VoidCallback? onScrubEnd;

  @override
  State<VideoScrubber> createState() => _VideoScrubberState();
}

class _VideoScrubberState extends State<VideoScrubber> {
  bool _focused = false;
  Duration? _dragPosition;

  Duration? get _total {
    final Duration? total = widget.total;
    if (total == null || total <= Duration.zero) {
      return null;
    }
    return total;
  }

  bool get _enabled => widget.onSeek != null && _total != null;

  Duration get _position {
    final Duration? total = _total;
    if (total == null) {
      return Duration.zero;
    }
    return clampPlaybackPosition(_dragPosition ?? widget.position, total);
  }

  double get _fraction {
    final Duration? total = _total;
    if (total == null) {
      return 0;
    }
    return _position.inMilliseconds / total.inMilliseconds;
  }

  void _onFocusHighlight(bool focused) {
    if (!mounted || focused == _focused) {
      return;
    }
    setState(() => _focused = focused);
  }

  void _emit(Duration position) {
    final Duration? total = _total;
    final ValueChanged<Duration>? onSeek = widget.onSeek;
    if (total == null || onSeek == null) {
      return;
    }
    onSeek(clampPlaybackPosition(position, total));
  }

  Duration? _positionForOffset(double dx, double width) {
    final Duration? total = _total;
    final double span = width - scrubberHandleRadius * 2;
    if (total == null || !width.isFinite || span <= 0) {
      return null;
    }
    final double fraction =
        ((dx - scrubberHandleRadius) / span).clamp(0.0, 1.0);
    return Duration(milliseconds: (total.inMilliseconds * fraction).round());
  }

  void _seekToOffset(double dx, double width) {
    final Duration? position = _positionForOffset(dx, width);
    if (position == null) {
      return;
    }
    _emit(position);
  }

  void _previewOffset(double dx, double width) {
    final Duration? position = _positionForOffset(dx, width);
    if (position == null) {
      return;
    }
    setState(() => _dragPosition = position);
    widget.onScrubUpdate?.call(position);
  }

  void _endDrag() {
    final Duration? position = _dragPosition;
    setState(() => _dragPosition = null);
    if (position != null) {
      _emit(position);
    }
    widget.onScrubEnd?.call();
  }

  Duration _stepped(int steps) {
    return _position + scrubberKeyboardStep * steps;
  }

  Object? _onStepIntent(_SeekStepIntent intent) {
    _emit(_stepped(intent.steps));
    return null;
  }

  Object? _onEdgeIntent(_SeekEdgeIntent intent) {
    _emit(intent.toEnd ? (_total ?? Duration.zero) : Duration.zero);
    return null;
  }

  String _label(Duration position) {
    final Duration? total = _total;
    return '${formatMediaDuration(position.inMilliseconds)}'
        ' of ${formatMediaDuration(total?.inMilliseconds)}';
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = _enabled;
    final Duration? total = _total;
    return FocusableActionDetector(
      enabled: enabled,
      onShowFocusHighlight: _onFocusHighlight,
      shortcuts: _scrubberShortcuts,
      actions: <Type, Action<Intent>>{
        _SeekStepIntent: CallbackAction<_SeekStepIntent>(
          onInvoke: _onStepIntent,
        ),
        _SeekEdgeIntent: CallbackAction<_SeekEdgeIntent>(
          onInvoke: _onEdgeIntent,
        ),
      },
      child: Semantics(
        slider: true,
        enabled: enabled,
        label: 'Video position',
        value: _label(_position),
        increasedValue: _label(
          total == null
              ? Duration.zero
              : clampPlaybackPosition(_stepped(1), total),
        ),
        decreasedValue: _label(
          total == null
              ? Duration.zero
              : clampPlaybackPosition(_stepped(-1), total),
        ),
        onIncrease: enabled ? () => _emit(_stepped(1)) : null,
        onDecrease: enabled ? () => _emit(_stepped(-1)) : null,
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double width = constraints.maxWidth;
            return GestureDetector(
              key: const ValueKey<String>('video-scrub-bar'),
              behavior: HitTestBehavior.opaque,
              onTapDown: enabled
                  ? (TapDownDetails details) =>
                      _seekToOffset(details.localPosition.dx, width)
                  : null,
              onHorizontalDragStart: enabled
                  ? (DragStartDetails details) =>
                      _previewOffset(details.localPosition.dx, width)
                  : null,
              onHorizontalDragUpdate: enabled
                  ? (DragUpdateDetails details) =>
                      _previewOffset(details.localPosition.dx, width)
                  : null,
              onHorizontalDragEnd:
                  enabled ? (DragEndDetails details) => _endDrag() : null,
              onHorizontalDragCancel: enabled ? _endDrag : null,
              child: Opacity(
                opacity: enabled ? 1.0 : 0.5,
                child: SizedBox(
                  height: scrubberHeight,
                  child: CustomPaint(
                    painter: _ScrubberPainter(
                      fraction: _fraction,
                      focused: _focused,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ScrubberPainter extends CustomPainter {
  const _ScrubberPainter({required this.fraction, required this.focused});

  final double fraction;
  final bool focused;

  @override
  void paint(Canvas canvas, Size size) {
    final double left = scrubberHandleRadius;
    final double right = size.width - scrubberHandleRadius;
    if (right <= left) {
      return;
    }
    final double centerY = size.height / 2;
    final Rect track = Rect.fromLTRB(
      left,
      centerY - _trackRadius,
      right,
      centerY + _trackRadius,
    );
    final RRect trackShape = RRect.fromRectAndRadius(
      track,
      const Radius.circular(_trackRadius),
    );
    canvas.drawRRect(trackShape, Paint()..color = Palette.cardBright);

    final double filled = (right - left) * fraction.clamp(0.0, 1.0);
    if (filled > 0) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, track.top, filled, _trackHeight),
          const Radius.circular(_trackRadius),
        ),
        Paint()..color = Palette.coral,
      );
    }
    canvas.drawRRect(
      trackShape,
      Paint()
        ..color = Palette.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = Shapes.outlineWidth,
    );

    final Offset handle = Offset(left + filled, centerY);
    canvas.drawCircle(handle, scrubberHandleRadius, Paint()..color = Palette.coral);
    canvas.drawCircle(
      handle,
      scrubberHandleRadius,
      Paint()
        ..color = Palette.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = focused ? _focusStroke : Shapes.outlineWidth,
    );
  }

  @override
  bool shouldRepaint(_ScrubberPainter oldDelegate) =>
      fraction != oldDelegate.fraction || focused != oldDelegate.focused;
}
