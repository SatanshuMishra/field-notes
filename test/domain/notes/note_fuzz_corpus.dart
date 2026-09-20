import 'dart:math';

const int noteFuzzSeed = 20260920;
const int noteFuzzGeneratedCount = 400;

final List<String> noteFuzzCorpus = List<String>.unmodifiable(<String>[
  ..._handWritten,
  ..._generated(),
]);

const List<String> _handWritten = <String>[
  '',
  '\n',
  '\n\n',
  ' ',
  ' \n ',
  '\t',
  'a',
  'a\n',
  '\na',
  'a\n\nb',
  'a\r\nb\r\n',
  '\r',
  'a\r',
  '#',
  '# ',
  '# h',
  '#h',
  '####  h',
  '## **b**',
  '### `c`',
  '   # indented',
  '    # four spaces',
  '-',
  '- ',
  '- a',
  '* a',
  '+ a',
  '-a',
  '1.',
  '1. ',
  '1) a',
  '10. a',
  '123456789. a',
  '1234567890. a',
  '>',
  '> ',
  '> a\n> b',
  '> a\nb',
  '>\n>',
  '> **a**\n> *b*',
  '```',
  '```\n',
  '```dart\ncode\n```',
  '```\ncode',
  '```\n\n\n',
  '````\n```\n````',
  '```a`b',
  '```\n# not a heading\n- not a bullet\n```',
  '---',
  '***',
  '___',
  '- - -',
  '--',
  '-- -',
  '----  ',
  '![](photo/)',
  '![a](photo/ab)',
  '![a](photo/ab "right medium")',
  '![a](photo/ab "x") y',
  '![a](http://x)',
  ' ![a](photo/0123456789ab "left small") ',
  '![a](photo/0123456789ab)\ntext after',
  '![](photo/0123456789ab)',
  '**',
  '*',
  '**a',
  'a**',
  '*a*',
  '**a**',
  '***a***',
  '****',
  '** a **',
  '_a_',
  'a_b_c',
  '__a__',
  '~~a~~',
  '~a~',
  '~~~a~~~',
  '`',
  '``',
  '`a`',
  '`a',
  'a`',
  '` `',
  '`a``b`',
  '[',
  '[a',
  '[a]',
  '[a](',
  '[a]()',
  '[a](b)',
  '[a](b c)',
  '[](b)',
  '[a [b](c)',
  '[a](b(c))',
  '[**a**](b)',
  '[a](b) [c](d)',
  '[`a`](b)',
  '**a *b* c**',
  '*a **b** c*',
  '*a **b* c**',
  '**a _b_ c**',
  '~~a **b** c~~',
  '**a `b` c**',
  '`a **b** c`',
  '**a\nb**',
  '# a\n- b\n1. c\n> d\n```\ne\n```\n---\n![f](photo/aa)\ng',
  'a\n\n\n\nb',
  '\n\n\na\n\n\n',
  'a \n \nb',
  'a\t\n\t\nb',
  '# Title\n\nSome **bold** and *italic* text with a [link](https://x.y).\n\n'
      '- one\n- two\n\n> quoted\n\n```\ncode\n```\n',
  'Une journée à Paris — café, *croissant*, 東京',
];

const List<String> _words = <String>[
  'morning',
  'walk',
  'coffee',
  'rain',
  'quiet',
  'garden',
  'letter',
  'sea',
  'a',
  'the',
  'and',
  '**',
  '*',
  '_',
  '__',
  '~~',
  '`',
  '[',
  ']',
  '(',
  ')',
  '![',
  '#',
  '>',
  '-',
  '1.',
  'photo/ab12',
  'x_y',
  '**bold**',
  '*it*',
  '`code`',
  '~~gone~~',
  '[link](u)',
  '\t',
];

List<String> _generated() {
  final Random random = Random(noteFuzzSeed);
  return List<String>.generate(
    noteFuzzGeneratedCount,
    (_) => _document(random),
  );
}

String _document(Random random) {
  final int lineCount = 1 + random.nextInt(12);
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < lineCount; i++) {
    buffer.write(_line(random));
    if (i < lineCount - 1 || random.nextBool()) {
      buffer.write(random.nextInt(8) == 0 ? '\r\n' : '\n');
    }
    if (random.nextInt(3) == 0) {
      buffer.write('\n' * random.nextInt(3));
    }
  }
  return buffer.toString();
}

String _line(Random random) {
  switch (random.nextInt(12)) {
    case 0:
      return '${'#' * (1 + random.nextInt(4))} ${_inline(random)}';
    case 1:
      return '${<String>['-', '*', '+'][random.nextInt(3)]} ${_inline(random)}';
    case 2:
      return '${1 + random.nextInt(20)}. ${_inline(random)}';
    case 3:
      return '> ${_inline(random)}';
    case 4:
      return '```${random.nextBool() ? 'dart' : ''}';
    case 5:
      return <String>['---', '***', '___', '- - -'][random.nextInt(4)];
    case 6:
      final String alt = random.nextBool() ? _inline(random) : '';
      final String attrs = random.nextBool() ? ' "right medium"' : '';
      return '![$alt](photo/${_hex(random)}$attrs)';
    case 7:
      return '';
    case 8:
      return ' ' * random.nextInt(5);
    default:
      return _inline(random);
  }
}

String _inline(Random random) {
  final int wordCount = 1 + random.nextInt(8);
  final StringBuffer buffer = StringBuffer();
  for (int i = 0; i < wordCount; i++) {
    if (i > 0 && random.nextInt(4) != 0) {
      buffer.write(' ');
    }
    buffer.write(_words[random.nextInt(_words.length)]);
  }
  return buffer.toString();
}

String _hex(Random random) {
  const String digits = '0123456789abcdef';
  final int length = 12 + 4 * random.nextInt(3);
  return String.fromCharCodes(
    List<int>.generate(
      length,
      (_) => digits.codeUnitAt(random.nextInt(digits.length)),
    ),
  );
}
