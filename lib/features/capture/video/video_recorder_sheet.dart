import 'package:flutter/widgets.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';

import 'camera_picker.dart';
import 'video_recorder.dart';

enum VideoRecorderPhase { preparing, idle, arming, recording, saving, denied }

class VideoRecorderSheet extends StatelessWidget {
  const VideoRecorderSheet({
    super.key,
    required this.phase,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
    this.preview,
    this.devices = const <VideoCaptureDevice>[],
    this.selectedDeviceId,
    this.onDeviceChanged,
    this.nudgeMessage,
    this.errorMessage,
    this.cameraLabel = 'Camera',
    this.title = 'Record video',
    this.armedHint = 'Tap record when you are ready.',
    this.armingHint = 'Getting the camera ready…',
    this.recordingHint = 'Recording…',
    this.savingHint = 'Saving your video…',
    this.capHint = 'Auto-stops at 30:00.',
    this.deniedMessage = cameraPermissionMessage,
    this.startLabel = 'Record',
    this.stopLabel = 'Stop & save',
    this.savingLabel = 'Saving…',
    this.armingLabel = 'Preparing…',
    this.tryAgainLabel = 'Try again',
    this.cancelLabel = 'Cancel',
    this.maxWidth = 460,
  });

  final VideoRecorderPhase phase;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCancel;
  final Widget? preview;
  final List<VideoCaptureDevice> devices;
  final String? selectedDeviceId;
  final ValueChanged<String>? onDeviceChanged;
  final String? nudgeMessage;
  final String? errorMessage;
  final String cameraLabel;
  final String title;
  final String armedHint;
  final String armingHint;
  final String recordingHint;
  final String savingHint;
  final String capHint;
  final String deniedMessage;
  final String startLabel;
  final String stopLabel;
  final String savingLabel;
  final String armingLabel;
  final String tryAgainLabel;
  final String cancelLabel;
  final double maxWidth;

  bool get _isRecording => phase == VideoRecorderPhase.recording;
  bool get _isPreparing =>
      phase == VideoRecorderPhase.preparing || phase == VideoRecorderPhase.arming;
  bool get _isSaving => phase == VideoRecorderPhase.saving;
  bool get _isDenied => phase == VideoRecorderPhase.denied;
  bool get _isIdle => phase == VideoRecorderPhase.idle;
  bool get _showsPicker => devices.isNotEmpty && !_isDenied && !_isSaving;

  @override
  Widget build(BuildContext context) {
    final String? errorMessage = this.errorMessage;
    final String? nudgeMessage = this.nudgeMessage;
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
              _VideoStage(
                phase: phase,
                preview: preview,
                armedHint: armedHint,
                armingHint: armingHint,
                recordingHint: recordingHint,
                savingHint: savingHint,
                capHint: capHint,
                deniedMessage: deniedMessage,
              ),
              if (_showsPicker) ...<Widget>[
                const SizedBox(height: 16),
                CameraPicker(
                  devices: devices,
                  selectedDeviceId: selectedDeviceId,
                  onChanged: _isIdle ? onDeviceChanged : null,
                  enabled: _isIdle,
                  label: cameraLabel,
                ),
              ],
              if (_isRecording && nudgeMessage != null) ...<Widget>[
                const SizedBox(height: 12),
                Toast(message: nudgeMessage, surface: Palette.cardWarm),
              ],
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
    if (_isPreparing) {
      return StickerButton(label: armingLabel, onPressed: null);
    }
    if (_isRecording) {
      return StickerButton(label: stopLabel, onPressed: onStop);
    }
    if (_isDenied) {
      return StickerButton(label: tryAgainLabel, onPressed: onStart);
    }
    return StickerButton(label: startLabel, onPressed: onStart);
  }
}

class _VideoStage extends StatelessWidget {
  const _VideoStage({
    required this.phase,
    required this.preview,
    required this.armedHint,
    required this.armingHint,
    required this.recordingHint,
    required this.savingHint,
    required this.capHint,
    required this.deniedMessage,
  });

  final VideoRecorderPhase phase;
  final Widget? preview;
  final String armedHint;
  final String armingHint;
  final String recordingHint;
  final String savingHint;
  final String capHint;
  final String deniedMessage;

  @override
  Widget build(BuildContext context) {
    return switch (phase) {
      VideoRecorderPhase.recording => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _previewFrame(preview),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Blink(child: _dot(Palette.danger)),
                const SizedBox(width: 12),
                Flexible(
                  child: Text(recordingHint, style: TypographyTokens.captionSans),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              capHint,
              textAlign: TextAlign.center,
              style: TypographyTokens.captionSans.copyWith(color: Palette.muted),
            ),
          ],
        ),
      VideoRecorderPhase.preparing ||
      VideoRecorderPhase.arming =>
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _previewFrame(preview),
            const SizedBox(height: 12),
            _stageMessage(armingHint, Palette.mutedDeep),
          ],
        ),
      VideoRecorderPhase.saving => _stageMessage(savingHint, Palette.muted),
      VideoRecorderPhase.denied => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const CrossHatchPlaceholder(height: 160),
            const SizedBox(height: 12),
            _stageMessage(deniedMessage, Palette.danger),
          ],
        ),
      VideoRecorderPhase.idle => Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _previewFrame(preview),
            const SizedBox(height: 12),
            _stageMessage(armedHint, Palette.mutedDeep),
          ],
        ),
    };
  }

  Widget _previewFrame(Widget? preview) {
    if (preview == null) {
      return const CrossHatchPlaceholder(height: 200);
    }
    return ClipRRect(
      borderRadius: Shapes.cardBorderRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Shapes.outline,
          borderRadius: Shapes.cardBorderRadius,
        ),
        child: SizedBox(
          height: 200,
          width: double.infinity,
          child: preview,
        ),
      ),
    );
  }

  Widget _stageMessage(String message, Color color) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Palette.cardWarm,
        border: Shapes.outline,
        borderRadius: Shapes.buttonBorderRadius,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _dot(color),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                message,
                textAlign: TextAlign.center,
                style: TypographyTokens.captionSans,
              ),
            ),
          ],
        ),
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
