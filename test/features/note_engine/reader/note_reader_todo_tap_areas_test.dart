import 'dart:ui' show CheckedState;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/reader/note_reader_view.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';
import 'package:field_notes/features/notes/render/note_photo_block.dart'
    show NoteMediaScope;

import '../../notes/support/notes_harness.dart';

const List<String> _todos = <String>[
  'call the ferry office',
  'pack the tide tables',
  'buy stamps',
];

final String _todoList = <String>[
  '- [ ] ${_todos[0]}',
  '- [x] ${_todos[1]}',
  '- [ ] ${_todos[2]}',
].join('\n');

final String _mixedList = <String>[
  '- [ ] ${_todos[0]}',
  '- ${_todos[1]}',
  '- [ ] ${_todos[2]}',
].join('\n');

final String _richNote = <String>[
  'Intro',
  '![Low tide](photo/a1b2c3d4e5f6 "left medium")',
  '- [ ] ${_todos[0]}',
  '| a | b |\n| --- | --- |\n| 1 | 2 |',
  '- [ ] ${_todos[2]}',
].join('\n\n');

Future<RenderNoteView> _pumpReader(
  WidgetTester tester,
  String source,
  ValueChanged<int> onToggleTask,
) async {
  tester.view.physicalSize = const Size(411, 869);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Material(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: NoteMediaScope(
            resolver: FakeNoteMediaResolver()..memoizeAll(),
            child: NoteReaderView(
              source: source,
              selectable: false,
              onToggleTask: onToggleTask,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return tester.renderObject<RenderNoteView>(
    find.descendant(
      of: find.byType(NoteReaderView),
      matching: find.byType(NoteViewBody),
    ),
  );
}

List<(String, MdRange)> _boxes(String source) {
  final List<(String, MdRange)> boxes = <(String, MdRange)>[];
  int at = 0;
  for (final String line in source.split('\n')) {
    if (line.startsWith('- [')) {
      boxes.add((line.substring(6), MdRange(at + 2, at + 5)));
    }
    at += line.length + 1;
  }
  return boxes;
}

Rect _line(RenderNoteView render, MdRange box) {
  final Rect content = render.noteLayout.rangeBounds(box);
  return render.contentToGlobal(content.topLeft) & content.size;
}

List<SemanticsNode> _selfAndAncestors(SemanticsNode node) => <SemanticsNode>[
  for (SemanticsNode? at = node; at != null; at = at.parent) at,
];

Rect _globalRect(SemanticsNode node) => _selfAndAncestors(node).fold(
  node.rect,
  (Rect rect, SemanticsNode at) => switch (at.transform) {
    final Matrix4 transform => MatrixUtils.transformRect(transform, rect),
    null => rect,
  },
);

Rect _reachable(SemanticsNode node) => _selfAndAncestors(node).skip(1).fold(
  _globalRect(node),
  (Rect rect, SemanticsNode ancestor) {
    final Rect bounds = _globalRect(ancestor);
    return rect.overlaps(bounds) ? rect.intersect(bounds) : Rect.zero;
  },
);

bool _focusable(SemanticsData data) =>
    !data.flagsCollection.scopesRoute &&
    (data.label.isNotEmpty ||
        data.value.isNotEmpty ||
        data.hint.isNotEmpty ||
        data.actions != 0 ||
        data.flagsCollection.isChecked != CheckedState.none);

SemanticsNode? _screenReaderTouch(SemanticsNode node, Offset point) {
  final Rect rect = _globalRect(node);
  if (point.dx < rect.left ||
      point.dx >= rect.right ||
      point.dy < rect.top ||
      point.dy >= rect.bottom) {
    return null;
  }
  for (final SemanticsNode child
      in node
          .debugListChildrenInOrder(DebugSemanticsDumpOrder.inverseHitTest)
          .reversed) {
    if (child.getSemanticsData().flagsCollection.isHidden) {
      continue;
    }
    if (_screenReaderTouch(child, point) case final SemanticsNode hit) {
      return hit;
    }
  }
  return _focusable(node.getSemanticsData()) ? node : null;
}

SemanticsNode _root(WidgetTester tester) =>
    tester.binding.renderViews.single.owner!.semanticsOwner!.rootSemanticsNode!;

List<SemanticsNode> _todoNodes(WidgetTester tester, String source) =>
    <SemanticsNode>[
      for (final (String label, MdRange _) in _boxes(source))
        find.semantics.byLabel(label).evaluate().single,
    ];

Future<List<String>> _misheardRows(WidgetTester tester, String source) async {
  final RenderNoteView render = await _pumpReader(tester, source, (int _) {});
  final List<String> wrong = <String>[];
  for (final (String label, MdRange box) in _boxes(source)) {
    final Rect line = _line(render, box);
    for (final double y in _rowsOf(line)) {
      final String? heard = _screenReaderTouch(
        _root(tester),
        Offset(line.center.dx, y),
      )?.getSemanticsData().label;
      if (heard != label) {
        wrong.add('y ${y.toStringAsFixed(1)} on "$label" focused "$heard"');
      }
    }
  }
  return wrong;
}

Iterable<double> _rowsOf(Rect line) sync* {
  for (double y = line.top + 0.5; y < line.bottom; y += 1) {
    yield y;
  }
}

void main() {
  testWidgets(
    'a screen reader touch anywhere down a to-do box focuses that to-do',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      expect(await _misheardRows(tester, _todoList), isEmpty);
      handle.dispose();
    },
  );

  testWidgets('a screen reader touch on a to-do box in a list with plain items '
      'focuses that to-do', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();

    expect(await _misheardRows(tester, _mixedList), isEmpty);
    handle.dispose();
  });

  testWidgets(
    'a screen reader tries a note\'s to-dos before its photos, tables and '
    'text',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      await _pumpReader(tester, _richNote, (int _) {});
      final List<String> tried = <String>[
        for (final SemanticsNode node
            in find.semantics
                .byLabel(_todos[0])
                .evaluate()
                .single
                .parent!
                .debugListChildrenInOrder(
                  DebugSemanticsDumpOrder.inverseHitTest,
                )
                .reversed)
          node.getSemanticsData().label,
      ];

      expect(tried.take(2).toSet(), <String>{_todos[0], _todos[2]});
      expect(
        tried.skip(2),
        containsAll(<String>[
          'Intro',
          'Photo, Low tide',
          'Table, 2 rows, 2 columns',
        ]),
      );
      handle.dispose();
    },
  );

  testWidgets('the reachable areas of neighbouring to-dos do not overlap', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pumpReader(tester, _todoList, (int _) {});
    final List<SemanticsNode> nodes = _todoNodes(tester, _todoList);
    final List<String> overlaps = <String>[
      for (int i = 0; i + 1 < nodes.length; i++)
        if (_reachable(nodes[i]).intersect(_reachable(nodes[i + 1]))
            case final Rect shared
            when shared.width > precisionErrorTolerance &&
                shared.height > precisionErrorTolerance)
          '"${_todos[i]}" and "${_todos[i + 1]}" share '
              '${shared.height.toStringAsFixed(1)} dp',
    ];

    expect(overlaps, isEmpty);
    handle.dispose();
  });

  testWidgets('a finger tap anywhere down a to-do box ticks that to-do', (
    WidgetTester tester,
  ) async {
    final List<int> toggled = <int>[];
    final RenderNoteView render = await _pumpReader(
      tester,
      _todoList,
      toggled.add,
    );
    final List<MdRange> boxes = <MdRange>[
      for (final (String _, MdRange box) in _boxes(_todoList)) box,
    ];
    for (final MdRange box in boxes) {
      final Rect line = _line(render, box);
      for (final double y in <double>[
        line.top + 1,
        line.center.dy,
        line.bottom - 1,
      ]) {
        await tester.tapAt(Offset(line.center.dx, y));
        await tester.pump(const Duration(milliseconds: 400));
      }
    }

    expect(toggled, <int>[
      for (final MdRange box in boxes) ...<int>[
        box.start,
        box.start,
        box.start,
      ],
    ]);
  });
}
