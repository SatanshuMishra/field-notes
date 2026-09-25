import 'package:flutter/widgets.dart';

import 'package:field_notes/design/icons/capture_icons.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/features/entry_cards/util/duration_format.dart';

enum VoiceRecorderPhase { idle, recording, paused, saving }

const Key voiceCloseKey = ValueKey<String>('voice-close');
const Key voiceRecordButtonKey = ValueKey<String>('voice-record-button');
const Key voiceDiscardPillKey = ValueKey<String>('voice-discard-pill');
const Key voiceSavePillKey = ValueKey<String>('voice-save-pill');

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

const double _minTapTarget = 48;

const double _closeInset = 18;
const double _closeGlyphSize = 22;
const double _closeTargetInset = (_minTapTarget - _closeGlyphSize) / 2;
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

const double _pillRowGapTop = 6;
const double _pillRowSpacing = 10;
const double _pillRadius = Shapes.radiusSheet;
const double _pillIconSize = 15;
const double _discardPillBorderWidth = 1.5;
const double _discardPillGap = 8;
const EdgeInsets _discardPillPadding =
    EdgeInsets.symmetric(horizontal: 18, vertical: 10);
const double _savePillBorderWidth = 2;
const double _savePillGap = 9;
const double _savePillGlyphRadius = 4;
const EdgeInsets _savePillPadding =
    EdgeInsets.symmetric(horizontal: 22, vertical: 11);
const double _pillLabelSize = 13;

class VoiceRecorderSheet extends StatelessWidget {
  const VoiceRecorderSheet({
    super.key,
    required this.phase,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
    this.onPause,
    this.onResume,
    this.onDiscard,
    this.elapsed = Duration.zero,
    this.errorMessage,
    this.title = 'New voice memo',
    this.armedHint = 'tap the mic when you’re ready',
    this.recordingHint = 'listening… speak freely',
    this.pausedHint = 'paused · resume when you’re ready',
    this.savingHint = 'Saving your recording…',
    this.recordingLabel = 'Recording',
    this.pausedLabel = 'Paused',
    this.discardLabel = 'Discard',
    this.saveLabel = 'Save memo',
  });

  final VoiceRecorderPhase phase;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCancel;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onDiscard;
  final Duration elapsed;
  final String? errorMessage;
  final String title;
  final String armedHint;
  final String recordingHint;
  final String pausedHint;
  final String savingHint;
  final String recordingLabel;
  final String pausedLabel;
  final String discardLabel;
  final String saveLabel;

  bool get _isRecording => phase == VoiceRecorderPhase.recording;
  bool get _isPaused => phase == VoiceRecorderPhase.paused;
  bool get _isSaving => phase == VoiceRecorderPhase.saving;
  bool get _isActive => _isRecording || _isPaused;

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
                if (_isActive) ...<Widget>[
                  const SizedBox(height: _pillRowGapTop),
                  _pillRow(),
                ],
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
          left: _closeInset - _closeTargetInset,
          top: _closeInset - _closeTargetInset,
          child: Semantics(
            button: true,
            enabled: !_isSaving,
            label: 'Close',
            child: GestureDetector(
              key: voiceCloseKey,
              behavior: HitTestBehavior.opaque,
              onTap: _isSaving ? null : onCancel,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: _minTapTarget,
                  minHeight: _minTapTarget,
                ),
                child: const Center(
                  child: SizedBox.square(
                    dimension: _closeGlyphSize,
                    child: CustomPaint(painter: _VoiceCloseGlyphPainter()),
                  ),
                ),
              ),
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
    if (_isRecording) {
      return recordingHint;
    }
    return _isPaused ? pausedHint : armedHint;
  }

  Widget _header() {
    if (_isRecording) {
      return _statusRow(
        label: recordingLabel,
        color: Palette.danger,
        dot: const Blink(
          stepped: true,
          minOpacity: 0,
          duration: _statusBlinkDuration,
          child: _StatusDot(color: Palette.danger),
        ),
      );
    }
    if (_isPaused) {
      return _statusRow(
        label: pausedLabel,
        color: Palette.statusAmber,
        dot: const _StatusDot(color: Palette.statusAmber),
      );
    }
    return Text(title, style: TypographyTokens.composerTitleAccent);
  }

  Widget _statusRow({
    required String label,
    required Color color,
    required Widget dot,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        dot,
        const SizedBox(width: _statusGap),
        Text(
          label.toUpperCase(),
          style: TypographyTokens.captureLabelSans.copyWith(
            letterSpacing: _statusTracking,
            color: color,
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

  VoidCallback? get _recordTap {
    if (_isSaving) {
      return null;
    }
    if (_isRecording) {
      return onPause;
    }
    return _isPaused ? onResume : onStart;
  }

  String get _recordSemanticsLabel {
    if (_isRecording) {
      return onPause != null ? 'Pause recording' : 'Stop recording';
    }
    if (_isPaused) {
      return onResume != null ? 'Resume recording' : 'Stop recording';
    }
    return 'Start recording';
  }

  Widget _recordButton() {
    return Semantics(
      button: true,
      enabled: _recordTap != null,
      label: _recordSemanticsLabel,
      child: GestureDetector(
        key: voiceRecordButtonKey,
        behavior: HitTestBehavior.opaque,
        onTap: _recordTap,
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
          child: _isRecording
              ? const IconStickerGlyphIcon(
                  glyph: IconStickerGlyph.pause,
                  color: Palette.onAccent,
                  size: _recordIconSize,
                )
              : const CaptureIcon(
                  glyph: CaptureGlyph.mic,
                  color: Palette.onAccent,
                  size: _recordIconSize,
                ),
        ),
      ),
    );
  }

  Widget _pillRow() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        _discardPill(),
        const SizedBox(width: _pillRowSpacing),
        _savePill(),
      ],
    );
  }

  Widget _discardPill() {
    return Semantics(
      container: true,
      button: true,
      enabled: onDiscard != null,
      child: GestureDetector(
        key: voiceDiscardPillKey,
        behavior: HitTestBehavior.opaque,
        onTap: onDiscard,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _minTapTarget,
            minHeight: _minTapTarget,
          ),
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Palette.dangerSurface,
                border: Border.all(
                  color: Palette.danger,
                  width: _discardPillBorderWidth,
                ),
                borderRadius: BorderRadius.circular(_pillRadius),
              ),
              child: Padding(
                padding: _discardPillPadding,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const IconStickerGlyphIcon(
                      glyph: IconStickerGlyph.trash,
                      color: Palette.danger,
                      size: _pillIconSize,
                    ),
                    const SizedBox(width: _discardPillGap),
                    Text(discardLabel, style: _pillLabelStyle(Palette.danger)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _savePill() {
    return Semantics(
      container: true,
      button: true,
      child: GestureDetector(
        key: voiceSavePillKey,
        behavior: HitTestBehavior.opaque,
        onTap: onStop,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _minTapTarget,
            minHeight: _minTapTarget,
          ),
          child: Center(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Palette.danger,
                border: Border.all(
                  color: Palette.ink,
                  width: _savePillBorderWidth,
                ),
                borderRadius: BorderRadius.circular(_pillRadius),
                boxShadow: Shadows.emphasis,
              ),
              child: Padding(
                padding: _savePillPadding,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    const SizedBox.square(
                      dimension: _pillIconSize,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Palette.onAccent,
                          borderRadius: BorderRadius.all(
                            Radius.circular(_savePillGlyphRadius),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: _savePillGap),
                    Text(saveLabel, style: _pillLabelStyle(Palette.onAccent)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _pillLabelStyle(Color color) =>
      TypographyTokens.labelSans.copyWith(
        fontSize: _pillLabelSize,
        fontWeight: FontWeight.w600,
        color: color,
      );

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

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _statusDotSize,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
