import 'package:flutter/widgets.dart';

import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';

enum VoiceRecorderPhase { idle, recording, saving }

class VoiceRecorderSheet extends StatelessWidget {
  const VoiceRecorderSheet({
    super.key,
    required this.phase,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
    this.errorMessage,
    this.title = 'Record voice',
    this.armedHint = 'Tap record when you are ready.',
    this.recordingHint = 'Recording…',
    this.savingHint = 'Saving your recording…',
    this.startLabel = 'Record',
    this.stopLabel = 'Stop & save',
    this.savingLabel = 'Saving…',
    this.cancelLabel = 'Cancel',
    this.maxWidth = 420,
  });

  final VoiceRecorderPhase phase;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCancel;
  final String? errorMessage;
  final String title;
  final String armedHint;
  final String recordingHint;
  final String savingHint;
  final String startLabel;
  final String stopLabel;
  final String savingLabel;
  final String cancelLabel;
  final double maxWidth;

  bool get _isRecording => phase == VoiceRecorderPhase.recording;
  bool get _isSaving => phase == VoiceRecorderPhase.saving;

  @override
  Widget build(BuildContext context) {
    final String? errorMessage = this.errorMessage;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: StickerCard(
          surface: Palette.cardBright,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(title, style: TypographyTokens.titleSerif),
              const SizedBox(height: 16),
              _VoiceStage(
                phase: phase,
                armedHint: armedHint,
                recordingHint: recordingHint,
                savingHint: savingHint,
              ),
              if (errorMessage != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  errorMessage,
                  style: TypographyTokens.captionSans
                      .copyWith(color: Palette.danger),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  StickerButton(
                    label: cancelLabel,
                    variant: StickerButtonVariant.secondary,
                    onPressed: _isSaving ? null : onCancel,
                  ),
                  const SizedBox(width: 12),
                  _primaryButton(),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _primaryButton() {
    if (_isSaving) {
      return StickerButton(label: savingLabel, onPressed: null);
    }
    if (_isRecording) {
      return StickerButton(label: stopLabel, onPressed: onStop);
    }
    return StickerButton(label: startLabel, onPressed: onStart);
  }
}

class _VoiceStage extends StatelessWidget {
  const _VoiceStage({
    required this.phase,
    required this.armedHint,
    required this.recordingHint,
    required this.savingHint,
  });

  final VoiceRecorderPhase phase;
  final String armedHint;
  final String recordingHint;
  final String savingHint;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.cardWarm,
        border: Shapes.outline,
        borderRadius: Shapes.buttonBorderRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: switch (phase) {
          VoiceRecorderPhase.recording => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Blink(
                  child: _dot(Palette.danger),
                ),
                const SizedBox(width: 12),
                const WaveformBars(),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(recordingHint, style: TypographyTokens.captionSans),
                ),
              ],
            ),
          VoiceRecorderPhase.saving => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _dot(Palette.muted),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(savingHint, style: TypographyTokens.captionSans),
                ),
              ],
            ),
          VoiceRecorderPhase.idle => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _dot(Palette.muted),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(armedHint, style: TypographyTokens.captionSans),
                ),
              ],
            ),
        },
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Shapes.outline,
      ),
    );
  }
}
