import 'package:field_notes/design/flowers/flowers.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/widgets/meadow_ribbon.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

const String _juneSummary = 'June, 5 days planted, mostly Tired and Hopeful';

const MeadowRange _june = MeadowRange(first: 151, last: 180, key: 'm5');

const Color _highlightTint = Color(0x21C76A54);

MeadowYear _june2026() => MeadowYear.build(
  days: <Day>[
    dayOf('2026-06-01', mood: Mood.tired),
    dayOf('2026-06-02', mood: Mood.hopeful),
    dayOf('2026-06-03', mood: Mood.tired),
    dayOf('2026-06-10', mood: Mood.tired),
  ],
  entryCounts: const <String, int>{'2026-06-01': 1, '2026-06-04': 2},
  year: 2026,
  today: DateTime(2026, 6, 10, 9),
);

class _RibbonHost extends StatefulWidget {
  const _RibbonHost({
    required this.year,
    required this.compact,
    required this.growthPoint,
    required this.calls,
  });

  final MeadowYear year;
  final bool compact;
  final int growthPoint;
  final List<MeadowRange?> calls;

  @override
  State<_RibbonHost> createState() => _RibbonHostState();
}

class _RibbonHostState extends State<_RibbonHost> {
  MeadowRange? _highlight;

  @override
  Widget build(BuildContext context) {
    return MeadowRibbon(
      year: widget.year,
      compact: widget.compact,
      growthPoint: widget.growthPoint,
      highlight: _highlight,
      onHighlight: (MeadowRange? range) {
        widget.calls.add(range);
        setState(() => _highlight = range);
      },
    );
  }
}

Future<void> _pump(
  WidgetTester tester,
  MeadowYear year, {
  required bool compact,
  required int growthPoint,
  List<MeadowRange?>? calls,
}) async {
  tester.view.physicalSize = compact
      ? const Size(390, 900)
      : const Size(1100, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    gardenHarness(
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _RibbonHost(
          year: year,
          compact: compact,
          growthPoint: growthPoint,
          calls: calls ?? <MeadowRange?>[],
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _month(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byType(AnimatedContainer),
);

Finder _grid(String label) => find.descendant(
  of: _month(label),
  matching: find.byWidgetPredicate(
    (Widget widget) =>
        widget is CustomPaint && widget.painter is MeadowDayGridPainter,
  ),
);

List<MeadowDaySquare> _squares(WidgetTester tester, String label) =>
    (tester.widget<CustomPaint>(_grid(label)).painter! as MeadowDayGridPainter)
        .squares;

Color? _tint(WidgetTester tester, String label) =>
    (tester.widget<AnimatedContainer>(_month(label)).decoration!
            as BoxDecoration)
        .color;

List<String?> _tallyTexts(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(of: find.byType(Wrap), matching: find.byType(Text)),
    )
    .map((Text text) => text.data)
    .toList();

void main() {
  testWidgets(
    'each month shows its days in mood colours and future days dashed',
    (WidgetTester tester) async {
      await _pump(tester, _june2026(), compact: false, growthPoint: 153);

      const List<String> labels = <String>[
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final double row = tester.getTopLeft(find.text('Jan')).dy;
      for (final String label in labels) {
        expect(find.text(label), findsOneWidget);
        expect(tester.getTopLeft(find.text(label)).dy, row);
      }

      final List<MeadowDaySquare> june = _squares(tester, 'Jun');
      expect(june, hasLength(30));
      expect(
        june[0],
        MeadowDaySquare(
          mark: MeadowDayMark.mood,
          fill: meadowChipColour(Mood.tired),
        ),
      );
      expect(
        june[1],
        MeadowDaySquare(
          mark: MeadowDayMark.mood,
          fill: meadowChipColour(Mood.hopeful),
        ),
      );
      expect(
        june[2],
        MeadowDaySquare(
          mark: MeadowDayMark.mood,
          fill: meadowChipColour(Mood.tired),
          faded: true,
        ),
      );
      expect(
        june[3],
        const MeadowDaySquare(
          mark: MeadowDayMark.sprout,
          fill: meadowSproutChipColour,
          faded: true,
        ),
      );
      expect(
        june[4],
        const MeadowDaySquare(mark: MeadowDayMark.empty, faded: true),
      );
      expect(
        june[9],
        MeadowDaySquare(
          mark: MeadowDayMark.mood,
          fill: meadowChipColour(Mood.tired),
          faded: true,
        ),
      );
      expect(
        june.sublist(10),
        everyElement(const MeadowDaySquare(mark: MeadowDayMark.future)),
      );
      expect(
        _squares(tester, 'Jan'),
        everyElement(const MeadowDaySquare(mark: MeadowDayMark.empty)),
      );
      expect(_squares(tester, 'Jan'), hasLength(31));
      expect(_squares(tester, 'Feb'), hasLength(28));
      expect(
        _squares(tester, 'Dec'),
        everyElement(const MeadowDaySquare(mark: MeadowDayMark.future)),
      );

      final Color outline = FieldNotesColors.light.ink16;
      final Color tired = meadowChipColour(Mood.tired);
      expect(
        _grid('Jun'),
        paints
          ..rrect(color: tired, style: PaintingStyle.fill)
          ..rrect(
            color: meadowChipColour(Mood.hopeful),
            style: PaintingStyle.fill,
          )
          ..rrect(
            color: tired.withValues(alpha: 0.22),
            style: PaintingStyle.fill,
          )
          ..rrect(
            color: meadowSproutChipColour.withValues(alpha: 0.22),
            style: PaintingStyle.fill,
          )
          ..rrect(
            color: outline.withValues(alpha: outline.a * 0.22),
            style: PaintingStyle.stroke,
            strokeWidth: 1,
          )
          ..path(color: outline, style: PaintingStyle.stroke, strokeWidth: 1),
      );

      await _pump(tester, _june2026(), compact: true, growthPoint: 161);
      final double first = tester.getTopLeft(find.text('Jan')).dy;
      for (final String label in <String>['Feb', 'Mar', 'Apr']) {
        expect(tester.getTopLeft(find.text(label)).dy, first);
      }
      final double second = tester.getTopLeft(find.text('May')).dy;
      expect(second, greaterThan(first));
      for (final String label in <String>['Jun', 'Jul', 'Aug']) {
        expect(tester.getTopLeft(find.text(label)).dy, second);
      }
      expect(tester.getTopLeft(find.text('Sep')).dy, greaterThan(second));
      expect(
        _squares(tester, 'Jun')[2],
        MeadowDaySquare(
          mark: MeadowDayMark.mood,
          fill: meadowChipColour(Mood.tired),
        ),
      );
    },
  );

  testWidgets('a month button highlights its days and reads its summary', (
    WidgetTester tester,
  ) async {
    final List<MeadowRange?> calls = <MeadowRange?>[];
    await _pump(
      tester,
      _june2026(),
      compact: false,
      growthPoint: 161,
      calls: calls,
    );

    final Finder june = find.bySemanticsLabel(_juneSummary);
    expect(june, findsOneWidget);
    expect(
      tester.getSemantics(june),
      isSemantics(
        label: _juneSummary,
        isButton: true,
        hasTapAction: true,
        isFocusable: true,
      ),
    );
    expect(find.bySemanticsLabel('January, no days planted'), findsOneWidget);
    expect(tester.getSize(_month('Jun')).height, greaterThanOrEqualTo(48));
    expect(_tint(tester, 'Jun'), isNot(_highlightTint));

    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(_month('Jun')));
    await tester.pumpAndSettle();
    expect(calls, <MeadowRange?>[_june]);
    expect(_tint(tester, 'Jun'), _highlightTint);
    expect(_tint(tester, 'May'), isNot(_highlightTint));

    await mouse.down(tester.getCenter(_month('Jun')));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(calls, <MeadowRange?>[_june]);

    await mouse.moveTo(tester.getCenter(_month('Jul')));
    await tester.pumpAndSettle();
    expect(calls.last, const MeadowRange(first: 181, last: 211, key: 'm6'));
    await mouse.moveTo(const Offset(1090, 690));
    await tester.pumpAndSettle();
    expect(calls.last, isNull);
    expect(_tint(tester, 'Jul'), isNot(_highlightTint));

    calls.clear();
    for (int press = 0; press < 6; press++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    }
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, <MeadowRange?>[_june]);
    expect(_tint(tester, 'Jun'), _highlightTint);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(calls, <MeadowRange?>[_june, null]);
    expect(_tint(tester, 'Jun'), isNot(_highlightTint));

    calls.clear();
    await _pump(
      tester,
      _june2026(),
      compact: true,
      growthPoint: 161,
      calls: calls,
    );
    expect(
      tester.getSemantics(find.bySemanticsLabel(_juneSummary)),
      isSemantics(label: _juneSummary, isButton: true),
    );
    final Size tapTarget = tester.getSize(_month('Jun'));
    expect(tapTarget.width, greaterThanOrEqualTo(48));
    expect(tapTarget.height, greaterThanOrEqualTo(48));
    await tester.tap(_month('Jun'));
    await tester.pumpAndSettle();
    expect(calls, <MeadowRange?>[_june]);
    expect(_tint(tester, 'Jun'), _highlightTint);
    await tester.tap(_month('Jun'));
    await tester.pumpAndSettle();
    expect(calls, <MeadowRange?>[_june, null]);
    expect(_tint(tester, 'Jun'), isNot(_highlightTint));
  });

  testWidgets('the tally lists moods present then sprouts', (
    WidgetTester tester,
  ) async {
    final MeadowYear year = MeadowYear.build(
      days: <Day>[
        dayOf('2026-01-01', mood: Mood.happy),
        dayOf('2026-01-02', mood: Mood.happy),
        dayOf('2026-01-03', mood: Mood.happy),
        dayOf('2026-01-05', mood: Mood.calm),
        dayOf('2026-01-07', mood: Mood.sad),
        dayOf('2026-01-08', mood: Mood.sad),
        dayOf('2026-06-05', mood: Mood.tired),
      ],
      entryCounts: const <String, int>{
        '2026-01-10': 1,
        '2026-01-11': 1,
        '2026-01-12': 3,
        '2026-01-13': 1,
        '2026-06-06': 1,
      },
      year: 2026,
      today: DateTime(2026, 6, 10, 9),
    );

    await _pump(tester, year, compact: false, growthPoint: 153);
    expect(_tallyTexts(tester), <String>[
      '3',
      'Happy',
      '1',
      'Calm',
      '2',
      'Sad',
      '4',
      'Sprouts',
    ]);
    final List<FlowerBloom> blooms = tester
        .widgetList<FlowerBloom>(find.byType(FlowerBloom))
        .toList();
    expect(blooms.map((FlowerBloom bloom) => bloom.kind), <FlowerKind>[
      Mood.happy.flower,
      Mood.calm.flower,
      Mood.sad.flower,
    ]);
    expect(blooms.map((FlowerBloom bloom) => bloom.size), everyElement(16));
    expect(
      tester.getTopLeft(find.text('Happy')).dx,
      lessThan(tester.getTopLeft(find.text('Calm')).dx),
    );
    expect(
      tester.getTopLeft(find.text('Sad')).dx,
      lessThan(tester.getTopLeft(find.text('Sprouts')).dx),
    );
    expect(find.text('Tired'), findsNothing);
    final TextStyle count = tester.widget<Text>(find.text('3')).style!;
    final TextStyle label = tester.widget<Text>(find.text('Happy')).style!;
    expect(count.fontWeight, FontWeight.w600);
    expect(count.color, FieldNotesColors.light.ink);
    expect(label.color, FieldNotesColors.light.muted);

    await _pump(tester, year, compact: true, growthPoint: 156);
    expect(_tallyTexts(tester), <String>[
      '3',
      'Happy',
      '1',
      'Calm',
      '1',
      'Tired',
      '2',
      'Sad',
      '4',
      'Sprouts',
    ]);
    expect(
      tester
          .widgetList<FlowerBloom>(find.byType(FlowerBloom))
          .map((FlowerBloom bloom) => bloom.size),
      everyElement(13),
    );

    final MeadowYear single = MeadowYear.build(
      days: <Day>[dayOf('2026-02-01', mood: Mood.love)],
      entryCounts: const <String, int>{'2026-02-02': 1},
      year: 2026,
      today: DateTime(2026, 6, 10, 9),
    );
    await _pump(tester, single, compact: false, growthPoint: 161);
    expect(_tallyTexts(tester), <String>['1', 'Loved', '1', 'Sprout']);

    final MeadowYear empty = MeadowYear.build(
      days: const <Day>[],
      entryCounts: const <String, int>{},
      year: 2026,
      today: DateTime(2026, 6, 10, 9),
    );
    await _pump(tester, empty, compact: false, growthPoint: 161);
    expect(find.byType(FlowerBloom), findsNothing);
    expect(find.textContaining('Sprout'), findsNothing);
    expect(find.byType(Wrap), findsNothing);
    expect(find.text('Jan'), findsOneWidget);
  });
}
