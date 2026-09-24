import 'package:field_notes/domain/notes/markdown/syntax_tree.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:flutter_test/flutter_test.dart';

VisibleSpan _span(VisibleSpanKind kind, int a, int b, int c, int d) =>
    VisibleSpan(
      kind: kind,
      visibleRange: MdRange(a, b),
      sourceRange: MdRange(c, d),
    );

VisibleSpan _text(int a, int b, int c, int d) =>
    _span(VisibleSpanKind.text, a, b, c, d);

VisibleSpan _marker(int a, int b, int c, int d) =>
    _span(VisibleSpanKind.marker, a, b, c, d);

VisibleSpan _break(int a, int b, int c, int d) =>
    _span(VisibleSpanKind.lineBreak, a, b, c, d);

VisibleSpan _atomic(int a, int b, int c, int d) =>
    _span(VisibleSpanKind.atomic, a, b, c, d);

VisibleText _fogOffActive() => VisibleText(
  text: 'The fog lifted',
  sourceLength: 18,
  lines: <VisibleLine>[
    VisibleLine(
      sourceLine: 0,
      sourceRange: const MdRange(0, 18),
      visibleRange: const MdRange(0, 14),
      spans: <VisibleSpan>[
        _text(0, 4, 0, 4),
        _text(4, 7, 6, 9),
        _text(7, 14, 11, 18),
      ],
    ),
  ],
  atomics: const <AtomicObject>[],
);

VisibleText _titleWithActiveBody() => VisibleText(
  text: 'Title\nThe **fog** lifted',
  sourceLength: 26,
  activeLine: 1,
  lines: <VisibleLine>[
    VisibleLine(
      sourceLine: 0,
      sourceRange: const MdRange(0, 8),
      visibleRange: const MdRange(0, 6),
      spans: <VisibleSpan>[_text(0, 5, 2, 7), _break(5, 6, 7, 8)],
    ),
    VisibleLine(
      sourceLine: 1,
      sourceRange: const MdRange(8, 26),
      visibleRange: const MdRange(6, 24),
      spans: <VisibleSpan>[
        _text(6, 10, 8, 12),
        _marker(10, 12, 12, 14),
        _text(12, 15, 14, 17),
        _marker(15, 17, 17, 19),
        _text(17, 24, 19, 26),
      ],
    ),
  ],
  atomics: const <AtomicObject>[],
);

const AtomicObject _photo = AtomicObject(
  kind: AtomicKind.photo,
  sourceRange: MdRange(2, 26),
  visibleOffset: 2,
);

VisibleText _photoNote() => VisibleText(
  text: 'A\n\uFFFC\nB',
  sourceLength: 28,
  lines: <VisibleLine>[
    VisibleLine(
      sourceLine: 0,
      sourceRange: const MdRange(0, 2),
      visibleRange: const MdRange(0, 2),
      spans: <VisibleSpan>[_text(0, 1, 0, 1), _break(1, 2, 1, 2)],
    ),
    VisibleLine(
      sourceLine: 1,
      sourceRange: const MdRange(2, 27),
      visibleRange: const MdRange(2, 4),
      spans: <VisibleSpan>[_atomic(2, 3, 2, 26), _break(3, 4, 26, 27)],
    ),
    VisibleLine(
      sourceLine: 2,
      sourceRange: const MdRange(27, 28),
      visibleRange: const MdRange(4, 5),
      spans: <VisibleSpan>[_text(4, 5, 27, 28)],
    ),
  ],
  atomics: const <AtomicObject>[_photo],
);

VisibleText _crlfNote() => VisibleText(
  text: 'A\nB',
  sourceLength: 4,
  lines: <VisibleLine>[
    VisibleLine(
      sourceLine: 0,
      sourceRange: const MdRange(0, 3),
      visibleRange: const MdRange(0, 2),
      spans: <VisibleSpan>[_text(0, 1, 0, 1), _break(1, 2, 1, 3)],
    ),
    VisibleLine(
      sourceLine: 1,
      sourceRange: const MdRange(3, 4),
      visibleRange: const MdRange(2, 3),
      spans: <VisibleSpan>[_text(2, 3, 3, 4)],
    ),
  ],
  atomics: const <AtomicObject>[],
);

const AtomicObject _box = AtomicObject(
  kind: AtomicKind.checkbox,
  sourceRange: MdRange(2, 6),
  visibleOffset: 0,
  visibleLength: 2,
);

VisibleText _taskOffActive() => VisibleText(
  text: '\u2611 pack',
  sourceLength: 10,
  lines: <VisibleLine>[
    VisibleLine(
      sourceLine: 0,
      sourceRange: const MdRange(0, 10),
      visibleRange: const MdRange(0, 6),
      spans: <VisibleSpan>[_atomic(0, 2, 2, 6), _text(2, 6, 6, 10)],
    ),
  ],
  atomics: const <AtomicObject>[_box],
);

VisibleText _singleLine(
  String text,
  int sourceLength,
  List<VisibleSpan> spans, {
  List<AtomicObject> atomics = const <AtomicObject>[],
}) => VisibleText(
  text: text,
  sourceLength: sourceLength,
  lines: <VisibleLine>[
    VisibleLine(
      sourceLine: 0,
      sourceRange: MdRange(0, sourceLength),
      visibleRange: MdRange(0, text.length),
      spans: spans,
    ),
  ],
  atomics: atomics,
);

final class _FixedProjector implements VisibleProjector {
  const _FixedProjector(this.value);

  final VisibleText value;

  @override
  VisibleText project(String source, MdTree tree, int? activeLine) => value;
}

final class _CellProjector implements VisibleProjector {
  const _CellProjector(this.withCell, this.withoutCell);

  final VisibleText withCell;
  final VisibleText withoutCell;

  @override
  VisibleText project(
    String source,
    MdTree tree,
    int? activeLine, {
    int? activeCell,
  }) => activeCell == null ? withoutCell : withCell;
}

void main() {
  test(
    'a visible text maps a hidden range to both of its source boundaries',
    () {
      final OffsetMap map = _fogOffActive().map;
      expect(map.visibleToSource(7), const SourceOffsets(9, 11));
      expect(map.visibleToSource(4), const SourceOffsets(4, 6));
      expect(map.visibleToSource(5), const SourceOffsets(7, 7));
      expect(map.visibleToSource(0), const SourceOffsets(0, 0));
      expect(map.visibleToSource(14), const SourceOffsets(18, 18));
      for (final int source in <int>[4, 5, 6]) {
        expect(map.sourceToVisible(source), 4, reason: 'source $source');
      }
      for (final int source in <int>[9, 10, 11]) {
        expect(map.sourceToVisible(source), 7, reason: 'source $source');
      }
      expect(map.sourceToVisible(12), 8);
      expect(map.sourceToVisible(18), 14);

      final VisibleText active = _titleWithActiveBody();
      expect(active.map.visibleToSource(0), const SourceOffsets(0, 2));
      expect(active.map.visibleToSource(11), const SourceOffsets(13, 13));
      final List<VisibleSpan> dimmed = <VisibleSpan>[
        for (final VisibleLine line in active.lines)
          for (final VisibleSpan span in line.spans)
            if (span.dimmed) span,
      ];
      expect(dimmed, <VisibleSpan>[
        _marker(10, 12, 12, 14),
        _marker(15, 17, 17, 19),
      ]);
    },
  );

  test('an atomic object maps as one unit', () {
    final VisibleText photo = _photoNote();
    expect(photo.map.visibleToSource(2), const SourceOffsets(2, 2));
    expect(photo.map.visibleToSource(3), const SourceOffsets(26, 26));
    expect(photo.map.sourceToVisible(2), 2);
    expect(photo.map.sourceToVisible(14), 2);
    expect(photo.map.sourceToVisible(26), 3);
    expect(photo.atomicAtVisible(2), _photo);
    expect(photo.atomicAtSource(14), _photo);
    expect(photo.atomicAtVisible(3), isNull);

    final VisibleText crlf = _crlfNote();
    expect(crlf.map.sourceToVisible(2), 1);
    expect(crlf.map.visibleToSource(2), const SourceOffsets(3, 3));

    final VisibleText task = _taskOffActive();
    expect(task.map.visibleToSource(1), const SourceOffsets(2, 6));
    expect(task.map.visibleToSource(0), const SourceOffsets(0, 2));
    expect(task.map.sourceToVisible(4), 0);
  });

  group('span kinds', () {
    test('only marker spans are dimmed', () {
      expect(_marker(0, 1, 0, 1).dimmed, isTrue);
      expect(_text(0, 1, 0, 1).dimmed, isFalse);
      expect(_break(0, 1, 0, 1).dimmed, isFalse);
      expect(_atomic(0, 1, 0, 1).dimmed, isFalse);
    });

    test('line breaks and atomics map as a unit', () {
      expect(_break(0, 1, 0, 2).mapsAsUnit, isTrue);
      expect(_atomic(0, 1, 0, 5).mapsAsUnit, isTrue);
      expect(_text(0, 1, 0, 1).mapsAsUnit, isFalse);
      expect(_marker(0, 1, 0, 1).mapsAsUnit, isFalse);
    });

    test('an atomic object reports its visible range', () {
      expect(_box.visibleRange, const MdRange(0, 2));
      expect(_photo.visibleRange, const MdRange(2, 3));
    });
  });

  test(
    'the active task line dims its list marker and keeps the box atomic',
    () {
      final VisibleText value = _singleLine(
        '- \u2611 pack',
        10,
        <VisibleSpan>[
          _marker(0, 2, 0, 2),
          _atomic(2, 4, 2, 6),
          _text(4, 8, 6, 10),
        ],
        atomics: const <AtomicObject>[
          AtomicObject(
            kind: AtomicKind.checkbox,
            sourceRange: MdRange(2, 6),
            visibleOffset: 2,
            visibleLength: 2,
          ),
        ],
      );
      final List<VisibleSpan> spans = value.lines.single.spans;
      expect(spans[0].dimmed, isTrue);
      expect(spans[1].dimmed, isFalse);
      expect(spans[1].mapsAsUnit, isTrue);
      expect(value.atomicAtVisible(3)?.kind, AtomicKind.checkbox);
      expect(value.atomicAtVisible(1), isNull);
      expect(value.map.visibleToSource(1), const SourceOffsets(1, 1));
      expect(value.map.visibleToSource(3), const SourceOffsets(2, 6));
      expect(value.map.sourceToVisible(6), 4);
    },
  );

  test('an empty visible text maps visible 0 across the whole source', () {
    final VisibleText empty = VisibleText(
      text: '',
      sourceLength: 7,
      lines: const <VisibleLine>[],
      atomics: const <AtomicObject>[],
    );
    expect(empty.map.visibleToSource(0), const SourceOffsets(0, 7));
    for (int s = 0; s <= 7; s++) {
      expect(empty.map.sourceToVisible(s), 0);
    }
    expect(empty.atomicAtVisible(0), isNull);
    expect(empty.atomicAtSource(3), isNull);
  });

  test('an empty last line has no spans and an empty visible range', () {
    final VisibleText value = VisibleText(
      text: 'a\n',
      sourceLength: 2,
      lines: <VisibleLine>[
        VisibleLine(
          sourceLine: 0,
          sourceRange: const MdRange(0, 2),
          visibleRange: const MdRange(0, 2),
          spans: <VisibleSpan>[_text(0, 1, 0, 1), _break(1, 2, 1, 2)],
        ),
        VisibleLine(
          sourceLine: 1,
          sourceRange: const MdRange(2, 2),
          visibleRange: const MdRange(2, 2),
          spans: const <VisibleSpan>[],
        ),
      ],
      atomics: const <AtomicObject>[],
    );
    expect(value.map.visibleToSource(2), const SourceOffsets(2, 2));
    expect(value.map.sourceToVisible(2), 2);
  });

  test('an emoji sequence inside a text span maps code unit by code unit', () {
    const String emoji = '\u{1F469}\u200D\u{1F467}';
    final VisibleText value = _singleLine(emoji, 9, <VisibleSpan>[
      _text(0, 5, 2, 7),
    ]);
    for (int v = 1; v < 5; v++) {
      expect(value.map.visibleToSource(v), SourceOffsets(v + 2, v + 2));
      expect(value.map.sourceToVisible(v + 2), v);
    }
    expect(value.map.visibleToSource(0), const SourceOffsets(0, 2));
    expect(value.map.visibleToSource(5), const SourceOffsets(7, 9));
  });

  group('validation', () {
    void rejects(VisibleText Function() build) {
      expect(build, throwsArgumentError);
    }

    test('overlapping visible ranges are rejected', () {
      rejects(
        () => _singleLine('abcd', 4, <VisibleSpan>[
          _text(0, 3, 0, 3),
          _text(2, 4, 3, 5),
        ]),
      );
    });

    test('a gap between visible ranges is rejected', () {
      rejects(
        () => _singleLine('abcd', 4, <VisibleSpan>[
          _text(0, 1, 0, 1),
          _text(2, 4, 2, 4),
        ]),
      );
    });

    test('a zero-width span is rejected', () {
      rejects(
        () => _singleLine('ab', 4, <VisibleSpan>[
          _text(0, 1, 0, 1),
          _marker(1, 1, 1, 1),
          _text(1, 2, 3, 4),
        ]),
      );
      rejects(
        () => _singleLine('ab', 4, <VisibleSpan>[
          _text(0, 1, 0, 1),
          _atomic(1, 2, 2, 2),
        ]),
      );
    });

    test('unordered or overlapping source ranges are rejected', () {
      rejects(
        () => _singleLine('ab', 4, <VisibleSpan>[
          _text(0, 1, 2, 3),
          _text(1, 2, 0, 1),
        ]),
      );
      rejects(
        () => _singleLine('abc', 4, <VisibleSpan>[
          _text(0, 2, 0, 2),
          _text(2, 3, 1, 2),
        ]),
      );
    });

    test('a source range past the source length is rejected', () {
      rejects(
        () => VisibleText(
          text: 'ab',
          sourceLength: 2,
          lines: <VisibleLine>[
            VisibleLine(
              sourceLine: 0,
              sourceRange: const MdRange(0, 3),
              visibleRange: const MdRange(0, 2),
              spans: <VisibleSpan>[_text(0, 2, 1, 3)],
            ),
          ],
          atomics: const <AtomicObject>[],
        ),
      );
    });

    test('a text span with unequal lengths is rejected', () {
      rejects(() => _singleLine('ab', 3, <VisibleSpan>[_text(0, 2, 0, 3)]));
    });

    test('a line break of visible length 2 is rejected', () {
      rejects(() => _singleLine('\n\n', 2, <VisibleSpan>[_break(0, 2, 0, 2)]));
    });

    test('a line break over three source units is rejected', () {
      rejects(() => _singleLine('\n', 3, <VisibleSpan>[_break(0, 1, 0, 3)]));
    });

    test('text length disagreeing with the spans is rejected', () {
      rejects(() => _singleLine('abc', 3, <VisibleSpan>[_text(0, 2, 0, 2)]));
    });

    test('an atomics list disagreeing with the atomic spans is rejected', () {
      rejects(
        () => _singleLine('\uFFFC', 4, <VisibleSpan>[
          _atomic(0, 1, 0, 4),
        ], atomics: const <AtomicObject>[]),
      );
      rejects(
        () => _singleLine(
          '\uFFFC',
          4,
          <VisibleSpan>[_atomic(0, 1, 0, 4)],
          atomics: const <AtomicObject>[
            AtomicObject(
              kind: AtomicKind.divider,
              sourceRange: MdRange(0, 3),
              visibleOffset: 0,
            ),
          ],
        ),
      );
      rejects(
        () => _singleLine(
          'ab',
          2,
          <VisibleSpan>[_text(0, 2, 0, 2)],
          atomics: const <AtomicObject>[_box],
        ),
      );
    });

    test('lines out of source order are rejected', () {
      rejects(
        () => VisibleText(
          text: 'a\nb',
          sourceLength: 3,
          lines: <VisibleLine>[
            VisibleLine(
              sourceLine: 1,
              sourceRange: const MdRange(0, 2),
              visibleRange: const MdRange(0, 2),
              spans: <VisibleSpan>[_text(0, 1, 0, 1), _break(1, 2, 1, 2)],
            ),
            VisibleLine(
              sourceLine: 1,
              sourceRange: const MdRange(2, 3),
              visibleRange: const MdRange(2, 3),
              spans: <VisibleSpan>[_text(2, 3, 2, 3)],
            ),
          ],
          atomics: const <AtomicObject>[],
        ),
      );
    });

    test('a span outside its line is rejected', () {
      rejects(
        () => VisibleText(
          text: 'ab',
          sourceLength: 2,
          lines: <VisibleLine>[
            VisibleLine(
              sourceLine: 0,
              sourceRange: const MdRange(0, 1),
              visibleRange: const MdRange(0, 1),
              spans: <VisibleSpan>[_text(0, 2, 0, 2)],
            ),
          ],
          atomics: const <AtomicObject>[],
        ),
      );
    });

    test('a negative active line is rejected', () {
      rejects(
        () => VisibleText(
          text: '',
          sourceLength: 0,
          lines: const <VisibleLine>[],
          atomics: const <AtomicObject>[],
          activeLine: -1,
        ),
      );
    });

    test(
      'an offset map rejects spans that do not reach its visible length',
      () {
        expect(
          () => OffsetMap(
            spans: <VisibleSpan>[_text(0, 1, 0, 1)],
            sourceLength: 1,
            visibleLength: 2,
          ),
          throwsArgumentError,
        );
      },
    );
  });

  group('range', () {
    test('visible offsets outside the text throw RangeError', () {
      final OffsetMap map = _fogOffActive().map;
      expect(() => map.visibleToSource(-1), throwsRangeError);
      expect(() => map.visibleToSource(15), throwsRangeError);
    });

    test('source offsets outside the source throw RangeError', () {
      final OffsetMap map = _fogOffActive().map;
      expect(() => map.sourceToVisible(-1), throwsRangeError);
      expect(() => map.sourceToVisible(19), throwsRangeError);
    });
  });

  group('equality', () {
    test('atomic objects compare by value', () {
      const AtomicObject copy = AtomicObject(
        kind: AtomicKind.photo,
        sourceRange: MdRange(2, 26),
        visibleOffset: 2,
      );
      expect(copy, _photo);
      expect(copy.hashCode, _photo.hashCode);
      expect(
        _photo,
        isNot(
          const AtomicObject(
            kind: AtomicKind.divider,
            sourceRange: MdRange(2, 26),
            visibleOffset: 2,
          ),
        ),
      );
      expect(
        _photo,
        isNot(
          const AtomicObject(
            kind: AtomicKind.photo,
            sourceRange: MdRange(2, 26),
            visibleOffset: 2,
            visibleLength: 2,
          ),
        ),
      );
    });

    test('spans compare by value', () {
      expect(_text(0, 1, 2, 3), _text(0, 1, 2, 3));
      expect(_text(0, 1, 2, 3).hashCode, _text(0, 1, 2, 3).hashCode);
      expect(_text(0, 1, 2, 3), isNot(_marker(0, 1, 2, 3)));
      expect(_text(0, 1, 2, 3), isNot(_text(0, 1, 3, 4)));
    });

    test('lines compare by value', () {
      final VisibleLine a = _photoNote().lines[1];
      final VisibleLine b = _photoNote().lines[1];
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(_photoNote().lines[0]));
      expect(
        a,
        isNot(
          VisibleLine(
            sourceLine: 1,
            sourceRange: const MdRange(2, 27),
            visibleRange: const MdRange(2, 4),
            spans: <VisibleSpan>[_atomic(2, 3, 2, 25), _break(3, 4, 26, 27)],
          ),
        ),
      );
    });

    test('source offsets compare by value', () {
      expect(const SourceOffsets(1, 2), const SourceOffsets(1, 2));
      expect(
        const SourceOffsets(1, 2).hashCode,
        const SourceOffsets(1, 2).hashCode,
      );
      expect(const SourceOffsets(1, 2), isNot(const SourceOffsets(2, 1)));
      expect(const SourceOffsets(1, 2).toString(), 'SourceOffsets(1, 2)');
    });

    test('visible texts compare by value', () {
      final VisibleText a = _titleWithActiveBody();
      final VisibleText b = _titleWithActiveBody();
      expect(a, a);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(_photoNote(), _photoNote());
      expect(_photoNote().hashCode, _photoNote().hashCode);
      expect(a, isNot(_fogOffActive()));
      final VisibleText otherActive = VisibleText(
        text: a.text,
        sourceLength: a.sourceLength,
        lines: a.lines,
        atomics: a.atomics,
        activeLine: 0,
      );
      expect(a, isNot(otherActive));
      final VisibleText otherLength = VisibleText(
        text: a.text,
        sourceLength: 27,
        lines: a.lines,
        atomics: a.atomics,
        activeLine: 1,
      );
      expect(a, isNot(otherLength));
    });
  });

  test('lists are unmodifiable copies', () {
    final List<VisibleSpan> spans = <VisibleSpan>[_text(0, 1, 0, 1)];
    final List<VisibleLine> lines = <VisibleLine>[
      VisibleLine(
        sourceLine: 0,
        sourceRange: const MdRange(0, 1),
        visibleRange: const MdRange(0, 1),
        spans: spans,
      ),
    ];
    final List<AtomicObject> atomics = <AtomicObject>[];
    final VisibleText value = VisibleText(
      text: 'a',
      sourceLength: 1,
      lines: lines,
      atomics: atomics,
    );
    spans.add(_text(1, 2, 1, 2));
    lines.clear();
    atomics.add(_photo);
    expect(value.lines.single.spans, hasLength(1));
    expect(value.atomics, isEmpty);
    expect(() => value.lines.add(value.lines.single), throwsUnsupportedError);
    expect(() => value.lines.single.spans.clear(), throwsUnsupportedError);
    expect(() => value.atomics.add(_photo), throwsUnsupportedError);
    expect(() => value.map.spans.clear(), throwsUnsupportedError);
  });

  test('a visible text builds its map once', () {
    final VisibleText value = _photoNote();
    expect(identical(value.map, value.map), isTrue);
    expect(value.map.visibleLength, value.text.length);
    expect(value.map.sourceLength, 28);
  });

  test('a projector implements the interface with a hand-built value', () {
    final VisibleText value = _fogOffActive();
    const String source = 'The **fog** lifted';
    final VisibleProjector projector = _FixedProjector(value);
    final VisibleText projected = projector.project(
      source,
      MdTree(sourceLength: source.length, blocks: const <MdBlock>[]),
      null,
    );
    expect(projected, value);
  });

  test('a projector may add an optional named parameter', () {
    final VisibleText withCell = _crlfNote();
    final VisibleText withoutCell = _fogOffActive();
    final _CellProjector concrete = _CellProjector(withCell, withoutCell);
    final VisibleProjector projector = concrete;
    final MdTree tree = MdTree(sourceLength: 0, blocks: const <MdBlock>[]);
    expect(projector.project('', tree, 0), withoutCell);
    expect(concrete.project('', tree, 0, activeCell: 1), withCell);
  });
}
