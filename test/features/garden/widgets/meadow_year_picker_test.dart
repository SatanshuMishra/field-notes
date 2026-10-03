import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/garden.dart';
import 'package:field_notes/features/garden/model/meadow_key_provider.dart';
import 'package:field_notes/features/garden/model/meadow_view_state.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/sky/sky_location.dart';
import 'package:field_notes/features/garden/sky/sky_location_provider.dart';
import 'package:field_notes/features/garden/sky/sky_time.dart';
import 'package:field_notes/features/garden/widgets/meadow_glass_popover.dart';
import 'package:field_notes/features/garden/widgets/meadow_year_picker.dart';
import 'package:field_notes/features/streak/journaled_dates_provider.dart';
import 'package:field_notes/state/journal_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

const Size _sidebarSurface = Size(1140, 900);
const Size _phone = Size(384, 832);

final DateTime _today = DateTime(2025, 5, 15, 9);
final DateTime _clock = DateTime.utc(2025, 5, 15, 18);
final SkyLocation _edmonton = resolveSkyLocation(
  'America/Edmonton',
  const Duration(hours: -6),
);

final List<Day> _days = <Day>[
  dayOf('2025-01-01', mood: Mood.happy),
  dayOf('2025-01-02', mood: Mood.happy),
  dayOf('2025-01-03', mood: Mood.calm),
  dayOf('2025-02-01', mood: Mood.warm),
  dayOf('2024-01-01', mood: Mood.happy),
  dayOf('2024-01-02', mood: Mood.happy),
  dayOf('2024-01-03', mood: Mood.sad),
  dayOf('2023-06-01', mood: Mood.calm),
];

const Map<String, int> _entryCounts = <String, int>{'2025-01-09': 1};

List<MeadowYear> _years() => <MeadowYear>[
  for (final int year in const <int>[2025, 2024, 2023])
    MeadowYear.build(
      days: _days,
      entryCounts: _entryCounts,
      year: year,
      today: _today,
    ),
];

Future<void> _pumpList(
  WidgetTester tester, {
  required bool compact,
  int openYear = 2024,
  ValueChanged<int>? onPick,
}) async {
  tester.view.physicalSize = compact ? _phone : _sidebarSurface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    gardenHarness(
      ColoredBox(
        color: meadowGlassFill,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: MeadowYearList(
              years: _years(),
              openYear: openYear,
              compact: compact,
              onPick: onPick ?? (int year) {},
            ),
          ),
        ),
      ),
      platform: compact ? TargetPlatform.android : TargetPlatform.macOS,
    ),
  );
}

void _expectRow(
  WidgetTester tester,
  int year, {
  required String meta,
  required String title,
}) {
  for (final String text in <String>['$year', meta, title]) {
    expect(
      find.descendant(
        of: find.byKey(meadowYearRowKey(year)),
        matching: find.text(text),
      ),
      findsOneWidget,
    );
  }
}

Color _textColour(WidgetTester tester, int year, String text) => tester
    .widget<Text>(
      find.descendant(
        of: find.byKey(meadowYearRowKey(year)),
        matching: find.text(text),
      ),
    )
    .style!
    .color!;

BoxDecoration _rowDecoration(WidgetTester tester, int year) =>
    tester
            .widget<DecoratedBox>(
              find
                  .descendant(
                    of: find.byKey(meadowYearRowKey(year)),
                    matching: find.byType(DecoratedBox),
                  )
                  .first,
            )
            .decoration
        as BoxDecoration;

bool Function(Symbol, List<dynamic>) _draws(Symbol call, Color colour) =>
    (Symbol method, List<dynamic> arguments) =>
        method == call &&
        (arguments.last as Paint).color.toARGB32() == colour.toARGB32();

void main() {
  testWidgets('the glass year list shows this year first then past years '
      'with weather and a weekly stripe', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _pumpList(tester, compact: false);

    final double thisYear = tester
        .getTopLeft(find.byKey(meadowYearRowKey(2025)))
        .dy;
    final double lastYear = tester
        .getTopLeft(find.byKey(meadowYearRowKey(2024)))
        .dy;
    final double yearBefore = tester
        .getTopLeft(find.byKey(meadowYearRowKey(2023)))
        .dy;
    expect(thisYear, lessThan(lastYear));
    expect(lastYear, lessThan(yearBefore));

    _expectRow(
      tester,
      2025,
      meta: '5 days so far',
      title: 'This year, still growing',
    );
    _expectRow(tester, 2024, meta: '3 blooms', title: 'Changeable skies');
    _expectRow(tester, 2023, meta: '1 bloom', title: 'Clear skies');

    expect(
      _textColour(tester, 2025, '2025').toARGB32(),
      meadowCream.toARGB32(),
    );
    expect(
      _textColour(tester, 2024, 'Changeable skies').toARGB32(),
      meadowCreamAt(0.88).toARGB32(),
    );
    expect(
      _textColour(tester, 2024, '3 blooms').toARGB32(),
      meadowCreamAt(0.7).toARGB32(),
    );

    final BoxDecoration open = _rowDecoration(tester, 2024);
    expect(open.color!.toARGB32(), meadowGlassWhite(0.16).toARGB32());
    expect(
      (open.border! as Border).top.color.toARGB32(),
      meadowGlassWhite(0.35).toARGB32(),
    );
    expect((open.border! as Border).top.width, 1);
    expect(open.borderRadius, const BorderRadius.all(Radius.circular(12)));
    final BoxDecoration closed = _rowDecoration(tester, 2025);
    expect(closed.color!.a, 0);
    expect(closed.border, isNull);

    expect(
      tester.renderObject(find.byKey(meadowYearRowKey(2025))),
      paints
        ..something(_draws(#drawRect, meadowChipColour(Mood.happy)))
        ..something(_draws(#drawRect, meadowGlassWhite(0.14)))
        ..something(_draws(#drawRect, meadowChipColour(Mood.warm)))
        ..something(_draws(#drawLine, meadowGlassWhite(0.3))),
    );
    expect(
      tester.renderObject(find.byKey(meadowYearRowKey(2024))),
      isNot(paints..something(_draws(#drawLine, meadowGlassWhite(0.3)))),
    );
    expect(
      tester.renderObject(find.byKey(meadowYearRowKey(2023))),
      paints
        ..something(_draws(#drawRect, meadowGlassWhite(0.14)))
        ..something(_draws(#drawRect, meadowChipColour(Mood.calm))),
    );

    expect(
      tester.getSemantics(find.byKey(meadowYearRowKey(2024))),
      isSemantics(isButton: true, isSelected: true),
    );
    expect(
      tester.getSemantics(find.byKey(meadowYearRowKey(2025))),
      isSemantics(isButton: true, isSelected: false),
    );
    semantics.dispose();
  });

  testWidgets('phone rows are roomier, at least 48 tall, and report the '
      'chosen year', (WidgetTester tester) async {
    final List<int> picks = <int>[];
    await _pumpList(tester, compact: true, openYear: 2025, onPick: picks.add);

    for (final int year in <int>[2025, 2024, 2023]) {
      expect(
        tester.getSize(find.byKey(meadowYearRowKey(year))).height,
        greaterThanOrEqualTo(48),
      );
    }
    final TextStyle year = tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(meadowYearRowKey(2025)),
            matching: find.text('2025'),
          ),
        )
        .style!;
    expect(year.fontSize, 20);
    expect(
      _rowDecoration(tester, 2025).borderRadius,
      const BorderRadius.all(Radius.circular(14)),
    );

    await tester.tap(find.byKey(meadowYearRowKey(2023)));
    await tester.pump();
    expect(picks, <int>[2023]);
  });

  testWidgets('on the phone escape and an outside tap close the year '
      'pop-over and a pick opens the year', (WidgetTester tester) async {
    tester.view.physicalSize = _phone;
    tester.view.devicePixelRatio = 1;
    tester.view.padding = const FakeViewPadding(top: 34, bottom: 24);
    tester.view.viewPadding = const FakeViewPadding(top: 34, bottom: 24);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      gardenHarness(
        const GardenScreen(),
        platform: TargetPlatform.android,
        overrides: <Override>[
          allDaysProvider.overrideWith(
            (Ref ref) => Stream<List<Day>>.value(_days),
          ),
          journalEntryCountsProvider.overrideWith(
            (Ref ref) => Stream<Map<String, int>>.value(_entryCounts),
          ),
          meadowKeyProvider.overrideWith((Ref ref) async => 24601),
          skyClockProvider.overrideWithValue(() => _clock),
          skyLocationProvider.overrideWith((Ref ref) async => _edmonton),
        ],
      ),
    );
    await tester.pump();
    await tester.pump();
    final ProviderContainer container = ProviderScope.containerOf(
      tester.element(find.byType(GardenScreen)),
    );

    Future<void> open() async {
      await tester.tap(find.byKey(meadowYearPickerButtonKey));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('your meadows'), findsOneWidget);
    }

    Future<void> closed() async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('your meadows'), findsNothing);
    }

    await open();
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await closed();

    await open();
    await tester.tapAt(const Offset(192, 200));
    await closed();
    expect(container.read(meadowViewStateProvider).studyYear, isNull);

    await open();
    await tester.tap(find.byKey(meadowYearRowKey(2024)));
    await closed();
    expect(container.read(meadowViewStateProvider).studyYear, 2024);
    expect(find.text('Your meadow, 2024'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
