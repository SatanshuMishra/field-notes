import 'package:flutter/widgets.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/entry_cards/util/duration_format.dart';

import 'camera_picker.dart';
import 'video_recorder.dart';

enum VideoRecorderPhase {
  preparing,
  idle,
  arming,
  recording,
  paused,
  saving,
  denied
}

const Key videoCloseKey = ValueKey<String>('video-close');
const Key videoShutterKey = ValueKey<String>('video-shutter');
const Key videoDiscardCircleKey = ValueKey<String>('video-discard-circle');
const Key videoSaveCircleKey = ValueKey<String>('video-save-circle');

const String videoFeedLabel = 'CAMERA FEED';

const double _viewportHeight = 480;

const List<Color> _vignetteColors = <Color>[
  Palette.viewportScrim,
  Color(0x000F0D0B),
  Color(0x000F0D0B),
  Color(0xB80F0D0B),
];
const List<double> _vignetteStops = <double>[0, 0.22, 0.68, 1];

const double _chromeInset = 16;
const double _closeGlyphSize = 22;

const double _pillRadius = Shapes.radiusMd;
const double _pillGap = 7;
const double _pillDotSize = 8;
const EdgeInsets _pillPadding =
    EdgeInsets.symmetric(horizontal: 12, vertical: 5);
const double _pillTimeSize = 13;
const Duration _pillBlinkDuration = Duration(milliseconds: 1200);

const double _pickerWidth = 280;

const double _underPillTop = 54;
const double _underPillGap = 8;

const double _hintBottom = 100;
const double _hintSize = 13;
const double _errorGap = 10;
const EdgeInsets _errorPadding =
    EdgeInsets.symmetric(horizontal: 14, vertical: 8);

const double _deniedMaxWidth = 420;
const EdgeInsets _deniedPadding =
    EdgeInsets.symmetric(horizontal: 22, vertical: 20);

const double _controlRowBottom = 22;
const double _controlRowGap = 30;
const double _shutterSize = 70;
const double _shutterBorderWidth = 4;
const double _shutterCoreSize = 24;
const double _shutterPauseGlyphSize = 26;

const double _sideCircleSize = 44;
const double _sideCircleBorderWidth = 1.5;
const double _sideGlyphSize = 18;
const double _sideCaptionGap = 3;
const double _sideCaptionSize = 10;
const Color _discardCaptionColor = Color(0xBFFFFFFF);

class VideoRecorderSheet extends StatelessWidget {
  const VideoRecorderSheet({
    super.key,
    required this.phase,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
    this.onPause,
    this.onResume,
    this.onDiscard,
    this.supportsPause = false,
    this.preview,
    this.devices = const <VideoCaptureDevice>[],
    this.selectedDeviceId,
    this.onDeviceChanged,
    this.elapsed = Duration.zero,
    this.nudgeMessage,
    this.errorMessage,
    this.cameraLabel = 'Camera',
    this.armedHint = 'tap the button to start recording',
    this.armingHint = 'Getting the camera ready…',
    this.recordingHint = 'recording… tap pause or stop',
    this.pausedHint = 'paused · resume or save your clip',
    this.savingHint = 'Saving your video…',
    this.capHint = 'Auto-stops at 30:00.',
    this.deniedMessage = cameraPermissionMessage,
    this.discardLabel = 'Discard',
    this.saveLabel = 'Save',
  });

  final VideoRecorderPhase phase;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCancel;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onDiscard;
  final bool supportsPause;
  final Widget? preview;
  final List<VideoCaptureDevice> devices;
  final String? selectedDeviceId;
  final ValueChanged<String>? onDeviceChanged;
  final Duration elapsed;
  final String? nudgeMessage;
  final String? errorMessage;
  final String cameraLabel;
  final String armedHint;
  final String armingHint;
  final String recordingHint;
  final String pausedHint;
  final String savingHint;
  final String capHint;
  final String deniedMessage;
  final String discardLabel;
  final String saveLabel;

  bool get _isRecording => phase == VideoRecorderPhase.recording;
  bool get _isPaused => phase == VideoRecorderPhase.paused;
  bool get _isActive => _isRecording || _isPaused;
  bool get _isPreparing =>
      phase == VideoRecorderPhase.preparing ||
      phase == VideoRecorderPhase.arming;
  bool get _isSaving => phase == VideoRecorderPhase.saving;
  bool get _isDenied => phase == VideoRecorderPhase.denied;
  bool get _isIdle => phase == VideoRecorderPhase.idle;
  bool get _showsPicker =>
      devices.isNotEmpty && !_isDenied && !_isSaving && !_isPaused;

  @override
  Widget build(BuildContext context) {
    final String? errorMessage = this.errorMessage;
    final String? hint = _hint;
    return SizedBox(
      height: _viewportHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _feed(),
          const IgnorePointer(child: _Vignette()),
          if (_isDenied) _deniedPanel(),
          _closeButton(),
          _timerPill(),
          if (_showsPicker) _picker(),
          _underPill(),
          if (errorMessage != null || hint != null)
            _bottomText(errorMessage, hint),
          _controlRow(),
        ],
      ),
    );
  }

  String? get _hint {
    if (_isDenied) {
      return null;
    }
    if (_isSaving) {
      return savingHint;
    }
    if (_isPreparing) {
      return armingHint;
    }
    if (_isRecording) {
      return recordingHint;
    }
    return _isPaused ? pausedHint : armedHint;
  }

  Widget _feed() {
    final Widget? preview = this.preview;
    if (preview != null) {
      return preview;
    }
    return const CrossHatchPlaceholder(
      variant: CrossHatchVariant.viewport,
      borderRadius: BorderRadius.zero,
      child: Text(videoFeedLabel, style: TypographyTokens.viewportMonoLabel),
    );
  }

  Widget _closeButton() {
    return Positioned(
      left: _chromeInset,
      top: _chromeInset,
      child: Semantics(
        button: true,
        label: 'Close',
        child: GestureDetector(
          key: videoCloseKey,
          behavior: HitTestBehavior.opaque,
          onTap: _isSaving ? null : onCancel,
          child: const IconStickerGlyphIcon(
            glyph: IconStickerGlyph.close,
            color: Palette.onAccent,
            size: _closeGlyphSize,
          ),
        ),
      ),
    );
  }

  Widget _timerPill() {
    return Positioned(
      top: _chromeInset,
      left: 0,
      right: 0,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Palette.viewportScrim,
            borderRadius: BorderRadius.circular(_pillRadius),
          ),
          child: Padding(
            padding: _pillPadding,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _stateDot(),
                const SizedBox(width: _pillGap),
                Text(
                  formatMediaDuration(elapsed.inMilliseconds),
                  style: TypographyTokens.captureLabelSans.copyWith(
                    fontSize: _pillTimeSize,
                    color: Palette.onAccent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stateDot() {
    if (_isRecording) {
      return const Blink(
        stepped: true,
        minOpacity: 0,
        duration: _pillBlinkDuration,
        child: _PillDot(color: Palette.recordFill),
      );
    }
    if (_isPaused) {
      return const _PillDot(color: Palette.viewportAmber);
    }
    return const _PillDot(color: Palette.onDark30);
  }

  Widget _picker() {
    return Positioned(
      top: _chromeInset,
      right: _chromeInset,
      child: SizedBox(
        width: _pickerWidth,
        child: CameraPicker(
          devices: devices,
          selectedDeviceId: selectedDeviceId,
          onChanged: _isIdle ? onDeviceChanged : null,
          enabled: _isIdle,
          label: cameraLabel,
        ),
      ),
    );
  }

  Widget _underPill() {
    final String? nudgeMessage = this.nudgeMessage;
    return Positioned(
      top: _underPillTop,
      left: 0,
      right: 0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (_isActive) Text(capHint, style: _hintStyle),
          if (_isActive && nudgeMessage != null) ...<Widget>[
            const SizedBox(height: _underPillGap),
            Toast(message: nudgeMessage, variant: ToastVariant.dark),
          ],
        ],
      ),
    );
  }

  Widget _bottomText(String? errorMessage, String? hint) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: _hintBottom,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (errorMessage != null) ...<Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: Palette.viewportScrim,
                borderRadius: BorderRadius.circular(_pillRadius),
              ),
              child: Padding(
                padding: _errorPadding,
                child: Text(
                  errorMessage,
                  textAlign: TextAlign.center,
                  style: TypographyTokens.captionSans
                      .copyWith(color: Palette.onDark85),
                ),
              ),
            ),
            const SizedBox(height: _errorGap),
          ],
          if (hint != null)
            Text(hint, textAlign: TextAlign.center, style: _hintStyle),
        ],
      ),
    );
  }

  Widget _deniedPanel() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _deniedMaxWidth),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Palette.viewportScrim,
            borderRadius: BorderRadius.circular(Shapes.radiusXl),
          ),
          child: Padding(
            padding: _deniedPadding,
            child: Text(
              deniedMessage,
              textAlign: TextAlign.center,
              style: TypographyTokens.bodySans.copyWith(
                color: Palette.onDark85,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _controlRow() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: _controlRowBottom,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (_isActive) ...<Widget>[
            _discardCircle(),
            const SizedBox(width: _controlRowGap),
          ],
          _shutter(),
          if (_isActive) ...<Widget>[
            const SizedBox(width: _controlRowGap),
            _saveCircle(),
          ],
        ],
      ),
    );
  }

  Widget _discardCircle() {
    return _SideControl(
      controlKey: videoDiscardCircleKey,
      onTap: onDiscard ?? onCancel,
      background: Palette.viewportScrim,
      borderColor: Palette.onDark40,
      glyph: IconStickerGlyph.trash,
      label: discardLabel,
      captionColor: _discardCaptionColor,
    );
  }

  Widget _saveCircle() {
    return _SideControl(
      controlKey: videoSaveCircleKey,
      onTap: onStop,
      background: Palette.coral,
      borderColor: Palette.onAccent,
      glyph: IconStickerGlyph.check,
      label: saveLabel,
      captionColor: Palette.onDark85,
    );
  }

  Widget _shutter() {
    return Semantics(
      button: true,
      label: _shutterLabel,
      child: GestureDetector(
        key: videoShutterKey,
        behavior: HitTestBehavior.opaque,
        onTap: _shutterTap,
        child: Container(
          width: _shutterSize,
          height: _shutterSize,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Palette.onAccent,
              width: _shutterBorderWidth,
            ),
          ),
          child: _showsPauseGlyph
              ? const IconStickerGlyphIcon(
                  glyph: IconStickerGlyph.pause,
                  color: Palette.onAccent,
                  size: _shutterPauseGlyphSize,
                )
              : const SizedBox.square(
                  dimension: _shutterCoreSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Palette.recordFill,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  bool get _showsPauseGlyph => _isRecording && supportsPause && onPause != null;

  String get _shutterLabel {
    if (_isRecording) {
      return _showsPauseGlyph ? 'Pause recording' : 'Stop recording';
    }
    if (_isPaused) {
      return onResume != null ? 'Resume recording' : 'Stop recording';
    }
    return 'Start recording';
  }

  VoidCallback? get _shutterTap {
    if (_isSaving || _isPreparing) {
      return null;
    }
    if (_isRecording) {
      return _showsPauseGlyph ? onPause : onStop;
    }
    return _isPaused ? (onResume ?? onStop) : onStart;
  }

  TextStyle get _hintStyle => TypographyTokens.hintAccent.copyWith(
        fontSize: _hintSize,
        color: Palette.onDark72,
      );
}

class _Vignette extends StatelessWidget {
  const _Vignette();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: _vignetteColors,
          stops: _vignetteStops,
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _SideControl extends StatelessWidget {
  const _SideControl({
    required this.controlKey,
    required this.onTap,
    required this.background,
    required this.borderColor,
    required this.glyph,
    required this.label,
    required this.captionColor,
  });

  final Key controlKey;
  final VoidCallback onTap;
  final Color background;
  final Color borderColor;
  final IconStickerGlyph glyph;
  final String label;
  final Color captionColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: controlKey,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: _sideCircleSize,
            height: _sideCircleSize,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: background,
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor,
                width: _sideCircleBorderWidth,
              ),
            ),
            child: IconStickerGlyphIcon(
              glyph: glyph,
              color: Palette.onAccent,
              size: _sideGlyphSize,
            ),
          ),
          const SizedBox(height: _sideCaptionGap),
          Text(
            label,
            style: TypographyTokens.labelSans.copyWith(
              fontSize: _sideCaptionSize,
              color: captionColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _PillDot extends StatelessWidget {
  const _PillDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _pillDotSize,
      child: DecoratedBox(
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}
