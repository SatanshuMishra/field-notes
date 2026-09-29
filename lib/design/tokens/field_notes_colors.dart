import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

@immutable
final class FieldNotesColors extends ThemeExtension<FieldNotesColors> {
  const FieldNotesColors({
    required this.page,
    required this.pageGradientInner,
    required this.pageGradientOuter,
    required this.panelTop,
    required this.panelBottom,
    required this.cardWarm,
    required this.cardLight,
    required this.cardBright,
    required this.cardAlt,
    required this.composerPaper,
    required this.paperShade,
    required this.titleBar,
    required this.hatchLight,
    required this.hatchMid,
    required this.hatchDark,
    required this.dangerSurface,
    required this.ink,
    required this.line,
    required this.shadow,
    required this.shadowTintBase,
    required this.pill,
    required this.inkSoft,
    required this.muted,
    required this.mutedDeep,
    required this.noticeInk,
    required this.noticeBodyInk,
    required this.placeholder,
    required this.dashMuted,
    required this.windowTitle,
    required this.sage,
    required this.accentInk,
    required this.coralLink,
    required this.coralHover,
    required this.dangerInk,
    required this.waveMid,
    required this.waveLight,
  });

  static const FieldNotesColors light = FieldNotesColors(
    page: Color(0xFFD9CBB2),
    pageGradientInner: Color(0xFFE6D8BF),
    pageGradientOuter: Color(0xFFCDBD9F),
    panelTop: Color(0xFFEFE2CE),
    panelBottom: Color(0xFFE9DCC4),
    cardWarm: Color(0xFFF8EFE0),
    cardLight: Color(0xFFFFF5EA),
    cardBright: Color(0xFFFFFAF1),
    cardAlt: Color(0xFFF6EFE0),
    composerPaper: Color(0xFFFBF3E4),
    paperShade: Color(0xFFF3E7D4),
    titleBar: Color(0xFFE4D6BF),
    hatchLight: Color(0xFFECDFC8),
    hatchMid: Color(0xFFE2D3BA),
    hatchDark: Color(0xFFD9C9AE),
    dangerSurface: Color(0xFFFBECEA),
    ink: Color(0xFF4A3B2E),
    line: Color(0xFF4A3B2E),
    shadow: Color(0xFF4A3B2E),
    shadowTintBase: Color(0xFF4A3B2E),
    pill: Color(0xFF4A3B2E),
    inkSoft: Color(0xFF6A5C4A),
    muted: Color(0xFFA08A70),
    mutedDeep: Color(0xFF8A7358),
    noticeInk: Color(0xFF7D6A52),
    noticeBodyInk: Color(0xFF6F6254),
    placeholder: Color(0xFFB3A58C),
    dashMuted: Color(0xFFC3B39A),
    windowTitle: Color(0xFFA3866A),
    sage: Color(0xFF7D8450),
    accentInk: Color(0xFFC76A54),
    coralLink: Color(0xFFB45C44),
    coralHover: Color(0xFF9A4832),
    dangerInk: Color(0xFFC0392B),
    waveMid: Color(0xFFDCAE9A),
    waveLight: Color(0xFFE3C4B2),
  );

  static const FieldNotesColors dark = FieldNotesColors(
    page: Color(0xFF0E0C0A),
    pageGradientInner: Color(0xFF1B1612),
    pageGradientOuter: Color(0xFF0B0907),
    panelTop: Color(0xFF1E1914),
    panelBottom: Color(0xFF191511),
    cardWarm: Color(0xFF29221B),
    cardLight: Color(0xFF342A20),
    cardBright: Color(0xFF211B16),
    cardAlt: Color(0xFF26201A),
    composerPaper: Color(0xFF2B241C),
    paperShade: Color(0xFF2D261E),
    titleBar: Color(0xFF241E19),
    hatchLight: Color(0xFF2E261F),
    hatchMid: Color(0xFF352C24),
    hatchDark: Color(0xFF3C3229),
    dangerSurface: Color(0xFF3B2320),
    ink: Color(0xFFEFE3CE),
    line: Color(0xFF9D8870),
    shadow: Color(0xFF070504),
    shadowTintBase: Color(0xFF000000),
    pill: Color(0xFF3D3229),
    inkSoft: Color(0xFFC4B39A),
    muted: Color(0xFFA6917A),
    mutedDeep: Color(0xFFBFAA8E),
    noticeInk: Color(0xFFB09C80),
    noticeBodyInk: Color(0xFFC4B39A),
    placeholder: Color(0xFF6E604F),
    dashMuted: Color(0xFF5C4F42),
    windowTitle: Color(0xFF8A7560),
    sage: Color(0xFFADB670),
    accentInk: Color(0xFFE8927A),
    coralLink: Color(0xFFE5907A),
    coralHover: Color(0xFFF0A58E),
    dangerInk: Color(0xFFEF7466),
    waveMid: Color(0xFF8A5C4B),
    waveLight: Color(0xFF5C4339),
  );

  static FieldNotesColors of(BuildContext context) =>
      Theme.of(context).extension<FieldNotesColors>() ?? light;

  final Color page;
  final Color pageGradientInner;
  final Color pageGradientOuter;
  final Color panelTop;
  final Color panelBottom;
  final Color cardWarm;
  final Color cardLight;
  final Color cardBright;
  final Color cardAlt;
  final Color composerPaper;
  final Color paperShade;
  final Color titleBar;
  final Color hatchLight;
  final Color hatchMid;
  final Color hatchDark;
  final Color dangerSurface;
  final Color ink;
  final Color line;
  final Color shadow;
  final Color shadowTintBase;
  final Color pill;
  final Color inkSoft;
  final Color muted;
  final Color mutedDeep;
  final Color noticeInk;
  final Color noticeBodyInk;
  final Color placeholder;
  final Color dashMuted;
  final Color windowTitle;
  final Color sage;
  final Color accentInk;
  final Color coralLink;
  final Color coralHover;
  final Color dangerInk;
  final Color waveMid;
  final Color waveLight;

  Color get ink08 => ink.withAlpha(0x14);
  Color get ink12 => ink.withAlpha(0x1F);
  Color get ink14 => ink.withAlpha(0x24);
  Color get ink16 => ink.withAlpha(0x29);
  Color get ink18 => ink.withAlpha(0x2E);
  Color get ink20 => ink.withAlpha(0x33);
  Color get ink22 => ink.withAlpha(0x38);
  Color get ink25 => ink.withAlpha(0x40);
  Color get ink28 => ink.withAlpha(0x47);
  Color get ink30 => ink.withAlpha(0x4D);
  Color get ink32 => ink.withAlpha(0x52);
  Color get ink34 => ink.withAlpha(0x57);
  Color get ink35 => ink.withAlpha(0x59);
  Color get ink40 => ink.withAlpha(0x66);

  Color shadowTint(int alpha) => shadowTintBase.withAlpha(alpha);

  @override
  FieldNotesColors copyWith({
    Color? page,
    Color? pageGradientInner,
    Color? pageGradientOuter,
    Color? panelTop,
    Color? panelBottom,
    Color? cardWarm,
    Color? cardLight,
    Color? cardBright,
    Color? cardAlt,
    Color? composerPaper,
    Color? paperShade,
    Color? titleBar,
    Color? hatchLight,
    Color? hatchMid,
    Color? hatchDark,
    Color? dangerSurface,
    Color? ink,
    Color? line,
    Color? shadow,
    Color? shadowTintBase,
    Color? pill,
    Color? inkSoft,
    Color? muted,
    Color? mutedDeep,
    Color? noticeInk,
    Color? noticeBodyInk,
    Color? placeholder,
    Color? dashMuted,
    Color? windowTitle,
    Color? sage,
    Color? accentInk,
    Color? coralLink,
    Color? coralHover,
    Color? dangerInk,
    Color? waveMid,
    Color? waveLight,
  }) {
    return FieldNotesColors(
      page: page ?? this.page,
      pageGradientInner: pageGradientInner ?? this.pageGradientInner,
      pageGradientOuter: pageGradientOuter ?? this.pageGradientOuter,
      panelTop: panelTop ?? this.panelTop,
      panelBottom: panelBottom ?? this.panelBottom,
      cardWarm: cardWarm ?? this.cardWarm,
      cardLight: cardLight ?? this.cardLight,
      cardBright: cardBright ?? this.cardBright,
      cardAlt: cardAlt ?? this.cardAlt,
      composerPaper: composerPaper ?? this.composerPaper,
      paperShade: paperShade ?? this.paperShade,
      titleBar: titleBar ?? this.titleBar,
      hatchLight: hatchLight ?? this.hatchLight,
      hatchMid: hatchMid ?? this.hatchMid,
      hatchDark: hatchDark ?? this.hatchDark,
      dangerSurface: dangerSurface ?? this.dangerSurface,
      ink: ink ?? this.ink,
      line: line ?? this.line,
      shadow: shadow ?? this.shadow,
      shadowTintBase: shadowTintBase ?? this.shadowTintBase,
      pill: pill ?? this.pill,
      inkSoft: inkSoft ?? this.inkSoft,
      muted: muted ?? this.muted,
      mutedDeep: mutedDeep ?? this.mutedDeep,
      noticeInk: noticeInk ?? this.noticeInk,
      noticeBodyInk: noticeBodyInk ?? this.noticeBodyInk,
      placeholder: placeholder ?? this.placeholder,
      dashMuted: dashMuted ?? this.dashMuted,
      windowTitle: windowTitle ?? this.windowTitle,
      sage: sage ?? this.sage,
      accentInk: accentInk ?? this.accentInk,
      coralLink: coralLink ?? this.coralLink,
      coralHover: coralHover ?? this.coralHover,
      dangerInk: dangerInk ?? this.dangerInk,
      waveMid: waveMid ?? this.waveMid,
      waveLight: waveLight ?? this.waveLight,
    );
  }

  @override
  FieldNotesColors lerp(
    covariant ThemeExtension<FieldNotesColors>? other,
    double t,
  ) {
    if (other is! FieldNotesColors) {
      return this;
    }
    return FieldNotesColors(
      page: Color.lerp(page, other.page, t)!,
      pageGradientInner: Color.lerp(
        pageGradientInner,
        other.pageGradientInner,
        t,
      )!,
      pageGradientOuter: Color.lerp(
        pageGradientOuter,
        other.pageGradientOuter,
        t,
      )!,
      panelTop: Color.lerp(panelTop, other.panelTop, t)!,
      panelBottom: Color.lerp(panelBottom, other.panelBottom, t)!,
      cardWarm: Color.lerp(cardWarm, other.cardWarm, t)!,
      cardLight: Color.lerp(cardLight, other.cardLight, t)!,
      cardBright: Color.lerp(cardBright, other.cardBright, t)!,
      cardAlt: Color.lerp(cardAlt, other.cardAlt, t)!,
      composerPaper: Color.lerp(composerPaper, other.composerPaper, t)!,
      paperShade: Color.lerp(paperShade, other.paperShade, t)!,
      titleBar: Color.lerp(titleBar, other.titleBar, t)!,
      hatchLight: Color.lerp(hatchLight, other.hatchLight, t)!,
      hatchMid: Color.lerp(hatchMid, other.hatchMid, t)!,
      hatchDark: Color.lerp(hatchDark, other.hatchDark, t)!,
      dangerSurface: Color.lerp(dangerSurface, other.dangerSurface, t)!,
      ink: Color.lerp(ink, other.ink, t)!,
      line: Color.lerp(line, other.line, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
      shadowTintBase: Color.lerp(shadowTintBase, other.shadowTintBase, t)!,
      pill: Color.lerp(pill, other.pill, t)!,
      inkSoft: Color.lerp(inkSoft, other.inkSoft, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      mutedDeep: Color.lerp(mutedDeep, other.mutedDeep, t)!,
      noticeInk: Color.lerp(noticeInk, other.noticeInk, t)!,
      noticeBodyInk: Color.lerp(noticeBodyInk, other.noticeBodyInk, t)!,
      placeholder: Color.lerp(placeholder, other.placeholder, t)!,
      dashMuted: Color.lerp(dashMuted, other.dashMuted, t)!,
      windowTitle: Color.lerp(windowTitle, other.windowTitle, t)!,
      sage: Color.lerp(sage, other.sage, t)!,
      accentInk: Color.lerp(accentInk, other.accentInk, t)!,
      coralLink: Color.lerp(coralLink, other.coralLink, t)!,
      coralHover: Color.lerp(coralHover, other.coralHover, t)!,
      dangerInk: Color.lerp(dangerInk, other.dangerInk, t)!,
      waveMid: Color.lerp(waveMid, other.waveMid, t)!,
      waveLight: Color.lerp(waveLight, other.waveLight, t)!,
    );
  }

  List<Color> get _values => <Color>[
    page,
    pageGradientInner,
    pageGradientOuter,
    panelTop,
    panelBottom,
    cardWarm,
    cardLight,
    cardBright,
    cardAlt,
    composerPaper,
    paperShade,
    titleBar,
    hatchLight,
    hatchMid,
    hatchDark,
    dangerSurface,
    ink,
    line,
    shadow,
    shadowTintBase,
    pill,
    inkSoft,
    muted,
    mutedDeep,
    noticeInk,
    noticeBodyInk,
    placeholder,
    dashMuted,
    windowTitle,
    sage,
    accentInk,
    coralLink,
    coralHover,
    dangerInk,
    waveMid,
    waveLight,
  ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is FieldNotesColors && listEquals(_values, other._values);
  }

  @override
  int get hashCode => Object.hashAll(_values);
}
