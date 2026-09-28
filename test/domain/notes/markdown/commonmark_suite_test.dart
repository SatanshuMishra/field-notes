import 'package:field_notes/domain/notes/markdown/note_tree.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/html_to_tree.dart';

const Set<String> _reasons = <String>{'unsupported', 'html', 'deviation'};

const Set<String> _rules = <String>{'G1', 'G2', 'G3', 'T1', 'V1'};

List<String> _supportedSections(Map<String, Object?> manifest) =>
    List<String>.unmodifiable(
      ((manifest['commonmark']! as Map<String, Object?>)['sections']!
              as List<Object?>)
          .cast<String>(),
    );

List<int> _gfmNumbers(Map<String, Object?> manifest) => List<int>.unmodifiable(
  ((manifest['gfm']! as Map<String, Object?>)['examples']! as List<Object?>)
      .cast<int>(),
);

ShapeNode _text(String text) => ShapeNode('text', text: text);

ShapeNode _paragraph(List<ShapeNode> children) =>
    ShapeNode('paragraph', children: children);

ShapeNode _codeBlock(String info, String text) => ShapeNode(
  'codeBlock',
  attributes: <String, String>{'info': info},
  text: text,
);

List<ShapeNode> _treeShape(String source) =>
    shapeFromTree(parseNoteTree(source), source);

void main() {
  final Map<String, Object?> manifest = loadManifest();
  final List<SpecExample> commonMark = loadSpecExamples(
    'commonmark-0.31.2.json',
  );
  final List<SpecExample> gfm = loadSpecExamples('gfm-0.29-gfm.json');
  final List<String> sections = _supportedSections(manifest);
  final List<Exclusion> commonMarkExclusions = manifestExclusions(
    manifest,
    'commonmark',
  );
  final List<Exclusion> gfmExclusions = manifestExclusions(manifest, 'gfm');
  final Set<int> excludedCommonMark = <int>{
    for (final Exclusion e in commonMarkExclusions) e.number,
  };

  test('commonmark supported sections pass except manifest exclusions', () {
    final List<String> failures = <String>[
      for (final SpecExample example in commonMark)
        if (sections.contains(example.section) &&
            !excludedCommonMark.contains(example.number))
          ?exampleFailure(example, tables: false),
    ];
    expect(
      failures,
      isEmpty,
      reason:
          '${failures.length} supported examples fail:\n'
          '${failures.join('\n')}',
    );
  });

  test('the fixtures hold every example and the supported sections', () {
    expect(commonMark, hasLength(652));
    expect(
      commonMark.where((SpecExample e) => sections.contains(e.section)),
      hasLength(483),
    );
    expect(sections, hasLength(19));
    expect(gfm, hasLength(677));
    expect(
      <int>[for (final SpecExample e in gfm) e.number],
      <int>[for (int n = 1; n <= 677; n++) n],
    );
  });

  test('every manifest exclusion is well formed and in scope', () {
    final Map<int, SpecExample> commonMarkByNumber = <int, SpecExample>{
      for (final SpecExample e in commonMark) e.number: e,
    };
    final List<int> gfmNumbers = _gfmNumbers(manifest);
    for (final Exclusion exclusion in commonMarkExclusions) {
      final SpecExample? example = commonMarkByNumber[exclusion.number];
      expect(example, isNotNull, reason: 'CommonMark ${exclusion.number}');
      expect(
        sections,
        contains(example!.section),
        reason: 'CommonMark ${exclusion.number}',
      );
    }
    for (final Exclusion exclusion in gfmExclusions) {
      expect(gfmNumbers, contains(exclusion.number));
      expect(gfm.any((SpecExample e) => e.number == exclusion.number), isTrue);
    }
    for (final Exclusion exclusion in <Exclusion>[
      ...commonMarkExclusions,
      ...gfmExclusions,
    ]) {
      expect(_reasons, contains(exclusion.reason));
      expect(exclusion.detail.trim(), isNotEmpty);
      if (exclusion.reason == 'deviation') {
        expect(_rules, contains(exclusion.rule));
      } else {
        expect(exclusion.rule, isNull);
      }
    }
    expect(excludedCommonMark, hasLength(commonMarkExclusions.length));
    expect(<int>{
      for (final Exclusion e in gfmExclusions) e.number,
    }, hasLength(gfmExclusions.length));
  });

  test('every excluded example really fails', () {
    final List<int> passing = <int>[
      for (final SpecExample example in commonMark)
        if (excludedCommonMark.contains(example.number) &&
            exampleFailure(example, tables: false) == null)
          example.number,
      for (final Exclusion exclusion in gfmExclusions)
        if (exampleFailure(
              gfm.firstWhere((SpecExample e) => e.number == exclusion.number),
              tables: true,
            ) ==
            null)
          exclusion.number,
    ];
    expect(passing, isEmpty);
  });

  test('the named exclusions are listed with their reasons', () {
    final Map<int, Exclusion> byNumber = <int, Exclusion>{
      for (final Exclusion e in commonMarkExclusions) e.number: e,
    };
    for (final int number in <int>[69, 236, 503, 517, 520, 531]) {
      expect(byNumber[number]?.reason, 'unsupported', reason: '$number');
    }
    for (final int number in <int>[335, 336]) {
      expect(byNumber[number]?.reason, 'deviation', reason: '$number');
      expect(byNumber[number]?.rule, 'V1', reason: '$number');
    }
  });

  test('of CommonMark 62 to 79 only 69 is excluded, as indented code', () {
    final List<Exclusion> inRange = <Exclusion>[
      for (final Exclusion e in commonMarkExclusions)
        if (e.number >= 62 && e.number <= 79) e,
    ];
    expect(<int>[for (final Exclusion e in inRange) e.number], <int>[69]);
    expect(inRange.single.reason, 'unsupported');
    expect(inRange.single.detail, contains('indented code'));
    expect(
      commonMark
          .where((SpecExample e) => e.number >= 62 && e.number <= 79)
          .every((SpecExample e) => e.section == 'ATX headings'),
      isTrue,
    );
  });

  group('shapeFromHtml', () {
    test('an emphasis inside a paragraph', () {
      expect(shapeFromHtml('<p>foo <em>bar</em></p>\n'), <ShapeNode>[
        _paragraph(<ShapeNode>[
          _text('foo '),
          ShapeNode('emphasis', children: <ShapeNode>[_text('bar')]),
        ]),
      ]);
    });

    test('a tight bullet list wraps its item text in a paragraph', () {
      expect(shapeFromHtml('<ul>\n<li>a</li>\n</ul>\n'), <ShapeNode>[
        ShapeNode(
          'bulletList',
          attributes: const <String, String>{'tight': 'true'},
          children: <ShapeNode>[
            ShapeNode(
              'listItem',
              attributes: const <String, String>{'task': 'none'},
              children: <ShapeNode>[
                _paragraph(<ShapeNode>[_text('a')]),
              ],
            ),
          ],
        ),
      ]);
    });

    test('the line break before a nested list is not a soft break', () {
      final List<ShapeNode> shape = shapeFromHtml(
        '<ul>\n<li>a\n<ul>\n<li>b</li>\n</ul>\n</li>\n</ul>\n',
      );
      final ShapeNode item = shape.single.children.single;
      expect(item.children, hasLength(2));
      expect(item.children.first, _paragraph(<ShapeNode>[_text('a')]));
      expect(item.children.last.kind, 'bulletList');
    });

    test('a code block takes its info from the language class', () {
      expect(
        shapeFromHtml('<pre><code class="language-ruby">x\n</code></pre>\n'),
        <ShapeNode>[_codeBlock('ruby', 'x\n')],
      );
    });

    test('a br with its line break is a hard break', () {
      expect(shapeFromHtml('<p>a<br />\nb</p>\n'), <ShapeNode>[
        _paragraph(<ShapeNode>[_text('a'), ShapeNode('hardBreak'), _text('b')]),
      ]);
    });

    test('entities decode in text', () {
      expect(shapeFromHtml('<p>&lt;&amp;&quot;</p>\n'), <ShapeNode>[
        _paragraph(<ShapeNode>[_text('<&"')]),
      ]);
    });

    test('a checkbox makes an unchecked task item', () {
      final List<ShapeNode> shape = shapeFromHtml(
        '<ul>\n<li><input disabled="" type="checkbox"> foo</li>\n</ul>\n',
      );
      expect(
        shape.single.children.single,
        ShapeNode(
          'listItem',
          attributes: const <String, String>{'task': 'unchecked'},
          children: <ShapeNode>[
            _paragraph(<ShapeNode>[_text('foo')]),
          ],
        ),
      );
    });

    test('a table takes its alignment from the header row', () {
      final List<ShapeNode> shape = shapeFromHtml(
        '<table>\n<thead>\n<tr>\n<th align="center">a</th>\n</tr>\n'
        '</thead>\n</table>\n',
      );
      expect(shape.single.kind, 'table');
      expect(shape.single.attributes, <String, String>{'alignment': 'centre'});
      expect(shape.single.children, hasLength(1));
    });

    test('a malformed percent sequence does not throw', () {
      expect(shapeFromHtml('<p><a href="a%">x</a></p>\n'), <ShapeNode>[
        _paragraph(<ShapeNode>[
          ShapeNode(
            'link',
            attributes: const <String, String>{'href': 'a%'},
            children: <ShapeNode>[_text('x')],
          ),
        ]),
      ]);
    });

    test('an image throws', () {
      expect(
        () => shapeFromHtml('<p><img src="x" alt="y" /></p>\n'),
        throwsUnsupportedError,
      );
    });
  });

  group('shapeFromTree code blocks', () {
    test('an unclosed and a closed fence hold the same text', () {
      expect(_treeShape('```\nfoo\n'), <ShapeNode>[_codeBlock('', 'foo\n')]);
      expect(_treeShape('```\nfoo\n```\n'), <ShapeNode>[
        _codeBlock('', 'foo\n'),
      ]);
    });

    test('a lone fence has no code lines', () {
      expect(_treeShape('```\n'), <ShapeNode>[_codeBlock('', '')]);
    });

    test('an empty code line is kept', () {
      expect(_treeShape('```\n\n```'), <ShapeNode>[_codeBlock('', '\n')]);
    });

    test('the info word keeps its resolved escapes', () {
      expect(
        _treeShape(
          r'``` a\+b'
          '\nx\n```',
        ),
        <ShapeNode>[_codeBlock('a+b', 'x\n')],
      );
    });
  });
}
