import 'package:flutter/material.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';

import 'camera_picker.dart';
import 'self_view_chip.dart';
import 'video_recorder.dart';

enum VideoRecorderPhase {
  preparing,
  idle,
  breathing,
  arming,
  recording,
  paused,
  saving,
  denied,
}

const Key videoCloseKey = ValueKey<String>('video-close');
const Key videoShutterKey = ValueKey<String>('video-shutter');
const Key videoDiscardCircleKey = ValueKey<String>('video-discard-circle');
const Key videoSaveCircleKey = ValueKey<String>('video-save-circle');
const Key videoKeepGoingKey = ValueKey<String>('video-keep-going');
const Key videoSelfViewKey = ValueKey<String>('video-self-view');
const Key videoKeyboardHintKey = ValueKey<String>('video-keyboard-hint');

const String videoFeedLabel = 'CAMERA FEED';
const String videoSidebarPrivacyLine = 'Private · only you will see this';
const String videoBottomBarPrivacyLine = 'Only you';
const String videoSelfViewOffTitle = 'The camera is still recording.';
const String videoSelfViewOffMessage = 'You just won’t see yourself.';
const String videoLetGoLabel = 'Let go';
const String videoKeepLabel = 'Keep';
const String videoStartLabel = 'Start recording';
const String videoSkipBreathLabel = 'Skip the breath';
const String videoPauseLabel = 'Pause recording';
const String videoResumeLabel = 'Resume recording';
const String videoStopAndKeepLabel = 'Stop and keep';

const Color _hintInk = Color(0xFFB7A58C);
const Color _selfViewOffInk = Color(0xFFB7A58C);
const Color _shutterRing = Color(0xEBF3E6D1);
const Color _shutterPauseInk = Color(0xFFFFFFFF);
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

const double _sidebarShutter = 80;
const double _bottomBarShutter = 72;
const double _shutterRingWidth = 3;
const double _sidebarShutterDot = 30;
const double _bottomBarShutterDot = 27;
const double _sidebarStopSquare = 26;
const double _bottomBarStopSquare = 24;
const double _stopSquareRadius = 5;
const double _shutterPauseGlyph = 26;
const double _disabledOpacity = 0.5;

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
const double _sidebarSelfViewOffSize = 18;
const double _bottomBarSelfViewOffSize = 14;
const double _selfViewOffLeading = 1.45;

const double _noteSize = 12;
const double _errorSize = 13;
const double _noteGap = 6;
const double _errorGap = 8;
const double _keyboardHintSize = 11;
const double _keyboardHintTracking = 0.22;
const double _keyboardHintInset = 20;
const double _sidebarTrailingGap = 8;
const double _bottomBarTrailingGap = 6;

const double _sidebarQuestionShadowBlur = 20;
const double _bottomBarQuestionShadowBlur = 16;
const Offset _questionShadowOffset = Offset(0, 2);

const double _deniedMaxWidth = 420;
const double _deniedGutter = 24;
const double _deniedTextSize = 14;
const double _deniedLeading = 1.45;
const double _deniedEdgeWidth = 1;
const BorderRadius _deniedRadius = BorderRadius.all(Radius.circular(18));
const EdgeInsets _deniedPadding = EdgeInsets.symmetric(
  horizontal: 22,
  vertical: 20,
);

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
    this.elapsed = Duration.zero,
    this.nudgeMessage,
    this.errorMessage,
    this.cameraLabel = 'Camera',
    this.armingHint = 'Getting the camera ready…',
    this.savingHint = 'Saving your video…',
    this.capHint = 'Auto-stops at 30:00.',
    this.deniedMessage = cameraPermissionMessage,
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
  final Duration elapsed;
  final String? nudgeMessage;
  final String? errorMessage;
  final String cameraLabel;
  final String armingHint;
  final String savingHint;
  final String capHint;
  final String deniedMessage;

  @override
  State<VideoRecorderSheet> createState() => _VideoRecorderSheetState();
}

class _VideoRecorderSheetState extends State<VideoRecorderSheet> {
  bool _selfView = true;

  VideoRecorderPhase get _phase => widget.phase;
  bool get _isRecording => _phase == VideoRecorderPhase.recording;
  bool get _isPaused => _phase == VideoRecorderPhase.paused;
  bool get _isTaking => _isRecording || _isPaused;
  bool get _isAsking => widget.asking && _isTaking;
  bool get _isGettingReady =>
      _phase == VideoRecorderPhase.preparing ||
      _phase == VideoRecorderPhase.arming;
  bool get _isSaving => _phase == VideoRecorderPhase.saving;
  bool get _isDenied => _phase == VideoRecorderPhase.denied;
  bool get _canPause => widget.supportsPause && widget.onPause != null;

  StagePhase get _stagePhase => switch (_phase) {
    VideoRecorderPhase.preparing ||
    VideoRecorderPhase.idle ||
    VideoRecorderPhase.denied => StagePhase.idle,
    VideoRecorderPhase.breathing ||
    VideoRecorderPhase.arming => StagePhase.breathing,
    VideoRecorderPhase.recording => StagePhase.recording,
    VideoRecorderPhase.paused => StagePhase.paused,
    VideoRecorderPhase.saving => StagePhase.saving,
  };

  void _setSelfView(bool value) => setState(() => _selfView = value);

  RecorderPrimaryVerb? get _shutterVerb {
    if (_isSaving || _isGettingReady || _isAsking) {
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
    RecorderPrimaryVerb.start => widget.onStart,
    RecorderPrimaryVerb.pause => widget.onPause,
    RecorderPrimaryVerb.resume => widget.onResume,
    RecorderPrimaryVerb.keep => widget.onStop,
    null => null,
  };

  VoidCallback? get _shutterTap => _primaryAction(_shutterVerb);

  RecorderPrimaryVerb? get _primaryVerb {
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
    return RecorderShortcuts(
      onPrimary: _primaryKey,
      onKeep: _keepKey,
      onLeave: _leaveKey,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          RecorderSurface(
            arrangement: RecorderArrangement.video,
            privacyLine: sidebar
                ? videoSidebarPrivacyLine
                : videoBottomBarPrivacyLine,
            onLeave: _isSaving ? null : widget.onLeave,
            leaveKey: videoCloseKey,
            glow: !_selfView && !_isDenied,
            background: _background(sidebar),
            trailing: _trailing(sidebar),
            question: _question(sidebar),
            centre: _isDenied ? _deniedPanel() : null,
            status: _status(),
            actions: _actions(sidebar),
          ),
          if (sidebar)
            Positioned(
              right: _keyboardHintInset,
              bottom: _keyboardHintInset,
              child: _keyboardHint(),
            ),
        ],
      ),
    );
  }

  Widget _background(bool sidebar) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Offstage(offstage: !_selfView, child: _feed()),
        IgnorePointer(child: Center(child: _centrePiece(sidebar))),
      ],
    );
  }

  Widget _feed() {
    final Widget? preview = widget.preview;
    if (preview != null) {
      return preview;
    }
    if (_isDenied) {
      return const SizedBox.shrink();
    }
    return CrossHatchPlaceholder(
      variant: CrossHatchVariant.viewport,
      borderRadius: BorderRadius.zero,
      child: Text(videoFeedLabel, style: context.textStyles.viewportMonoLabel),
    );
  }

  Widget _centrePiece(bool sidebar) {
    final double diameter = sidebar ? _sidebarGlow : _bottomBarGlow;
    final bool hidden = !_selfView && !_isDenied;
    return SizedBox.square(
      dimension: diameter,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          if (_phase == VideoRecorderPhase.breathing)
            BreathingGlow(
              diameter: diameter,
              mode: BreathingGlowMode.settle,
              alpha: _settleGlowAlpha,
            ),
          if (hidden && _isRecording)
            BreathingGlow(diameter: diameter, alpha: _breatheGlowAlpha),
          if (hidden) _selfViewOffCopy(sidebar),
        ],
      ),
    );
  }

  Widget _selfViewOffCopy(bool sidebar) {
    final TextStyle style = TextStyle(
      fontFamily: TypographyTokens.serif,
      fontSize: sidebar ? _sidebarSelfViewOffSize : _bottomBarSelfViewOffSize,
      fontWeight: FontWeight.w400,
      fontStyle: FontStyle.italic,
      height: _selfViewOffLeading,
      color: _selfViewOffInk,
    );
    return MergeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            videoSelfViewOffTitle,
            textAlign: TextAlign.center,
            style: style,
          ),
          Text(
            videoSelfViewOffMessage,
            textAlign: TextAlign.center,
            style: style,
          ),
        ],
      ),
    );
  }

  Widget? _trailing(bool sidebar) {
    final bool picker =
        _phase == VideoRecorderPhase.idle && widget.devices.length > 1;
    final bool chip = !_isDenied;
    if (!picker && !chip) {
      return null;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (picker)
          Flexible(
            child: CameraPicker(
              devices: widget.devices,
              selectedDeviceId: widget.selectedDeviceId,
              onChanged: widget.onDeviceChanged,
              label: widget.cameraLabel,
            ),
          ),
        if (picker && chip)
          SizedBox(
            width: sidebar ? _sidebarTrailingGap : _bottomBarTrailingGap,
          ),
        if (chip)
          SelfViewChip(
            key: videoSelfViewKey,
            value: _selfView,
            onChanged: _setSelfView,
          ),
      ],
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
      child: ReflectionPrompt(phase: _stagePhase, showKicker: false),
    );
  }

  Widget? _status() {
    final String? nudge = _isRecording ? widget.nudgeMessage : null;
    final String? error = widget.errorMessage;
    final Widget? line = _statusLine();
    final bool capHint = _phase == VideoRecorderPhase.idle;
    if (line == null && nudge == null && error == null && !capHint) {
      return null;
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        ?line,
        if (nudge != null) _note(nudge),
        if (capHint) _note(widget.capHint),
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
    if (_isGettingReady) {
      return Semantics(
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
      );
    }
    return RecorderStatusLine(
      phase: _stagePhase,
      elapsed: widget.elapsed,
      savingText: widget.savingHint,
      inline: true,
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
      child: ConstrainedBox(
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
      ),
    );
  }

  Widget _actions(bool sidebar) {
    if (_isAsking) {
      return LetGoPanel(
        compact: !sidebar,
        keepGoingKey: videoKeepGoingKey,
        letGoKey: widget.letGoKey,
        onKeepGoing: widget.onKeepGoing ?? () {},
        onLetGo: widget.onLetGo ?? () {},
      );
    }
    final double slot = sidebar ? _sidebarSideSlot : _bottomBarSideSlot;
    final double gap = sidebar ? _sidebarControlGap : _bottomBarControlGap;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        SizedBox(width: slot, child: _isTaking ? _letGoControl(sidebar) : null),
        SizedBox(width: gap),
        _shutter(sidebar),
        SizedBox(width: gap),
        SizedBox(width: slot, child: _isTaking ? _keepControl(sidebar) : null),
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

  Widget _shutter(bool sidebar) {
    final VoidCallback? tap = _shutterTap;
    final double size = sidebar ? _sidebarShutter : _bottomBarShutter;
    return Semantics(
      button: true,
      enabled: tap != null,
      label: _shutterLabel,
      child: GestureDetector(
        key: videoShutterKey,
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: FocusRing(
          enabled: tap != null,
          onPressed: tap,
          surface: FocusRingSurface.dark,
          borderRadius: BorderRadius.all(Radius.circular(size / 2)),
          child: Opacity(
            opacity: tap == null ? _disabledOpacity : 1.0,
            child: Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: _shutterRing, width: _shutterRingWidth),
                ),
              ),
              child: _shutterCore(sidebar),
            ),
          ),
        ),
      ),
    );
  }

  Widget _shutterCore(bool sidebar) {
    if (_isRecording && _canPause) {
      return const IconStickerGlyphIcon(
        glyph: IconStickerGlyph.pause,
        color: _shutterPauseInk,
        size: _shutterPauseGlyph,
      );
    }
    if (_isRecording) {
      final double side = sidebar ? _sidebarStopSquare : _bottomBarStopSquare;
      return SizedBox.square(
        dimension: side,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.accentRecord,
            borderRadius: BorderRadius.all(Radius.circular(_stopSquareRadius)),
          ),
        ),
      );
    }
    final double dot = sidebar ? _sidebarShutterDot : _bottomBarShutterDot;
    return SizedBox.square(
      dimension: dot,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.accentRecord,
          shape: BoxShape.circle,
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
    return Semantics(
      container: true,
      button: true,
      label: label,
      child: GestureDetector(
        key: controlKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            FocusRing(
              onPressed: onTap,
              surface: FocusRingSurface.dark,
              borderRadius: BorderRadius.all(Radius.circular(diameter / 2)),
              child: Container(
                width: diameter,
                height: diameter,
                alignment: Alignment.center,
                decoration: decoration,
                child: glyph,
              ),
            ),
            const SizedBox(height: _sideCaptionGap),
            ExcludeSemantics(
              child: Text(label, maxLines: 1, softWrap: false, style: caption),
            ),
          ],
        ),
      ),
    );
  }
}
