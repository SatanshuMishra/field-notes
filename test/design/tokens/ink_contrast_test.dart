import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';

const FieldNotesColors _l = FieldNotesColors.light;
const FieldNotesColors _d = FieldNotesColors.dark;

typedef _Surface = (String, Color);
typedef _Pairing = (String, Color, List<_Surface>);
typedef _Change = (String, Color, Color, _Surface, double);

const List<_Surface> _lightSurfaces = <_Surface>[
  ('page', Color(0xFFD9CBB2)),
  ('pageGradientInner', Color(0xFFE6D8BF)),
  ('panelTop', Color(0xFFEFE2CE)),
  ('panelBottom', Color(0xFFE9DCC4)),
  ('cardWarm', Color(0xFFF8EFE0)),
  ('cardLight', Color(0xFFFFF5EA)),
  ('cardBright', Color(0xFFFFFAF1)),
  ('cardAlt', Color(0xFFF6EFE0)),
  ('composerPaper', Color(0xFFFBF3E4)),
  ('paperShade', Color(0xFFF3E7D4)),
  ('titleBar', Color(0xFFE4D6BF)),
  ('dangerSurface', Color(0xFFFBECEA)),
];

const List<_Surface> _darkSurfaces = <_Surface>[
  ('page', Color(0xFF0D0C0C)),
  ('pageGradientInner', Color(0xFF191616)),
  ('panelTop', Color(0xFF1C1919)),
  ('panelBottom', Color(0xFF181515)),
  ('cardWarm', Color(0xFF272222)),
  ('cardLight', Color(0xFF312A2A)),
  ('cardBright', Color(0xFF1F1B1B)),
  ('cardAlt', Color(0xFF242020)),
  ('composerPaper', Color(0xFF292424)),
  ('paperShade', Color(0xFF2B2626)),
  ('titleBar', Color(0xFF221E1E)),
  ('dangerSurface', Color(0xFF3B2320)),
];

const List<_Surface> _lightFields = <_Surface>[
  ('cardBright', Color(0xFFFFFAF1)),
  ('cardLight', Color(0xFFFFF5EA)),
  ('cardWarm', Color(0xFFF8EFE0)),
  ('cardAlt', Color(0xFFF6EFE0)),
  ('paperShade', Color(0xFFF3E7D4)),
];

const List<_Surface> _darkFields = <_Surface>[
  ('page', Color(0xFF0D0C0C)),
  ('cardBright', Color(0xFF1F1B1B)),
  ('cardLight', Color(0xFF312A2A)),
  ('cardWarm', Color(0xFF272222)),
  ('cardAlt', Color(0xFF242020)),
  ('paperShade', Color(0xFF2B2626)),
];

const List<_Surface> _lightPhoneShell = <_Surface>[
  ('panelTop', Color(0xFFEFE2CE)),
  ('cardWarm', Color(0xFFF8EFE0)),
  ('cardLight', Color(0xFFFFF5EA)),
  ('cardBright', Color(0xFFFFFAF1)),
];

const List<_Surface> _darkPhoneShell = <_Surface>[
  ('panelTop', Color(0xFF1C1919)),
  ('cardWarm', Color(0xFF272222)),
  ('cardLight', Color(0xFF312A2A)),
  ('cardBright', Color(0xFF1F1B1B)),
];

const List<_Surface> _lightTitleBar = <_Surface>[
  ('titleBar', Color(0xFFE4D6BF)),
];

const List<_Surface> _darkTitleBar = <_Surface>[
  ('titleBar', Color(0xFF221E1E)),
];

const List<_Surface> _lightOffTrack = <_Surface>[
  ('panelTop', Color(0xFFEFE2CE)),
];

const List<_Surface> _darkOffTrack = <_Surface>[
  ('panelTop', Color(0xFF1C1919)),
];

const List<_Surface> _onTrack = <_Surface>[
  ('Palette.coral', Color(0xFFB8566A)),
];

const List<_Surface> _lightFieldFace = <_Surface>[
  ('cardBright', Color(0xFFFFFAF1)),
];

const List<_Surface> _darkFieldFace = <_Surface>[
  ('cardBright', Color(0xFF1F1B1B)),
];

const List<_Surface> _darkRingSurfaces = <_Surface>[
  ('Palette.coral', Color(0xFFB8566A)),
  ('Palette.danger', Color(0xFFC0392B)),
  ('Palette.toolbarInk', Color(0xFF2A241D)),
  ('Palette.mediaGround', Color(0xFF1C1713)),
];

final List<_Pairing> _textInks = <_Pairing>[
  ('light ink', _l.ink, _lightSurfaces),
  ('light inkSoft', _l.inkSoft, _lightSurfaces),
  ('light muted', _l.muted, _lightSurfaces),
  ('light mutedDeep', _l.mutedDeep, _lightSurfaces),
  ('light noticeInk', _l.noticeInk, _lightSurfaces),
  ('light noticeBodyInk', _l.noticeBodyInk, _lightSurfaces),
  ('light sage', _l.sage, _lightSurfaces),
  ('light accentInk', _l.accentInk, _lightSurfaces),
  ('light coralLink', _l.coralLink, _lightSurfaces),
  ('light accentInkStrong', _l.accentInkStrong, _lightPhoneShell),
  ('light mutedInkStrong', _l.mutedInkStrong, _lightPhoneShell),
  ('light dangerInk', _l.dangerInk, _lightSurfaces),
  ('light placeholder', _l.placeholder, _lightFields),
  ('light windowTitle', _l.windowTitle, _lightTitleBar),
  ('dark ink', _d.ink, _darkSurfaces),
  ('dark inkSoft', _d.inkSoft, _darkSurfaces),
  ('dark muted', _d.muted, _darkSurfaces),
  ('dark mutedDeep', _d.mutedDeep, _darkSurfaces),
  ('dark noticeInk', _d.noticeInk, _darkSurfaces),
  ('dark noticeBodyInk', _d.noticeBodyInk, _darkSurfaces),
  ('dark sage', _d.sage, _darkSurfaces),
  ('dark accentInk', _d.accentInk, _darkSurfaces),
  ('dark coralLink', _d.coralLink, _darkSurfaces),
  ('dark accentInkStrong', _d.accentInkStrong, _darkPhoneShell),
  ('dark mutedInkStrong', _d.mutedInkStrong, _darkPhoneShell),
  ('dark dangerInk', _d.dangerInk, _darkSurfaces),
  ('dark placeholder', _d.placeholder, _darkFields),
  ('dark windowTitle', _d.windowTitle, _darkTitleBar),
];

final List<_Pairing> _controlInks = <_Pairing>[
  ('light checkbox box ink', _l.ink, _lightSurfaces),
  ('light switch track outline line', _l.line, _lightSurfaces),
  ('light switch knob outline line', _l.line, _lightOffTrack),
  ('light switch knob face cardBright', _l.cardBright, _onTrack),
  ('light field border line', _l.line, _lightSurfaces),
  ('light focused field border Palette.coral', Palette.coral, _lightFieldFace),
  ('light focus ring ink', _l.ink, _lightSurfaces),
  (
    'focus ring Palette.focusRingOnDark',
    Palette.focusRingOnDark,
    _darkRingSurfaces,
  ),
  ('dark checkbox box ink', _d.ink, _darkSurfaces),
  ('dark switch track outline line', _d.line, _darkSurfaces),
  ('dark switch knob outline line', _d.line, _darkOffTrack),
  ('dark switch knob face cardBright', _d.cardBright, _onTrack),
  ('dark field border line', _d.line, _darkSurfaces),
  ('dark focused field border Palette.coral', Palette.coral, _darkFieldFace),
  ('dark focus ring ink', _d.ink, _darkSurfaces),
];

final List<_Change> _changes = <_Change>[
  (
    'light inkSoft',
    Color(0xFF6A5C4A),
    _l.inkSoft,
    ('page', Color(0xFFD9CBB2)),
    4.5,
  ),
  (
    'light muted',
    Color(0xFFA08A70),
    _l.muted,
    ('page', Color(0xFFD9CBB2)),
    4.5,
  ),
  (
    'light mutedDeep',
    Color(0xFF8A7358),
    _l.mutedDeep,
    ('page', Color(0xFFD9CBB2)),
    4.5,
  ),
  (
    'light noticeInk',
    Color(0xFF7D6A52),
    _l.noticeInk,
    ('page', Color(0xFFD9CBB2)),
    4.5,
  ),
  (
    'light noticeBodyInk',
    Color(0xFF6F6254),
    _l.noticeBodyInk,
    ('page', Color(0xFFD9CBB2)),
    4.5,
  ),
  ('light sage', Color(0xFF6D876D), _l.sage, ('page', Color(0xFFD9CBB2)), 4.5),
  (
    'light accentInk',
    Color(0xFFB8566A),
    _l.accentInk,
    ('page', Color(0xFFD9CBB2)),
    4.5,
  ),
  (
    'light coralLink',
    Color(0xFFB55669),
    _l.coralLink,
    ('page', Color(0xFFD9CBB2)),
    4.5,
  ),
  (
    'light dangerInk',
    Color(0xFFC0392B),
    _l.dangerInk,
    ('page', Color(0xFFD9CBB2)),
    4.5,
  ),
  (
    'light placeholder',
    Color(0xFFB3A58C),
    _l.placeholder,
    ('paperShade', Color(0xFFF3E7D4)),
    4.5,
  ),
  (
    'light windowTitle',
    Color(0xFFA3866A),
    _l.windowTitle,
    ('titleBar', Color(0xFFE4D6BF)),
    4.5,
  ),
  (
    'dark placeholder',
    Color(0xFF6A605F),
    _d.placeholder,
    ('cardLight', Color(0xFF312A2A)),
    4.5,
  ),
  (
    'dark windowTitle',
    Color(0xFF837675),
    _d.windowTitle,
    ('titleBar', Color(0xFF221E1E)),
    4.5,
  ),
];

double _contrast(Color a, Color b) {
  final double x = a.computeLuminance();
  final double y = b.computeLuminance();
  return (math.max(x, y) + 0.05) / (math.min(x, y) + 0.05);
}

double _hueDistance(double a, double b) {
  final double d = (a - b).abs() % 360;
  return math.min(d, 360 - d);
}

void _expectPairings(List<_Pairing> pairings, double ratio) {
  for (final (String name, Color ink, List<_Surface> surfaces) in pairings) {
    for (final (String surface, Color ground) in surfaces) {
      expect(
        _contrast(ink, ground),
        greaterThanOrEqualTo(ratio),
        reason: '$name on $surface',
      );
    }
  }
}

void main() {
  test('every light text ink reaches 4.5:1 on every surface it sits on', () {
    _expectPairings(_textInks, 4.5);
  });

  test('a changed ink keeps its hue', () {
    for (final (String name, Color before, Color after, _Surface _, double _)
        in _changes) {
      final HSLColor was = HSLColor.fromColor(before);
      final HSLColor now = HSLColor.fromColor(after);
      expect(after, isNot(before), reason: '$name changed');
      expect(
        _hueDistance(was.hue, now.hue),
        lessThanOrEqualTo(1),
        reason: '$name hue',
      );
      expect(
        (was.saturation - now.saturation).abs(),
        lessThanOrEqualTo(0.02),
        reason: '$name saturation',
      );
    }
  });

  test('every control ink reaches 3:1 on its surface', () {
    _expectPairings(_controlInks, 3.0);
  });

  test('a changed ink moves by the least step', () {
    for (final (
          String name,
          Color before,
          Color after,
          (String surface, Color ground),
          double ratio,
        )
        in _changes) {
      final HSLColor was = HSLColor.fromColor(before);
      final HSLColor now = HSLColor.fromColor(after);
      final double back = now.lightness < was.lightness ? 0.01 : -0.01;
      final Color stepBack = now
          .withLightness((now.lightness + back).clamp(0.0, 1.0))
          .toColor();
      expect(
        _contrast(after, ground),
        greaterThanOrEqualTo(ratio),
        reason: '$name reaches $ratio on $surface',
      );
      expect(
        _contrast(stepBack, ground),
        lessThan(ratio),
        reason: '$name one step back on $surface',
      );
    }
  });
}
