import 'package:field_notes/data/media/blob_prefix.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('prefix shape', () {
    test('the reference default is a 12-hex prefix of a 64-hex digest', () {
      expect(photoRefPrefixLength, 12);
      expect(blobIdLength, 64);
      expect(blobPrefixOf('7f3ac91b2d4e5a6b7c8d'), '7f3ac91b2d4e');
      expect(blobPrefixOf('7f3ac91b2d4e5a6b', length: 16), '7f3ac91b2d4e5a6b');
    });

    test('a prefix shorter than the id returns the id itself', () {
      expect(blobPrefixOf('7f3ac91b', length: 12), '7f3ac91b');
    });

    test('uniqueness extends in 4-character steps and stops at the digest', () {
      expect(photoRefPrefixStep, 4);
      expect(nextPrefixLength(12), 16);
      expect(nextPrefixLength(16), 20);
      expect(nextPrefixLength(60), 64);
      expect(nextPrefixLength(62), 64);
    });
  });

  group('validation', () {
    test('accepts lower hex from the reference length up to a full digest', () {
      expect(isBlobPrefix('7f3ac91b2d4e'), isTrue);
      expect(isBlobPrefix('0' * 64), isTrue);
      expect(isShortBlobReference('7f3ac91b2d4e'), isTrue);
      expect(isShortBlobReference('0' * 64), isFalse);
    });

    test('rejects short, over-long, upper-case and non-hex values', () {
      expect(isBlobPrefix('7f3ac91b2d4'), isFalse);
      expect(isBlobPrefix('0' * 65), isFalse);
      expect(isBlobPrefix('7F3AC91B2D4E'), isFalse);
      expect(isBlobPrefix('7f3ac91b2d4g'), isFalse);
      expect(isBlobPrefix(''), isFalse);
      expect(isLowerHex(''), isFalse);
    });
  });

  group('range successor', () {
    test('increments the last hex digit', () {
      expect(blobPrefixUpperBound('7f3ac91b2d4e'), '7f3ac91b2d4f');
      expect(blobPrefixUpperBound('aa0'), 'aa1');
    });

    test('crosses the digit-to-letter gap without skipping ids', () {
      expect(blobPrefixUpperBound('ab9'), 'aba');
    });

    test('carries past trailing f by shortening the bound', () {
      expect(blobPrefixUpperBound('aff'), 'b');
      expect(blobPrefixUpperBound('a9ff'), 'aa');
    });

    test('an all-f prefix has no upper bound', () {
      expect(blobPrefixUpperBound('fff'), isNull);
      expect(blobPrefixUpperBound('f' * 12), isNull);
    });

    test('the bound excludes the first id outside the prefix range', () {
      const String prefix = 'ab9';
      final String? upper = blobPrefixUpperBound(prefix);
      expect('ab9f'.compareTo(upper!) < 0, isTrue);
      expect('aba0'.compareTo(upper) < 0, isFalse);
    });
  });

  group('references in note source', () {
    test('finds every distinct photo reference prefix', () {
      const String source = '# trip\n'
          '![a](photo/7f3ac91b2d4e "right medium")\n'
          'text\n'
          '![b](photo/00112233445566778899 "full")\n'
          '![a again](photo/7f3ac91b2d4e)\n';

      expect(
        List<String>.of(blobPrefixesIn(source))..sort(),
        <String>['00112233445566778899', '7f3ac91b2d4e'],
      );
    });

    test('ignores tokens that are not a valid prefix', () {
      expect(blobPrefixesIn('![x](photo/7f3ac91b2d4)'), isEmpty);
      expect(blobPrefixesIn('![x](photo/ZZZZZZZZZZZZ)'), isEmpty);
      expect(blobPrefixesIn('no photos here'), isEmpty);
    });
  });
}
