import 'package:flutter/material.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/icons/capture_icons.dart';
import 'package:field_notes/design/interaction/hover_style.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/keyboard/shortcut_modifier.dart';
import 'package:field_notes/design/motion/motion_tokens.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/features/capture/audio/cannot_hear_notice.dart';
import 'package:field_notes/features/capture/audio/input_panel.dart';
import 'package:field_notes/features/capture/audio/microphone_hearing.dart';
import 'package:field_notes/features/capture/immersive/capture_button.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';

enum VoiceRecorderPhase {
  idle(StagePhase.idle),
  breathing(StagePhase.breathing),
  recording(StagePhase.recording),
  paused(StagePhase.paused),
  saving(StagePhase.saving);

  const VoiceRecorderPhase(this.stage);

  final StagePhase stage;

  bool get isTaking => stage.isTaking;
}

const Key voiceCloseKey = ValueKey<String>('voice-close');
const Key voiceRecordButtonKey = ValueKey<String>('voice-record-button');
const Key voiceDiscardPillKey = ValueKey<String>('voice-discard-pill');
const Key voiceSavePillKey = ValueKey<String>('voice-save-pill');
const Key voiceOrbZoneKey = ValueKey<String>('voice-orb-zone');
const Key voiceActionsKey = ValueKey<String>('voice-actions');
const Key voiceKeepGoingKey = ValueKey<String>('voice-keep-going');
const Key voiceErrorKey = ValueKey<String>('voice-error');
const Key voiceKeyHintKey = ValueKey<String>('voice-key-hint');
const Key voiceCometsKey = ValueKey<String>('voice-comets');
const Key voiceSavingSpinnerKey = ValueKey<String>('voice-saving-spinner');
const Key voiceTakeIndicatorKey = ValueKey<String>('voice-take-indicator');

const Key _letGoSlotKey = ValueKey<String>('voice-let-go-slot');
const Key _takeActionsSlotKey = ValueKey<String>('voice-take-actions-slot');

ValueKey<String> voiceOrbFormKey(CaptureButtonForm form) =>
    ValueKey<String>('voice-orb-form-${form.name}');

const String voiceSidebarPrivacyLine = 'Private · only you will hear this';
const String voiceBottomBarPrivacyLine = 'Only you will hear this';
const String voiceSavingStatus = 'Saving your recording…';
const String voiceKeepLabel = 'Keep this';
const String voiceStartLabel = 'Start recording';
const String voiceStartNowLabel = 'Start now';
const String voicePauseLabel = 'Pause recording';
const String voiceResumeLabel = 'Resume recording';
const String voiceSavingLabel = 'Saving';
const String voiceOrbShortcutHint = 'Shortcut: Space';

String voiceKeepShortcutHint(TargetPlatform platform) =>
    usesCommandKey(platform)
    ? 'Shortcut: Command Return'
    : 'Shortcut: Control Enter';

const double voiceSidebarOrbZone = 250;
const double voiceBottomBarOrbZone = 184;
const double voiceSidebarOrb = 124;
const double voiceBottomBarOrb = 100;
const double voiceSavingOrbOpacity = 0.35;
const double voiceCountdownCoreScale = 0.56;
const double voiceSavingCoreScale = 0.3;
const double voiceSavingCoreOpacity = 0.7;
const double voicePausedCoreOpacity = 0.86;
const double voiceActionsHeight = 118;

const Color _orbEdge = Color(0x24F3E6D1);
const Color _orbShadow = Color(0xBFB8566A);
const Color _orbGlyphInk = Palette.onAccent;
const Color _orbCountdownRing = Color(0x5CF3E6D1);
const Color _orbResumeRing = Color(0x8FF3E6D1);
const Color _orbSavingRing = Color(0x47F3E6D1);
const Color _orbSweep = Color(0xFFC86075);
const Color _keepFill = Color(0xFFF3E6D1);
const Color _keepInk = Color(0xFF1C1713);
const Color _keepShadow = Color(0x73F3E6D1);
const Color _letGoInk = Color(0xFFB7A58C);
const Color _keyHintInk = Color(0xFF9A8872);

const double _minTapTarget = 48;
const double _sidebarLevelReach = 60;
const double _bottomBarLevelReach = 44;
const double _sidebarOrbGlyph = 42;
const double _bottomBarOrbGlyph = 36;
const Alignment _orbHighlight = Alignment(-0.24, -0.36);
const double _orbGradientRadius = 0.92;
const List<double> _orbStops = <double>[0, 0.58, 1];
const double _orbEdgeWidth = 1;
const Offset _orbShadowOffset = Offset(0, 26);
const double _orbShadowBlur = 60;
const double _orbShadowSpread = -18;
const Duration _orbFade = Duration(milliseconds: 600);

const double _keyHintSize = 11;
const double _keyHintTracking = 0.02 * _keyHintSize;

const double _errorGap = 8;
const double _inputGap = 12;

const double _sidebarActionsGap = 10;
const double _bottomBarActionsGap = 8;
const double _sidebarActionSize = 14;
const double _bottomBarLetGoSize = 13;
const double _keepSize = 14;
const double _keepGlyph = 15;
const double _savingSpinnerSize = 20;
const double _savingSpinnerStroke = 2;
const double _sidebarKeepGap = 9;
const double _bottomBarKeepGap = 8;
const double _bottomBarKeepMaxWidth = 170;
const EdgeInsets _sidebarLetGoPadding = EdgeInsets.symmetric(
  horizontal: 20,
  vertical: 13,
);
const EdgeInsets _bottomBarLetGoPadding = EdgeInsets.symmetric(horizontal: 16);
const EdgeInsets _sidebarKeepPadding = EdgeInsets.symmetric(
  horizontal: 24,
  vertical: 13,
);
const EdgeInsets _bottomBarKeepPadding = EdgeInsets.symmetric(horizontal: 16);
const BorderRadius _actionRadius = BorderRadius.all(Radius.circular(24));
const Offset _keepShadowOffset = Offset(0, 12);
const double _keepShadowBlur = 30;
const double _keepShadowSpread = -14;
const double _disabledActionOpacity = 0.5;

void _ignore() {}

Decoration _hoverVeil(
  BuildContext context, {
  required bool hovered,
  required HoverShape shape,
  required BorderRadius borderRadius,
}) => HoverStyle.decoration(
  color: hovered ? HoverStyle.of(context, FocusRingSurface.dark, shape) : null,
  shape: shape,
  borderRadius: borderRadius,
);

class VoiceRecorderSheet extends StatefulWidget {
  const VoiceRecorderSheet({
    super.key,
    required this.phase,
    required this.onStart,
    required this.onStop,
    required this.onCancel,
    this.onPause,
    this.onResume,
    this.onDiscard,
    this.onDismiss,
    this.onKeepGoing,
    this.onLetGo,
    this.asking = false,
    this.elapsed = Duration.zero,
    this.errorMessage,
    this.letGoKey,
    this.levels = const Stream<double>.empty(),
    this.savingText = voiceSavingStatus,
    this.onVoiceSettings,
    this.hearing = MicrophoneHearing.hearing,
    this.titleController,
    this.questionIndex,
  });

  final VoiceRecorderPhase phase;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onCancel;
  final VoidCallback? onPause;
  final VoidCallback? onResume;
  final VoidCallback? onDiscard;
  final VoidCallback? onDismiss;
  final VoidCallback? onKeepGoing;
  final VoidCallback? onLetGo;
  final bool asking;
  final Duration elapsed;
  final String? errorMessage;
  final Key? letGoKey;
  final Stream<double> levels;
  final String savingText;
  final VoidCallback? onVoiceSettings;
  final MicrophoneHearing hearing;
  final TextEditingController? titleController;
  final int? questionIndex;

  @override
  State<VoiceRecorderSheet> createState() => _VoiceRecorderSheetState();
}

class _VoiceRecorderSheetState extends State<VoiceRecorderSheet>
    with TickerProviderStateMixin, RecorderChromeFade<VoiceRecorderSheet> {
  late final AnimationController _breath = AnimationController(
    vsync: this,
    duration: stageBreathDuration,
  );

  VoiceRecorderPhase get _phase => widget.phase;

  bool get _saving => _phase == VoiceRecorderPhase.saving;

  bool get _canKeep => _phase.isTaking && !widget.asking;

  bool get _cannotHear =>
      _phase == VoiceRecorderPhase.idle &&
      widget.hearing == MicrophoneHearing.cannotHear;

  @override
  bool get chromeControlsEnabled =>
      !widget.asking && widget.hearing == MicrophoneHearing.hearing;

  @override
  bool get takeIsRunning => _phase == VoiceRecorderPhase.recording;

  @override
  void initState() {
    super.initState();
    _followBreath(null);
  }

  @override
  void didUpdateWidget(VoiceRecorderSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    _followBreath(oldWidget.phase);
    followChrome();
    final String? error = widget.errorMessage;
    if (error != null && error != oldWidget.errorMessage) {
      revealChrome();
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  void _followBreath(VoiceRecorderPhase? previous) {
    if (_phase != VoiceRecorderPhase.breathing) {
      _breath.stop();
    } else if (previous != VoiceRecorderPhase.breathing) {
      _breath.forward(from: 0);
    }
  }

  RecorderPrimaryVerb? get _orbVerb {
    if (widget.asking || _cannotHear) {
      return null;
    }
    return switch (_phase) {
      VoiceRecorderPhase.idle ||
      VoiceRecorderPhase.breathing => RecorderPrimaryVerb.start,
      VoiceRecorderPhase.recording => RecorderPrimaryVerb.pause,
      VoiceRecorderPhase.paused => RecorderPrimaryVerb.resume,
      VoiceRecorderPhase.saving => null,
    };
  }

  VoidCallback? get _orbTap => switch (_orbVerb) {
    RecorderPrimaryVerb.start || RecorderPrimaryVerb.retry => widget.onStart,
    RecorderPrimaryVerb.pause => widget.onPause,
    RecorderPrimaryVerb.resume => widget.onResume,
    RecorderPrimaryVerb.keep => widget.onStop,
    null => null,
  };

  VoidCallback? get _keepKey => _canKeep ? widget.onStop : null;

  RecorderLeaveVerb? get _leaveVerb {
    if (_saving) {
      return null;
    }
    return widget.asking && widget.onDismiss != null
        ? RecorderLeaveVerb.keepGoing
        : RecorderLeaveVerb.leave;
  }

  VoidCallback? get _leaveKey =>
      _leaveVerb == null ? null : (widget.onDismiss ?? widget.onCancel);

  String _keyHint(BuildContext context) => recorderKeyHint(
    platform: Theme.of(context).platform,
    primary: _orbTap == null ? null : _orbVerb,
    keep: _keepKey != null,
    leave: _leaveKey == null ? null : _leaveVerb,
  );

  @override
  Widget build(BuildContext context) {
    final bool sidebar = stageLayoutOf(context) == ShellLayout.sidebar;
    return revealsChromeOnActivity(
      child: RecorderShortcuts(
        onPrimary: _orbTap,
        onKeep: _keepKey,
        onLeave: _leaveKey,
        child: holdsChromeWhileFocused(
          child: RecorderSurface(
            leaveKey: voiceCloseKey,
            privacyLine: sidebar
                ? voiceSidebarPrivacyLine
                : voiceBottomBarPrivacyLine,
            onLeave: _saving || widget.asking ? null : widget.onCancel,
            trailing: _trailing(context, sidebar),
            title: _title(),
            question: ReflectionPrompt(
              phase: _phase.stage,
              showKicker: true,
              initialIndex: widget.questionIndex,
            ),
            centre: _OrbZone(
              phase: _phase,
              sidebar: sidebar,
              levels: widget.levels,
              onTap: _orbTap,
              breath: _breath,
            ),
            status: _status(context),
            actions: _actions(sidebar),
            chromeOpacity: chromeOpacity,
          ),
        ),
      ),
    );
  }

  Widget? _title() {
    final TextEditingController? controller = widget.titleController;
    if (controller == null) {
      return null;
    }
    return RecorderTitleField(controller: controller, readOnly: _saving);
  }

  Widget _trailing(BuildContext context, bool sidebar) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (sidebar)
          Flexible(
            child: FadeTransition(
              opacity: chromeOpacity,
              child: _KeyHint(text: _keyHint(context)),
            ),
          ),
        if (showsTakeIndicator)
          Flexible(
            child: FadeTransition(
              key: voiceTakeIndicatorKey,
              opacity: takeIndicatorOpacity,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: RecorderTakeIndicator(elapsed: widget.elapsed),
              ),
            ),
          ),
        RecorderFadeSwitch(
          child: _saving
              ? null
              : Padding(
                  padding: EdgeInsets.only(left: sidebar ? _inputGap : 0),
                  child: RecorderInputButton(
                    onVoiceSettings: widget.onVoiceSettings,
                    takeLevels: _phase == VoiceRecorderPhase.idle
                        ? null
                        : widget.levels,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _status(BuildContext context) {
    final String? errorMessage = widget.errorMessage;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        RecorderFadeSwitch(
          child: _cannotHear
              ? null
              : KeyedSubtree(
                  key: ValueKey<StagePhase>(_phase.stage),
                  child: RecorderStatusLine(
                    phase: _phase.stage,
                    elapsed: widget.elapsed,
                    savingText: widget.savingText,
                    inline: false,
                  ),
                ),
        ),
        SoundLostWarning(
          key: soundLostWarningKey,
          hearing: widget.hearing,
          taking: _phase == VoiceRecorderPhase.recording,
        ),
        if (_cannotHear) const CannotHearNotice(),
        if (errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: _errorGap),
            child: Semantics(
              container: true,
              liveRegion: true,
              child: Text(
                errorMessage,
                key: voiceErrorKey,
                textAlign: TextAlign.center,
                style: context.textStyles.captionSans.copyWith(
                  color: context.colors.accentBright,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _actions(bool sidebar) {
    final Widget? content;
    if (widget.asking) {
      content = KeyedSubtree(
        key: _letGoSlotKey,
        child: LetGoPanel(
          onKeepGoing: widget.onKeepGoing ?? _ignore,
          onLetGo: widget.onLetGo ?? _ignore,
          compact: !sidebar,
          keepGoingKey: voiceKeepGoingKey,
          letGoKey: widget.letGoKey,
        ),
      );
    } else if (_phase.isTaking || _saving) {
      content = KeyedSubtree(
        key: _takeActionsSlotKey,
        child: _TakeActions(
          sidebar: sidebar,
          onLetGo: _saving ? null : widget.onDiscard,
          onKeep: _saving ? null : widget.onStop,
          saving: _saving,
        ),
      );
    } else {
      content = null;
    }
    return ConstrainedBox(
      key: voiceActionsKey,
      constraints: const BoxConstraints(minHeight: voiceActionsHeight),
      child: Center(heightFactor: 1, child: RecorderFadeSwitch(child: content)),
    );
  }
}

class _KeyHint extends StatelessWidget {
  const _KeyHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Text(
        text,
        key: voiceKeyHintKey,
        textAlign: TextAlign.right,
        style: const TextStyle(
          fontFamily: TypographyTokens.sans,
          fontSize: _keyHintSize,
          fontWeight: FontWeight.w500,
          letterSpacing: _keyHintTracking,
          color: _keyHintInk,
        ),
      ),
    );
  }
}

class _OrbZone extends StatelessWidget {
  const _OrbZone({
    required this.phase,
    required this.sidebar,
    required this.levels,
    required this.onTap,
    required this.breath,
  });

  final VoiceRecorderPhase phase;
  final bool sidebar;
  final Stream<double> levels;
  final VoidCallback? onTap;
  final Animation<double> breath;

  VoiceLevelStage? get _cometsStage => switch (phase) {
    VoiceRecorderPhase.breathing => VoiceLevelStage.breathing,
    VoiceRecorderPhase.recording => VoiceLevelStage.recording,
    VoiceRecorderPhase.paused => VoiceLevelStage.paused,
    VoiceRecorderPhase.idle || VoiceRecorderPhase.saving => null,
  };

  Widget _settleGlow(double zone) {
    return Positioned.fill(
      child: phase == VoiceRecorderPhase.breathing
          ? BreathingGlow(diameter: zone, mode: BreathingGlowMode.settle)
          : const SizedBox.shrink(),
    );
  }

  Widget _comets() {
    final VoiceLevelStage? stage = _cometsStage;
    if (stage == null) {
      return const Positioned.fill(child: SizedBox.shrink());
    }
    final double reach = sidebar ? _sidebarLevelReach : _bottomBarLevelReach;
    return Positioned(
      left: -reach,
      top: -reach,
      right: -reach,
      bottom: -reach,
      child: VoiceLevelField(
        key: voiceCometsKey,
        levels: levels,
        stage: stage,
        orbRadius: (sidebar ? voiceSidebarOrb : voiceBottomBarOrb) / 2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double zone = sidebar ? voiceSidebarOrbZone : voiceBottomBarOrbZone;
    return SizedBox.square(
      key: voiceOrbZoneKey,
      dimension: zone,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: <Widget>[
          _settleGlow(zone),
          _Orb(phase: phase, sidebar: sidebar, onTap: onTap, breath: breath),
          _comets(),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({
    required this.phase,
    required this.sidebar,
    required this.onTap,
    required this.breath,
  });

  final VoiceRecorderPhase phase;
  final bool sidebar;
  final VoidCallback? onTap;
  final Animation<double> breath;

  String get _label => switch (phase) {
    VoiceRecorderPhase.breathing => voiceStartNowLabel,
    VoiceRecorderPhase.recording => voicePauseLabel,
    VoiceRecorderPhase.paused => voiceResumeLabel,
    VoiceRecorderPhase.idle => voiceStartLabel,
    VoiceRecorderPhase.saving => voiceSavingLabel,
  };

  double get _opacity => onTap == null && phase != VoiceRecorderPhase.saving
      ? voiceSavingOrbOpacity
      : 1;

  double get _diameter => sidebar ? voiceSidebarOrb : voiceBottomBarOrb;

  double get _glyphSize => sidebar ? _sidebarOrbGlyph : _bottomBarOrbGlyph;

  Widget _mic() => CaptureIcon(
    glyph: CaptureGlyph.mic,
    color: _orbGlyphInk,
    size: _glyphSize,
  );

  Widget _ringed(Color ring, {Widget? sweep, Widget? centre}) {
    return SizedBox.square(
      dimension: _diameter,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: ring, width: captureRingWidth),
              ),
            ),
          ),
          if (sweep != null) Positioned.fill(child: sweep),
          ?centre,
        ],
      ),
    );
  }

  Widget _core(BuildContext context, CaptureButtonForm form) {
    return switch (form) {
      CaptureButtonForm.ready => _mic(),
      CaptureButtonForm.countdown => _ringed(
        _orbCountdownRing,
        sweep: CaptureCountdownSweep(progress: breath, color: _orbSweep),
      ),
      CaptureButtonForm.pause || CaptureButtonForm.stop => IconStickerGlyphIcon(
        glyph: IconStickerGlyph.pause,
        color: _orbGlyphInk,
        size: _glyphSize,
      ),
      CaptureButtonForm.resume => _ringed(_orbResumeRing, centre: _mic()),
      CaptureButtonForm.saving => _ringed(
        _orbSavingRing,
        sweep: const CaptureSavingSweep(color: _orbSweep),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onTap = this.onTap;
    final bool enabled = onTap != null;
    final double diameter = _diameter;
    final CaptureButtonForm form = captureButtonForm(
      phase.stage,
      canPause: true,
    );
    final BorderRadius radius = BorderRadius.all(Radius.circular(diameter / 2));
    return Pressable(
      key: voiceRecordButtonKey,
      label: _label,
      hint: sidebar && enabled ? voiceOrbShortcutHint : null,
      onPressed: onTap,
      surface: FocusRingSurface.dark,
      shape: HoverShape.circle,
      borderRadius: radius,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => AnimatedOpacity(
        opacity: _opacity,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : _orbFade,
        curve: Curves.ease,
        child: SizedBox.square(
          dimension: diameter,
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: _hoverVeil(
              context,
              hovered: hovered,
              shape: HoverShape.circle,
              borderRadius: radius,
            ),
            child: CaptureButtonFace(
              form: form,
              diameter: diameter,
              fade: MediaQuery.disableAnimationsOf(context)
                  ? Duration.zero
                  : Motion.fade,
              formKey: voiceOrbFormKey,
              base: _OrbDisc(form: form),
              core: _core,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbDisc extends StatelessWidget {
  const _OrbDisc({required this.form});

  final CaptureButtonForm form;

  double get _scale => switch (form) {
    CaptureButtonForm.countdown => voiceCountdownCoreScale,
    CaptureButtonForm.saving => voiceSavingCoreScale,
    CaptureButtonForm.ready ||
    CaptureButtonForm.pause ||
    CaptureButtonForm.stop ||
    CaptureButtonForm.resume => 1,
  };

  double get _opacity => switch (form) {
    CaptureButtonForm.resume => voicePausedCoreOpacity,
    CaptureButtonForm.saving => voiceSavingCoreOpacity,
    CaptureButtonForm.ready ||
    CaptureButtonForm.countdown ||
    CaptureButtonForm.pause ||
    CaptureButtonForm.stop => 1,
  };

  @override
  Widget build(BuildContext context) {
    final bool still = MediaQuery.disableAnimationsOf(context);
    return AnimatedScale(
      scale: _scale,
      duration: still ? Duration.zero : Motion.stage,
      curve: Motion.entranceCurve,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(end: _opacity),
        duration: still ? Duration.zero : Motion.fade,
        curve: Motion.fadeCurve,
        builder: (BuildContext context, double opacity, Widget? disc) =>
            Opacity(opacity: opacity, child: disc),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              center: _orbHighlight,
              radius: _orbGradientRadius,
              colors: <Color>[
                context.colors.accentBright,
                Palette.coral,
                context.colors.accentDeep,
              ],
              stops: _orbStops,
            ),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: _orbShadow,
                offset: _orbShadowOffset,
                blurRadius: _orbShadowBlur,
                spreadRadius: _orbShadowSpread,
              ),
              BoxShadow(color: _orbEdge, spreadRadius: _orbEdgeWidth),
            ],
          ),
        ),
      ),
    );
  }
}

class _TakeActions extends StatelessWidget {
  const _TakeActions({
    required this.sidebar,
    required this.onLetGo,
    required this.onKeep,
    required this.saving,
  });

  final bool sidebar;
  final VoidCallback? onLetGo;
  final VoidCallback? onKeep;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    final double? height = sidebar ? null : _minTapTarget;
    final Widget letGo = _ActionButton(
      key: voiceDiscardPillKey,
      label: letGoConfirmLabel,
      onPressed: onLetGo,
      ink: _letGoInk,
      fontSize: sidebar ? _sidebarActionSize : _bottomBarLetGoSize,
      fontWeight: FontWeight.w500,
      padding: sidebar ? _sidebarLetGoPadding : _bottomBarLetGoPadding,
      height: height,
    );
    final Widget keep = _ActionButton(
      key: voiceSavePillKey,
      label: voiceKeepLabel,
      onPressed: onKeep,
      hint: sidebar ? voiceKeepShortcutHint(Theme.of(context).platform) : null,
      ink: _keepInk,
      fill: _keepFill,
      glyph: IconStickerGlyph.check,
      glyphGap: sidebar ? _sidebarKeepGap : _bottomBarKeepGap,
      fontSize: _keepSize,
      fontWeight: FontWeight.w600,
      padding: sidebar ? _sidebarKeepPadding : _bottomBarKeepPadding,
      height: height,
      expand: !sidebar,
      busy: saving,
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        letGo,
        SizedBox(width: sidebar ? _sidebarActionsGap : _bottomBarActionsGap),
        if (sidebar)
          keep
        else
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _bottomBarKeepMaxWidth,
              ),
              child: keep,
            ),
          ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.ink,
    required this.fontSize,
    required this.fontWeight,
    required this.padding,
    this.height,
    this.hint,
    this.fill,
    this.glyph,
    this.glyphGap = 0,
    this.expand = false,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color ink;
  final double fontSize;
  final FontWeight fontWeight;
  final EdgeInsets padding;
  final double? height;
  final String? hint;
  final Color? fill;
  final IconStickerGlyph? glyph;
  final double glyphGap;
  final bool expand;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onPressed = this.onPressed;
    final bool enabled = onPressed != null;
    final Color? fill = this.fill;
    final IconStickerGlyph? glyph = this.glyph;
    final Widget text = Text(
      label,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: TypographyTokens.sans,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: ink,
      ),
    );
    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (glyph != null) ...<Widget>[
          IconStickerGlyphIcon(glyph: glyph, color: ink, size: _keepGlyph),
          SizedBox(width: glyphGap),
        ],
        if (expand) Flexible(child: text) else text,
      ],
    );
    Widget face(BuildContext context, bool hovered) => FocusRingFace(
      borderRadius: _actionRadius,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: _hoverVeil(
          context,
          hovered: hovered,
          shape: HoverShape.pill,
          borderRadius: _actionRadius,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: _actionRadius,
            boxShadow: fill == null
                ? null
                : const <BoxShadow>[
                    BoxShadow(
                      color: _keepShadow,
                      offset: _keepShadowOffset,
                      blurRadius: _keepShadowBlur,
                      spreadRadius: _keepShadowSpread,
                    ),
                  ],
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: height ?? 0),
            child: Padding(
              padding: padding,
              child: Center(
                widthFactor: expand ? null : 1,
                heightFactor: 1,
                child: busy ? _savingFace(content) : content,
              ),
            ),
          ),
        ),
      ),
    );
    return Pressable(
      label: label,
      hint: enabled ? hint : null,
      onPressed: onPressed,
      surface: FocusRingSurface.dark,
      shape: HoverShape.pill,
      borderRadius: _actionRadius,
      paintsHover: false,
      ringsFace: true,
      builder: (BuildContext context, bool hovered) => ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: _minTapTarget,
          minHeight: _minTapTarget,
        ),
        child: Center(
          widthFactor: expand ? null : 1,
          heightFactor: 1,
          child: Opacity(
            opacity: enabled || busy ? 1 : _disabledActionOpacity,
            child: face(context, hovered),
          ),
        ),
      ),
    );
  }

  Widget _savingFace(Widget content) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        Visibility(
          visible: false,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: content,
        ),
        SizedBox.square(
          key: voiceSavingSpinnerKey,
          dimension: _savingSpinnerSize,
          child: CircularProgressIndicator(
            color: ink,
            strokeWidth: _savingSpinnerStroke,
          ),
        ),
      ],
    );
  }
}
