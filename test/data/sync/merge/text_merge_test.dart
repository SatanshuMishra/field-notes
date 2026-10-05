import 'package:field_notes/data/sync/merge/text_merge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('edits to different lines merge', () {
    expect(
      merge(base: 'a\nb\nc', local: 'A\nb\nc', remote: 'a\nb\nC'),
      const TextMergeResult.merged('A\nb\nC'),
    );
  });

  test('edits to the same line conflict', () {
    expect(
      merge(base: 'a\nb', local: 'a\nX', remote: 'a\nY'),
      const TextMergeResult.conflict(),
    );
  });

  test('the same edit on both sides counts as one', () {
    expect(
      merge(base: 'a\nb', local: 'a\nX', remote: 'a\nX'),
      const TextMergeResult.merged('a\nX'),
    );
  });

  test('a closing paragraph and a first-line fix merge', () {
    expect(
      merge(base: 'l1\nl2', local: 'L1\nl2', remote: 'l1\nl2\n\nclosing'),
      const TextMergeResult.merged('L1\nl2\n\nclosing'),
    );
  });

  test('a line added beside an edited line merges', () {
    expect(
      merge(base: 'a\nb\nc', local: 'a\nnew\nb\nc', remote: 'a\nb\nC'),
      const TextMergeResult.merged('a\nnew\nb\nC'),
    );
  });

  test('lines added at the same place conflict', () {
    expect(
      merge(base: 'a\nb\nc', local: 'a\nb\nc\nd', remote: 'a\nb\nc\ne'),
      const TextMergeResult.conflict(),
    );
  });

  test('a removed line conflicts with an edit to it', () {
    expect(
      merge(base: 'a\nb\nc', local: 'a\nc', remote: 'a\nB\nc'),
      const TextMergeResult.conflict(),
    );
  });

  test('an unchanged side takes the other side whole', () {
    expect(
      merge(base: 'a\nb\nc', local: 'a\nb\nc', remote: 'x\ny'),
      const TextMergeResult.merged('x\ny'),
    );
  });
}
