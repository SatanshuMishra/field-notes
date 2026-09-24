import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/entry_cards/cards/note_body.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/document/change_set.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/history.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/layout/block_layout.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/note_layout_engine.dart';
import 'package:field_notes/features/note_engine/layout/note_typography.dart';
import 'package:field_notes/features/note_engine/layout/photo_planner.dart';
import 'package:field_notes/features/note_engine/photos/photo_commands.dart';
import 'package:field_notes/features/note_engine/photos/photo_import_flow.dart';
import 'package:field_notes/features/note_engine/photos/photo_relocation.dart';
import 'package:field_notes/features/note_engine/projection/active_line.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:field_notes/features/note_engine/reader/note_reader_view.dart';
import 'package:field_notes/features/note_engine/render/photo_figure.dart';
import 'package:field_notes/features/notes/render/note_photo_block.dart'
    show NoteMediaScope;

import '../../../domain/notes/note_fuzz_corpus.dart';
import '../../notes/support/notes_harness.dart'
    show
        FakeNoteMediaResolver,
        availablePhoto,
        notesHarness,
        photoIdA,
        photoIdB,
        photoIdC,
        photoLine,
        prefixOf;

const String _prose =
    'The tide came in slowly over the flats this morning, '
    'and the herons stood in a line along the channel as if waiting for a '
    'signal. We walked out as far as the **old pilings**, where the mud '
    'gives way to shell, and sat on the driftwood log that has been there '
    'since the storm in March. *Nothing moved for a long time.* Then the '
    'light changed, the water turned from grey to a dull green, and the '
    'birds lifted all at once and went north over the dunes. On the way back '
    'we found a whelk shell, perfect and empty, half buried in the sand near '
    'the boardwalk, and a single blue mussel still closed tight. The wind '
    'had dropped by then and the whole marsh smelled of salt and cut grass.';

const String _everyKind =
    '# Title\n\nbody **bold**\n\n- one\n- two\n\n'
    '> quote\n\n```\ncode\n```\n\n---\n\n![alt](photo/0123456789ab)';

const String _p = '![p](photo/abc123abc123)';

const double _floatBottom = 186.67;
const double _besideLimit = 186.17;
const double _lineHeight = 25.6;
const double _aspect = 1.5;
const double _nudge = 0.01;

final String _a = photoLine(photoIdA);
final String _b = photoLine(photoIdB);
final String _c = photoLine(photoIdC, caption: 'porch light');

final String _strongRun =
    'plain **${List<String>.filled(120, 'bold').join(' ')}** after';

final String _calm = List<String>.filled(40, 'calm').join(' ');

final String _nestedRun =
    '*$_calm **${List<String>.filled(40, 'loud').join(' ')}** $_calm*';

final class _CurvedScaler extends TextScaler {
  const _CurvedScaler();

  @override
  double scale(double fontSize) => fontSize + 4;

  @override
  double get textScaleFactor => 1.25;
}

final class _GridWidth {
  const _GridWidth(this.label, this.em, {this.nudge = 0});

  final String label;
  final double em;
  final double nudge;

  double pixelsAt(double em) => this.em * em + nudge;
}

const List<_GridWidth> _gridWidths = <_GridWidth>[
  _GridWidth('390pt phone, 20 em', 20),
  _GridWidth('430pt phone, 22.5 em', 22.5),
  _GridWidth('a hair under the old gate', 28.9, nudge: -_nudge),
  _GridWidth('a hair over the old gate', 28.9, nudge: _nudge),
  _GridWidth('a hair over the 30 em gate', 30, nudge: _nudge),
  _GridWidth('32.4 em', 32.4),
  _GridWidth('34.9 em', 34.9),
  _GridWidth('35 em', 35),
  _GridWidth('1280 window, 80 em', 80),
];

const Map<String, TextScaler> _gridScalers = <String, TextScaler>{
  '0.9x': TextScaler.linear(0.9),
  '1x': TextScaler.noScaling,
  '1.15x': TextScaler.linear(1.15),
  '1.5x': TextScaler.linear(1.5),
  'non-linear': _CurvedScaler(),
};

const String _nextParagraph = 'A paragraph.';
const String _nextHeading = '# A heading';

typedef _GridRow = ({
  int row,
  _GridWidth width,
  String scale,
  MdPhotoSize size,
  MdPhotoSide side,
  String next,
});

List<_GridRow> _grid() {
  final List<(_GridWidth, String, MdPhotoSize, String)> cells =
      <(_GridWidth, String, MdPhotoSize, String)>[
        for (final _GridWidth width in _gridWidths)
          for (final String scale in _gridScalers.keys)
            for (final MdPhotoSize size in MdPhotoSize.values)
              for (final String next in <String>[_nextParagraph, _nextHeading])
                (width, scale, size, next),
      ];
  return <_GridRow>[
    for (final (int row, (_GridWidth, String, MdPhotoSize, String) cell)
        in cells.indexed)
      (
        row: row,
        width: cell.$1,
        scale: cell.$2,
        size: cell.$3,
        side: row.isEven ? MdPhotoSide.right : MdPhotoSide.left,
        next: cell.$4,
      ),
  ];
}

String _gridName(_GridRow row) =>
    '#${row.row} ${row.width.label} @ ${row.scale}, '
    '${row.size.name} ${row.side.name}, '
    '${row.next == _nextParagraph ? 'before a paragraph' : 'before a heading'}';

Iterable<MdBlock> _allBlocks(List<MdBlock> blocks) sync* {
  for (final MdBlock block in blocks) {
    yield block;
    yield* _allBlocks(block.blocks);
  }
}

Iterable<MdInline> _allInlines(List<MdInline> inlines) sync* {
  for (final MdInline inline in inlines) {
    yield inline;
    yield* _allInlines(inline.children);
  }
}

Iterable<MdInline> _treeInlines(MdTree tree) sync* {
  for (final MdBlock block in _allBlocks(tree.blocks)) {
    yield* _allInlines(block.inlines);
  }
}

List<MdBlock> _photos(MdTree tree) => <MdBlock>[
  for (final MdBlock block in tree.blocks)
    if (block.kind == MdBlockKind.photoLine) block,
];

List<String> _references(String source) => <String>[
  for (final MdBlock block in _photos(parseNoteTree(source)))
    MdPhotoLine.ofBlock(block, source).reference,
];

LayoutInputs _inputs(
  String source, {
  double width = 560,
  TextScaler scaler = TextScaler.noScaling,
  Map<String, Size>? dimensions,
}) {
  final MdTree tree = parseNoteTree(source);
  return LayoutInputs(
    source: source,
    tree: tree,
    visibleText: const NoteVisibleProjector().project(source, tree, null),
    activeLine: null,
    columnWidth: width,
    textScaler: scaler,
    boldText: false,
    locale: const Locale('en', 'US'),
    readerMode: true,
    mediaDimensions: <String, Size>{
      for (final MdBlock block in _allBlocks(tree.blocks))
        if (block.photoLine case final MdPhotoLineData data)
          data.reference: const Size(1200, 800),
      ...?dimensions,
    },
  );
}

NoteLayoutEngine _engine() =>
    NoteLayoutEngine(projector: const NoteVisibleProjector());

LaidOutNote _layout(
  String source, {
  double width = 560,
  TextScaler scaler = TextScaler.noScaling,
  Map<String, Size>? dimensions,
  NoteLayoutEngine? engine,
}) => (engine ?? _engine()).layout(
  _inputs(source, width: width, scaler: scaler, dimensions: dimensions),
);

bool _isPhotoFragment(LaidOutNote note, FragmentInfo fragment) =>
    note.inputs.tree.blocks[fragment.blockIndex].kind == MdBlockKind.photoLine;

List<FragmentInfo> _textFragments(LaidOutNote note) => <FragmentInfo>[
  for (final FragmentInfo fragment in note.fragments)
    if (!_isPhotoFragment(note, fragment)) fragment,
];

bool _overlaps(MdRange a, MdRange b) => a.start < b.end && b.start < a.end;

bool _inside(MdRange inner, MdRange outer) =>
    outer.start <= inner.start && inner.end <= outer.end;

List<FragmentInfo> _fragmentsInside(
  LaidOutNote note,
  MdRange range,
) => <FragmentInfo>[
  for (final FragmentInfo fragment in _textFragments(note))
    if (!fragment.sourceRange.isEmpty && _inside(fragment.sourceRange, range))
      fragment,
];

FragmentInfo _fragmentAt(LaidOutNote note, int offset) =>
    _textFragments(note).firstWhere(
      (FragmentInfo fragment) =>
          fragment.sourceRange.start <= offset &&
          offset < fragment.sourceRange.end,
    );

MdRange _rangeOf(String source, String text) {
  final int start = source.indexOf(text);
  return MdRange(start, start + text.length);
}

PhotoLayoutPlan _plan(
  MdPhotoSize size, {
  required double column,
  TextScaler scaler = TextScaler.noScaling,
  MdPhotoSide side = MdPhotoSide.right,
}) => planPhoto(
  placement: MdPhotoPlacement(side: side, size: size),
  columnWidth: column,
  textScaler: scaler,
  aspect: _aspect,
);

void _expectRect(Rect actual, Rect expected, String reason) {
  expect(actual.left, closeTo(expected.left, 0.01), reason: '$reason left');
  expect(actual.top, closeTo(expected.top, 0.01), reason: '$reason top');
  expect(actual.width, closeTo(expected.width, 0.01), reason: '$reason width');
  expect(
    actual.height,
    closeTo(expected.height, 0.01),
    reason: '$reason height',
  );
}

void _expectSameLayout(LaidOutNote actual, LaidOutNote fresh, String reason) {
  expect(
    actual.fragments.length,
    fresh.fragments.length,
    reason: '$reason fragments',
  );
  for (int i = 0; i < fresh.fragments.length; i++) {
    final FragmentInfo got = actual.fragments[i];
    final FragmentInfo want = fresh.fragments[i];
    expect(got.sourceRange, want.sourceRange, reason: '$reason #$i source');
    expect(got.visibleRange, want.visibleRange, reason: '$reason #$i visible');
    expect(got.besideFloat, want.besideFloat, reason: '$reason #$i beside');
    _expectRect(got.lineBox.rect, want.lineBox.rect, '$reason #$i');
  }
  expect(
    actual.photoRects.length,
    fresh.photoRects.length,
    reason: '$reason photos',
  );
  for (int i = 0; i < fresh.photoRects.length; i++) {
    expect(
      actual.photoRects[i].flow,
      fresh.photoRects[i].flow,
      reason: '$reason photo #$i',
    );
    _expectRect(
      actual.photoRects[i].rect,
      fresh.photoRects[i].rect,
      '$reason photo #$i',
    );
  }
}

void _checkResizePurity() {
  final String source = '$_a\n$_prose';
  final NoteLayoutEngine engine = _engine();
  for (final double available in <double>[
    560,
    559,
    558.5,
    540,
    544,
    539,
    600,
    900,
  ]) {
    final double column = noteColumnWidth(
      availableWidth: available,
      textScaler: TextScaler.noScaling,
    );
    _expectSameLayout(
      _layout(source, width: column, engine: engine),
      _layout(source, width: column),
      'at $available',
    );
  }
  expect(
    noteColumnWidth(availableWidth: 900, textScaler: TextScaler.noScaling),
    720,
  );
}

void _checkExactBand() {
  for (double column = 480; column <= 720; column += 0.7) {
    final PhotoLayoutPlan plan = planPhoto(
      placement: const MdPhotoPlacement(),
      columnWidth: column,
      textScaler: TextScaler.noScaling,
      aspect: _aspect,
    );
    expect(plan.mode, PhotoMode.floatRight, reason: '$column');
    expect(plan.width, closeTo(column / 2, 1e-9), reason: '$column');
    expect(
      plan.bandWidth,
      closeTo(column - column / 2 - 16, 1e-9),
      reason: '$column',
    );
  }
  for (final double column in <double>[480, 560, 640, 720]) {
    final double band = column - column / 2 - 16;
    final LaidOutNote note = _layout('$_a\n$_prose', width: column);
    final List<FragmentInfo> beside = <FragmentInfo>[
      for (final FragmentInfo fragment in _textFragments(note))
        if (fragment.besideFloat) fragment,
    ];
    expect(beside, isNotEmpty, reason: '$column');
    for (final FragmentInfo fragment in beside) {
      expect(
        fragment.lineBox.rect.left,
        greaterThanOrEqualTo(-0.01),
        reason: '$column $fragment',
      );
      expect(
        fragment.lineBox.rect.right,
        lessThanOrEqualTo(band + 0.5),
        reason: '$column $fragment',
      );
    }
  }
}

void _checkLargeBandFloor() {
  final PhotoLayoutPlan centred = _plan(MdPhotoSize.large, column: 620);
  expect(centred.mode, PhotoMode.centred);
  expect(centred.floats, isFalse);
  expect(centred.width, closeTo(413.33, 0.01));
  final PhotoLayoutPlan floated = _plan(MdPhotoSize.large, column: 630);
  expect(floated.mode, PhotoMode.floatRight);
  expect(floated.width, closeTo(420, 1e-9));
  expect(floated.bandWidth, closeTo(194, 1e-9));
  expect(floated.bandWidth / 16, closeTo(12.125, 1e-9));
}

void _checkScale() {
  final String source = '$_a\n$_prose';
  for (final double s in <double>[0.9, 1, 1.15, 1.5]) {
    final TextScaler scaler = TextScaler.linear(s);
    final NoteLayoutEngine engine = _engine();
    _layout(source, engine: engine);
    _expectSameLayout(
      _layout(source, scaler: scaler, engine: engine),
      _layout(source, scaler: scaler),
      'at ${s}x',
    );
    final double em = 16 * s;
    final PhotoLayoutPlan wide = _plan(
      MdPhotoSize.large,
      column: 39 * em + _nudge,
      scaler: scaler,
    );
    expect(wide.floats, isTrue, reason: '${s}x at 39 em');
    expect(wide.mode, PhotoMode.floatRight, reason: '${s}x at 39 em');
    final PhotoLayoutPlan narrow = _plan(
      MdPhotoSize.large,
      column: 38.9 * em,
      scaler: scaler,
    );
    expect(narrow.floats, isFalse, reason: '${s}x at 38.9 em');
    expect(narrow.mode, PhotoMode.centred, reason: '${s}x at 38.9 em');
  }
}

void _checkHalfPixelRule() {
  final LaidOutNote note = _layout('$_a\n$_prose');
  expect(note.photoRects, hasLength(1));
  _expectRect(
    note.photoRects.single.rect,
    const Rect.fromLTWH(280, 0, 280, _floatBottom),
    'photo',
  );
  final List<FragmentInfo> fragments = _textFragments(note);
  final int firstBelow = fragments.indexWhere(
    (FragmentInfo fragment) => fragment.lineBox.rect.top >= _besideLimit,
  );
  expect(firstBelow, greaterThan(0));
  for (final FragmentInfo fragment in fragments.take(firstBelow)) {
    expect(fragment.lineBox.rect.top, lessThan(_besideLimit));
    expect(fragment.besideFloat, isTrue, reason: '$fragment');
    expect(
      fragment.lineBox.rect.right,
      lessThanOrEqualTo(264.5),
      reason: '$fragment',
    );
  }
  final List<FragmentInfo> below = fragments.sublist(firstBelow);
  for (final FragmentInfo fragment in below) {
    expect(fragment.besideFloat, isFalse, reason: '$fragment');
    expect(fragment.lineBox.rect.left, closeTo(0, 0.01), reason: '$fragment');
  }
  expect(
    below.any((FragmentInfo fragment) => fragment.lineBox.rect.right > 264),
    isTrue,
  );
}

void _checkTallFloat() {
  final String source = '$_a\nA short line.';
  final LaidOutNote note = _layout(
    source,
    dimensions: <String, Size>{prefixOf(photoIdA): const Size(900, 1600)},
  );
  final Rect photo = note.photoRects.single.rect;
  expect(photo.left, closeTo(280, 0.01));
  expect(photo.width, closeTo(280, 0.01));
  expect(photo.height, closeTo(448, 0.01));
  final List<FragmentInfo> paragraph = _fragmentsInside(
    note,
    _rangeOf(source, 'A short line.'),
  );
  expect(paragraph, hasLength(1));
  expect(paragraph.single.besideFloat, isTrue);
  expect(note.size.height, closeTo(448, 0.01));
}

void _expectFragmentsCoverVisibleText(String source, String reason) {
  final LaidOutNote note = _layout('$_a\n$source');
  final VisibleText visible = note.inputs.visibleText;
  final List<FragmentInfo> fragments = note.fragments;
  for (int i = 1; i < fragments.length; i++) {
    expect(
      fragments[i].visibleRange.start,
      greaterThanOrEqualTo(fragments[i - 1].visibleRange.end),
      reason: '$reason fragment $i',
    );
  }
  for (int offset = 0; offset < visible.text.length; offset++) {
    final String unit = visible.text[offset];
    if (unit == '\n' || unit == '\r') {
      continue;
    }
    if (visible.atomics.any(
      (AtomicObject atomic) => atomic.visibleRange.contains(offset),
    )) {
      continue;
    }
    final int holders = fragments
        .where(
          (FragmentInfo fragment) => fragment.visibleRange.contains(offset),
        )
        .length;
    expect(holders, 1, reason: '$reason visible offset $offset');
  }
}

void _checkCorpusFragments() {
  for (final (int index, String source) in noteFuzzCorpus.indexed) {
    expect(
      () => _layout('$_a\n$source'),
      returnsNormally,
      reason: 'corpus #$index',
    );
    _expectFragmentsCoverVisibleText(source, 'corpus #$index');
  }
}

double _paintedWidth(String text, TextStyle style) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.noScaling,
  )..layout();
  final double width = painter.width;
  painter.dispose();
  return width;
}

MdRange _withoutOuterSpaces(String source, MdRange range) {
  int start = range.start;
  int end = range.end;
  while (start < end && source[start] == ' ') {
    start++;
  }
  while (end > start && source[end - 1] == ' ') {
    end--;
  }
  return MdRange(start, end);
}

List<FragmentInfo> _overlapping(LaidOutNote note, MdRange range) =>
    <FragmentInfo>[
      for (final FragmentInfo fragment in _textFragments(note))
        if (_overlaps(fragment.sourceRange, range)) fragment,
    ];

void _expectPartWidths(
  LaidOutNote note,
  MdRange range,
  TextStyle style,
  String reason,
) {
  final String source = note.inputs.source;
  final List<FragmentInfo> fragments = _overlapping(note, range);
  expect(fragments, isNotEmpty, reason: reason);
  for (final FragmentInfo fragment in fragments) {
    final MdRange part = _withoutOuterSpaces(
      source,
      MdRange(
        math.max(range.start, fragment.sourceRange.start),
        math.min(range.end, fragment.sourceRange.end),
      ),
    );
    if (part.isEmpty) {
      continue;
    }
    final List<Rect> boxes = note.selectionBoxes(
      NoteSelection(anchor: part.start, head: part.end),
    );
    expect(boxes, isNotEmpty, reason: '$reason $part');
    final double left = boxes.map((Rect box) => box.left).reduce(math.min);
    final double right = boxes.map((Rect box) => box.right).reduce(math.max);
    expect(
      right - left,
      closeTo(_paintedWidth(part.sliceOf(source), style), 0.5),
      reason: '$reason $part',
    );
  }
}

MdInline _firstInline(MdTree tree, MdInlineKind kind) =>
    _treeInlines(tree).firstWhere((MdInline inline) => inline.kind == kind);

EditorState _state(String source, {NoteSelection? selection}) =>
    EditorState.create(
      source,
      parse: parseNoteTree,
      selection: selection ?? const NoteSelection.collapsed(0),
      history: const NoteHistory(),
    );

(String, NoteSelection) _insert(
  String source,
  int caret, [
  List<String>? references,
]) {
  final PhotoEdit edit = photoInsertion(
    source,
    photoTargetAt(source, parseNoteTree(source), caret),
    references ?? <String>[prefixOf(photoIdA)],
  );
  return (edit.changes.apply(source), edit.selection);
}

String _applied(EditorState state, Transaction? transaction) =>
    transaction!.changes.apply(state.source);

void _expectSelection(NoteSelection actual, int start, int end) {
  expect(actual.start, start, reason: '$actual');
  expect(actual.end, end, reason: '$actual');
}

void _pinView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpBody(
  WidgetTester tester,
  String source, {
  double width = 560,
}) async {
  _pinView(tester);
  await tester.pumpWidget(
    notesHarness(
      NoteMediaScope(
        resolver: FakeNoteMediaResolver(<String, ResolvedMedia>{
          prefixOf(photoIdA): availablePhoto(photoIdA),
          prefixOf(photoIdB): availablePhoto(photoIdB),
          prefixOf(photoIdC): availablePhoto(photoIdC),
        })..memoizeAll(),
        child: NoteBody(text: source),
      ),
      width: width,
    ),
  );
  await tester.pumpAndSettle();
}

List<MethodCall> _captureClipboard(WidgetTester tester) {
  final List<MethodCall> log = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      log.add(call);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return log;
}

Future<void> _pressWithControl(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  await tester.pump();
  await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
  await tester.pumpAndSettle();
}

String _copiedText(List<MethodCall> log) {
  final MethodCall call = log.lastWhere(
    (MethodCall c) => c.method == 'Clipboard.setData',
  );
  return (call.arguments as Map<Object?, Object?>)['text']! as String;
}

Offset _bodyTopLeft(WidgetTester tester) =>
    tester.getTopLeft(find.byType(NoteBody));

Future<void> _focusReader(WidgetTester tester) async {
  final TestGesture gesture = await tester.startGesture(
    _bodyTopLeft(tester) + const Offset(5, 5),
    kind: PointerDeviceKind.mouse,
  );
  addTearDown(gesture.removePointer);
  await tester.pump(const Duration(milliseconds: 110));
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<String> _selectAllAndCopy(WidgetTester tester, String source) async {
  final List<MethodCall> log = _captureClipboard(tester);
  await _pumpBody(tester, source);
  await _focusReader(tester);
  await _pressWithControl(tester, LogicalKeyboardKey.keyA);
  await _pressWithControl(tester, LogicalKeyboardKey.keyC);
  return _copiedText(log);
}

void _checkPhotoRemovalRoundTrips() {
  for (final String source in _removalCorpus()) {
    final MdTree tree = parseNoteTree(source);
    for (final MdBlock photo in _photos(tree)) {
      final PhotoEdit edit = photoRemoval(source, tree, photo);
      final String after = edit.changes.apply(source);
      expect(
        edit.changes.invert(source).apply(after),
        source,
        reason: '$source at ${photo.sourceRange}',
      );
      expect(
        _photos(parseNoteTree(after)),
        hasLength(_photos(tree).length - 1),
        reason: '$source at ${photo.sourceRange}',
      );
    }
  }
}

List<String> _removalCorpus() => <String>[
  'one\n$_a\ntwo',
  'one\n$_a',
  _a,
  '$_a\n',
  'one\r\n$_a',
  'one\r\n$_a\r\ntwo\r\n',
  '$_a\n$_b\n$_c',
  '# Title\n\n$_a\n\n- item\n$_b\n\n```\ncode\n```\n$_c',
  '  $_a  \nindented',
];

void main() {
  group('float_split_cache_test.dart', () {
    test('start at the 19.4 em residual and step every half em', () {
      _checkExactBand();
    });

    test('lay the head out no wider than the band and never under 19.4 em', () {
      _checkExactBand();
      _checkLargeBandFloor();
    });

    test('a rounding hair under the residual still lands in bucket zero', () {
      _checkExactBand();
      _checkLargeBandFloor();
    });

    test('are the same at every text scale', () {
      _checkScale();
    });

    test('misses when nothing is stored', () {
      _checkResizePurity();
    });

    test('hits on the same span, scaler and bucket', () {
      _checkResizePurity();
    });

    test('keys on span identity, not on equal content', () {
      _checkResizePurity();
    });

    test('misses when the text scaler changes', () {
      _checkScale();
    });

    test('misses when the band narrows into a lower bucket', () {
      _checkResizePurity();
    });

    test('holds the split for one bucket of widening, not two', () {
      _checkResizePurity();
    });

    test(
      'walking the band back and forth across a bucket edge never misses',
      () {
        _checkResizePurity();
      },
    );

    test('holds within one line of the photo height and misses past it', () {
      _checkHalfPixelRule();
    });

    test('walking the photo height across a line boundary never misses', () {
      _checkHalfPixelRule();
    });

    test('a float with no line beside it never hits', () {
      _checkHalfPixelRule();
    });

    test(
      'a line starting within the edge tolerance of the foot is below it',
      () {
        _checkHalfPixelRule();
      },
    );

    test('a paragraph wholly beside the photo holds however tall it grows', () {
      _checkTallFloat();
    });

    test('a replaced split is served in place of the old one', () {
      _checkResizePurity();
    });

    test('is bounded and evicts the least recently used split', () {
      _checkResizePurity();
    });

    test('clear drops every split', () {
      _checkResizePurity();
    });
  });

  group('float_plan_table_test.dart', () {
    test('planFloat decision table', () {
      for (final _GridRow row in _grid()) {
        final String name = _gridName(row);
        final TextScaler scaler = _gridScalers[row.scale]!;
        final double em = scaler.scale(16);
        final double column = noteColumnWidth(
          availableWidth: row.width.pixelsAt(em),
          textScaler: scaler,
        );
        final PhotoLayoutPlan plan = _plan(
          row.size,
          column: column,
          scaler: scaler,
          side: row.side,
        );
        final PhotoMode floatMode = row.side == MdPhotoSide.right
            ? PhotoMode.floatRight
            : PhotoMode.floatLeft;
        if (column < 30 * em) {
          expect(plan.mode, PhotoMode.centred, reason: name);
          expect(plan.floats, isFalse, reason: name);
          expect(plan.width, closeTo(column, 1e-9), reason: name);
        } else {
          switch (row.size) {
            case MdPhotoSize.small:
              expect(plan.mode, floatMode, reason: name);
              expect(plan.width, closeTo(column / 3, 1e-9), reason: name);
            case MdPhotoSize.medium:
              expect(plan.mode, floatMode, reason: name);
              expect(plan.width, closeTo(column / 2, 1e-9), reason: name);
            case MdPhotoSize.large:
              expect(
                plan.mode,
                column >= 39 * em ? floatMode : PhotoMode.centred,
                reason: name,
              );
              expect(plan.width, closeTo(column * 2 / 3, 1e-9), reason: name);
            case MdPhotoSize.full:
              expect(plan.mode, PhotoMode.centred, reason: name);
              expect(plan.width, closeTo(column, 1e-9), reason: name);
          }
        }
        if (row.width.em == 80) {
          expect(column, closeTo(45 * em, 1e-9), reason: name);
          if (row.size == MdPhotoSize.large) {
            expect(plan.width, closeTo(30 * em, 1e-9), reason: name);
            expect(plan.bandWidth, closeTo(14 * em, 1e-9), reason: name);
          }
        }
        expect(plan.photoHeight, closeTo(plan.width / _aspect, 1e-9));
        final String line = photoLine(photoIdA, side: row.side, size: row.size);
        final Rect beforeParagraph = _layout(
          '$line\n$_nextParagraph',
          width: column,
          scaler: scaler,
        ).photoRects.single.rect;
        final Rect beforeHeading = _layout(
          '$line\n$_nextHeading',
          width: column,
          scaler: scaler,
        ).photoRects.single.rect;
        _expectRect(beforeParagraph, beforeHeading, name);
        expect(beforeParagraph.width, closeTo(plan.width, 0.01), reason: name);
      }
    });

    test('covers every width, scale, size and next block once', () {
      final List<_GridRow> rows = _grid();
      expect(rows, hasLength(360));
      expect(<(String, String, MdPhotoSize, String)>{
        for (final _GridRow row in rows)
          (row.width.label, row.scale, row.size, row.next),
      }, hasLength(360));
    });

    test('em is scale(fontSize), never scale(1) * fontSize', () {
      const TextScaler curved = _CurvedScaler();
      expect(NoteTypography.emOf(curved), 20);
      expect(curved.scale(1) * 16, isNot(20));
      expect(
        noteColumnWidth(availableWidth: double.infinity, textScaler: curved),
        900,
      );
    });

    test('every size demotes at the same width: 28.9 em', () {
      for (final MapEntry<String, TextScaler> entry in _gridScalers.entries) {
        final TextScaler scaler = entry.value;
        final double em = NoteTypography.emOf(scaler);
        final double under = 30 * em - _nudge;
        final double over = 30 * em + _nudge;
        expect(
          isDesktopColumn(columnWidth: under, em: em),
          isFalse,
          reason: entry.key,
        );
        for (final MdPhotoSize size in MdPhotoSize.values) {
          final String reason = '${entry.key} ${size.name}';
          final PhotoLayoutPlan narrow = _plan(
            size,
            column: under,
            scaler: scaler,
          );
          expect(narrow.mode, PhotoMode.centred, reason: reason);
          expect(narrow.width, closeTo(under, 1e-9), reason: reason);
          final PhotoLayoutPlan wide = _plan(
            size,
            column: over,
            scaler: scaler,
          );
          expect(
            wide.floats,
            photoCanFloat(size: size, columnWidth: over, em: em),
            reason: reason,
          );
          switch (size) {
            case MdPhotoSize.small:
            case MdPhotoSize.medium:
              expect(wide.mode, PhotoMode.floatRight, reason: reason);
            case MdPhotoSize.large:
              expect(wide.mode, PhotoMode.centred, reason: reason);
              expect(wide.width, closeTo(over * 2 / 3, 1e-9), reason: reason);
            case MdPhotoSize.full:
              expect(wide.mode, PhotoMode.centred, reason: reason);
              expect(wide.width, closeTo(over, 1e-9), reason: reason);
          }
        }
      }
    });

    test('the photo shrinks continuously before it demotes', () {
      for (double column = 720; column >= 480; column -= 0.5) {
        final PhotoLayoutPlan plan = _plan(MdPhotoSize.medium, column: column);
        expect(plan.mode, PhotoMode.floatRight, reason: '$column');
        expect(plan.width, closeTo(column / 2, 1e-9), reason: '$column');
      }
      final PhotoLayoutPlan demoted = _plan(MdPhotoSize.medium, column: 479.5);
      expect(demoted.mode, PhotoMode.centred);
      expect(demoted.width, closeTo(479.5, 1e-9));
    });

    test('demotion is a step, not a continuation: stated here plainly', () {
      final PhotoLayoutPlan small = _plan(MdPhotoSize.small, column: 480);
      final PhotoLayoutPlan medium = _plan(MdPhotoSize.medium, column: 480);
      final PhotoLayoutPlan large = _plan(MdPhotoSize.large, column: 480);
      expect(small.floats, isTrue);
      expect(small.width, closeTo(160, 1e-9));
      expect(medium.floats, isTrue);
      expect(medium.width, closeTo(240, 1e-9));
      expect(large.mode, PhotoMode.centred);
      expect(large.width, closeTo(320, 1e-9));
      expect(480 - 320 - 16, 144);
      expect(144 / 16, 9);
      expect(
        photoCanFloat(size: MdPhotoSize.large, columnWidth: 480, em: 16),
        isFalse,
      );
      for (final MdPhotoSize size in <MdPhotoSize>[
        MdPhotoSize.small,
        MdPhotoSize.medium,
        MdPhotoSize.large,
      ]) {
        final PhotoLayoutPlan plan = _plan(size, column: 479.99);
        expect(plan.mode, PhotoMode.centred, reason: size.name);
        expect(plan.width, closeTo(479.99, 1e-9), reason: size.name);
      }
    });

    test('the side never changes the geometry', () {
      for (final _GridWidth width in _gridWidths) {
        final double column = noteColumnWidth(
          availableWidth: width.pixelsAt(16),
          textScaler: TextScaler.noScaling,
        );
        for (final MdPhotoSize size in MdPhotoSize.values) {
          final String reason = '${width.label} ${size.name}';
          final PhotoLayoutPlan left = _plan(
            size,
            column: column,
            side: MdPhotoSide.left,
          );
          final PhotoLayoutPlan right = _plan(size, column: column);
          expect(
            <Object>[left.width, left.photoHeight, left.bandWidth, left.floats],
            <Object>[
              right.width,
              right.photoHeight,
              right.bandWidth,
              right.floats,
            ],
            reason: reason,
          );
          if (left.floats) {
            expect(left.mode, PhotoMode.floatLeft, reason: reason);
            expect(right.mode, PhotoMode.floatRight, reason: reason);
          }
        }
      }
    });
  });

  group('note_document_test.dart', () {
    test(
      'pairs a photo with the paragraph immediately after it, and only it',
      () {
        final String source = '$_a\n# Heading\n- one\n- two\n\n$_prose';
        final LaidOutNote note = _layout(source);
        for (final String text in <String>['Heading', 'one', 'two']) {
          final FragmentInfo fragment = _fragmentAt(note, source.indexOf(text));
          expect(fragment.besideFloat, isTrue, reason: text);
        }
        final List<FragmentInfo> prose = _fragmentsInside(
          note,
          _rangeOf(source, _prose),
        );
        final int firstBelow = prose.indexWhere(
          (FragmentInfo fragment) => fragment.lineBox.rect.top >= _besideLimit,
        );
        expect(firstBelow, greaterThanOrEqualTo(0));
        for (final FragmentInfo fragment in prose.take(firstBelow)) {
          expect(fragment.besideFloat, isTrue, reason: '$fragment');
        }
        for (final FragmentInfo fragment in prose.sublist(firstBelow)) {
          expect(fragment.besideFloat, isFalse, reason: '$fragment');
          expect(
            fragment.lineBox.rect.left,
            closeTo(0, 0.01),
            reason: '$fragment',
          );
        }

        final List<PhotoRect> photos = _layout('$_a\n$_b\n$_prose').photoRects;
        expect(photos, hasLength(2));
        expect(photos[1].rect.top, closeTo(photos[0].rect.bottom + 12.8, 0.01));
        expect(photos[1].rect.top, closeTo(199.47, 0.01));
      },
    );

    test('an invalid placement stacks even when a paragraph follows', () {
      const String source = '![](photo/a1b2c3d4e5f6 "right huge")\nbody';
      final LaidOutNote note = _layout(source);
      final PhotoRect photo = note.photoRects.single;
      expect(photo.flow, PhotoFlow.block);
      _expectRect(
        photo.rect,
        const Rect.fromLTWH(140, 0, 280, _floatBottom),
        'photo',
      );
      final FragmentInfo body = _fragmentAt(note, source.indexOf('body'));
      expect(body.lineBox.rect.left, closeTo(0, 0.01));
      expect(body.lineBox.rect.top, closeTo(199.47, 0.01));
    });

    test('pairs nothing when photos cannot float', () {
      final String source =
          'intro\n\n$_a\nbody\n\n# Head\n\n$_b\n# Next\n\n'
          '$_c\n$_a\ntail\n\n- item\n\n$_b';
      final LaidOutNote note = _layout(source, width: 320);
      expect(
        note.fragments.where((FragmentInfo fragment) => fragment.besideFloat),
        isEmpty,
      );
      expect(note.photoRects, hasLength(5));
      for (final PhotoRect photo in note.photoRects) {
        expect(photo.rect.width, closeTo(320, 0.01), reason: '$photo');
        expect(photo.flow, PhotoFlow.block, reason: '$photo');
      }
    });

    test(
      'keeps every block exactly once, in source order, over the corpus',
      () {
        _checkCorpusFragments();
      },
    );

    testWidgets(
      'renders a paired photo as one PhotoWrapBlock under the one SelectionArea',
      (WidgetTester tester) async {
        final String source =
            'intro\n\n$_a\nbody text\n\n# Head\n\n$_b\n# Next';
        await _pumpBody(tester, source);

        expect(find.byType(NoteReaderView), findsOneWidget);
        expect(find.byType(PhotoFigure), findsNWidgets(2));

        final LaidOutNote note = _layout(source);
        final FragmentInfo body = _fragmentAt(
          note,
          source.indexOf('body text'),
        );
        final FragmentInfo head = _fragmentAt(note, source.indexOf('Head'));
        expect(body.besideFloat, isTrue);
        expect(head.besideFloat, isTrue);
        expect(
          head.lineBox.rect.top,
          closeTo(body.lineBox.rect.bottom + _lineHeight, 0.01),
        );
      },
    );

    test('renders one block view per block in source order', () {
      expect(
        const NoteVisibleProjector()
            .project(_everyKind, parseNoteTree(_everyKind), null)
            .text,
        'Title\n\nbody bold\n\n• one\n• two\n\nquote\n\ncode\n\n'
        '￼\n\n￼',
      );
      final List<FragmentInfo> fragments = _layout(_everyKind).fragments;
      expect(fragments, isNotEmpty);
      for (int i = 1; i < fragments.length; i++) {
        expect(
          fragments[i].sourceRange.start,
          greaterThanOrEqualTo(fragments[i - 1].sourceRange.start),
          reason: 'fragment $i',
        );
      }
    });

    testWidgets('sits under exactly one SelectionArea', (
      WidgetTester tester,
    ) async {
      final List<MethodCall> log = _captureClipboard(tester);
      await _pumpBody(tester, _everyKind);

      expect(find.byType(NoteReaderView), findsOneWidget);
      expect(find.byType(SelectionArea), findsNothing);

      await _focusReader(tester);
      await _pressWithControl(tester, LogicalKeyboardKey.keyA);
      await _pressWithControl(tester, LogicalKeyboardKey.keyC);

      expect(
        _copiedText(log),
        'Title\n\nbody bold\n\n• one\n• two\n\nquote\n\ncode\n\n\n\n',
      );
    });

    testWidgets('list markers are excluded from selection', (
      WidgetTester tester,
    ) async {
      expect(
        await _selectAllAndCopy(tester, '- one\n\n2. two'),
        '• one\n\n2. two',
      );
    });

    test('paragraph prose carries the note body style', () {
      expect(NoteTypography.body, TypographyTokens.noteBody);
      expect(NoteTypography.body.fontFamily, 'Newsreader');
      expect(NoteTypography.body.fontSize, 16);
      expect(NoteTypography.body.fontWeight, FontWeight.w400);
      expect(NoteTypography.body.height, 1.6);
      final LaidOutNote note = _layout('a quiet morning');
      expect(note.fragments, hasLength(1));
      expect(note.fragments.single.lineBox.rect.left, closeTo(0, 0.01));
      expect(
        note.fragments.single.lineBox.rect.height,
        closeTo(_lineHeight, 0.01),
      );
    });

    test('inline styles reach the span tree', () {
      expect(NoteTypography.strong.fontWeight, FontWeight.w700);
      expect(NoteTypography.emphasis.fontStyle, FontStyle.italic);
      expect(
        NoteTypography.strikethrough.decoration,
        TextDecoration.lineThrough,
      );
      expect(NoteTypography.link.color, Palette.coralLink);
      expect(NoteTypography.link.decoration, TextDecoration.underline);
      expect(NoteTypography.link.decorationColor, Palette.coral30);
      final TextStyle code = NoteTypography.inlineCode(NoteTypography.body);
      expect(code.fontFamily, TypographyTokens.mono);
      expect(code.fontSize, 14);
      expect(code.backgroundColor, Palette.ink08);
      expect(NoteTypography.highlight.backgroundColor, Palette.highlight);

      final LaidOutNote note = _layout('a **b** *c* `d` ~~e~~ [f](g)');
      _expectPartWidths(
        note,
        const MdRange(4, 5),
        NoteTypography.body.merge(NoteTypography.strong),
        'b',
      );
      _expectPartWidths(
        note,
        const MdRange(13, 14),
        NoteTypography.inlineCode(NoteTypography.body),
        'd',
      );
    });

    test('headings take the heading tokens', () {
      expect(NoteTypography.heading(1), TypographyTokens.titleSerif);
      expect(NoteTypography.heading(2), TypographyTokens.headlineSerif);
      expect(NoteTypography.heading(3), TypographyTokens.bannerSerif);
      expect(
        NoteTypography.heading(4),
        TypographyTokens.bannerSerif.copyWith(fontSize: 18),
      );
      expect(
        NoteTypography.heading(5),
        TypographyTokens.bannerSerif.copyWith(fontSize: 17),
      );
      expect(
        NoteTypography.heading(6),
        TypographyTokens.bannerSerif.copyWith(fontSize: 16),
      );
      const String source = '# one\n\n## two\n\n### three';
      final FragmentInfo one = _fragmentAt(
        _layout(source),
        source.indexOf('one'),
      );
      expect(one.lineBox.rect.height, closeTo(28.8, 0.5));
    });

    testWidgets('renders without a selection region when no overlay exists', (
      WidgetTester tester,
    ) async {
      _pinView(tester);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 360,
                child: NoteMediaScope(
                  resolver: FakeNoteMediaResolver()..memoizeAll(),
                  child: const NoteBody(text: '# head\n\nbody'),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.byType(NoteReaderView), findsOneWidget);
    });

    testWidgets('a selection across two blocks copies with the break kept', (
      WidgetTester tester,
    ) async {
      final List<MethodCall> log = _captureClipboard(tester);
      await _pumpBody(tester, 'first paragraph\n\nsecond paragraph');
      final Offset origin = _bodyTopLeft(tester);

      final Offset start =
          origin +
          Offset(_paintedWidth('first ', NoteTypography.body) + 1, 12.8);
      final Offset end =
          origin + Offset(_paintedWidth('second', NoteTypography.body) + 1, 64);
      final TestGesture gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.mouse,
      );
      addTearDown(gesture.removePointer);
      await tester.pump(const Duration(milliseconds: 110));
      for (int step = 1; step <= 8; step++) {
        await gesture.moveTo(Offset.lerp(start, end, step / 8)!);
        await tester.pump();
      }
      await gesture.up();
      await tester.pumpAndSettle();

      await _pressWithControl(tester, LogicalKeyboardKey.keyC);

      expect(_copiedText(log), 'paragraph\n\nsecond');
    });

    testWidgets('select all copies every block separated by breaks', (
      WidgetTester tester,
    ) async {
      expect(
        await _selectAllAndCopy(tester, '# head\n\n- one\n- two\n\ntail'),
        'head\n\n• one\n• two\n\ntail',
      );
    });
  });

  group('inline_span_slice_test.dart', () {
    test('head plus tail is the root plain text at every offset', () {
      _checkCorpusFragments();
    });

    test('splitting inside a styled leaf keeps the style on both halves', () {
      final String source = '$_a\n$_strongRun';
      final MdRange strong = _firstInline(
        parseNoteTree(source),
        MdInlineKind.strong,
      ).contentRange;
      for (final double width in <double>[480, 560, 600]) {
        final LaidOutNote note = _layout(source, width: width);
        final List<FragmentInfo> parts = _overlapping(note, strong);
        expect(parts.length, greaterThanOrEqualTo(3), reason: '$width');
        expect(
          parts.any((FragmentInfo fragment) => fragment.besideFloat),
          isTrue,
          reason: '$width',
        );
        expect(
          parts.any((FragmentInfo fragment) => !fragment.besideFloat),
          isTrue,
          reason: '$width',
        );
        _expectPartWidths(
          note,
          strong,
          NoteTypography.body.merge(NoteTypography.strong),
          'strong at $width',
        );
      }
    });

    test('splitting at a nested-span boundary re-parents each ancestor', () {
      final String source = '$_a\n$_nestedRun';
      final MdTree tree = parseNoteTree(source);
      final MdInline emphasis = _firstInline(tree, MdInlineKind.emphasis);
      final MdInline strong = _firstInline(tree, MdInlineKind.strong);
      final MdRange calm = MdRange(
        emphasis.contentRange.start,
        strong.sourceRange.start - 1,
      );
      expect(calm.sliceOf(source), _calm);
      for (final double width in <double>[480, 560, 600]) {
        final LaidOutNote note = _layout(source, width: width);
        expect(
          _overlapping(note, strong.contentRange).length,
          greaterThanOrEqualTo(2),
          reason: '$width',
        );
        _expectPartWidths(
          note,
          strong.contentRange,
          NoteTypography.body
              .merge(NoteTypography.emphasis)
              .merge(NoteTypography.strong),
          'strong at $width',
        );
        _expectPartWidths(
          note,
          calm,
          NoteTypography.body.merge(NoteTypography.emphasis),
          'calm at $width',
        );
      }
    });

    test('offset zero yields an empty styled head and the root as tail', () {
      final String source = <String>[
        '$_a\nLine 1.',
        for (int n = 2; n <= 8; n++) 'Line $n.',
      ].join('\n\n');
      final LaidOutNote note = _layout(source);
      for (int n = 1; n <= 8; n++) {
        final FragmentInfo line = _fragmentAt(note, source.indexOf('Line $n.'));
        if (n <= 4) {
          expect(
            line.lineBox.rect.top,
            closeTo((n - 1) * 2 * _lineHeight, 0.01),
            reason: 'line $n',
          );
          expect(line.besideFloat, isTrue, reason: 'line $n');
        } else {
          expect(line.besideFloat, isFalse, reason: 'line $n');
          expect(line.lineBox.rect.left, closeTo(0, 0.01), reason: 'line $n');
        }
      }
      expect(
        _fragmentAt(note, source.indexOf('Line 5.')).lineBox.rect.top,
        closeTo(204.8, 0.01),
      );
    });

    test('an offset past the end yields the root and no tail', () {
      final String source = '$_a\nA short line.';
      final LaidOutNote note = _layout(source);
      final List<FragmentInfo> paragraph = _fragmentsInside(
        note,
        _rangeOf(source, 'A short line.'),
      );
      expect(paragraph, hasLength(1));
      expect(paragraph.single.besideFloat, isTrue);
      expect(note.size.height, closeTo(_floatBottom, 0.01));
    });

    test('a placeholder span goes wholly to one side', () {
      final String source = '$_a\n- [ ] one\n- [ ] two\n---';
      final LaidOutNote note = _layout(source);
      final List<AtomicObject> atomics = note.inputs.visibleText.atomics;
      expect(
        atomics.map((AtomicObject atomic) => atomic.kind),
        containsAll(<AtomicKind>[
          AtomicKind.photo,
          AtomicKind.checkbox,
          AtomicKind.divider,
        ]),
      );
      for (final AtomicObject atomic in atomics) {
        final List<FragmentInfo> touching = <FragmentInfo>[
          for (final FragmentInfo fragment in note.fragments)
            if (_overlaps(fragment.visibleRange, atomic.visibleRange)) fragment,
        ];
        expect(touching.length, lessThanOrEqualTo(1), reason: '$atomic');
        for (final FragmentInfo fragment in touching) {
          expect(
            _inside(atomic.visibleRange, fragment.visibleRange),
            isTrue,
            reason: '$atomic in $fragment',
          );
        }
      }
      final MdBlock divider = note.inputs.tree.blocks.firstWhere(
        (MdBlock block) => block.kind == MdBlockKind.thematicBreak,
      );
      expect(
        note.rangeBounds(divider.sourceRange).top,
        greaterThanOrEqualTo(199.46),
      );
    });
  });

  group('photo_placement_test.dart', () {
    test('an unknown or repeated token makes a placement invalid', () {
      for (final (String title, MdPhotoSide side, MdPhotoSize size)
          in <(String, MdPhotoSide, MdPhotoSize)>[
            ('right medium', MdPhotoSide.right, MdPhotoSize.medium),
            ('', MdPhotoSide.right, MdPhotoSize.medium),
            ('   ', MdPhotoSide.right, MdPhotoSize.medium),
            ('Left SMALL', MdPhotoSide.left, MdPhotoSize.small),
            ('full', MdPhotoSide.right, MdPhotoSize.full),
          ]) {
        final MdPhotoPlacement placement = MdPhotoPlacement.parse(title);
        expect(placement.isValid, isTrue, reason: '"$title"');
        expect(placement.side, side, reason: '"$title"');
        expect(placement.size, size, reason: '"$title"');
      }
      for (final String title in <String>[
        'right huge',
        'sideways',
        'left right',
        'small large',
        'right medium tilt',
      ]) {
        expect(
          MdPhotoPlacement.parse(title).isValid,
          isFalse,
          reason: '"$title"',
        );
      }
      final MdPhotoPlacement edited = MdPhotoPlacement.parse(
        'right huge',
      ).copyWith(side: MdPhotoSide.left);
      expect(edited.isValid, isTrue);
      expect(edited.format(), 'left medium');

      final EditorState state = _state('![](photo/a1b2c3d4e5f6 "right huge")');
      expect(
        _applied(
          state,
          setPhotoSide(state, _photos(state.tree).single, MdPhotoSide.left),
        ),
        '![](photo/a1b2c3d4e5f6 "left medium")',
      );
    });
  });

  group('photo_line_edits_test.dart', () {
    test('locates every photo line by its physical line', () {
      final String source = 'one\n$_a\n\ntwo\n$_b';
      final List<MdBlock> photos = _photos(parseNoteTree(source));
      expect(photos, hasLength(2));
      expect(_references(source), <String>['a1b2c3d4e5f6', 'b2c3d4e5f6a1']);
      expect(photoLineRange(source, photos[0]), const MdRange(4, 42));
      expect(photoLineRange(source, photos[0]).sliceOf(source), _a);
      expect(photoLineRange(source, photos[1]).end, source.length);
    });

    test(
      'reads the caption from the alt slot and the placement from the title',
      () {
        final String source = photoLine(
          photoIdA,
          caption: 'the porch',
          side: MdPhotoSide.left,
          size: MdPhotoSize.large,
        );
        final MdPhotoLine line = MdPhotoLine.ofBlock(
          _photos(parseNoteTree(source)).single,
          source,
        );
        expect(line.caption, 'the porch');
        expect(line.placement.isValid, isTrue);
        expect(line.placement.side, MdPhotoSide.left);
        expect(line.placement.size, MdPhotoSize.large);
      },
    );

    test('ignores photo syntax inside a code fence', () {
      expect(
        _allBlocks(
          parseNoteTree('```\n$_a\n```').blocks,
        ).where((MdBlock block) => block.kind == MdBlockKind.photoLine),
        isEmpty,
      );
    });

    test('answers the photo whose line holds the caret, at either end', () {
      final String source = 'one\n$_a\ntwo\n$_b';
      final List<MdBlock> photos = _photos(parseNoteTree(source));
      for (final (int caret, MdBlock photo) in <(int, MdBlock)>[
        (4, photos[0]),
        (42, photos[0]),
        (52, photos[1]),
      ]) {
        expect(
          selectedPhoto(
            _state(source, selection: NoteSelection.collapsed(caret)),
          ),
          photo,
          reason: '$caret',
        );
      }
    });

    test('is null on a text line or with no caret at all', () {
      final String source = 'one\n$_a\ntwo\n$_b';
      expect(
        selectedPhoto(
          _state(source, selection: const NoteSelection.collapsed(1)),
        ),
        isNull,
      );
      final Transaction restore = _state(
        source,
      ).externalWrite(source, selectionBase: -1, selectionExtent: -1);
      expect(restore.event, TransactionEvent.restore);
      expect(restore.selection.isCollapsed, isTrue);
      expect(restore.selection.start, inInclusiveRange(0, source.length));
    });

    test('follows the extent of a ranged selection', () {
      final String source = 'one\n$_a\ntwo\n$_b';
      expect(
        activeLineAt(
          source,
          parseNoteTree(source),
          const NoteSelection(anchor: 0, head: 49),
        ).line,
        3,
      );
    });

    test('a new photo line is the 38-character right medium form', () {
      final String line = canonicalPhotoLine(
        prefixOf(photoIdA),
        '',
        const MdPhotoPlacement(),
      );
      expect(line, _a);
      expect(line.length, 38);
    });

    test(
      'a blank note gains the photo and a fresh line to keep writing on',
      () {
        final (String source, NoteSelection selection) = _insert('', 0);
        expect(source, '$_a\n');
        _expectSelection(selection, 0, 38);
      },
    );

    test('mid-line, the photo goes below that line and the caret after it', () {
      expect(_insert('one\ntwo', 2).$1, 'one\ntwo\n$_a\n');
    });

    test('at the end of the last line it appends and opens a new line', () {
      final (String source, NoteSelection selection) = _insert('went out', 8);
      expect(source, 'went out\n$_a\n');
      _expectSelection(selection, 9, 47);
    });

    test('at the start of a line the photo goes above it', () {
      expect(_insert('one\ntwo', 4).$1, 'one\ntwo\n$_a\n');
    });

    test('on a blank line the photo takes that line', () {
      expect(_insert('one\n\ntwo', 4).$1, 'one\n$_a\ntwo');
    });

    test('with no caret the photo is appended rather than lost', () {
      final EditorState blank = _state('');
      final EditorState state = blank.apply(
        blank.externalWrite('one', selectionBase: -1, selectionExtent: -1),
      );
      expect(state.selection, const NoteSelection.collapsed(3));
      final PhotoEdit edit = photoInsertion(
        state.source,
        photoTargetAt(state.source, state.tree, state.selection.end),
        <String>[prefixOf(photoIdA)],
      );
      expect(edit.changes.apply(state.source), 'one\n$_a\n');
    });

    test('several picks land as consecutive photo lines in pick order', () {
      final (String source, NoteSelection _) = _insert('one', 3, <String>[
        prefixOf(photoIdA),
        prefixOf(photoIdB),
      ]);
      expect(source, 'one\n$_a\n$_b\n');
      expect(_references(source), <String>[
        prefixOf(photoIdA),
        prefixOf(photoIdB),
      ]);
    });

    test('an empty pick leaves the value untouched', () async {
      const String source = 'one';
      final EditorState state = _state(
        source,
        selection: const NoteSelection.collapsed(3),
      );
      expect(
        () => photoInsertion(
          source,
          photoTargetAt(source, state.tree, 3),
          const <String>[],
        ),
        throwsArgumentError,
      );
      final List<PhotoImportOutcome> outcomes = <PhotoImportOutcome>[];
      final PhotoImportFlow flow = PhotoImportFlow(
        readState: () => state,
        onOutcome: outcomes.add,
      );
      await flow.importAtCaret(() async => const <String>[]);
      expect(outcomes, isEmpty);
      expect(flow.placeholders, isEmpty);
      flow.dispose();
    });

    test('setPhotoSize rewrites only the title slot', () {
      final EditorState state = _state('before\n$_a\nafter');
      final Transaction transaction = setPhotoSize(
        state,
        _photos(state.tree).single,
        MdPhotoSize.large,
      )!;
      expect(
        transaction.changes.apply(state.source),
        'before\n![](photo/a1b2c3d4e5f6 "right large")\nafter',
      );
      final TextReplacement replacement =
          transaction.changes.replacements.single;
      expect(replacement.from, greaterThanOrEqualTo(31));
      expect(replacement.to, lessThanOrEqualTo(43));
    });

    test('setPhotoSide rewrites only the title slot', () {
      final EditorState state = _state('before\n$_a\nafter');
      final String written = _applied(
        state,
        setPhotoSide(state, _photos(state.tree).single, MdPhotoSide.left),
      );
      expect(written, 'before\n![](photo/a1b2c3d4e5f6 "left medium")\nafter');
      expect(written.startsWith('before\n'), isTrue);
      expect(written.endsWith('\nafter'), isTrue);
    });

    test('a caret after the photo shifts by exactly the rewrite length', () {
      final EditorState state = _state('before\n$_a\nafter');
      final Transaction transaction = setPhotoSize(
        state,
        _photos(state.tree).single,
        MdPhotoSize.small,
      )!;
      final int mapped = transaction.changes.mapPosition(
        48,
        side: MapSide.after,
      );
      expect(mapped, 47);
      expect(transaction.changes.apply(state.source).substring(mapped), 'ter');
    });

    test('a caret at the end of the photo line stays at its end', () {
      final EditorState state = _state('before\n$_a\nafter');
      final Transaction transaction = setPhotoSize(
        state,
        _photos(state.tree).single,
        MdPhotoSize.full,
      )!;
      expect(transaction.changes.mapPosition(45, side: MapSide.after), 43);
      _expectSelection(transaction.selection, 7, 43);
    });

    test('attribute words it does not know are dropped by a rewrite', () {
      final EditorState state = _state(
        '![](photo/a1b2c3d4e5f6 "left small nofloat")',
      );
      expect(
        _applied(
          state,
          setPhotoSize(state, _photos(state.tree).single, MdPhotoSize.large),
        ),
        '![](photo/a1b2c3d4e5f6 "centre large")',
      );
    });

    test('setting a side on an invalid placement writes a valid one', () {
      final EditorState state = _state('![](photo/a1b2c3d4e5f6 "right huge")');
      expect(
        _applied(
          state,
          setPhotoSide(state, _photos(state.tree).single, MdPhotoSide.left),
        ),
        '![](photo/a1b2c3d4e5f6 "left medium")',
      );
    });

    test('setPhotoCaption writes the alt slot, sanitised and trimmed', () {
      final EditorState state = _state('before\n$_a\nafter');
      final String written = _applied(
        state,
        setPhotoCaption(
          state,
          _photos(state.tree).single,
          '  the [old] porch\nat dusk  ',
        ),
      );
      final List<MdBlock> photos = _photos(parseNoteTree(written));
      expect(photos, hasLength(1));
      final MdPhotoLine line = MdPhotoLine.ofBlock(photos.single, written);
      expect(line.caption, 'the [old porch at dusk');
      expect(line.title, 'right medium');
    });

    test(
      'replacePhotoReference swaps the photo and keeps caption and placement',
      () {
        final EditorState state = _state(_c);
        expect(
          _applied(
            state,
            replacePhotoReference(
              state,
              _photos(state.tree).single,
              prefixOf(photoIdB),
            ),
          ),
          '![porch light](photo/b2c3d4e5f6a1 "right medium")',
        );
      },
    );

    test('selectPhotoLine puts the caret on that photo', () {
      final String source = '$_a\ntext\n$_b';
      final MdBlock second = _photos(parseNoteTree(source))[1];
      final NoteSelection selection = photoSelection(source, second);
      expect(selection, const NoteSelection(anchor: 44, head: 82));
      final EditorState state = _state(source, selection: selection);
      expect(state.source, source);
      expect(selectedPhoto(state), second);
    });

    test(
      'moves past the neighbouring line and keeps the blank lines in place',
      () {
        final EditorState state = _state('one\n\n$_a\n\ntwo');
        final Transaction transaction = movePhotoUp(
          state,
          _photos(state.tree).single,
        )!;
        expect(transaction.changes.apply(state.source), '$_a\none\n\ntwo');
        _expectSelection(transaction.selection, 0, 38);
      },
    );

    test('up then down is an exact round trip, caret included', () {
      final String original = 'A\n$_p\n\nB';
      final EditorState start = _state(original);
      final Transaction down = movePhotoDown(
        start,
        _photos(start.tree).single,
      )!;
      final EditorState moved = start.apply(down);
      expect(moved.source, 'A\n\nB\n$_p');
      _expectSelection(down.selection, 5, 29);
      final Transaction up = movePhotoUp(moved, _photos(moved.tree).single)!;
      expect(up.changes.apply(moved.source), original);
      _expectSelection(up.selection, 2, 26);

      final EditorState other = _state('one\ntwo\n$_a\nthree\n\nfour');
      expect(
        _applied(other, movePhotoUp(other, _photos(other.tree).single)),
        '$_a\none\ntwo\n\nthree\n\nfour',
      );
    });

    test('splits a multi-line paragraph one line at a time', () {
      final EditorState state = _state('one\ntwo\nthree\n$_a');
      expect(
        _applied(state, movePhotoUp(state, _photos(state.tree).single)),
        '$_a\none\ntwo\nthree',
      );
    });

    test('steps over a code fence whole instead of falling into it', () {
      final EditorState state = _state('para\n```\ncode\n```\n$_a');
      final String moved = _applied(
        state,
        movePhotoUp(state, _photos(state.tree).single),
      );
      expect(moved, 'para\n$_a\n```\ncode\n```');
      expect(_photos(parseNoteTree(moved)), hasLength(1));
    });

    test('two adjacent photos trade places', () {
      final EditorState state = _state('$_a\n$_b');
      final Transaction transaction = movePhotoDown(
        state,
        _photos(state.tree).first,
      )!;
      expect(transaction.changes.apply(state.source), '$_b\n$_a');
      _expectSelection(transaction.selection, 39, 77);
    });

    test('the first photo cannot move up and the last cannot move down', () {
      final EditorState state = _state('$_a\nmiddle\n$_b');
      final List<MdBlock> photos = _photos(state.tree);
      expect(canMovePhotoUp(state, photos.first), isFalse);
      expect(canMovePhotoDown(state, photos.first), isTrue);
      expect(canMovePhotoUp(state, photos.last), isTrue);
      expect(canMovePhotoDown(state, photos.last), isFalse);
      expect(movePhotoUp(state, photos.first), isNull);
      expect(movePhotoDown(state, photos.last), isNull);
    });

    test(
      'the removed text reinserted at its offset is the source, byte for byte',
      () {
        _checkPhotoRemovalRoundTrips();
      },
    );

    test('restore gives back the exact value, caret included', () {
      for (final String source in _removalCorpus()) {
        for (final MdBlock photo in _photos(parseNoteTree(source))) {
          final NoteSelection selection = photoSelection(source, photo);
          final EditorState state = _state(source, selection: selection);
          final EditorState restored = state
              .apply(removePhoto(state, photo).transaction)
              .undo();
          expect(restored.source, source, reason: source);
          expect(restored.selection, selection, reason: source);
        }
      }
    });

    test('a middle photo takes its own newline with it', () {
      final EditorState state = _state('one\n$_a\ntwo');
      final EditorState removed = state.apply(
        removePhoto(state, _photos(state.tree).single).transaction,
      );
      expect(removed.source, 'one\n\ntwo');
      expect(removed.selection, const NoteSelection.collapsed(5));
    });

    test(
      'a last photo takes the newline before it, so no blank line is left',
      () {
        final EditorState state = _state('one\n$_a');
        final EditorState removed = state.apply(
          removePhoto(state, _photos(state.tree).single).transaction,
        );
        expect(removed.source, 'one');
        expect(removed.selection, const NoteSelection.collapsed(3));
      },
    );

    test(
      'after an intervening edit, restore puts the photo back as a line',
      () {
        final EditorState state = _state('one\n$_a\ntwo');
        final EditorState removed = state.apply(
          removePhoto(state, _photos(state.tree).single).transaction,
        );
        expect(removed.source, 'one\n\ntwo');
        final EditorState edited = removed.apply(
          Transaction(
            changes: ChangeSet.single(8, 8, 8, '!'),
            selection: const NoteSelection.collapsed(9),
            event: TransactionEvent.external,
            addToHistory: false,
          ),
        );
        expect(edited.source, 'one\n\ntwo!');
        final EditorState restored = edited.undo();
        expect(restored.source, 'one\n$_a\ntwo!');
        expect(_photos(restored.tree), hasLength(1));
      },
    );
  });
}
