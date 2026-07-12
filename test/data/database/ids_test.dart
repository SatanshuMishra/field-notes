import 'package:flutter_test/flutter_test.dart';
import 'package:field_notes/data/database/ids.dart';

void main() {
  const crockfordBase32 = '0123456789ABCDEFGHJKMNPQRSTVWXYZ';

  group('newId', () {
    test('returns a 26-character canonical Crockford base32 ULID', () {
      final id = newId();
      expect(id.length, 26);
      for (final char in id.split('')) {
        expect(
          crockfordBase32.contains(char.toUpperCase()),
          isTrue,
          reason: 'unexpected non-Crockford character "$char" in "$id"',
        );
      }
    });

    test('returns a distinct value on every call', () {
      final ids = List<String>.generate(2000, (_) => newId()).toSet();
      expect(ids.length, 2000);
    });
  });
}
