import 'dart:async';

import 'package:flutter/material.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/interaction/hover_style.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/motion/motion_tokens.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/capture/audio/cannot_hear_notice.dart';
import 'package:field_notes/features/capture/core/capture_day_line.dart';
import 'package:field_notes/features/capture/audio/input_panel.dart';
import 'package:field_notes/features/capture/audio/microphone_hearing.dart';
import 'package:field_notes/features/capture/immersive/capture_button.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';

import 'camera_gestures.dart';
import 'camera_glyphs.dart';
import 'camera_picker.dart';
import 'video_recorder.dart';
import 'video_shutter.dart';

enum VideoRecorderPhase {
  preparing,
  idle,
  breathing,
  arming,
  recording,
  paused,
  saving,
  denied;

  StagePhase get stage => switch (this) {
    VideoRecorderPhase.preparing ||
    VideoRecorderPhase.idle ||
    VideoRecorderPhase.denied => StagePhase.idle,
    VideoRecorderPhase.breathing ||
    VideoRecorderPhase.arming => StagePhase.breathing,
    VideoRecorderPhase.recording => StagePhase.recording,
    VideoRecorderPhase.paused => StagePhase.paused,
    VideoRecorderPhase.saving => StagePhase.saving,
  };
}

const Set<VideoRecorderPhase> _takingPhases = <VideoRecorderPhase>{
  VideoRecorderPhase.breathing,
  VideoRecorderPhase.arming,
  VideoRecorderPhase.recording,
  VideoRecorderPhase.paused,
};

const Key videoCloseKey = ValueKey<String>('video-close');
const Key videoShutterKey = ValueKey<String>('video-shutter');
const Key videoDiscardCircleKey = ValueKey<String>('video-discard-circle');
const Key videoSaveCircleKey = ValueKey<String>('video-save-circle');
const Key videoKeepGoingKey = ValueKey<String>('video-keep-going');
const Key videoCameraKey = ValueKey<String>('video-camera');
const Key videoKeyboardHintKey = ValueKey<String>('video-keyboard-hint');
const Key videoFlipCameraKey = ValueKey<String>('video-flip-camera');
const Key videoTryAgainKey = ValueKey<String>('video-try-again');
const Key videoTakeIndicatorKey = ValueKey<String>('video-take-indicator');

const String videoCameraOffTitle = 'Camera off.';
const String videoCameraOffMessage = 'Only your voice is kept, as a voice log.';
const String videoLetGoLabel = 'Let go';
const String videoKeepLabel = 'Keep';
const String videoStartLabel = 'Start recording';
const String videoSkipBreathLabel = 'Skip the breath';
const String videoPauseLabel = 'Pause recording';
const String videoResumeLabel = 'Resume recording';
const String videoStopAndKeepLabel = 'Stop and keep';
const String videoCameraLabel = 'Camera';
const String videoTryAgainLabel = 'Try again';
const String videoSavingHint = 'Saving your video…';

String videoSwitchCameraLabel(VideoCaptureDevice device) =>
    'Switch to ${device.label.toLowerCase()}';

const Color _hintInk = Color(0xFFB7A58C);
const Color _cameraOffInk = Color(0xFFB7A58C);
const Color _letGoFill = Color(0x80140F0C);
const Color _letGoEdge = Color(0x59F3E6D1);
const Color _letGoGlyphInk = Color(0xD9FFFFFF);
const Color _letGoCaptionInk = Color(0xCCF3E6D1);
const Color _keepFill = Color(0xFFF3E6D1);
const Color _keepGlyphInk = Color(0xFF1C1713);
const Color _keepCaptionInk = Color(0xFFF3E6D1);
const Color _deniedFill = Color(0xB81C1713);
const Color _deniedEdge = Color(0x24F3E6D1);
const Color _deniedInk = Color(0xFFDCCAB0);
const Color _questionShadow = Color(0x73000000);

const double _disabledOpacity = 0.5;
const double videoPausedShutterOpacity = 0.55;
const Duration videoArmingHintDelay = Duration(milliseconds: 600);

const double _sidebarSideCircle = 52;
const double _bottomBarSideCircle = 48;
const double _sidebarSideSlot = 68;
const double _bottomBarSideSlot = 64;
const double _sidebarControlGap = 34;
const double _bottomBarControlGap = 22;
const double _sideEdgeWidth = 1.5;
const double _letGoGlyph = 17;
const double _keepGlyph = 19;
const double _sideCaptionGap = 6;
const double _sidebarCaptionSize = 11;
const double _bottomBarCaptionSize = 10;

const double _sidebarGlow = 300;
const double _bottomBarGlow = 210;
const double _settleGlowAlpha = 0.4;
const double _breatheGlowAlpha = 0.3;
const double _sidebarCameraOffSize = 18;
const double _bottomBarCameraOffSize = 14;
const double _cameraOffLeading = 1.45;

const double _noteSize = 12;
const double _errorSize = 13;
const double _noteGap = 6;
const double _errorGap = 8;
const double _keyboardHintSize = 11;
const double _keyboardHintTracking = 0.22;
const double _keyboardHintInset = 20;
const double _sidebarTrailingGap = 8;

const double _sidebarQuestionShadowBlur = 20;
const double _bottomBarQuestionShadowBlur = 16;
const Offset _questionShadowOffset = Offset(0, 2);
const TextStyle _statusOverPicture = TextStyle(
  shadows: <Shadow>[
    Shadow(
      color: _questionShadow,
      offset: _questionShadowOffset,
      blurRadius: _bottomBarQuestionShadowBlur,
    ),
  ],
);

const double _deniedMaxWidth = 420;
const double _deniedGutter = 24;
const double _deniedTextSize = 14;
const double _deniedLeading = 1.45;
const double _deniedEdgeWidth = 1;
const double _deniedActionGap = 16;
const BorderRadius _deniedRadius = BorderRadius.all(Radius.circular(18));
const EdgeInsets _deniedPadding = EdgeInsets.symmetric(
  horizontal: 22,
  vertical: 20,
);

const Key _armingHintLineKey = ValueKey<String>('video-arming-hint-line');
const Key _letGoPanelSlotKey = ValueKey<String>('video-let-go-panel-slot');
const Key _controlsSlotKey = ValueKey<String>('video-controls-slot');

class VideoRecorderSheet extends StatefulWidget {
  const VideoRecorderSheet({
    super.key,
    required this.phase,
    required this.onStart,
    required this.onStop,
    required this.onLeave,
    this.onPause,
    this.onResume,
    this.onKeepGoing,
    this.onLetGo,
    this.asking = false,
    this.letGoKey,
    this.supportsPause = false,
    this.preview,
    this.devices = const <VideoCaptureDevice>[],
    this.selectedDeviceId,
    this.onDeviceChanged,
    this.cameraOn = true,
    this.onCameraChanged,
    this.controls,
    this.elapsed = Duration.zero,
    this.nudgeMessage,
    this.errorMessage,
    this.cameraLabel = 'Camera',
    this.armingHint = 'Getting the camera ready…',
    this.savingHint = videoSavingHint,
    this.capHint = 'Auto-stops at 30:00.',
    this.deniedMessage = cameraPermissionMessage,
    this.onVoiceSettings,
    this.levels = const Stream<double>.empty(),
    this.hearing = MicrophoneHearing.hearing,
    this.titleController,
    this.dayLine,
  });

  final VideoRecorderPhase phase;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onLeave;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onKeepGoing;
  final VoidCallback? onLetGo;
  final bool asking;
  final Key? letGoKey;
  final bool supportsPause;
  final Widget? preview;
  final List<VideoCaptureDevice> devices;
  final String? selectedDeviceId;
  final ValueChanged<String>? onDeviceChanged;
  final bool cameraOn;
  final ValueChanged<bool>? onCameraChanged;
  final CameraControls? controls;
  final Duration elapsed;
  final String? nudgeMessage;
  final String? errorMessage;
  final String cameraLabel;
  final String armingHint;
  final String savingHint;
  final String capHint;
  final String deniedMessage;
  final VoidCallback? onVoiceSettings;
  final Stream<double> levels;
  final MicrophoneHearing hearing;
  final TextEditingController? titleController;
  final CaptureDayLine? dayLine;

  @override
  State<VideoRecorderSheet> createState() => _VideoRecorderSheetState();
}

class _VideoRecorderSheetState extends State<VideoRecorderSheet>
    with TickerProviderStateMixin, RecorderChromeFade<VideoRecorderSheet> {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: stageBreathDuration,
  );
  Timer? _hintTimer;
  bool _hintDue = false;

  @override
  bool get chromeControlsEnabled =>
      !_isAsking && widget.hearing == MicrophoneHearing.hearing;

  @override
  bool get takeIsRunning => _isRecording;

  @override
  void initState() {
    super.initState();
    _followBreath(null);
    _followGettingReady(wasGettingReady: false);
  }

  @override
  void didUpdateWidget(VideoRecorderSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    _followBreath(oldWidget.phase);
    _followGettingReady(wasGettingReady: _gettingReadyIn(oldWidget.phase));
    followChrome();
    if (_isNewMessage(oldWidget.nudgeMessage, widget.nudgeMessage) ||
        _isNewMessage(oldWidget.errorMessage, widget.errorMessage)) {
      revealChrome();
    }
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    _breath.dispose();
    super.dispose();
  }

  static bool _isNewMessage(String? before, String? after) =>
      after != null && after != before;

  void _followBreath(VideoRecorderPhase? previous) {
    switch (_phase) {
      case VideoRecorderPhase.breathing:
        if (previous != VideoRecorderPhase.breathing) {
          _breath.forward(from: 0);
        }
      case VideoRecorderPhase.arming:
        _breath.value = 1;
      case VideoRecorderPhase.preparing:
      case VideoRecorderPhase.idle:
      case VideoRecorderPhase.recording:
      case VideoRecorderPhase.paused:
      case VideoRecorderPhase.saving:
      case VideoRecorderPhase.denied:
        _breath.stop();
    }
  }

  static bool _gettingReadyIn(VideoRecorderPhase phase) =>
      phase == VideoRecorderPhase.preparing ||
      phase == VideoRecorderPhase.arming;

  void _followGettingReady({required bool wasGettingReady}) {
    if (_isGettingReady == wasGettingReady) {
      return;
    }
    _hintTimer?.cancel();
    _hintTimer = null;
    _hintDue = false;
    if (_isGettingReady) {
      _hintTimer = Timer(videoArmingHintDelay, _showHint);
    }
  }

  void _showHint() {
    _hintTimer = null;
    if (mounted && _isGettingReady) {
      setState(() => _hintDue = true);
    }
  }

  Duration get _fade =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : Motion.fade;

  Widget _fadeSwitch(Widget? child) => RecorderFadeSwitch(child: child);

  Widget _collapseSwitch(Widget? child) =>
      RecorderFadeSwitch(collapsing: true, child: child);

  VideoRecorderPhase get _phase => widget.phase;
  bool get _isRecording => _phase == VideoRecorderPhase.recording;
  bool get _isPaused => _phase == VideoRecorderPhase.paused;
  bool get _isTaking => _isRecording || _isPaused;
  bool get _isAsking => widget.asking && _isTaking;
  bool get _isGettingReady => _gettingReadyIn(_phase);
  bool get _isSaving => _phase == VideoRecorderPhase.saving;
  bool get _isDenied => _phase == VideoRecorderPhase.denied;
  bool get _canPause => widget.supportsPause && widget.onPause != null;
  bool get _cannotHear =>
      _phase == VideoRecorderPhase.idle &&
      widget.hearing == MicrophoneHearing.cannotHear;

  bool get _showsCameraOff =>
      !widget.cameraOn &&
      switch (_phase) {
        VideoRecorderPhase.idle ||
        VideoRecorderPhase.breathing ||
        VideoRecorderPhase.arming ||
        VideoRecorderPhase.recording ||
        VideoRecorderPhase.paused => true,
        VideoRecorderPhase.preparing ||
        VideoRecorderPhase.saving ||
        VideoRecorderPhase.denied => false,
      };

  VoidCallback? get _toggleCamera {
    final ValueChanged<bool>? onCameraChanged = widget.onCameraChanged;
    if (onCameraChanged == null) {
      return null;
    }
    return () => onCameraChanged(!widget.cameraOn);
  }

  VideoCaptureDevice? get _otherCamera {
    final List<VideoCaptureDevice> devices = widget.devices;
    if (!widget.cameraOn ||
        _phase != VideoRecorderPhase.idle ||
        devices.length < 2) {
      return null;
    }
    final int current = devices.indexWhere(
      (VideoCaptureDevice device) => device.id == widget.selectedDeviceId,
    );
    return devices[(current + 1) % devices.length];
  }

  VoidCallback? get _flip {
    final VideoCaptureDevice? other = _otherCamera;
    final ValueChanged<String>? onDeviceChanged = widget.onDeviceChanged;
    if (other == null || onDeviceChanged == null) {
      return null;
    }
    return () => onDeviceChanged(other.id);
  }

  RecorderPrimaryVerb? get _shutterVerb {
    if (_isSaving || _isGettingReady || _isAsking || _cannotHear || _isDenied) {
      return null;
    }
    if (_isRecording) {
      return _canPause ? RecorderPrimaryVerb.pause : RecorderPrimaryVerb.keep;
    }
    if (_isPaused) {
      return widget.onResume != null
          ? RecorderPrimaryVerb.resume
          : RecorderPrimaryVerb.keep;
    }
    return RecorderPrimaryVerb.start;
  }

  VoidCallback? _primaryAction(RecorderPrimaryVerb? verb) => switch (verb) {
    RecorderPrimaryVerb.start || RecorderPrimaryVerb.retry => widget.onStart,
    RecorderPrimaryVerb.pause => widget.onPause,
    RecorderPrimaryVerb.resume => widget.onResume,
    RecorderPrimaryVerb.keep => widget.onStop,
    null => null,
  };

  VoidCallback? get _shutterTap => _primaryAction(_shutterVerb);

  RecorderPrimaryVerb? get _primaryVerb {
    if (_isDenied) {
      return RecorderPrimaryVerb.retry;
    }
    if (_isRecording && !_canPause) {
      return null;
    }
    return _shutterVerb;
  }

  VoidCallback? get _primaryKey => _primaryAction(_primaryVerb);

  VoidCallback? get _keepKey => _isTaking ? widget.onStop : null;

  RecorderLeaveVerb? get _leaveVerb {
    if (_isSaving) {
      return null;
    }
    return _isAsking ? RecorderLeaveVerb.keepGoing : RecorderLeaveVerb.leave;
  }

  VoidCallback? get _leaveKey => switch (_leaveVerb) {
    RecorderLeaveVerb.keepGoing => widget.onKeepGoing,
    RecorderLeaveVerb.leave => widget.onLeave,
    null => null,
  };

  String get _keyHint => recorderKeyHint(
    platform: Theme.of(context).platform,
    primary: _primaryKey == null ? null : _primaryVerb,
    keep: _keepKey != null,
    leave: _leaveKey == null ? null : _leaveVerb,
  );

  String get _shutterLabel {
    if (_phase == VideoRecorderPhase.breathing) {
      return videoSkipBreathLabel;
    }
    if (_isRecording) {
      return _canPause ? videoPauseLabel : videoStopAndKeepLabel;
    }
    if (_isPaused) {
      return widget.onResume != null ? videoResumeLabel : videoStopAndKeepLabel;
    }
    return videoStartLabel;
  }

  @override
  Widget build(BuildContext context) {
    final bool sidebar = stageLayoutOf(context) == ShellLayout.sidebar;
    return revealsChromeOnActivity(
      child: RecorderShortcuts(
        onPrimary: _primaryKey,
        onKeep: _keepKey,
        onLeave: _leaveKey,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            holdsChromeWhileFocused(
              child: RecorderSurface(
                arrangement: RecorderArrangement.video,
                dayLine: widget.dayLine,
                onLeave: _isSaving ? null : widget.onLeave,
                leaveKey: videoCloseKey,
                glassLeave: true,
                feedGestures: _gestures(sidebar),
                glow: !widget.cameraOn && !_isDenied,
                background: _background(sidebar),
                trailing: _trailing(sidebar),
                title: _title(),
                question: _question(sidebar),
                centre: _isDenied ? _deniedPanel() : null,
                status: DefaultTextStyle.merge(
                  style: _statusOverPicture,
                  child: _status(),
                ),
                actions: _actions(sidebar),
                chromeOpacity: chromeOpacity,
              ),
            ),
            if (sidebar)
              Positioned(
                right: _keyboardHintInset,
                bottom: _keyboardHintInset,
                child: FadeTransition(
                  opacity: chromeOpacity,
                  child: _keyboardHint(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget? _title() {
    final TextEditingController? controller = widget.titleController;
    if (controller == null || _isDenied) {
      return null;
    }
    return RecorderTitleField(
      controller: controller,
      overPicture: true,
      readOnly: _isSaving,
    );
  }

  Widget _background(bool sidebar) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (widget.cameraOn) ?_feed(),
        IgnorePointer(child: Center(child: _centrePiece(sidebar))),
      ],
    );
  }

  Widget? _gestures(bool sidebar) {
    final CameraControls? controls = widget.controls;
    if (sidebar || controls == null || !widget.cameraOn || _isDenied) {
      return null;
    }
    return CameraGestureLayer(
      key: ValueKey<String?>(widget.selectedDeviceId),
      controls: controls,
      onFlip: _flip,
    );
  }

  Widget? _feed() => widget.preview;

  Widget _centrePiece(bool sidebar) {
    final double diameter = sidebar ? _sidebarGlow : _bottomBarGlow;
    final bool cameraOff = _showsCameraOff;
    return SizedBox.square(
      dimension: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          _fadeSwitch(
            _phase == VideoRecorderPhase.breathing
                ? BreathingGlow(
                    diameter: diameter,
                    mode: BreathingGlowMode.settle,
                    alpha: _settleGlowAlpha,
                  )
                : null,
          ),
          _fadeSwitch(
            cameraOff && _isRecording
                ? BreathingGlow(diameter: diameter, alpha: _breatheGlowAlpha)
                : null,
          ),
          _fadeSwitch(
            cameraOff
                ? FadeTransition(
                    opacity: chromeOpacity,
                    child: _cameraOffCopy(sidebar),
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _cameraOffCopy(bool sidebar) {
    final TextStyle style = TextStyle(
      fontFamily: TypographyTokens.serif,
      fontSize: sidebar ? _sidebarCameraOffSize : _bottomBarCameraOffSize,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.italic,
      height: _cameraOffLeading,
      color: _cameraOffInk,
    );
    return MergeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(videoCameraOffTitle, textAlign: TextAlign.center, style: style),
          Text(
            videoCameraOffMessage,
            textAlign: TextAlign.center,
            style: style,
          ),
        ],
      ),
    );
  }

  Widget _trailing(bool sidebar) {
    final bool idle = _phase == VideoRecorderPhase.idle;
    final bool taking = _takingPhases.contains(_phase);
    final bool showsInput = idle || taking;
    final bool picker =
        sidebar && idle && widget.cameraOn && widget.devices.length > 1;
    final VideoCaptureDevice? other = sidebar ? null : _otherCamera;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (sidebar)
          Flexible(
            child: _fadeSwitch(
              picker
                  ? Padding(
                      padding: const EdgeInsets.only(
                        right: _sidebarTrailingGap,
                      ),
                      child: CameraPicker(
                        devices: widget.devices,
                        selectedDeviceId: widget.selectedDeviceId,
                        onChanged: widget.onDeviceChanged,
                        label: widget.cameraLabel,
                      ),
                    )
                  : null,
            ),
          ),
        _fadeSwitch(
          other == null
              ? null
              : RecorderGlassButton(
                  key: videoFlipCameraKey,
                  label: videoSwitchCameraLabel(other),
                  onPressed: _flip,
                  glyph: const CameraGlyph(CameraGlyphKind.flip),
                ),
        ),
        _fadeSwitch(
          idle
              ? RecorderGlassButton(
                  key: videoCameraKey,
                  label: videoCameraLabel,
                  toggled: widget.cameraOn,
                  onPressed: _toggleCamera,
                  glyph: CameraGlyph(
                    widget.cameraOn
                        ? CameraGlyphKind.camera
                        : CameraGlyphKind.cameraOff,
                  ),
                )
              : null,
        ),
        if (showsTakeIndicator) _takeIndicator(),
        _fadeSwitch(
          showsInput
              ? RecorderInputButton(
                  androidVideo:
                      Theme.of(context).platform == TargetPlatform.android,
                  onVoiceSettings: widget.onVoiceSettings,
                  takeLevels: taking ? widget.levels : null,
                  ringLevels: widget.cameraOn ? widget.levels : null,
                  ringHearing: widget.hearing,
                )
              : null,
        ),
      ],
    );
  }

  Widget _takeIndicator() {
    return FadeTransition(
      key: videoTakeIndicatorKey,
      opacity: takeIndicatorOpacity,
      child: RecorderTakeIndicator(elapsed: widget.elapsed),
    );
  }

  Widget _question(bool sidebar) {
    return DefaultTextStyle.merge(
      style: TextStyle(
        shadows: <Shadow>[
          Shadow(
            color: _questionShadow,
            offset: _questionShadowOffset,
            blurRadius: sidebar
                ? _sidebarQuestionShadowBlur
                : _bottomBarQuestionShadowBlur,
          ),
        ],
      ),
      child: ReflectionPrompt(phase: _phase.stage, showKicker: false),
    );
  }

  Widget _status() {
    final String? nudge = _isRecording ? widget.nudgeMessage : null;
    final String? error = widget.errorMessage;
    final Widget? line = _statusLine();
    final bool capHint = _phase == VideoRecorderPhase.idle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _fadeSwitch(line),
        if (line != null)
          SoundLostWarning(
            key: soundLostWarningKey,
            hearing: widget.hearing,
            taking: _isRecording,
          ),
        if (_cannotHear) const CannotHearNotice(),
        if (nudge != null) _note(nudge),
        _collapseSwitch(capHint ? _note(widget.capHint) : null),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: _errorGap),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: TypographyTokens.sans,
                fontSize: _errorSize,
                fontWeight: FontWeight.w500,
                color: context.colors.accentBright,
              ),
            ),
          ),
      ],
    );
  }

  Widget? _statusLine() {
    if (_isDenied) {
      return null;
    }
    if (_isGettingReady && _hintDue) {
      return KeyedSubtree(
        key: _armingHintLineKey,
        child: Semantics(
          container: true,
          liveRegion: true,
          label: widget.armingHint,
          excludeSemantics: true,
          child: RecorderStatusLine(
            phase: StagePhase.saving,
            elapsed: Duration.zero,
            savingText: widget.armingHint,
            inline: true,
          ),
        ),
      );
    }
    if (_phase == VideoRecorderPhase.preparing) {
      return null;
    }
    final StagePhase stage = _phase.stage;
    return KeyedSubtree(
      key: ValueKey<StagePhase>(stage),
      child: RecorderStatusLine(
        phase: stage,
        elapsed: widget.elapsed,
        savingText: widget.savingHint,
        inline: true,
      ),
    );
  }

  Widget _note(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: _noteGap),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontFamily: TypographyTokens.sans,
          fontSize: _noteSize,
          fontWeight: FontWeight.w500,
          color: _hintInk,
        ),
      ),
    );
  }

  Widget _deniedPanel() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _deniedGutter),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _deniedMessage(),
          const SizedBox(height: _deniedActionGap),
          StickerButton(
            key: videoTryAgainKey,
            label: videoTryAgainLabel,
            ground: StickerGround.media,
            focusSurface: FocusRingSurface.dark,
            padTapTarget: true,
            onPressed: widget.onStart,
          ),
        ],
      ),
    );
  }

  Widget _deniedMessage() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _deniedMaxWidth),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: _deniedFill,
          border: Border.fromBorderSide(
            BorderSide(color: _deniedEdge, width: _deniedEdgeWidth),
          ),
          borderRadius: _deniedRadius,
        ),
        child: Padding(
          padding: _deniedPadding,
          child: Text(
            widget.deniedMessage,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: TypographyTokens.sans,
              fontSize: _deniedTextSize,
              fontWeight: FontWeight.w400,
              height: _deniedLeading,
              color: _deniedInk,
            ),
          ),
        ),
      ),
    );
  }

  Widget _actions(bool sidebar) {
    return _fadeSwitch(
      _isAsking
          ? KeyedSubtree(
              key: _letGoPanelSlotKey,
              child: LetGoPanel(
                compact: !sidebar,
                keepGoingKey: videoKeepGoingKey,
                letGoKey: widget.letGoKey,
                onKeepGoing: widget.onKeepGoing ?? () {},
                onLetGo: widget.onLetGo ?? () {},
              ),
            )
          : KeyedSubtree(key: _controlsSlotKey, child: _controls(sidebar)),
    );
  }

  Widget _controls(bool sidebar) {
    final double slot = sidebar ? _sidebarSideSlot : _bottomBarSideSlot;
    final double gap = sidebar ? _sidebarControlGap : _bottomBarControlGap;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(
          width: slot,
          child: _fadeSwitch(_isTaking ? _letGoControl(sidebar) : null),
        ),
        SizedBox(width: gap),
        _shutter(sidebar),
        SizedBox(width: gap),
        SizedBox(
          width: slot,
          child: _fadeSwitch(_isTaking ? _keepControl(sidebar) : null),
        ),
      ],
    );
  }

  Widget _letGoControl(bool sidebar) {
    return _SideControl(
      controlKey: videoDiscardCircleKey,
      label: videoLetGoLabel,
      onTap: widget.onLeave,
      diameter: sidebar ? _sidebarSideCircle : _bottomBarSideCircle,
      decoration: const BoxDecoration(
        color: _letGoFill,
        shape: BoxShape.circle,
        border: Border.fromBorderSide(
          BorderSide(color: _letGoEdge, width: _sideEdgeWidth),
        ),
      ),
      glyph: const IconStickerGlyphIcon(
        glyph: IconStickerGlyph.close,
        color: _letGoGlyphInk,
        size: _letGoGlyph,
      ),
      caption: TextStyle(
        fontFamily: TypographyTokens.sans,
        fontSize: sidebar ? _sidebarCaptionSize : _bottomBarCaptionSize,
        fontWeight: FontWeight.w500,
        color: _letGoCaptionInk,
      ),
    );
  }

  Widget _keepControl(bool sidebar) {
    return _SideControl(
      controlKey: videoSaveCircleKey,
      label: videoKeepLabel,
      onTap: widget.onStop,
      diameter: sidebar ? _sidebarSideCircle : _bottomBarSideCircle,
      decoration: const BoxDecoration(color: _keepFill, shape: BoxShape.circle),
      glyph: const IconStickerGlyphIcon(
        glyph: IconStickerGlyph.check,
        color: _keepGlyphInk,
        size: _keepGlyph,
      ),
      caption: TextStyle(
        fontFamily: TypographyTokens.sans,
        fontSize: sidebar ? _sidebarCaptionSize : _bottomBarCaptionSize,
        fontWeight: FontWeight.w600,
        color: _keepCaptionInk,
      ),
    );
  }

  double _shutterOpacity(VoidCallback? tap) {
    if (_phase == VideoRecorderPhase.arming) {
      return 1;
    }
    if (tap == null) {
      return _disabledOpacity;
    }
    return _isPaused ? videoPausedShutterOpacity : 1;
  }

  VideoShutterForm get _shutterForm => _isSaving
      ? VideoShutterForm.ready
      : captureButtonForm(_phase.stage, canPause: _canPause);

  Widget _shutter(bool sidebar) {
    final VoidCallback? tap = _shutterTap;
    final double size = videoShutterDiameter(sidebar: sidebar);
    return Pressable(
      key: videoShutterKey,
      label: _shutterLabel,
      onPressed: tap,
      surface: FocusRingSurface.dark,
      shape: HoverShape.circle,
      borderRadius: BorderRadius.all(Radius.circular(size / 2)),
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: _shutterOpacity(tap)),
        duration: _fade,
        curve: Motion.fadeCurve,
        builder: (BuildContext context, double opacity, Widget? face) =>
            Opacity(opacity: opacity, child: face),
        child: VideoShutterFace(
          form: _shutterForm,
          sidebar: sidebar,
          breath: _breath,
          fade: _fade,
        ),
      ),
    );
  }

  Widget _keyboardHint() {
    return Text(
      _keyHint,
      key: videoKeyboardHintKey,
      maxLines: 1,
      softWrap: false,
      textAlign: TextAlign.right,
      style: const TextStyle(
        fontFamily: TypographyTokens.sans,
        fontSize: _keyboardHintSize,
        fontWeight: FontWeight.w500,
        letterSpacing: _keyboardHintTracking,
        color: _hintInk,
      ),
    );
  }
}

class _SideControl extends StatelessWidget {
  const _SideControl({
    required this.controlKey,
    required this.label,
    required this.onTap,
    required this.diameter,
    required this.decoration,
    required this.glyph,
    required this.caption,
  });

  final Key controlKey;
  final String label;
  final VoidCallback onTap;
  final double diameter;
  final BoxDecoration decoration;
  final Widget glyph;
  final TextStyle caption;

  @override
  Widget build(BuildContext context) {
    final BorderRadius radius = BorderRadius.all(Radius.circular(diameter / 2));
    return Pressable(
      key: controlKey,
      label: label,
      onPressed: onTap,
      surface: FocusRingSurface.dark,
      shape: HoverShape.circle,
      borderRadius: radius,
      paintsHover: false,
      ringsFace: true,
      builder: (BuildContext context, bool hovered) => Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          FocusRingFace(
            child: Container(
              width: diameter,
              height: diameter,
              alignment: Alignment.center,
              decoration: decoration,
              foregroundDecoration: HoverStyle.decoration(
                color: hovered
                    ? HoverStyle.of(
                        context,
                        FocusRingSurface.dark,
                        HoverShape.circle,
                      )
                    : null,
                shape: HoverShape.circle,
                borderRadius: radius,
              ),
              child: glyph,
            ),
          ),
          const SizedBox(height: _sideCaptionGap),
          Text(label, maxLines: 1, softWrap: false, style: caption),
        ],
      ),
    );
  }
}
