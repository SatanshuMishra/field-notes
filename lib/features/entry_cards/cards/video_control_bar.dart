import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../util/duration_format.dart';
import 'video_scrubber.dart';

const double _muteTarget = 48;
const double _muteChip = 32;
const double _muteGlyph = 18;
const Border _focusOutline = Border.fromBorderSide(
  BorderSide(color: Palette.ink, width: 3),
);

class VideoControlBar extends StatelessWidget {
  const VideoControlBar({
    super.key,
    required this.position,
    required this.total,
    required this.muted,
    required this.onSeek,
    required this.onToggleMute,
  });

  final Duration position;
  final Duration? total;
  final bool muted;
  final ValueChanged<Duration>? onSeek;
  final VoidCallback? onToggleMute;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Palette.cardWarm,
        border: Shapes.outline,
        borderRadius: Shapes.buttonBorderRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: VideoScrubber(
                position: position,
                total: total,
                onSeek: onSeek,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${formatMediaDuration(position.inMilliseconds)}'
              ' / ${formatMediaDuration(total?.inMilliseconds)}',
              maxLines: 1,
              style: TypographyTokens.captionSans,
            ),
            const SizedBox(width: 4),
            VideoMuteToggle(muted: muted, onTap: onToggleMute),
          ],
        ),
      ),
    );
  }
}

class VideoMuteToggle extends StatefulWidget {
  const VideoMuteToggle({super.key, required this.muted, required this.onTap});

  final bool muted;
  final VoidCallback? onTap;

  @override
  State<VideoMuteToggle> createState() => _VideoMuteToggleState();
}

class _VideoMuteToggleState extends State<VideoMuteToggle> {
  bool _focused = false;

  void _onFocusHighlight(bool focused) {
    if (!mounted || focused == _focused) {
      return;
    }
    setState(() => _focused = focused);
  }

  Object? _activate(Intent intent) {
    widget.onTap?.call();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;
    return FocusableActionDetector(
      enabled: enabled,
      onShowFocusHighlight: _onFocusHighlight,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: _activate),
      },
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.muted ? 'Unmute video' : 'Mute video',
        child: GestureDetector(
          key: const ValueKey<String>('video-mute-toggle'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.5,
            child: SizedBox(
              width: _muteTarget,
              height: _muteTarget,
              child: Center(
                child: Container(
                  width: _muteChip,
                  height: _muteChip,
                  decoration: BoxDecoration(
                    color: Palette.cardBright,
                    border: _focused ? _focusOutline : Shapes.outline,
                    borderRadius: Shapes.buttonBorderRadius,
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(_muteGlyph, _muteGlyph),
                      painter: _MuteGlyph(muted: widget.muted),
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

class _MuteGlyph extends CustomPainter {
  const _MuteGlyph({required this.muted});

  final bool muted;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Paint fill = Paint()..color = Palette.ink;
    final Path speaker = Path()
      ..moveTo(0, h * 0.35)
      ..lineTo(w * 0.22, h * 0.35)
      ..lineTo(w * 0.48, h * 0.12)
      ..lineTo(w * 0.48, h * 0.88)
      ..lineTo(w * 0.22, h * 0.65)
      ..lineTo(0, h * 0.65)
      ..close();
    canvas.drawPath(speaker, fill);

    final Paint stroke = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = Shapes.outlineWidth
      ..strokeCap = StrokeCap.round;

    if (muted) {
      canvas.drawLine(
        Offset(w * 0.62, h * 0.32),
        Offset(w * 0.95, h * 0.68),
        stroke,
      );
      canvas.drawLine(
        Offset(w * 0.95, h * 0.32),
        Offset(w * 0.62, h * 0.68),
        stroke,
      );
      return;
    }
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.48, h * 0.5), radius: w * 0.24),
      -0.9,
      1.8,
      false,
      stroke,
    );
    canvas.drawArc(
      Rect.fromCircle(center: Offset(w * 0.48, h * 0.5), radius: w * 0.44),
      -0.9,
      1.8,
      false,
      stroke,
    );
  }

  @override
  bool shouldRepaint(_MuteGlyph oldDelegate) => muted != oldDelegate.muted;
}
