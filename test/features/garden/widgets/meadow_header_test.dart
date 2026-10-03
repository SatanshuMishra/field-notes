import 'package:field_notes/design/tokens/typography.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/sky/sky_astronomy.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/garden_header.dart';
import 'package:field_notes/features/garden/widgets/meadow_glass_popover.dart';
import 'package:field_notes/features/garden/widgets/meadow_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

const Size _sidebarSurface = Size(1140, 900);
const Size _bottomBarSurface = Size(400, 860);

final DateTime _instant = DateTime.utc(2025, 5, 15, 18);

Future<void> _pump(
  WidgetTester tester,
  Widget header, {
  required Size surface,
  required bool compact,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    gardenHarness(
      ColoredBox(
        color: meadowGlassFill,
        child: Padding(padding: const EdgeInsets.all(16), child: header),
      ),
      platform: compact ? TargetPlatform.android : TargetPlatform.macOS,
    ),
  );
}

TextStyle _style(WidgetTester tester, String text) =>
    tester.widget<Text>(find.text(text)).style!;

void main() {
  testWidgets("this year's header counts blooms and sprouts so far", (
    WidgetTester tester,
  ) async {
    for (final (bool compact, Size surface, String summary)
        in <(bool, Size, String)>[
          (
            false,
            _sidebarSurface,
            '129 blooms and 6 sprouts so far in 2025 · '
                'quietly filling in as the year goes',
          ),
          (true, _bottomBarSurface, '129 blooms and 6 sprouts so far in 2025'),
        ]) {
      await _pump(
        tester,
        const MeadowHeader(
          compact: false,
          mode: MeadowSceneMode.page,
          year: 2025,
          blooms: 129,
          sprouts: 6,
          weather: 'Clear skies',
        ).copyFor(compact),
        surface: surface,
        compact: compact,
      );

      expect(find.text('your meadow'), findsOneWidget);
      expect(find.text('Every day, a bloom'), findsOneWidget);
      expect(find.text(summary), findsOneWidget);
      expect(find.text('meadow study'), findsNothing);
      expect(find.text(meadowBackLabel), findsNothing);

      final TextStyle kicker = _style(tester, 'your meadow');
      expect(kicker.fontFamily, TypographyTokens.accent);
      expect(kicker.fontSize, compact ? 16 : 17);
      expect(kicker.color!.toARGB32(), meadowKickerInk.toARGB32());
      expect(kicker.shadows, isNotEmpty);
      final TextStyle title = _style(tester, 'Every day, a bloom');
      expect(title.fontFamily, TypographyTokens.serif);
      expect(title.fontSize, compact ? 26 : 34);
      expect(title.height, compact ? 1.05 : 1.02);
      expect(title.color!.toARGB32(), meadowCream.toARGB32());
      final TextStyle line = _style(tester, summary);
      expect(line.fontFamily, TypographyTokens.sans);
      expect(line.fontSize, compact ? 11.5 : 12.5);
      expect(line.color!.a, closeTo(compact ? 0.9 : 0.88, 0.01));
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets("a past year's header says meadow study with its weather and, on "
      'macOS, a way back', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    int backs = 0;
    await _pump(
      tester,
      MeadowHeader(
        compact: false,
        mode: MeadowSceneMode.study,
        year: 2024,
        blooms: 205,
        sprouts: 6,
        weather: 'Changeable skies',
        onBack: () => backs++,
      ),
      surface: _sidebarSurface,
      compact: false,
    );

    expect(find.text('meadow study'), findsOneWidget);
    expect(find.text('Your meadow, 2024'), findsOneWidget);
    expect(
      find.text('Changeable skies · 205 blooms and 6 sprouts across 2024'),
      findsOneWidget,
    );
    expect(find.text('your meadow'), findsNothing);
    expect(find.text('Every day, a bloom'), findsNothing);
    expect(
      tester.getSemantics(find.text(meadowBackLabel)),
      isSemantics(label: meadowBackLabel, isButton: true),
    );
    expect(
      tester.getTopLeft(find.text(meadowBackLabel)).dy,
      lessThan(tester.getTopLeft(find.text('meadow study')).dy),
    );
    expect(
      _style(tester, meadowBackLabel).color!.toARGB32(),
      meadowCreamAt(0.9).toARGB32(),
    );
    await tester.tap(find.text(meadowBackLabel));
    await tester.pump();
    expect(backs, 1);

    await _pump(
      tester,
      MeadowHeader(
        compact: true,
        mode: MeadowSceneMode.study,
        year: 2024,
        blooms: 205,
        sprouts: 6,
        weather: 'Changeable skies',
        onBack: () => backs++,
      ),
      surface: _bottomBarSurface,
      compact: true,
    );
    expect(find.text('meadow study'), findsOneWidget);
    expect(find.text('Your meadow, 2024'), findsOneWidget);
    expect(find.text('Changeable skies · 205 blooms'), findsOneWidget);
    expect(find.text(meadowBackLabel), findsNothing);
    expect(find.text(meadowBackCompactLabel), findsNothing);
    semantics.dispose();
  });

  testWidgets('the dock clock shows the time over its next sunrise or sunset', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      Center(
        child: GardenSkyClock(
          moment: SkyMoment(instant: _instant),
          sunEvent: SkyEvent(
            instant: DateTime.utc(2025, 5, 16, 3, 1),
            isRise: false,
          ),
        ),
      ),
      surface: _sidebarSurface,
      compact: false,
    );
    final BuildContext context = tester.element(find.byType(GardenSkyClock));
    final String clock = gardenClockLabel(
      context,
      SkyMoment(instant: _instant),
    );
    expect(find.text(clock), findsOneWidget);
    expect(_style(tester, clock).fontSize, 13);
    expect(_style(tester, clock).color!.toARGB32(), meadowCream.toARGB32());
    final Finder note = find.textContaining('sunset ');
    expect(note, findsOneWidget);
    final TextStyle noteStyle = tester.widget<Text>(note).style!;
    expect(noteStyle.fontSize, 10.5);
    expect(noteStyle.color!.a, closeTo(0.72, 0.01));
    expect(
      tester.getTopLeft(note).dy,
      greaterThan(tester.getTopLeft(find.text(clock)).dy),
    );
    expect(find.text(meadowPlayTheDayLabel), findsNothing);
    expect(find.text(meadowNowLabel), findsNothing);
  });
}

extension on MeadowHeader {
  MeadowHeader copyFor(bool compact) => MeadowHeader(
    compact: compact,
    mode: mode,
    year: year,
    blooms: blooms,
    sprouts: sprouts,
    weather: weather,
    onBack: onBack,
  );
}
