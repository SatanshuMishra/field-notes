import 'package:flutter/widgets.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/icons/capture_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
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

const String voiceSidebarPrivacyLine = 'Private · only you will hear this';
const String voiceBottomBarPrivacyLine = 'Only you will hear this';
const String voiceSavingStatus = 'Saving your recording…';
const String voiceKeepLabel = 'Keep this';
const String voiceStartLabel = 'Start recording';
const String voiceStartNowLabel = 'Start now';
const String voicePauseLabel = 'Pause recording';
const String voiceResumeLabel = 'Resume recording';
const String voiceOrbShortcutHint = 'Shortcut: Space';
const String voiceKeepShortcutHint = 'Shortcut: Command Return';

const double voiceSidebarOrbZone = 250;
const double voiceBottomBarOrbZone = 184;
const double voiceSidebarOrb = 124;
const double voiceBottomBarOrb = 100;
const double voicePausedOrbOpacity = 0.55;
const double voiceSavingOrbOpacity = 0.35;
const double voiceActionsHeight = 118;

const Color _orbLight = Color(0xFFE3937A);
const Color _orbDeep = Color(0xFFA4503D);
const Color _orbEdge = Color(0x24F3E6D1);
const Color _orbShadow = Color(0xBFC76A54);
const Color _orbGlyphInk = Palette.onAccent;
const Color _keepFill = Color(0xFFF3E6D1);
const Color _keepInk = Color(0xFF1C1713);
const Color _keepShadow = Color(0x73F3E6D1);
const Color _letGoInk = Color(0xFFB7A58C);
const Color _keyHintInk = Color(0xFF9A8872);
const Color _errorInk = Color(0xFFE79A80);

const double _minTapTarget = 48;
const double _sidebarRingInset = 34;
const double _bottomBarRingInset = 26;
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

const double _sidebarActionsGap = 10;
const double _bottomBarActionsGap = 8;
const double _sidebarActionSize = 14;
const double _bottomBarLetGoSize = 13;
const double _keepSize = 14;
const double _keepGlyph = 15;
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
    this.onDismiss,
    this.onKeepGoing,
    this.onLetGo,
    this.asking = false,
    this.elapsed = Duration.zero,
    this.errorMessage,
    this.letGoKey,
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

  bool get _saving => phase == VoiceRecorderPhase.saving;

  bool get _canKeep => phase.isTaking && !asking;

  RecorderPrimaryVerb? get _orbVerb {
    if (asking) {
      return null;
    }
    return switch (phase) {
      VoiceRecorderPhase.idle ||
      VoiceRecorderPhase.breathing => RecorderPrimaryVerb.start,
      VoiceRecorderPhase.recording => RecorderPrimaryVerb.pause,
      VoiceRecorderPhase.paused => RecorderPrimaryVerb.resume,
      VoiceRecorderPhase.saving => null,
    };
  }

  VoidCallback? get _orbTap => switch (_orbVerb) {
    RecorderPrimaryVerb.start => onStart,
    RecorderPrimaryVerb.pause => onPause,
    RecorderPrimaryVerb.resume => onResume,
    RecorderPrimaryVerb.keep => onStop,
    null => null,
  };

  VoidCallback? get _keepKey => _canKeep ? onStop : null;

  RecorderLeaveVerb? get _leaveVerb {
    if (_saving) {
      return null;
    }
    return asking && onDismiss != null
        ? RecorderLeaveVerb.keepGoing
        : RecorderLeaveVerb.leave;
  }

  VoidCallback? get _leaveKey =>
      _leaveVerb == null ? null : (onDismiss ?? onCancel);

  String get _keyHint => recorderKeyHint(
    primary: _orbTap == null ? null : _orbVerb,
    keep: _keepKey != null,
    leave: _leaveKey == null ? null : _leaveVerb,
  );

  @override
  Widget build(BuildContext context) {
    final bool sidebar = stageLayoutOf(context) == ShellLayout.sidebar;
    return RecorderShortcuts(
      onPrimary: _orbTap,
      onKeep: _keepKey,
      onLeave: _leaveKey,
      child: RecorderSurface(
        leaveKey: voiceCloseKey,
        privacyLine: sidebar
            ? voiceSidebarPrivacyLine
            : voiceBottomBarPrivacyLine,
        onLeave: _saving || asking ? null : onCancel,
        trailing: sidebar ? _KeyHint(text: _keyHint) : null,
        question: ReflectionPrompt(phase: phase.stage, showKicker: true),
        centre: _OrbZone(phase: phase, sidebar: sidebar, onTap: _orbTap),
        status: _status(),
        actions: _actions(sidebar),
      ),
    );
  }

  Widget _status() {
    final String? errorMessage = this.errorMessage;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        RecorderStatusLine(
          phase: phase.stage,
          elapsed: elapsed,
          savingText: voiceSavingStatus,
          inline: false,
        ),
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
                style: TypographyTokens.captionSans.copyWith(color: _errorInk),
              ),
            ),
          ),
      ],
    );
  }

  Widget _actions(bool sidebar) {
    final Widget? content;
    if (asking) {
      content = LetGoPanel(
        onKeepGoing: onKeepGoing ?? _ignore,
        onLetGo: onLetGo ?? _ignore,
        compact: !sidebar,
        keepGoingKey: voiceKeepGoingKey,
        letGoKey: letGoKey,
      );
    } else if (phase.isTaking || _saving) {
      content = _TakeActions(
        sidebar: sidebar,
        onLetGo: _saving ? null : onDiscard,
        onKeep: _saving ? null : onStop,
      );
    } else {
      content = null;
    }
    return ConstrainedBox(
      key: voiceActionsKey,
      constraints: const BoxConstraints(minHeight: voiceActionsHeight),
      child: Center(heightFactor: 1, child: content),
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
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.fade,
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
    required this.onTap,
  });

  final VoiceRecorderPhase phase;
  final bool sidebar;
  final VoidCallback? onTap;

  BreathingGlowMode? get _glow => switch (phase) {
    VoiceRecorderPhase.breathing => BreathingGlowMode.settle,
    VoiceRecorderPhase.recording => BreathingGlowMode.breathe,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final double zone = sidebar ? voiceSidebarOrbZone : voiceBottomBarOrbZone;
    final BreathingGlowMode? glow = _glow;
    return SizedBox.square(
      key: voiceOrbZoneKey,
      dimension: zone,
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          Positioned.fill(
            child: glow == null
                ? const SizedBox.shrink()
                : BreathingGlow(
                    diameter: zone,
                    mode: glow,
                    ringInset: glow == BreathingGlowMode.breathe
                        ? (sidebar ? _sidebarRingInset : _bottomBarRingInset)
                        : null,
                  ),
          ),
          _Orb(phase: phase, sidebar: sidebar, onTap: onTap),
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb({required this.phase, required this.sidebar, required this.onTap});

  final VoiceRecorderPhase phase;
  final bool sidebar;
  final VoidCallback? onTap;

  String get _label => switch (phase) {
    VoiceRecorderPhase.breathing => voiceStartNowLabel,
    VoiceRecorderPhase.recording => voicePauseLabel,
    VoiceRecorderPhase.paused => voiceResumeLabel,
    VoiceRecorderPhase.idle || VoiceRecorderPhase.saving => voiceStartLabel,
  };

  double get _opacity => switch (phase) {
    VoiceRecorderPhase.paused => voicePausedOrbOpacity,
    VoiceRecorderPhase.saving => voiceSavingOrbOpacity,
    _ => 1,
  };

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onTap = this.onTap;
    final bool enabled = onTap != null;
    final double diameter = sidebar ? voiceSidebarOrb : voiceBottomBarOrb;
    final double glyph = sidebar ? _sidebarOrbGlyph : _bottomBarOrbGlyph;
    return Semantics(
      button: true,
      enabled: enabled,
      label: _label,
      hint: sidebar && enabled ? voiceOrbShortcutHint : null,
      child: GestureDetector(
        key: voiceRecordButtonKey,
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: FocusRing(
          enabled: enabled,
          onPressed: onTap,
          surface: FocusRingSurface.dark,
          borderRadius: BorderRadius.all(Radius.circular(diameter / 2)),
          child: AnimatedOpacity(
            opacity: _opacity,
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : _orbFade,
            curve: Curves.ease,
            child: SizedBox.square(
              dimension: diameter,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    center: _orbHighlight,
                    radius: _orbGradientRadius,
                    colors: <Color>[_orbLight, Palette.coral, _orbDeep],
                    stops: _orbStops,
                  ),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: _orbShadow,
                      offset: _orbShadowOffset,
                      blurRadius: _orbShadowBlur,
                      spreadRadius: _orbShadowSpread,
                    ),
                    BoxShadow(color: _orbEdge, spreadRadius: _orbEdgeWidth),
                  ],
                ),
                child: Center(
                  child: ExcludeSemantics(
                    child: phase == VoiceRecorderPhase.recording
                        ? IconStickerGlyphIcon(
                            glyph: IconStickerGlyph.pause,
                            color: _orbGlyphInk,
                            size: glyph,
                          )
                        : CaptureIcon(
                            glyph: CaptureGlyph.mic,
                            color: _orbGlyphInk,
                            size: glyph,
                          ),
                  ),
                ),
              ),
            ),
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
  });

  final bool sidebar;
  final VoidCallback? onLetGo;
  final VoidCallback? onKeep;

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
      hint: sidebar ? voiceKeepShortcutHint : null,
      ink: _keepInk,
      fill: _keepFill,
      glyph: IconStickerGlyph.check,
      glyphGap: sidebar ? _sidebarKeepGap : _bottomBarKeepGap,
      fontSize: _keepSize,
      fontWeight: FontWeight.w600,
      padding: sidebar ? _sidebarKeepPadding : _bottomBarKeepPadding,
      height: height,
      expand: !sidebar,
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

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onPressed = this.onPressed;
    final bool enabled = onPressed != null;
    final Color? fill = this.fill;
    final IconStickerGlyph? glyph = this.glyph;
    final Widget text = Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontFamily: TypographyTokens.sans,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: ink,
      ),
    );
    final Widget face = DecoratedBox(
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
      child: SizedBox(
        height: height,
        child: Padding(
          padding: padding,
          child: Center(
            widthFactor: expand ? null : 1,
            heightFactor: height == null ? 1 : null,
            child: ExcludeSemantics(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (glyph != null) ...<Widget>[
                    IconStickerGlyphIcon(
                      glyph: glyph,
                      color: ink,
                      size: _keepGlyph,
                    ),
                    SizedBox(width: glyphGap),
                  ],
                  if (expand) Flexible(child: text) else text,
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      hint: enabled ? hint : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _minTapTarget,
            minHeight: _minTapTarget,
          ),
          child: Center(
            widthFactor: expand ? null : 1,
            heightFactor: 1,
            child: FocusRing(
              enabled: enabled,
              onPressed: onPressed,
              surface: FocusRingSurface.dark,
              borderRadius: _actionRadius,
              child: Opacity(
                opacity: enabled ? 1 : _disabledActionOpacity,
                child: face,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
