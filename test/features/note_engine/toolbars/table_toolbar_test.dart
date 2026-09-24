import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/commands/table_commands.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/toolbars/table_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const String _table = '| a | b |\n| --- | --- |\n| c | d |\n| e | f |';
const String _framed = 'Intro\n\n$_table\n\nOutro';

final Map<Key, TableEdit> _edits = <Key, TableEdit>{
  tableToolbarRowAboveKey: TableEdit.rowAbove,
  tableToolbarRowBelowKey: TableEdit.rowBelow,
  tableToolbarColumnLeftKey: TableEdit.columnLeft,
  tableToolbarColumnRightKey: TableEdit.columnRight,
  tableToolbarDeleteRowKey: TableEdit.deleteRow,
  tableToolbarDeleteColumnKey: TableEdit.deleteColumn,
  tableToolbarAlignLeftKey: TableEdit.alignLeft,
  tableToolbarAlignCentreKey: TableEdit.alignCentre,
  tableToolbarAlignRightKey: TableEdit.alignRight,
  tableToolbarDeleteTableKey: TableEdit.deleteTable,
};

final Map<Key, String> _labels = <Key, String>{
  tableToolbarRowAboveKey: 'Row above',
  tableToolbarRowBelowKey: 'Row below',
  tableToolbarColumnLeftKey: 'Column left',
  tableToolbarColumnRightKey: 'Column right',
  tableToolbarDeleteRowKey: 'Delete row',
  tableToolbarDeleteColumnKey: 'Delete column',
  tableToolbarAlignLeftKey: 'Align left',
  tableToolbarAlignCentreKey: 'Align centre',
  tableToolbarAlignRightKey: 'Align right',
  tableToolbarDeleteTableKey: 'Delete table',
};

const List<Duration> _holds = <Duration>[
  Duration(milliseconds: 30),
  Duration(milliseconds: 110),
  Duration(milliseconds: 300),
];

EditorState _state(String source, int caret) => EditorState.create(
  source,
  parse: (String s) => parseNoteTree(s, tables: true),
  selection: NoteSelection.collapsed(caret),
);

final class _Harness {
  _Harness(this.state);

  EditorState state;
  final List<Transaction> dispatched = <Transaction>[];
  int dismissals = 0;
}

void _pinSurface(WidgetTester tester, {double width = 1200}) {
  tester.view.physicalSize = Size(width, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<_Harness> _pump(
  WidgetTester tester,
  String source,
  int caret, {
  bool enabled = true,
  bool dismissible = false,
}) async {
  final _Harness harness = _Harness(_state(source, caret));
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          key: UniqueKey(),
          builder: (BuildContext context, StateSetter setState) => TableToolbar(
            state: harness.state,
            enabled: enabled,
            onDismiss: dismissible ? () => harness.dismissals++ : null,
            onTransaction: (Transaction transaction) {
              harness.dispatched.add(transaction);
              setState(() {
                harness.state = harness.state.apply(transaction);
              });
            },
          ),
        ),
      ),
    ),
  );
  return harness;
}

Future<void> _hold(WidgetTester tester, Key key, Duration hold) async {
  final TestGesture gesture = await tester.startGesture(
    tester.getCenter(find.byKey(key)),
  );
  await tester.pump(hold);
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('the table toolbar shows while the caret is in a table', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final SemanticsHandle handle = tester.ensureSemantics();

    await _pump(tester, _framed, 2);
    expect(find.byKey(tableToolbarKey), findsNothing);

    await _pump(tester, _framed, 34);
    expect(find.byKey(tableToolbarKey), findsOneWidget);
    for (final MapEntry<Key, String> entry in _labels.entries) {
      expect(find.byKey(entry.key), findsOneWidget);
      expect(tester.getSemantics(find.byKey(entry.key)).label, entry.value);
    }

    await _pump(tester, _framed, 10);
    expect(find.byKey(tableToolbarKey), findsOneWidget);

    await _pump(tester, _framed, 34, enabled: false);
    expect(find.byKey(tableToolbarKey), findsNothing);

    await _pump(tester, '- | a |\n  | - |', 4);
    expect(find.byKey(tableToolbarKey), findsNothing);
    handle.dispose();
  });

  testWidgets('each table control works for held presses', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    for (final MapEntry<Key, TableEdit> entry in _edits.entries) {
      for (final Duration hold in _holds) {
        final _Harness harness = await _pump(tester, _framed, 34);
        final EditorState start = harness.state;
        await _hold(tester, entry.key, hold);
        final String reason = '${entry.value} held $hold';
        expect(harness.dispatched, hasLength(1), reason: reason);
        final Transaction transaction = harness.dispatched.single;
        expect(transaction.event, TransactionEvent.table, reason: reason);
        expect(
          transaction.changes,
          editTable(start, entry.value)!.changes,
          reason: reason,
        );
        if (entry.value == TableEdit.deleteTable) {
          final MdTree tree = harness.state.tree;
          expect(
            tree.blocks.where((MdBlock b) => b.kind == MdBlockKind.table),
            isEmpty,
            reason: reason,
          );
          final List<String> paragraphs = <String>[
            for (final MdBlock block in tree.blocks)
              if (block.kind == MdBlockKind.paragraph)
                harness.state.source.substring(
                  block.contentRange.start,
                  block.contentRange.end,
                ),
          ];
          expect(paragraphs, <String>['Intro', 'Outro'], reason: reason);
        }
      }
    }
  });

  testWidgets('column right adds a cell to every row and the delimiter row', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final _Harness harness = await _pump(tester, _table, 27);
    await _hold(
      tester,
      tableToolbarColumnRightKey,
      const Duration(milliseconds: 110),
    );
    expect(harness.dispatched, hasLength(1));
    expect(
      harness.state.source,
      '| a |  | b |\n| --- | --- | --- |\n| c |  | d |\n| e |  | f |',
    );
  });

  testWidgets('align centre marks and disables its control', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final SemanticsHandle handle = tester.ensureSemantics();
    final _Harness harness = await _pump(tester, _table, 27);
    await _hold(
      tester,
      tableToolbarAlignCentreKey,
      const Duration(milliseconds: 110),
    );
    expect(harness.dispatched, hasLength(1));
    expect(harness.state.source.split('\n')[1], '| :---: | --- |');
    expect(
      tester.getSemantics(find.byKey(tableToolbarAlignCentreKey)),
      isSemantics(
        hasSelectedState: true,
        isSelected: true,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    for (final Key key in <Key>[
      tableToolbarAlignLeftKey,
      tableToolbarAlignRightKey,
    ]) {
      expect(
        tester.getSemantics(find.byKey(key)),
        isSemantics(hasSelectedState: true, isSelected: false),
      );
    }
    expect(
      tester.getSemantics(find.byKey(tableToolbarRowAboveKey)),
      isSemantics(hasSelectedState: false),
    );
    await _hold(
      tester,
      tableToolbarAlignCentreKey,
      const Duration(milliseconds: 110),
    );
    expect(harness.dispatched, hasLength(1));
    handle.dispose();
  });

  testWidgets('header row controls that would do nothing are disabled', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final SemanticsHandle handle = tester.ensureSemantics();
    final _Harness harness = await _pump(tester, _table, 3);
    for (final Key key in <Key>[
      tableToolbarRowAboveKey,
      tableToolbarDeleteRowKey,
    ]) {
      expect(
        tester.getSemantics(find.byKey(key)),
        isSemantics(hasEnabledState: true, isEnabled: false),
      );
      expect(tester.widget<GestureDetector>(find.byKey(key)).onTap, isNull);
      await _hold(tester, key, const Duration(milliseconds: 110));
    }
    expect(harness.dispatched, isEmpty);
    expect(harness.state.source, _table);
    handle.dispose();
  });

  testWidgets('escape inside the bar calls onDismiss', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final _Harness harness = await _pump(
      tester,
      _framed,
      34,
      dismissible: true,
    );
    Focus.of(
      tester.element(find.byKey(tableToolbarRowAboveKey)),
    ).requestFocus();
    await tester.pump();
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.escape), isTrue);
    expect(harness.dismissals, 1);
    expect(harness.dispatched, isEmpty);

    await _pump(tester, _framed, 34);
    Focus.of(
      tester.element(find.byKey(tableToolbarRowAboveKey)),
    ).requestFocus();
    await tester.pump();
    expect(await tester.sendKeyEvent(LogicalKeyboardKey.escape), isFalse);
  });

  testWidgets(
    'desktop controls measure at least 28',
    (WidgetTester tester) async {
      _pinSurface(tester);
      await _pump(tester, _framed, 34);
      for (final Key key in _labels.keys) {
        final Size size = tester.getSize(find.byKey(key));
        expect(size.width, greaterThanOrEqualTo(28));
        expect(size.height, greaterThanOrEqualTo(28));
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'android controls measure at least 48',
    (WidgetTester tester) async {
      _pinSurface(tester);
      await _pump(tester, _framed, 34);
      for (final Key key in _labels.keys) {
        final Size size = tester.getSize(find.byKey(key));
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'a narrow bar scrolls its controls',
    (WidgetTester tester) async {
      _pinSurface(tester, width: 200);
      await _pump(tester, _framed, 34);
      expect(tester.getSize(find.byKey(tableToolbarKey)).width, 200);
      expect(tester.getSize(find.byKey(tableToolbarDeleteTableKey)).width, 48);
      final Finder scroll = find.descendant(
        of: find.byKey(tableToolbarKey),
        matching: find.byType(SingleChildScrollView),
      );
      expect(scroll, findsOneWidget);
      expect(
        tester.widget<SingleChildScrollView>(scroll).scrollDirection,
        Axis.horizontal,
      );
      final ScrollableState scrollable = tester.state<ScrollableState>(
        find.descendant(of: scroll, matching: find.byType(Scrollable)),
      );
      expect(scrollable.position.maxScrollExtent, greaterThan(0));
      expect(
        find.descendant(
          of: find.byKey(tableToolbarKey),
          matching: find.byType(RawScrollbar),
        ),
        findsNothing,
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets('the bar joins the editable text tap region group', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    await _pump(tester, _framed, 34);
    final TapRegion region = tester.widget<TapRegion>(
      find
          .ancestor(
            of: find.byKey(tableToolbarKey),
            matching: find.byType(TapRegion),
          )
          .first,
    );
    expect(region.groupId, EditableText);
  });

  testWidgets('a shown bar schedules no frames', (WidgetTester tester) async {
    _pinSurface(tester);
    await _pump(tester, _framed, 34);
    await tester.pumpAndSettle();
    expect(find.byKey(tableToolbarKey), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  test('tableToolbarRect follows the photo toolbar placement rule', () {
    const Size bar = Size(300, 38);
    const Rect view = Rect.fromLTWH(0, 0, 600, 400);
    Rect? place(Rect table) =>
        tableToolbarRect(table: table, bar: bar, view: view, surface: view);
    expect(
      place(const Rect.fromLTWH(100, 200, 300, 100)),
      const Rect.fromLTWH(100, 152, 300, 38),
    );
    expect(
      place(const Rect.fromLTWH(100, 20, 300, 100)),
      const Rect.fromLTWH(100, 130, 300, 38),
    );
    expect(
      place(const Rect.fromLTWH(100, 20, 300, 360)),
      const Rect.fromLTWH(100, 30, 300, 38),
    );
    expect(place(const Rect.fromLTWH(100, 500, 300, 100)), isNull);
    expect(
      place(const Rect.fromLTWH(-100, 200, 200, 100)),
      const Rect.fromLTWH(0, 152, 300, 38),
    );
    expect(
      place(const Rect.fromLTWH(450, 200, 150, 100)),
      const Rect.fromLTWH(300, 152, 300, 38),
    );
  });

  test('tableAtCaret finds only the top-level table at the caret', () {
    expect(tableAtCaret(_state(_framed, 2)), isNull);
    expect(tableAtCaret(_state(_framed, 55)), isNull);
    expect(tableAtCaret(_state('- | a |\n  | - |', 4)), isNull);
    expect(tableAtCaret(_state(_framed, 34)), const MdRange(7, 50));
  });
}
