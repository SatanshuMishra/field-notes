import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter/widgets.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/glass/glass_surface.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/sticker_button.dart';
import 'package:field_notes/features/capture/video/camera_glyphs.dart';

const double _mediaMutedAlpha = 0.68;

class RecorderInkScope extends InheritedWidget {
  const RecorderInkScope({
    super.key,
    required this.brightness,
    required super.child,
  });

  final Brightness brightness;

  @override
  bool updateShouldNotify(RecorderInkScope oldWidget) =>
      oldWidget.brightness != brightness;
}

@immutable
final class CometInks {
  const CometInks({
    required this.glow,
    required this.hotTrail,
    required this.coolTrail,
    required this.head,
    required this.star,
  });

  static const CometInks dark = CometInks(
    glow: Color(0xFFB8566A),
    hotTrail: Color(0xFFE58D9C),
    coolTrail: Color(0xFFF3E6D1),
    head: Color(0xFFF3E6D1),
    star: Color(0xFFF3E6D1),
  );

  static const CometInks light = CometInks(
    glow: Color(0xFFB8566A),
    hotTrail: Color(0xFFA54B5D),
    coolTrail: Color(0xFF6F605B),
    head: Color(0xFF5C4E4A),
    star: Color(0xFF6F605B),
  );

  final Color glow;
  final Color hotTrail;
  final Color coolTrail;
  final Color head;
  final Color star;
}

@immutable
final class RecorderInks {
  const RecorderInks._({
    required this.brightness,
    required this.ground,
    required this.chrome,
    required this.leaveGlyph,
    required this.leaveGlyphBottomBar,
    required this.dayLead,
    required this.title,
    required this.caret,
    required this.question,
    required this.kicker,
    required this.status,
    required this.timer,
    required this.numeral,
    required this.pausedDot,
    required this.takeTime,
    required this.takeTimeShadow,
    required this.keyHint,
    required this.letGo,
    required this.keepFill,
    required this.keepInk,
    required this.keepShadow,
    required this.orbRing,
    required this.orbOutline,
    required this.countdownRing,
    required this.resumeRing,
    required this.savingRing,
    required this.panelFill,
    required this.panelEdge,
    required this.panelTitle,
    required this.panelMessage,
    required this.error,
    required this.glassGlyph,
    required this.inputInk,
    required this.inputMutedInk,
    required this.focus,
    required this.glass,
    required this.sticker,
    required this.overlay,
    required this.comets,
  });

  factory RecorderInks.of(BuildContext context) {
    final RecorderInkScope? scope = context
        .dependOnInheritedWidgetOfExactType<RecorderInkScope>();
    final FieldNotesColors colors = context.colors;
    return scope?.brightness == Brightness.light
        ? RecorderInks._light(colors)
        : RecorderInks._dark(colors);
  }

  factory RecorderInks._dark(FieldNotesColors colors) => RecorderInks._(
    brightness: Brightness.dark,
    ground: Palette.mediaGround,
    chrome: const Color(0xFFB7A58C),
    leaveGlyph: const Color(0xCCFFFFFF),
    leaveGlyphBottomBar: const Color(0xBFFFFFFF),
    dayLead: const Color(0xFFE692A0),
    title: const Color(0xFFF3E6D1),
    caret: const Color(0xFFE3889A),
    question: const Color(0xFFF3E6D1),
    kicker: colors.accentSoft,
    status: const Color(0xFFDCCAB0),
    timer: const Color(0xFFB7A58C),
    numeral: const Color(0xFFF3E6D1),
    pausedDot: const Color(0xFFD9B36B),
    takeTime: const Color(0xFFF3E6D1),
    takeTimeShadow: const Color(0x73000000),
    keyHint: const Color(0xFF9A8872),
    letGo: const Color(0xFFB7A58C),
    keepFill: const Color(0xFFF3E6D1),
    keepInk: const Color(0xFF1C1713),
    keepShadow: const Color(0x73F3E6D1),
    orbRing: const Color(0xEBF3E6D1),
    orbOutline: null,
    countdownRing: const Color(0x5CF3E6D1),
    resumeRing: const Color(0x8FF3E6D1),
    savingRing: const Color(0x47F3E6D1),
    panelFill: const Color(0xB81C1713),
    panelEdge: const Color(0x24F3E6D1),
    panelTitle: const Color(0xFFF3E6D1),
    panelMessage: const Color(0xFFB7A58C),
    error: colors.accentBright,
    glassGlyph: cameraGlyphInk,
    inputInk: Palette.mediaInk,
    inputMutedInk: Palette.mediaInk.withValues(alpha: _mediaMutedAlpha),
    focus: FocusRingSurface.dark,
    glass: GlassTone.media,
    sticker: StickerGround.media,
    overlay: SystemUiOverlayStyle.light,
    comets: CometInks.dark,
  );

  factory RecorderInks._light(FieldNotesColors colors) => RecorderInks._(
    brightness: Brightness.light,
    ground: colors.viewerStage,
    chrome: const Color(0xFF554737),
    leaveGlyph: colors.ink.withValues(alpha: 0.8),
    leaveGlyphBottomBar: colors.ink.withValues(alpha: 0.75),
    dayLead: colors.accentInk,
    title: colors.ink,
    caret: Palette.coral,
    question: colors.ink,
    kicker: colors.accentInk,
    status: colors.ink,
    timer: const Color(0xFF554737),
    numeral: colors.ink,
    pausedDot: const Color(0xFF8E6A1F),
    takeTime: colors.ink,
    takeTimeShadow: const Color(0x00000000),
    keyHint: colors.mutedInkStrong,
    letGo: const Color(0xFF554737),
    keepFill: colors.mediaCta,
    keepInk: colors.mediaCtaInk,
    keepShadow: colors.ink.withValues(alpha: 0.25),
    orbRing: const Color(0xFFF6ECDC),
    orbOutline: const Color(0xFFB9A88A),
    countdownRing: colors.ink.withValues(alpha: 0.36),
    resumeRing: colors.ink.withValues(alpha: 0.56),
    savingRing: colors.ink.withValues(alpha: 0.28),
    panelFill: colors.composerPaper.withValues(alpha: 0.92),
    panelEdge: colors.ink.withValues(alpha: 0.2),
    panelTitle: colors.ink,
    panelMessage: const Color(0xFF554737),
    error: colors.accentInk,
    glassGlyph: colors.ink,
    inputInk: colors.ink,
    inputMutedInk: colors.mutedInkStrong,
    focus: FocusRingSurface.light,
    glass: GlassTone.paper,
    sticker: StickerGround.page,
    overlay: SystemUiOverlayStyle.dark,
    comets: CometInks.light,
  );

  final Brightness brightness;
  final Color ground;
  final Color chrome;
  final Color leaveGlyph;
  final Color leaveGlyphBottomBar;
  final Color dayLead;
  final Color title;
  final Color caret;
  final Color question;
  final Color kicker;
  final Color status;
  final Color timer;
  final Color numeral;
  final Color pausedDot;
  final Color takeTime;
  final Color takeTimeShadow;
  final Color keyHint;
  final Color letGo;
  final Color keepFill;
  final Color keepInk;
  final Color keepShadow;
  final Color orbRing;
  final Color? orbOutline;
  final Color countdownRing;
  final Color resumeRing;
  final Color savingRing;
  final Color panelFill;
  final Color panelEdge;
  final Color panelTitle;
  final Color panelMessage;
  final Color error;
  final Color glassGlyph;
  final Color inputInk;
  final Color inputMutedInk;
  final FocusRingSurface focus;
  final GlassTone glass;
  final StickerGround sticker;
  final SystemUiOverlayStyle overlay;
  final CometInks comets;

  bool get dark => brightness == Brightness.dark;
}
