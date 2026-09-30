import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_date.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/widgets/meadow_landmarks.dart';
import 'package:field_notes/features/garden/widgets/meadow_tabs.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/garden_harness.dart';

const String _spruceText =
    'The tallest tree at the forest edge marks the 20 days in a row your '
    'meadow grew. The bees keep their hive in it.';

const Color _coral = Color(0xFFC76A54);

List<Day> _days(int year, Iterable<int> days, Mood mood) => <Day>[
  for (final int day in days)
    dayOf(captureDateKey(DateTime(year, 1, day)), mood: mood),
];

Iterable<int> _through(int first, int last) =>
    Iterable<int>.generate(last - first + 1, (int i) => first + i);

List<Day> _twentyInARow(int year) => <Day>[
  ..._days(year, _through(1, 10), Mood.happy),
  ..._days(year, _through(11, 20), Mood.sad),
];

MeadowYear _thisYear(List<Day> days) => MeadowYear.build(
  days: days,
  entryCounts: const <String, int>{},
  year: 2026,
  today: DateTime(2026, 6, 10, 9),
);

MeadowYear _lastYear(List<Day> days) => MeadowYear.build(
  days: days,
  entryCounts: const <String, int>{},
  year: 2025,
  today: DateTime(2026, 3, 1, 9),
);

class _Host extends StatefulWidget {
  const _Host({super.key, required this.builder, required this.calls});

  final Widget Function(MeadowRange?, ValueChanged<MeadowRange?>) builder;
  final List<MeadowRange?> calls;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  MeadowRange? _highlight;

  @override
  Widget build(BuildContext context) {
    return widget.builder(_highlight, (MeadowRange? range) {
      widget.calls.add(range);
      setState(() => _highlight = range);
    });
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required bool compact,
  required List<MeadowRange?> calls,
  required Widget Function(MeadowRange?, ValueChanged<MeadowRange?>) builder,
}) async {
  tester.view.physicalSize = compact
      ? const Size(390, 1400)
      : const Size(1100, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    gardenHarness(
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: _Host(key: UniqueKey(), builder: builder, calls: calls),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _pumpLandmarks(
  WidgetTester tester,
  MeadowYear year, {
  required bool compact,
  List<MeadowRange?>? calls,
}) => _pump(
  tester,
  compact: compact,
  calls: calls ?? <MeadowRange?>[],
  builder: (MeadowRange? highlight, ValueChanged<MeadowRange?> onHighlight) =>
      MeadowLandmarks(
        year: year,
        isCurrentYear: year.year == 2026,
        compact: compact,
        highlight: highlight,
        onHighlight: onHighlight,
      ),
);

Future<void> _pumpTabs(
  WidgetTester tester,
  MeadowYear year, {
  required bool compact,
  required List<MeadowRange?> calls,
}) => _pump(
  tester,
  compact: compact,
  calls: calls,
  builder: (MeadowRange? highlight, ValueChanged<MeadowRange?> onHighlight) =>
      MeadowTabs(
        year: year,
        isCurrentYear: year.year == 2026,
        compact: compact,
        growthPoint: year.limit,
        highlight: highlight,
        onHighlight: onHighlight,
      ),
);

Color _border(WidgetTester tester, String title) {
  final AnimatedContainer card = tester.widget<AnimatedContainer>(
    find.ancestor(
      of: find.text(title),
      matching: find.byType(AnimatedContainer),
    ),
  );
  return ((card.decoration! as BoxDecoration).border! as Border).top.color;
}

Future<void> _focusAndPress(
  WidgetTester tester,
  String text,
  LogicalKeyboardKey key,
) async {
  Focus.of(tester.element(find.text(text))).requestFocus();
  await tester.pump();
  await tester.sendKeyEvent(key);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the spruce card counts the days in a row the meadow grew', (
    WidgetTester tester,
  ) async {
    await _pumpLandmarks(
      tester,
      _thisYear(_twentyInARow(2026)),
      compact: false,
    );
    final Text text = tester.widget<Text>(
      find.textContaining('The tallest tree at the forest edge'),
    );
    expect(
      text.data,
      'The tallest tree at the forest edge marks the 20 days in a row your '
      'meadow grew. The bees keep their hive in it.',
    );
    expect(text.data, isNot(contains('writing')));
  });

  testWidgets('this year so far lists only the landmarks the data supports', (
    WidgetTester tester,
  ) async {
    await _pumpLandmarks(
      tester,
      _thisYear(_twentyInARow(2026)),
      compact: false,
    );
    expect(find.text('longest run'), findsOneWidget);
    expect(find.text('The old spruce'), findsOneWidget);
    expect(find.text(_spruceText), findsOneWidget);
    expect(find.text('Jan 1 – Jan 20'), findsOneWidget);
    expect(find.text('heaviest stretch'), findsOneWidget);
    expect(find.text('Mist in the hollow'), findsOneWidget);
    expect(
      find.text(
        'Fog settles over the flowers from these days. After dark the '
        'fireflies gather there and flash together.',
      ),
      findsOneWidget,
    );
    expect(find.text('Jan 11 – Jan 26'), findsOneWidget);
    expect(find.text('brightest stretch'), findsOneWidget);
    expect(find.text('Butterflies'), findsOneWidget);
    expect(
      find.text(
        'They drift toward the flowers from these days and linger longest '
        'there.',
      ),
      findsOneWidget,
    );
    expect(find.text('Jan 1 – Jan 16'), findsOneWidget);
    expect(find.text('the weather'), findsOneWidget);
    expect(find.text('Heavy skies'), findsOneWidget);
    expect(
      find.text(
        '50% of your days so far were heavy ones. That sets the cloud cover '
        'and how thick the morning fog lies.',
      ),
      findsOneWidget,
    );
    final List<String> order = <String>[
      'The old spruce',
      'Mist in the hollow',
      'Butterflies',
      'Heavy skies',
    ];
    final double row = tester.getTopLeft(find.text(order.first)).dy;
    for (int index = 1; index < order.length; index++) {
      expect(tester.getTopLeft(find.text(order[index])).dy, row);
      expect(
        tester.getTopLeft(find.text(order[index])).dx,
        greaterThan(tester.getTopLeft(find.text(order[index - 1])).dx),
      );
    }
    final TextStyle kicker = tester
        .widget<Text>(find.text('longest run'))
        .style!;
    expect(kicker.color, FieldNotesColors.light.sage);
    final TextStyle pill = tester
        .widget<Text>(find.text('Jan 1 – Jan 20'))
        .style!;
    expect(pill.color, FieldNotesColors.light.accentInk);

    await _pumpLandmarks(
      tester,
      _thisYear(<Day>[
        ..._days(2026, _through(1, 6), Mood.happy),
        ..._days(2026, <int>[8], Mood.sad),
      ]),
      compact: false,
    );
    expect(find.text('The old spruce'), findsNothing);
    expect(find.text('Mist in the hollow'), findsOneWidget);
    expect(find.text('Butterflies'), findsOneWidget);
    expect(find.text('Clear skies'), findsOneWidget);
    expect(
      find.text(
        '14% of your days so far were heavy ones. That sets the cloud cover '
        'and how thick the morning fog lies.',
      ),
      findsOneWidget,
    );

    await _pumpLandmarks(
      tester,
      _thisYear(_days(2026, <int>[1, 3, 5, 7, 9], Mood.calm)),
      compact: true,
    );
    expect(find.text('The old spruce'), findsNothing);
    expect(find.text('Mist in the hollow'), findsNothing);
    expect(find.text('Butterflies'), findsNothing);
    expect(find.text('the weather'), findsOneWidget);
    expect(find.text('Clear skies'), findsOneWidget);
    expect(find.textContaining('–'), findsNothing);

    await _pumpLandmarks(tester, _thisYear(const <Day>[]), compact: false);
    expect(find.text('The old spruce'), findsNothing);
    expect(find.text('Mist in the hollow'), findsNothing);
    expect(find.text('Butterflies'), findsNothing);
    expect(find.text('Clear skies'), findsOneWidget);
    expect(
      find.text(
        '0% of your days so far were heavy ones. That sets the cloud cover '
        'and how thick the morning fog lies.',
      ),
      findsOneWidget,
    );

    await _pumpLandmarks(tester, _thisYear(_twentyInARow(2026)), compact: true);
    final double left = tester.getTopLeft(find.text('The old spruce')).dx;
    double previous = tester.getTopLeft(find.text('The old spruce')).dy;
    for (final String title in order.skip(1)) {
      expect(tester.getTopLeft(find.text(title)).dx, left);
      expect(tester.getTopLeft(find.text(title)).dy, greaterThan(previous));
      previous = tester.getTopLeft(find.text(title)).dy;
    }
  });

  testWidgets(
    'a landmark card highlights its days and past years call the tab Landmarks',
    (WidgetTester tester) async {
      final MeadowYear past = _lastYear(_twentyInARow(2025));
      final List<MeadowRange?> calls = <MeadowRange?>[];
      await _pumpTabs(tester, past, compact: false, calls: calls);

      expect(find.text('The year, day by day'), findsOneWidget);
      expect(find.text('Landmarks'), findsOneWidget);
      expect(find.text('This year so far'), findsNothing);
      expect(find.text('Hover a month to find its flowers'), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Landmarks')),
        isSemantics(
          label: 'Landmarks',
          isButton: true,
          isSelected: false,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.text('Landmarks')).rect.height,
        greaterThanOrEqualTo(48),
      );

      await _focusAndPress(tester, 'Jan', LogicalKeyboardKey.enter);
      expect(calls, <MeadowRange?>[
        const MeadowRange(first: 0, last: 30, key: 'm0'),
      ]);

      await tester.tap(find.text('Landmarks'));
      await tester.pumpAndSettle();
      expect(calls.last, isNull);
      expect(find.text('Jan'), findsNothing);
      expect(
        find.text('Hover one to find those days in the meadow'),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.text('Landmarks')),
        isSemantics(label: 'Landmarks', isSelected: true),
      );
      expect(
        find.text(
          '50% of your days were heavy ones. That sets the cloud cover and '
          'how thick the morning fog lies.',
        ),
        findsOneWidget,
      );
      expect(
        tester.getSemantics(find.text('The old spruce')),
        isSemantics(isButton: true, hasTapAction: true, isFocusable: true),
      );
      expect(
        tester.getSemantics(find.text('Heavy skies')),
        isSemantics(isButton: false, hasTapAction: false),
      );
      expect(_border(tester, 'The old spruce'), FieldNotesColors.light.line);

      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: Offset.zero);
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(find.text('The old spruce')));
      await tester.pumpAndSettle();
      expect(calls.last, const MeadowRange(first: 0, last: 19, key: 'l0'));
      expect(_border(tester, 'The old spruce'), _coral);
      expect(
        _border(tester, 'Mist in the hollow'),
        FieldNotesColors.light.line,
      );

      await mouse.moveTo(tester.getCenter(find.text('Heavy skies')));
      await tester.pumpAndSettle();
      expect(calls.last, isNull);
      expect(_border(tester, 'The old spruce'), FieldNotesColors.light.line);
      expect(_border(tester, 'Heavy skies'), FieldNotesColors.light.line);

      calls.clear();
      await _focusAndPress(tester, 'Butterflies', LogicalKeyboardKey.enter);
      expect(calls, <MeadowRange?>[
        const MeadowRange(first: 0, last: 15, key: 'l2'),
      ]);
      expect(_border(tester, 'Butterflies'), _coral);
      await _focusAndPress(tester, 'Butterflies', LogicalKeyboardKey.space);
      expect(calls.last, isNull);

      await tester.tap(find.text('The year, day by day'));
      await tester.pumpAndSettle();
      expect(find.text('Jan'), findsOneWidget);
      await mouse.removePointer();

      calls.clear();
      await _pumpTabs(tester, past, compact: true, calls: calls);
      expect(find.text('Day by day'), findsOneWidget);
      expect(find.text('Landmarks'), findsOneWidget);
      expect(find.text('Tap a month to find its flowers'), findsOneWidget);
      await tester.tap(find.text('Jan'));
      await tester.pumpAndSettle();
      expect(calls, <MeadowRange?>[
        const MeadowRange(first: 0, last: 30, key: 'm0'),
      ]);
      await tester.tapAt(
        tester.getCenter(find.text('Landmarks')) - const Offset(0, 20),
      );
      await tester.pumpAndSettle();
      expect(calls, <MeadowRange?>[
        const MeadowRange(first: 0, last: 30, key: 'm0'),
        null,
      ]);
      expect(find.text('Tap one to find those days'), findsOneWidget);
      await tester.tap(find.text('Mist in the hollow'));
      await tester.pumpAndSettle();
      expect(calls.last, const MeadowRange(first: 10, last: 25, key: 'l1'));
      expect(_border(tester, 'Mist in the hollow'), _coral);
      await tester.tap(find.text('Mist in the hollow'));
      await tester.pumpAndSettle();
      expect(calls.last, isNull);
      expect(
        _border(tester, 'Mist in the hollow'),
        FieldNotesColors.light.line,
      );

      await _pumpTabs(
        tester,
        _thisYear(_twentyInARow(2026)),
        compact: false,
        calls: <MeadowRange?>[],
      );
      expect(find.text('This year so far'), findsOneWidget);
      expect(find.text('Landmarks'), findsNothing);
      await tester.tap(find.text('This year so far'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          '50% of your days so far were heavy ones. That sets the cloud cover '
          'and how thick the morning fog lies.',
        ),
        findsOneWidget,
      );
    },
  );
}
