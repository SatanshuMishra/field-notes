import 'dart:ui' show Tristate;

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/settings_fields/settings_status_pill.dart';
import 'package:field_notes/design/widgets/anchored_dropdown.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/entry_cards/compact/compact_log_card.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteReaderView;
import 'package:field_notes/features/note_engine/render/render_note_view.dart'
    show NoteViewBody, RenderNoteView;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../features/entry_cards/support/entry_cards_harness.dart';

const String _twoTodos = '- [ ] water the peonies\n- [ ] buy seed packets';
const String _firstLabel = 'water the peonies';
const String _secondLabel = 'buy seed packets';
const int _firstBox = 2;
const int _secondBox = 26;
const MdRange _firstBoxRange = MdRange(2, 6);
const Size _paintedBox = Size(10, 21.6);
const double _pixelSlack = 0.1;
const double _cornerInset = 1;
const int _maxTabs = 12;

const Map<TargetPlatform, double> _platformTargets = <TargetPlatform, double>{
  TargetPlatform.android: 48,
  TargetPlatform.macOS: 28,
  TargetPlatform.windows: 40,
};

const String _dropdownLabel = 'Bluetooth headset microphone 2';
const String _pillLabel = 'Last synced on Tuesday morning';

final class _Card {
  final List<int> toggles = <int>[];
  int opens = 0;
}

Future<_Card> _pumpCard(
  WidgetTester tester,
  TargetPlatform platform, {
  bool ticks = false,
}) async {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final _Card card = _Card();
  final int at = DateTime(2025, 7, 2, 8, 30).millisecondsSinceEpoch;
  String source = _twoTodos;
  await tester.pumpWidget(
    MaterialApp(
      theme: fieldNotesTheme(platform: platform, brightness: Brightness.light),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) => ListView(
            padding: const EdgeInsets.all(24),
            children: <Widget>[
              CompactLogCard(
                entry: Entry(
                  id: 'e1',
                  dayId: 'd1',
                  type: EntryType.text,
                  textContent: source,
                  createdAt: at,
                  updatedAt: at,
                ),
                resolver: FakeMediaResolver(),
                density: CompactLogDensity.feed,
                onOpen: () => card.opens++,
                onToggleTask: (int box) {
                  card.toggles.add(box);
                  if (ticks) {
                    setState(() {
                      source = source.replaceRange(box + 1, box + 2, 'x');
                    });
                  }
                },
                onEdit: () {},
                onDelete: () {},
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return card;
}

RenderNoteView _noteView(WidgetTester tester) =>
    tester.renderObject<RenderNoteView>(
      find.descendant(
        of: find.byType(NoteReaderView),
        matching: find.byType(NoteViewBody),
      ),
    );

SemanticsNode _todo(WidgetTester tester, String label) =>
    find.semantics.byLabel(label).evaluate().single;

Offset _globalPoint(SemanticsNode node, Offset local) {
  Offset point = local;
  for (
    SemanticsNode? current = node;
    current != null;
    current = current.parent
  ) {
    final Matrix4? transform = current.transform;
    if (transform != null) {
      point = MatrixUtils.transformPoint(transform, point);
    }
  }
  return point;
}

List<Offset> _cornersOf(SemanticsNode node) {
  final Rect inner = node.rect.deflate(_cornerInset);
  return <Offset>[
    for (final Offset corner in <Offset>[
      inner.topLeft,
      inner.topRight,
      inner.bottomLeft,
      inner.bottomRight,
      inner.center,
    ])
      _globalPoint(node, corner),
  ];
}

void main() {
  testWidgets("a to-do checkbox meets each platform's target", (
    WidgetTester tester,
  ) async {
    final TargetPlatform platform = debugDefaultTargetPlatformOverride!;
    final double target = _platformTargets[platform]!;
    final SemanticsHandle semantics = tester.ensureSemantics();
    final _Card card = await _pumpCard(tester, platform);

    final SemanticsNode firstTodo = _todo(tester, _firstLabel);
    final SemanticsNode secondTodo = _todo(tester, _secondLabel);
    final Rect first = firstTodo.rect;
    final Rect second = secondTodo.rect;
    expect(identical(firstTodo.parent, secondTodo.parent), isTrue);
    for (final Rect area in <Rect>[first, second]) {
      expect(area.width, greaterThanOrEqualTo(target - _pixelSlack));
      expect(area.height, greaterThanOrEqualTo(target - _pixelSlack));
    }
    expect(first.overlaps(second), isFalse);
    expect(
      _noteView(tester).noteLayout.rangeBounds(_firstBoxRange).size.width,
      closeTo(_paintedBox.width, _pixelSlack),
    );
    expect(
      _noteView(tester).noteLayout.rangeBounds(_firstBoxRange).size.height,
      closeTo(_paintedBox.height, _pixelSlack),
    );

    final PointerDeviceKind kind = platform == TargetPlatform.android
        ? PointerDeviceKind.touch
        : PointerDeviceKind.mouse;
    for (final (SemanticsNode todo, int box) in <(SemanticsNode, int)>[
      (firstTodo, _firstBox),
      (secondTodo, _secondBox),
    ]) {
      for (final Offset point in _cornersOf(todo)) {
        card.toggles.clear();
        await tester.tapAt(point, kind: kind);
        await tester.pumpAndSettle();
        expect(card.toggles, <int>[box], reason: 'tap at $point');
      }
    }
    expect(card.opens, 0);
    semantics.dispose();
  }, variant: TargetPlatformVariant(_platformTargets.keys.toSet()));

  testWidgets(
    'a to-do toggles from the keyboard',
    (WidgetTester tester) async {
      final TargetPlatform platform = debugDefaultTargetPlatformOverride!;
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _pumpCard(tester, platform, ticks: true);

      for (
        int tabs = 0;
        tabs < _maxTabs &&
            _todo(tester, _firstLabel).flagsCollection.isFocused !=
                Tristate.isTrue;
        tabs++
      ) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
      }
      expect(_todo(tester, _firstLabel), isSemantics(isFocused: true));

      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(_todo(tester, _firstLabel), isSemantics(isChecked: true));
      expect(_todo(tester, _secondLabel), isSemantics(isChecked: false));
      semantics.dispose();
    },
    variant: const TargetPlatformVariant(<TargetPlatform>{
      TargetPlatform.macOS,
      TargetPlatform.windows,
    }),
  );

  testWidgets('shared dropdown and status pill text wraps at 2x', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: fieldNotesTheme(
          platform: TargetPlatform.android,
          brightness: Brightness.light,
        ),
        builder: (BuildContext context, Widget? child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SizedBox(
            width: 280,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: SettingsStatusPill(label: _pillLabel),
                ),
                AnchoredDropdown<String>(
                  choices: const <AnchoredDropdownChoice<String>>[
                    AnchoredDropdownChoice<String>(
                      value: 'headset',
                      label: _dropdownLabel,
                    ),
                  ],
                  current: 'headset',
                  onSelected: (String _) {},
                  builder:
                      (BuildContext context, bool open, VoidCallback toggle) =>
                          TextButton(
                            onPressed: toggle,
                            child: const Text('Microphone'),
                          ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Microphone'));
    await tester.pumpAndSettle();

    for (final String label in <String>[_pillLabel, _dropdownLabel]) {
      final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
        find.text(label),
      );
      expect(paragraph.didExceedMaxLines, isFalse, reason: label);
      expect(paragraph.size.width, lessThanOrEqualTo(280), reason: label);
    }
  });
}
