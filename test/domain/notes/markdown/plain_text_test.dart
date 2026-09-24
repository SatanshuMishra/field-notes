import 'package:field_notes/domain/notes/markdown/note_tree.dart';
import 'package:field_notes/domain/notes/markdown/plain_text.dart';
import 'package:flutter_test/flutter_test.dart';

String _plain(String source) => plainTextOfTree(parseNoteTree(source), source);

void main() {
  test('plain text drops markers and joins blocks by source line breaks', () {
    const String source =
        '# Harbour day\r\n'
        'The **fog** lifted\n'
        '\n'
        '- [x] pack\n'
        '  - tent\n'
        '> quoted `code`\n'
        '```js\n'
        'let x\n'
        '```\n'
        '---\n'
        '![Low tide](photo/4fef9c2c3c9a "left medium")\n'
        '\n'
        '| a | b |\n'
        '| - | - |\n'
        '| c | d |\n'
        '\n'
        '[sea](https://x) <https://y.z>';
    expect(
      _plain(source),
      'Harbour day\n'
      'The fog lifted\n'
      '\n'
      'pack\n'
      'tent\n'
      'quoted code\n'
      'let x\n'
      '\n'
      'Low tide\n'
      '\n'
      'a\tb\n'
      'c\td\n'
      '\n'
      'sea https://y.z',
    );
  });

  test('empty notes, blank lines and photo lines keep their line breaks', () {
    expect(_plain(''), '');
    expect(_plain('A\n\n\nB'), 'A\n\n\nB');
    expect(_plain('![](photo/0123456789ab)\n\nb'), '\n\nb');
  });

  test('dividers are empty lines and fence lines leave with their break', () {
    expect(_plain('---'), '');
    expect(_plain('```\n```'), '');
    expect(_plain('x\n```\ny'), 'x\ny');
  });

  test('escapes drop their backslash and entities stay literal', () {
    expect(_plain(r'\*a\*'), '*a*');
    expect(_plain('&amp;'), '&amp;');
  });

  test('list markers, task boxes, crlf and autolink brackets give nothing', () {
    expect(_plain('- [ ] a\n1. [x] b'), 'a\nb');
    expect(_plain('a\r\nb'), 'a\nb');
    expect(_plain('<me@x.y>'), 'me@x.y');
  });

  test('an escaped pipe in a cell gives the pipe alone', () {
    expect(
      _plain(
        r'| a \| b |'
        '\n| - |',
      ),
      'a | b',
    );
  });

  test('blank-line whitespace stays only outside containers', () {
    expect(_plain('a\n  \nb'), 'a\n  \nb');
    expect(_plain('- a\n  \n- b'), 'a\n\nb');
  });

  test('table rows give cells up to the header count joined by tabs', () {
    expect(
      _plain('| a | b |\n| - | - |\n| c | d | e |\n| f |'),
      'a\tb\nc\td\nf',
    );
  });

  test('a tree for another source length is rejected', () {
    expect(
      () => plainTextOfTree(parseNoteTree('ab'), 'abc'),
      throwsArgumentError,
    );
  });
}
