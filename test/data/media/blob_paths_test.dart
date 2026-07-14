import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:field_notes/data/media/blob_paths.dart';
import 'package:field_notes/data/media/content_hash.dart';

void main() {
  group('relPathForId', () {
    test('shards under blobs/ on the first two hex characters', () {
      final id = 'ab${'c' * 62}';
      expect(relPathForId(id), p.join('blobs', 'ab', 'c' * 62));
    });
  });

  group('idFromRelPath', () {
    test('round-trips a real content id', () {
      final id = sha256Hex([1, 2, 3]);
      expect(idFromRelPath(relPathForId(id)), id);
    });

    test('rejects paths that are not well-formed blob paths', () {
      expect(idFromRelPath('blobs/zz'), isNull);
      expect(idFromRelPath(p.join('other', 'ab', 'c' * 62)), isNull);
      expect(idFromRelPath(p.join('blobs', 'ab', 'short')), isNull);
      expect(idFromRelPath(p.join('blobs', 'a', 'b${'c' * 62}')), isNull);
      expect(idFromRelPath(p.join('blobs', 'AB', 'C' * 62)), isNull);
    });
  });
}
