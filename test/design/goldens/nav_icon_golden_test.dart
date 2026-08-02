@Tags(<String>['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/icons/nav_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';

import 'golden_harness.dart';

const double _size = 18;

const List<(NavGlyph, String)> _glyphs = <(NavGlyph, String)>[
  (NavGlyph.home, 'nav_icon_home'),
  (NavGlyph.calendar, 'nav_icon_calendar'),
  (NavGlyph.garden, 'nav_icon_garden'),
  (NavGlyph.search, 'nav_icon_search'),
];

Future<void> _captureGlyph(
  WidgetTester tester,
  NavGlyph glyph,
  String name,
) async {
  pinGoldenSurface(tester);

  await tester.pumpWidget(
    goldenHarness(
      NavIcon(glyph: glyph, color: Palette.ink, size: _size),
    ),
  );

  await expectLater(
    find.byType(RepaintBoundary),
    matchesGoldenFile('images/$name.png'),
  );
}

void main() {
  for (final (NavGlyph glyph, String name) in _glyphs) {
    testWidgets('the ${glyph.name} nav icon matches its golden', (
      WidgetTester tester,
    ) async {
      await _captureGlyph(tester, glyph, name);
    });
  }
}
