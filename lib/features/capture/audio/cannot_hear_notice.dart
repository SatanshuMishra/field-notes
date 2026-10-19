import 'dart:async';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/capture/audio/microphone_glyph.dart';
import 'package:field_notes/features/capture/audio/microphone_hearing.dart';
import 'package:field_notes/features/capture/immersive/stage_phase.dart';
import 'package:flutter/widgets.dart';

const String cannotHearMessage =
    "Field Notes can't hear you. Are you speaking? Check your input";
const String cannotHearNoticeLabel = '$cannotHearMessage in Input';
const String soundLostMessage =
    "Field Notes can't hear you. Reconnecting your microphone";
const Duration soundLostWarningDelay = Duration(seconds: 1);

const Key cannotHearNoticeKey = ValueKey<String>('cannot-hear-notice');
const Key cannotHearPointerKey = ValueKey<String>('cannot-hear-pointer');
const Key soundLostWarningKey = ValueKey<String>('sound-lost-warning');

const Color _statusInk = Color(0xFFDCCAB0);
const double _sidebarStatusSize = 21;
const double _bottomBarStatusSize = 18;
const double _lineGap = 8;
const double _glyphGap = 8;
const double _pointerSize = 14;
const double _pointerStroke = 1.8;

TextStyle _statusStyle(BuildContext context) => TextStyle(
  fontFamily: TypographyTokens.accent,
  fontSize: stageLayoutOf(context) == ShellLayout.sidebar
      ? _sidebarStatusSize
      : _bottomBarStatusSize,
  fontWeight: FontWeight.w600,
  color: _statusInk,
);

class CannotHearNotice extends StatelessWidget {
  const CannotHearNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: cannotHearNoticeKey,
      padding: const EdgeInsets.only(top: _lineGap),
      child: Semantics(
        container: true,
        liveRegion: true,
        label: cannotHearNoticeLabel,
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Flexible(
              child: Text(
                cannotHearMessage,
                textAlign: TextAlign.center,
                style: _statusStyle(context),
              ),
            ),
            const SizedBox(width: _glyphGap),
            const MicrophoneGlyph(),
            const SizedBox(width: _glyphGap / 2),
            const SizedBox.square(
              key: cannotHearPointerKey,
              dimension: _pointerSize,
              child: CustomPaint(painter: _UpwardPointerPainter(_statusInk)),
            ),
          ],
        ),
      ),
    );
  }
}

class SoundLostWarning extends StatefulWidget {
  const SoundLostWarning({
    super.key,
    required this.hearing,
    required this.taking,
  });

  final MicrophoneHearing hearing;
  final bool taking;

  @override
  State<SoundLostWarning> createState() => _SoundLostWarningState();
}

class _SoundLostWarningState extends State<SoundLostWarning> {
  Timer? _delay;
  bool _warned = false;

  bool get _soundMissing =>
      widget.taking && widget.hearing != MicrophoneHearing.hearing;

  @override
  void initState() {
    super.initState();
    _follow();
  }

  @override
  void didUpdateWidget(SoundLostWarning oldWidget) {
    super.didUpdateWidget(oldWidget);
    _follow();
  }

  @override
  void dispose() {
    _delay?.cancel();
    super.dispose();
  }

  void _follow() {
    if (!_soundMissing) {
      _delay?.cancel();
      _delay = null;
      _warned = false;
      return;
    }
    if (_warned || _delay != null) {
      return;
    }
    _delay = Timer(soundLostWarningDelay, _warn);
  }

  void _warn() {
    _delay = null;
    if (mounted && _soundMissing) {
      setState(() => _warned = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_warned) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: _lineGap),
      child: Semantics(
        container: true,
        liveRegion: true,
        label: soundLostMessage,
        excludeSemantics: true,
        child: Text(
          soundLostMessage,
          textAlign: TextAlign.center,
          style: _statusStyle(context),
        ),
      ),
    );
  }
}

class _UpwardPointerPainter extends CustomPainter {
  const _UpwardPointerPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _pointerStroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final double side = size.shortestSide;
    final Offset tip = Offset(side, 0);
    canvas.drawLine(Offset(0, side), tip, stroke);
    canvas.drawPath(
      Path()
        ..moveTo(side * 0.4, 0)
        ..lineTo(tip.dx, tip.dy)
        ..lineTo(side, side * 0.6),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_UpwardPointerPainter oldDelegate) =>
      oldDelegate.color != color;
}
