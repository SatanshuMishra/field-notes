import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/widgets/meadow_year_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

const Size _sidebarSurface = Size(1140, 900);
const Size _bottomBarSurface = Size(400, 860);

final DateTime _today = DateTime(2025, 5, 15, 9);

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

Future<void> _pump(
  WidgetTester tester,
  Widget picker, {
  required Size surface,
  required Alignment anchor,
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    gardenHarness(
      Align(
        alignment: anchor,
        child: Padding(padding: const EdgeInsets.all(24), child: picker),
      ),
      platform: TargetPlatform.macOS,
    ),
  );
}

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.byKey(meadowYearPickerButtonKey));
  await tester.pumpAndSettle();
  expect(find.text('your meadows'), findsOneWidget);
}

Rect _buttonFace(WidgetTester tester) => tester.getRect(
  find.descendant(
    of: find.byKey(meadowYearPickerButtonKey),
    matching: find.byType(CompositedTransformTarget),
  ),
);

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

bool Function(Symbol, List<dynamic>) _draws(Symbol call, Color colour) =>
    (Symbol method, List<dynamic> arguments) =>
        method == call &&
        (arguments.last as Paint).color.toARGB32() == colour.toARGB32();

void main() {
  testWidgets(
    'the picker lists this year first then past years with weather and a weekly stripe',
    (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _pump(
        tester,
        MeadowYearPicker(
          years: _years(),
          openYear: 2024,
          onPick: (int year) {},
          compact: false,
        ),
        surface: _sidebarSurface,
        anchor: Alignment.topRight,
      );

      expect(find.text('2024'), findsOneWidget);
      expect(find.text('your meadows'), findsNothing);

      await _open(tester);

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

      final Color ink = FieldNotesColors.light.ink;
      expect(
        tester.renderObject(find.byKey(meadowYearRowKey(2025))),
        paints
          ..something(_draws(#drawRect, meadowChipColour(Mood.happy)))
          ..something(_draws(#drawRect, ink.withAlpha(0x1A)))
          ..something(_draws(#drawRect, meadowChipColour(Mood.warm)))
          ..something(_draws(#drawLine, ink.withAlpha(0x33))),
      );
      expect(
        tester.renderObject(find.byKey(meadowYearRowKey(2024))),
        paints
          ..something(_draws(#drawRRect, Palette.coral.withAlpha(0x21)))
          ..something(_draws(#drawRect, meadowChipColour(Mood.happy))),
      );
      expect(
        tester.renderObject(find.byKey(meadowYearRowKey(2024))),
        isNot(paints..something(_draws(#drawLine, ink.withAlpha(0x33)))),
      );
      expect(
        tester.renderObject(find.byKey(meadowYearRowKey(2023))),
        paints
          ..something(_draws(#drawRect, ink.withAlpha(0x1A)))
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

      final Rect face = _buttonFace(tester);
      final Rect popover = tester.getRect(
        find.byKey(meadowYearPickerPopoverKey),
      );
      expect(popover.width, 300);
      expect(popover.height, lessThanOrEqualTo(360));
      expect(popover.right, moreOrLessEquals(face.right));
      expect(popover.top, moreOrLessEquals(face.bottom + 8));
      semantics.dispose();
    },
  );

  testWidgets(
    'choosing a year reports it and escape or back closes the picker',
    (WidgetTester tester) async {
      final List<int> picks = <int>[];
      int pageBacks = 0;
      await _pump(
        tester,
        PopScope<Object?>(
          canPop: false,
          onPopInvokedWithResult: (bool didPop, Object? result) => pageBacks++,
          child: MeadowYearPicker(
            years: _years(),
            openYear: 2025,
            onPick: picks.add,
            compact: true,
          ),
        ),
        surface: _bottomBarSurface,
        anchor: Alignment.topLeft,
      );

      await _open(tester);
      final Rect face = _buttonFace(tester);
      final Rect popover = tester.getRect(
        find.byKey(meadowYearPickerPopoverKey),
      );
      expect(popover.width, 236);
      expect(popover.height, lessThanOrEqualTo(300));
      expect(popover.left, moreOrLessEquals(face.left));

      await tester.tap(find.byKey(meadowYearRowKey(2024)));
      await tester.pumpAndSettle();

      expect(picks, <int>[2024]);
      expect(find.text('your meadows'), findsNothing);

      await _open(tester);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text('your meadows'), findsNothing);

      await _open(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('your meadows'), findsNothing);
      expect(pageBacks, 0);

      await _open(tester);
      await tester.tapAt(const Offset(200, 800));
      await tester.pumpAndSettle();

      expect(find.text('your meadows'), findsNothing);
      expect(picks, <int>[2024]);

      await tester.binding.handlePopRoute();
      await tester.pump();

      expect(pageBacks, 1);
    },
  );
}
