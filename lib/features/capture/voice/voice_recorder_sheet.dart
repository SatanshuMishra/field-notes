import 'package:flutter/widgets.dart';

import 'package:field_notes/design/icons/capture_icons.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/entry_cards/util/duration_format.dart';

enum VoiceRecorderPhase { idle, recording, saving }

const Key voiceCloseKey = ValueKey<String>('voice-close');
const Key voiceRecordButtonKey = ValueKey<String>('voice-record-button');

const List<double> voiceWaveHeights = <double>[
  0.30,
  0.65,
  0.95,
  0.50,
  0.80,
  0.40,
  1.00,
  0.55,
  0.85,
  0.35,
  0.70,
  0.45,
];

const List<Duration> voiceWaveDurations = <Duration>[
  Duration(milliseconds: 700),
  Duration(milliseconds: 850),
  Duration(milliseconds: 1000),
  Duration(milliseconds: 1150),
];

const double _voiceWaveThreshold = 0.6;

const Duration _haloPulseDuration = Duration(milliseconds: 2400);
const Duration _statusBlinkDuration = Duration(milliseconds: 1200);

const double _padTop = 40;
const double _padHorizontal = 22;
const double _padBottom = 44;

const double _closeInset = 18;
const double _closeGlyphSize = 22;
const double _closeStrokeWidth = 2;
const double _closeViewBox = 24;

const double _headerGap = 4;
const double _statusGap = 7;
const double _statusDotSize = 8;
const double _statusTracking = 0.96;

const double _stageSize = 150;
const double _stageGapTop = 14;
const double _stageGapBottom = 6;

const double _recordButtonSize = 92;
const double _recordBorderWidth = 2.5;
const double _recordIconSize = 38;
const double _recordShadowAlpha = 0.7;
const Offset _recordShadowOffset = Offset(0, 10);
const double _recordShadowBlur = 24;
const double _recordShadowSpread = -8;

const double _hintGap = 2;

const double _waveGapTop = 12;
const double _waveGapBottom = 4;
const double _waveHeight = 40;
const double _waveBarWidth = 4;
const double _waveSpacing = 3;

const double _hairlineWidth = 120;
const double _hairlineHeight = 2;
const double _hairlineRadius = 2;

const double _errorGap = 12;

class VoiceRecorderSheet extends StatelessWidget {
  const VoiceRecorderSheet({
    super.key,
    required this.phase,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
    this.elapsed = Duration.zero,
    this.errorMessage,
    this.title = 'New voice memo',
    this.armedHint = 'tap the mic when you’re ready',
    this.recordingHint = 'listening… speak freely',
    this.savingHint = 'Saving your recording…',
    this.recordingLabel = 'Recording',
  });

  final VoiceRecorderPhase phase;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCancel;
  final Duration elapsed;
  final String? errorMessage;
  final String title;
  final String armedHint;
  final String recordingHint;
  final String savingHint;
  final String recordingLabel;

  bool get _isRecording => phase == VoiceRecorderPhase.recording;
  bool get _isSaving => phase == VoiceRecorderPhase.saving;

  @override
  Widget build(BuildContext context) {
    final String? errorMessage = this.errorMessage;
    return Stack(
      children: <Widget>[
        SizedBox(
          width: double.infinity,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              _padHorizontal,
              _padTop,
              _padHorizontal,
              _padBottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const SizedBox(height: _headerGap),
                _header(),
                const SizedBox(height: _stageGapTop),
                _stage(),
                const SizedBox(height: _stageGapBottom),
                Text(
                  formatMediaDuration(elapsed.inMilliseconds),
                  style: TypographyTokens.timerSerif,
                ),
                const SizedBox(height: _hintGap),
                Text(
                  _hint,
                  textAlign: TextAlign.center,
                  style: TypographyTokens.hintAccent,
                ),
                const SizedBox(height: _waveGapTop),
                _wave(),
                const SizedBox(height: _waveGapBottom),
                if (errorMessage != null) ...<Widget>[
                  const SizedBox(height: _errorGap),
                  Text(
                    errorMessage,
                    textAlign: TextAlign.center,
                    style: TypographyTokens.captionSans
                        .copyWith(color: Palette.danger),
                  ),
                ],
              ],
            ),
          ),
        ),
        Positioned(
          left: _closeInset,
          top: _closeInset,
          child: GestureDetector(
            key: voiceCloseKey,
            behavior: HitTestBehavior.opaque,
            onTap: _isSaving ? null : onCancel,
            child: const SizedBox.square(
              dimension: _closeGlyphSize,
              child: CustomPaint(painter: _VoiceCloseGlyphPainter()),
            ),
          ),
        ),
      ],
    );
  }

  String get _hint {
    if (_isSaving) {
      return savingHint;
    }
    return _isRecording ? recordingHint : armedHint;
  }

  Widget _header() {
    if (!_isRecording) {
      return Text(title, style: TypographyTokens.composerTitleAccent);
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Blink(
          stepped: true,
          minOpacity: 0,
          duration: _statusBlinkDuration,
          child: SizedBox.square(
            dimension: _statusDotSize,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Palette.danger,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        const SizedBox(width: _statusGap),
        Text(
          recordingLabel.toUpperCase(),
          style: TypographyTokens.captureLabelSans.copyWith(
            letterSpacing: _statusTracking,
            color: Palette.danger,
          ),
        ),
      ],
    );
  }

  Widget _stage() {
    return SizedBox.square(
      dimension: _stageSize,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (_isRecording)
            const GlowPulse(
              diameter: _stageSize,
              duration: _haloPulseDuration,
            ),
          _recordButton(),
        ],
      ),
    );
  }

  Widget _recordButton() {
    return GestureDetector(
      key: voiceRecordButtonKey,
      behavior: HitTestBehavior.opaque,
      onTap: _isSaving ? null : (_isRecording ? onStop : onStart),
      child: Container(
        width: _recordButtonSize,
        height: _recordButtonSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Palette.coral,
          shape: BoxShape.circle,
          border: Border.all(color: Palette.ink, width: _recordBorderWidth),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Palette.coral.withValues(alpha: _recordShadowAlpha),
              offset: _recordShadowOffset,
              blurRadius: _recordShadowBlur,
              spreadRadius: _recordShadowSpread,
            ),
          ],
        ),
        child: const CaptureIcon(
          glyph: CaptureGlyph.mic,
          color: Palette.onAccent,
          size: _recordIconSize,
        ),
      ),
    );
  }

  Widget _wave() {
    return SizedBox(
      height: _waveHeight,
      child: Center(
        child: _isRecording
            ? const WaveformBars(
                heights: voiceWaveHeights,
                perBarDurations: voiceWaveDurations,
                twoToneThreshold: _voiceWaveThreshold,
                barWidth: _waveBarWidth,
                spacing: _waveSpacing,
                maxHeight: _waveHeight,
              )
            : const SizedBox(
                width: _hairlineWidth,
                height: _hairlineHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Palette.ink18,
                    borderRadius: BorderRadius.all(
                      Radius.circular(_hairlineRadius),
                    ),
                  ),
                ),
              ),
      ),
    );
  }
}

class _VoiceCloseGlyphPainter extends CustomPainter {
  const _VoiceCloseGlyphPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint stroke = Paint()
      ..color = Palette.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = _closeStrokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.scale(size.shortestSide / _closeViewBox);
    canvas.drawLine(const Offset(6, 6), const Offset(18, 18), stroke);
    canvas.drawLine(const Offset(18, 6), const Offset(6, 18), stroke);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_VoiceCloseGlyphPainter oldDelegate) => false;
}
