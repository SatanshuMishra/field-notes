import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/capture/text/editor/editor.dart';

typedef FormatCase = ({
  String name,
  TextEditingValue Function(TextEditingValue value) action,
  String text,
  int base,
  int extent,
  String expectedText,
  int expectedBase,
  int expectedExtent,
});

TextEditingValue _valueOf(String text, int base, int extent) {
  return TextEditingValue(
    text: text,
    selection: TextSelection(baseOffset: base, extentOffset: extent),
  );
}

const List<FormatCase> _cases = <FormatCase>[
  (
    name: 'bold wraps a single word',
    action: toggleBold,
    text: 'hello world',
    base: 0,
    extent: 5,
    expectedText: '**hello** world',
    expectedBase: 2,
    expectedExtent: 7,
  ),
  (
    name: 'bold unwraps markers outside the selection',
    action: toggleBold,
    text: '**hello** world',
    base: 2,
    extent: 7,
    expectedText: 'hello world',
    expectedBase: 0,
    expectedExtent: 5,
  ),
  (
    name: 'bold unwraps markers inside the selection',
    action: toggleBold,
    text: '**hello** world',
    base: 0,
    extent: 9,
    expectedText: 'hello world',
    expectedBase: 0,
    expectedExtent: 5,
  ),
  (
    name: 'bold on a collapsed caret leaves it between the markers',
    action: toggleBold,
    text: 'ab',
    base: 1,
    extent: 1,
    expectedText: 'a****b',
    expectedBase: 3,
    expectedExtent: 3,
  ),
  (
    name: 'bold wraps a multi word selection',
    action: toggleBold,
    text: 'one two three',
    base: 4,
    extent: 13,
    expectedText: 'one **two three**',
    expectedBase: 6,
    expectedExtent: 15,
  ),
  (
    name: 'italic wraps with a single underscore',
    action: toggleItalic,
    text: 'hello world',
    base: 6,
    extent: 11,
    expectedText: 'hello _world_',
    expectedBase: 7,
    expectedExtent: 12,
  ),
  (
    name: 'italic unwraps its own markers',
    action: toggleItalic,
    text: 'hello _world_',
    base: 7,
    extent: 12,
    expectedText: 'hello world',
    expectedBase: 6,
    expectedExtent: 11,
  ),
  (
    name: 'italic inside bold leaves the bold markers alone',
    action: toggleItalic,
    text: '**hello**',
    base: 2,
    extent: 7,
    expectedText: '**_hello_**',
    expectedBase: 3,
    expectedExtent: 8,
  ),
  (
    name: 'heading prefixes the caret line',
    action: toggleHeading,
    text: 'a title',
    base: 3,
    extent: 3,
    expectedText: '## a title',
    expectedBase: 6,
    expectedExtent: 6,
  ),
  (
    name: 'heading removes an existing prefix of any level',
    action: toggleHeading,
    text: '# a title',
    base: 4,
    extent: 4,
    expectedText: 'a title',
    expectedBase: 2,
    expectedExtent: 2,
  ),
  (
    name: 'heading prefixes every line the selection touches',
    action: toggleHeading,
    text: 'one\ntwo\nthree',
    base: 1,
    extent: 9,
    expectedText: '## one\n## two\n## three',
    expectedBase: 4,
    expectedExtent: 18,
  ),
  (
    name: 'heading removes the prefix from every selected line',
    action: toggleHeading,
    text: '## one\n## two',
    base: 4,
    extent: 11,
    expectedText: 'one\ntwo',
    expectedBase: 1,
    expectedExtent: 5,
  ),
  (
    name: 'the list prefix applies to the caret line',
    action: toggleBullet,
    text: 'milk',
    base: 4,
    extent: 4,
    expectedText: '- milk',
    expectedBase: 6,
    expectedExtent: 6,
  ),
  (
    name: 'the list prefix toggles off again',
    action: toggleBullet,
    text: '- milk',
    base: 6,
    extent: 6,
    expectedText: 'milk',
    expectedBase: 4,
    expectedExtent: 4,
  ),
  (
    name: 'the list prefix applies to a multi line selection',
    action: toggleBullet,
    text: 'milk\neggs',
    base: 0,
    extent: 9,
    expectedText: '- milk\n- eggs',
    expectedBase: 2,
    expectedExtent: 13,
  ),
  (
    name: 'quote prefixes the caret line',
    action: toggleQuote,
    text: 'she said',
    base: 0,
    extent: 0,
    expectedText: '> she said',
    expectedBase: 2,
    expectedExtent: 2,
  ),
  (
    name: 'quote toggles off again',
    action: toggleQuote,
    text: '> she said',
    base: 2,
    extent: 10,
    expectedText: 'she said',
    expectedBase: 0,
    expectedExtent: 8,
  ),
  (
    name: 'a link wraps the selection and parks the caret in the target',
    action: toggleLink,
    text: 'see the docs',
    base: 4,
    extent: 12,
    expectedText: 'see [the docs]()',
    expectedBase: 15,
    expectedExtent: 15,
  ),
  (
    name: 'a link on a collapsed caret parks it in the label',
    action: toggleLink,
    text: 'see ',
    base: 4,
    extent: 4,
    expectedText: 'see []()',
    expectedBase: 5,
    expectedExtent: 5,
  ),
  (
    name: 'a link unwraps back to its label',
    action: toggleLink,
    text: 'see [the docs](https://a.b)',
    base: 5,
    extent: 13,
    expectedText: 'see the docs',
    expectedBase: 4,
    expectedExtent: 12,
  ),
];

void main() {
  group('format actions', () {
    for (final FormatCase testCase in _cases) {
      test(testCase.name, () {
        final TextEditingValue input = _valueOf(
          testCase.text,
          testCase.base,
          testCase.extent,
        );
        final TextEditingValue result = testCase.action(input);

        expect(result.text, testCase.expectedText);
        expect(result.selection.baseOffset, testCase.expectedBase);
        expect(result.selection.extentOffset, testCase.expectedExtent);
        expect(result.composing, TextRange.empty);
        expect(input.text, testCase.text);
        expect(input.selection.baseOffset, testCase.base);
      });
    }

    test('every action tolerates a value that was never focused', () {
      const TextEditingValue value = TextEditingValue(text: 'orphan');
      expect(value.selection.isValid, isFalse);

      for (final TextEditingValue Function(TextEditingValue) action
          in <TextEditingValue Function(TextEditingValue)>[
        toggleBold,
        toggleItalic,
        toggleHeading,
        toggleBullet,
        toggleQuote,
        toggleLink,
      ]) {
        final TextEditingValue result = action(value);
        expect(result.text, contains('orphan'));
        expect(result.selection.isValid, isTrue);
      }
    });

    test('no action ever shortens the text it was given', () {
      const TextEditingValue value = TextEditingValue(
        text: 'keep every character',
        selection: TextSelection(baseOffset: 0, extentOffset: 4),
      );

      for (final TextEditingValue Function(TextEditingValue) action
          in <TextEditingValue Function(TextEditingValue)>[
        toggleBold,
        toggleItalic,
        toggleHeading,
        toggleBullet,
        toggleQuote,
        toggleLink,
      ]) {
        final TextEditingValue result = action(value);
        expect(result.text.length, greaterThan(value.text.length));
        expect(result.text.replaceAll(RegExp(r'[*_#>\-\[\]() ]'), ''),
            value.text.replaceAll(' ', ''));
      }
    });
  });
}
