import 'dart:ui'
    show Locale, Offset, Rect, Size, TextAffinity, TextDirection, TextPosition;

import 'package:field_notes/domain/notes/markdown/syntax_tree.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:flutter/painting.dart' show TextScaler;
import 'package:flutter/rendering.dart' show TextSelectionPoint;
import 'package:flutter_test/flutter_test.dart';

MdTree _helloTree() => MdTree(
  sourceLength: 5,
  blocks: <MdBlock>[
    MdBlock(
      kind: MdBlockKind.paragraph,
      sourceRange: const MdRange(0, 5),
      contentRange: const MdRange(0, 5),
      inlines: <MdInline>[
        MdInline(
          kind: MdInlineKind.text,
          sourceRange: const MdRange(0, 5),
          contentRange: const MdRange(0, 5),
        ),
      ],
    ),
  ],
);

VisibleText _helloVisible({int? activeLine}) => VisibleText(
  text: 'Hello',
  sourceLength: 5,
  lines: <VisibleLine>[
    VisibleLine(
      sourceLine: 0,
      sourceRange: const MdRange(0, 5),
      visibleRange: const MdRange(0, 5),
      spans: const <VisibleSpan>[
        VisibleSpan(
          kind: VisibleSpanKind.text,
          visibleRange: MdRange(0, 5),
          sourceRange: MdRange(0, 5),
        ),
      ],
    ),
  ],
  atomics: const <AtomicObject>[],
  activeLine: activeLine,
);

Map<String, Size> _fixtureMedia() => <String, Size>{
  'abc123abc123': const Size(4000, 3000),
  'def456def456': const Size(3000, 2000),
};

LayoutInputs _inputs({
  String source = 'Hello',
  MdTree? tree,
  VisibleText? visibleText,
  int? activeLine,
  double columnWidth = 688,
  TextScaler textScaler = TextScaler.noScaling,
  bool boldText = false,
  Locale locale = const Locale('en'),
  bool readerMode = false,
  Map<String, Size>? mediaDimensions,
  Set<String> unavailableMedia = const <String>{},
}) => LayoutInputs(
  source: source,
  tree: tree ?? _helloTree(),
  visibleText: visibleText ?? _helloVisible(activeLine: activeLine),
  activeLine: activeLine,
  columnWidth: columnWidth,
  textScaler: textScaler,
  boldText: boldText,
  locale: locale,
  readerMode: readerMode,
  mediaDimensions: mediaDimensions ?? _fixtureMedia(),
  unavailableMedia: unavailableMedia,
);

void _expectEqual(Object a, Object b) {
  expect(a, equals(b));
  expect(a.hashCode, b.hashCode);
}

void _expectEachDiffers(Object base, List<Object> variants) {
  for (final Object variant in variants) {
    expect(base == variant, isFalse, reason: '$base against $variant');
  }
}

const LineBox _lineBox = LineBox(
  rect: Rect.fromLTWH(0, 0, 688, 25.6),
  baseline: 20,
);

const TextSelectionPoint _startPoint = TextSelectionPoint(
  Offset(0, 25.6),
  TextDirection.ltr,
);

const TextSelectionPoint _endPoint = TextSelectionPoint(
  Offset(40, 25.6),
  TextDirection.ltr,
);

const PhotoRect _photo = PhotoRect(
  sourceRange: MdRange(6, 30),
  reference: 'abc123abc123',
  occurrence: 0,
  rect: Rect.fromLTWH(0, 0, 344, 290),
  imageRect: Rect.fromLTWH(0, 0, 344, 258),
  flow: PhotoFlow.floatLeft,
);

const FragmentInfo _fragment = FragmentInfo(
  blockIndex: 0,
  sourceRange: MdRange(0, 5),
  visibleRange: MdRange(0, 5),
  lineBox: _lineBox,
  besideFloat: false,
);

const SelectionEndpoints _endpoints = SelectionEndpoints(
  start: _startPoint,
  end: _endPoint,
  startLineHeight: 25.6,
  endLineHeight: 25.6,
);

LineBox _box({
  Rect rect = const Rect.fromLTWH(0, 0, 688, 25.6),
  double baseline = 20,
}) => LineBox(rect: rect, baseline: baseline);

FragmentInfo _frag({
  int blockIndex = 0,
  MdRange sourceRange = const MdRange(0, 5),
  MdRange visibleRange = const MdRange(0, 5),
  LineBox? lineBox,
  bool besideFloat = false,
}) => FragmentInfo(
  blockIndex: blockIndex,
  sourceRange: sourceRange,
  visibleRange: visibleRange,
  lineBox: lineBox ?? _box(),
  besideFloat: besideFloat,
);

PhotoRect _photoRect({
  MdRange sourceRange = const MdRange(6, 30),
  String reference = 'abc123abc123',
  int occurrence = 0,
  Rect rect = const Rect.fromLTWH(0, 0, 344, 290),
  Rect imageRect = const Rect.fromLTWH(0, 0, 344, 258),
  PhotoFlow flow = PhotoFlow.floatLeft,
}) => PhotoRect(
  sourceRange: sourceRange,
  reference: reference,
  occurrence: occurrence,
  rect: rect,
  imageRect: imageRect,
  flow: flow,
);

SelectionEndpoints _ends({
  TextSelectionPoint start = _startPoint,
  TextSelectionPoint end = _endPoint,
  double startLineHeight = 25.6,
  double endLineHeight = 25.6,
}) => SelectionEndpoints(
  start: start,
  end: end,
  startLineHeight: startLineHeight,
  endLineHeight: endLineHeight,
);

final class _FakeNoteLayout implements NoteLayout {
  _FakeNoteLayout(this.inputs);

  @override
  final LayoutInputs inputs;

  @override
  Size get size => const Size(688, 25.6);

  @override
  List<PhotoRect> get photoRects => const <PhotoRect>[_photo];

  @override
  List<FragmentInfo> get fragments => const <FragmentInfo>[_fragment];

  @override
  Rect caretRect(int position, TextAffinity affinity) =>
      position == 3 && affinity == TextAffinity.downstream
      ? const Rect.fromLTWH(24, 0, 2, 25.6)
      : Rect.zero;

  @override
  List<Rect> selectionBoxes(NoteSelection selection) =>
      selection == const NoteSelection(anchor: 0, head: 5)
      ? const <Rect>[Rect.fromLTWH(0, 0, 40, 25.6)]
      : const <Rect>[];

  @override
  SelectionEndpoints selectionEndpoints(NoteSelection selection) => _endpoints;

  @override
  Rect rangeBounds(MdRange range) => range == const MdRange(0, 5)
      ? const Rect.fromLTWH(0, 0, 40, 25.6)
      : Rect.zero;

  @override
  LineBox lineBoxAt(int position, TextAffinity affinity) =>
      position == 3 && affinity == TextAffinity.upstream
      ? _lineBox
      : const LineBox(rect: Rect.zero, baseline: 0);

  @override
  TextPosition positionAt(Offset point) => point == const Offset(10, 4)
      ? const TextPosition(offset: 1, affinity: TextAffinity.upstream)
      : const TextPosition(offset: 0);

  @override
  MdRange wordBoundary(int position) => const MdRange(0, 5);

  @override
  MdRange lineBoundary(int position, TextAffinity affinity) =>
      affinity == TextAffinity.downstream
      ? const MdRange(0, 5)
      : const MdRange(0, 0);

  @override
  MdRange paragraphBoundary(int position) => const MdRange(0, 5);

  @override
  MdRange get documentBoundary => MdRange(0, inputs.source.length);

  @override
  TextPosition verticalTarget(
    int position,
    TextAffinity affinity,
    double goalX,
    VerticalMove direction,
  ) =>
      position == 3 &&
          affinity == TextAffinity.upstream &&
          goalX == 42.0 &&
          direction == VerticalMove.down
      ? const TextPosition(offset: 5)
      : const TextPosition(offset: 0);
}

void main() {
  test('layout value types compare by value', () {
    _expectEqual(_box(), _box());
    _expectEachDiffers(_box(), <Object>[
      _box(rect: const Rect.fromLTWH(0, 0, 688, 26.1)),
      _box(baseline: 20.5),
    ]);

    _expectEqual(_frag(), _frag());
    _expectEachDiffers(_frag(), <Object>[
      _frag(blockIndex: 1),
      _frag(sourceRange: const MdRange(0, 4)),
      _frag(visibleRange: const MdRange(1, 5)),
      _frag(lineBox: _box(baseline: 21)),
      _frag(besideFloat: true),
    ]);

    _expectEqual(_photoRect(), _photoRect());
    _expectEachDiffers(_photoRect(), <Object>[
      _photoRect(sourceRange: const MdRange(6, 31)),
      _photoRect(reference: 'def456def456'),
      _photoRect(occurrence: 1),
      _photoRect(rect: const Rect.fromLTWH(0, 0, 344, 290.5)),
      _photoRect(imageRect: const Rect.fromLTWH(0, 0, 344, 258.5)),
      _photoRect(flow: PhotoFlow.block),
    ]);

    _expectEqual(_ends(), _ends());
    _expectEachDiffers(_ends(), <Object>[
      _ends(
        start: const TextSelectionPoint(Offset(0.5, 25.6), TextDirection.ltr),
      ),
      _ends(end: const TextSelectionPoint(Offset(40, 25.6), TextDirection.rtl)),
      _ends(startLineHeight: 30),
      _ends(endLineHeight: 30),
    ]);

    final LayoutInputs base = _inputs();
    _expectEqual(base, _inputs());
    _expectEqual(
      base,
      _inputs(
        mediaDimensions: <String, Size>{
          'def456def456': const Size(3000, 2000),
          'abc123abc123': const Size(4000, 3000),
        },
      ),
    );
    _expectEachDiffers(base, <Object>[
      _inputs(
        source: 'Hellp',
        visibleText: VisibleText(
          text: 'Hellp',
          sourceLength: 5,
          lines: _helloVisible().lines,
          atomics: const <AtomicObject>[],
        ),
      ),
      _inputs(
        tree: MdTree(
          sourceLength: 5,
          blocks: <MdBlock>[
            MdBlock(
              kind: MdBlockKind.paragraph,
              sourceRange: const MdRange(0, 5),
              contentRange: const MdRange(0, 5),
            ),
          ],
        ),
      ),
      _inputs(activeLine: 0),
      _inputs(columnWidth: 688.5),
      _inputs(textScaler: const TextScaler.linear(1.5)),
      _inputs(boldText: true),
      _inputs(locale: const Locale('fr')),
      _inputs(readerMode: true),
      _inputs(
        mediaDimensions: <String, Size>{
          'abc123abc123': const Size(4000, 3000),
          'def456def456': const Size(3000, 2001),
        },
      ),
      _inputs(
        mediaDimensions: <String, Size>{'abc123abc123': const Size(4000, 3000)},
      ),
      _inputs(unavailableMedia: <String>{'abc123abc123'}),
    ]);
  });

  test('the layout interface names every l8 query', () {
    final LayoutInputs inputs = _inputs();
    final NoteLayout layout = _FakeNoteLayout(inputs);
    const NoteSelection selection = NoteSelection(anchor: 0, head: 5);

    expect(
      layout.caretRect(3, TextAffinity.downstream),
      const Rect.fromLTWH(24, 0, 2, 25.6),
    );
    expect(layout.selectionBoxes(selection), const <Rect>[
      Rect.fromLTWH(0, 0, 40, 25.6),
    ]);
    expect(layout.selectionEndpoints(selection), _endpoints);
    expect(
      layout.rangeBounds(const MdRange(0, 5)),
      const Rect.fromLTWH(0, 0, 40, 25.6),
    );
    expect(layout.lineBoxAt(3, TextAffinity.upstream), _lineBox);
    expect(
      layout.positionAt(const Offset(10, 4)),
      const TextPosition(offset: 1, affinity: TextAffinity.upstream),
    );
    expect(layout.wordBoundary(3), const MdRange(0, 5));
    expect(
      layout.lineBoundary(3, TextAffinity.downstream),
      const MdRange(0, 5),
    );
    expect(layout.paragraphBoundary(3), const MdRange(0, 5));
    expect(layout.documentBoundary, const MdRange(0, 5));
    expect(
      layout.verticalTarget(3, TextAffinity.upstream, 42.0, VerticalMove.down),
      const TextPosition(offset: 5),
    );
    expect(layout.size, const Size(688, 25.6));
    expect(layout.photoRects, const <PhotoRect>[_photo]);
    expect(layout.fragments, const <FragmentInfo>[_fragment]);
    expect(layout.inputs, same(inputs));
    expect(layout.inputs, _inputs());
  });

  group('LayoutInputs validation', () {
    test('reader mode rejects an active line', () {
      expect(
        () => _inputs(readerMode: true, activeLine: 0),
        throwsArgumentError,
      );
      expect(
        () => LayoutInputs(
          source: 'Hello',
          tree: _helloTree(),
          visibleText: _helloVisible(activeLine: 0),
          activeLine: 0,
          columnWidth: 688,
          textScaler: TextScaler.noScaling,
          boldText: false,
          locale: const Locale('en'),
          readerMode: true,
          mediaDimensions: _fixtureMedia(),
        ),
        throwsArgumentError,
      );
      expect(_inputs(readerMode: true).readerMode, isTrue);
    });

    test('mismatched source lengths throw', () {
      expect(
        () => _inputs(tree: MdTree(sourceLength: 4, blocks: const <MdBlock>[])),
        throwsArgumentError,
      );
      expect(
        () => _inputs(
          source: 'Hello!',
          tree: MdTree(sourceLength: 6, blocks: const <MdBlock>[]),
        ),
        throwsArgumentError,
      );
      expect(() => _inputs(source: 'Hell'), throwsArgumentError);
    });

    test('a visible text for another active line throws', () {
      expect(
        () => _inputs(visibleText: _helloVisible(activeLine: 0)),
        throwsArgumentError,
      );
      expect(
        () => _inputs(activeLine: 0, visibleText: _helloVisible()),
        throwsArgumentError,
      );
    });

    test('a zero, negative or non-finite column width throws', () {
      for (final double width in <double>[0, -1, double.infinity, double.nan]) {
        expect(() => _inputs(columnWidth: width), throwsArgumentError);
      }
    });
  });

  test('LayoutInputs keeps unmodifiable copies of its media', () {
    final Map<String, Size> media = _fixtureMedia();
    final Set<String> unavailable = <String>{'def456def456'};
    final LayoutInputs inputs = _inputs(
      mediaDimensions: media,
      unavailableMedia: unavailable,
    );

    media['ghi789ghi789'] = const Size(10, 10);
    media.remove('abc123abc123');
    unavailable.add('abc123abc123');

    expect(inputs.mediaDimensions, _fixtureMedia());
    expect(inputs.unavailableMedia, <String>{'def456def456'});
    expect(
      () => inputs.mediaDimensions['x'] = const Size(1, 1),
      throwsUnsupportedError,
    );
    expect(() => inputs.unavailableMedia.add('x'), throwsUnsupportedError);
  });
}
