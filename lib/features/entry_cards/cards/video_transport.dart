import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';

const double _transportSize = 56;
const double _transportGlyph = 18;
const Border _transportFocusOutline = Border.fromBorderSide(
  BorderSide(color: Palette.ink, width: 3),
);

const String videoTransportBusyNotice = "Can't start this video right now";
const String videoTransportBusyHint = 'Tap to try again';

class VideoTransport extends StatefulWidget {
  const VideoTransport({
    super.key,
    required this.isPlaying,
    required this.onTap,
    this.hint,
  });

  final bool isPlaying;
  final VoidCallback? onTap;
  final String? hint;

  @override
  State<VideoTransport> createState() => _VideoTransportState();
}

class _VideoTransportState extends State<VideoTransport> {
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
        label: widget.isPlaying ? 'Pause video' : 'Play video',
        hint: widget.hint,
        child: GestureDetector(
          key: const ValueKey<String>('video-play-toggle'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.5,
            child: Container(
              width: _transportSize,
              height: _transportSize,
              decoration: BoxDecoration(
                color: Palette.coral,
                shape: BoxShape.circle,
                border: _focused ? _transportFocusOutline : Shapes.outline,
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(_transportGlyph, _transportGlyph),
                  painter: _TransportGlyph(isPlaying: widget.isPlaying),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VideoTransportBusyNotice extends StatelessWidget {
  const VideoTransportBusyNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: videoTransportBusyNotice,
      child: const DecoratedBox(
        decoration: BoxDecoration(
          color: Palette.cardWarm,
          border: Shapes.outline,
          borderRadius: Shapes.buttonBorderRadius,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: ExcludeSemantics(
            child: Text(
              videoTransportBusyNotice,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: TypographyTokens.captionSans,
            ),
          ),
        ),
      ),
    );
  }
}

class _TransportGlyph extends CustomPainter {
  const _TransportGlyph({required this.isPlaying});

  final bool isPlaying;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fill = Paint()..color = Palette.cardBright;
    if (isPlaying) {
      final double barWidth = size.width * 0.3;
      canvas.drawRect(Rect.fromLTWH(0, 0, barWidth, size.height), fill);
      canvas.drawRect(
        Rect.fromLTWH(size.width - barWidth, 0, barWidth, size.height),
        fill,
      );
      return;
    }
    final Path triangle = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(triangle, fill);
  }

  @override
  bool shouldRepaint(_TransportGlyph oldDelegate) =>
      isPlaying != oldDelegate.isPlaying;
}
