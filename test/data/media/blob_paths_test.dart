import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:field_notes/data/media/blob_paths.dart';
import 'package:field_notes/data/media/content_hash.dart';
import 'package:field_notes/domain/models/media_kind.dart';

const List<String> _knownMimes = <String>[
  'video/mp4',
  'video/quicktime',
  'video/x-m4v',
  'video/3gpp',
  'video/webm',
  'video/x-matroska',
  'audio/mp4',
  'audio/x-m4a',
  'audio/aac',
  'audio/mpeg',
  'audio/mp3',
  'audio/wav',
  'audio/x-wav',
  'audio/wave',
  'audio/vnd.wave',
  'audio/aiff',
  'audio/x-aiff',
  'audio/flac',
  'audio/x-flac',
  'audio/ogg',
  'audio/opus',
  'audio/webm',
  'audio/amr',
  'image/jpeg',
  'image/png',
  'image/heic',
  'image/heif',
  'image/webp',
  'image/gif',
  'image/tiff',
  'image/bmp',
];

const List<String> _unmappedMimes = <String>[
  '',
  '   ',
  'application/octet-stream',
  'text/plain',
  'video/x-unheard-of',
  'audio/x-unheard-of',
  'image/x-unheard-of',
];

void main() {
  group('relPathForId', () {
    test('shards under blobs/ on the first two hex characters', () {
      final id = 'ab${'c' * 62}';
      expect(relPathForId(id), p.join('blobs', 'ab', 'c' * 62));
    });
  });

  group('blobExtensionFor', () {
    test('maps every known mime to a non-empty dotted extension', () {
      for (final mime in _knownMimes) {
        for (final kind in MediaKind.values) {
          final extension = blobExtensionFor(mime: mime, kind: kind);
          expect(extension, startsWith('.'), reason: '$mime/$kind');
          expect(extension.length, greaterThan(1), reason: '$mime/$kind');
        }
      }
    });

    test('falls back on kind for a mime it does not know', () {
      for (final mime in _unmappedMimes) {
        expect(blobExtensionFor(mime: mime, kind: MediaKind.video), '.mp4');
        expect(blobExtensionFor(mime: mime, kind: MediaKind.audio), '.m4a');
        expect(blobExtensionFor(mime: mime, kind: MediaKind.photo), '.jpg');
      }
    });

    test('never yields an extension that carries no media type', () {
      for (final mime in <String>[..._knownMimes, ..._unmappedMimes]) {
        for (final kind in MediaKind.values) {
          expect(
            blobExtensionFor(mime: mime, kind: kind),
            isNot(anyOf('', '.', '.bin', '.dat', '.txt')),
            reason: '$mime/$kind',
          );
        }
      }
    });

    test('ignores casing and mime parameters', () {
      expect(
        blobExtensionFor(mime: 'VIDEO/QuickTime', kind: MediaKind.video),
        '.mov',
      );
      expect(
        blobExtensionFor(mime: 'audio/mp4; codecs="mp4a.40.2"',
            kind: MediaKind.audio),
        '.m4a',
      );
    });
  });

  group('relPathForBlob', () {
    test('appends the derived extension to the legacy stem', () {
      final id = sha256Hex([7, 7, 7]);
      expect(
        relPathForBlob(id: id, mime: 'video/quicktime', kind: MediaKind.video),
        '${relPathForId(id)}.mov',
      );
    });

    test('round-trips through idFromRelPath for every mime and kind', () {
      final id = sha256Hex([1, 2, 3]);
      for (final mime in <String>[..._knownMimes, ..._unmappedMimes]) {
        for (final kind in MediaKind.values) {
          final relPath = relPathForBlob(id: id, mime: mime, kind: kind);
          expect(p.extension(relPath), isNotEmpty, reason: '$mime/$kind');
          expect(idFromRelPath(relPath), id, reason: '$mime/$kind');
        }
      }
    });
  });

  group('idFromRelPath', () {
    final id = sha256Hex([1, 2, 3]);
    final stem = relPathForId(id);

    final accepted = <String, String>{
      'legacy extensionless form': stem,
      'video extension': '$stem.mov',
      'audio extension': '$stem.m4a',
      'photo extension': '$stem.jpg',
      'long extension': '$stem.webm',
    };

    for (final entry in accepted.entries) {
      test('accepts the ${entry.key}', () {
        expect(idFromRelPath(entry.value), id);
      });
    }

    final rejected = <String, String>{
      'a truncated path': 'blobs/zz',
      'a foreign root': p.join('other', 'ab', 'c' * 62),
      'a short final segment': p.join('blobs', 'ab', 'short'),
      'a mis-sized shard': p.join('blobs', 'a', 'b${'c' * 62}'),
      'upper case hex': p.join('blobs', 'AB', 'C' * 62),
      'non-hex characters': p.join('blobs', 'ab', 'g' * 62),
      'a stem that is too long': '$stem$stem.mov',
      'an extra path segment': p.join('blobs', 'ab', 'cd', 'c' * 62),
      'a doubled extension': '$stem.mov.mov',
      'an extension only': p.join('blobs', 'ab', '.mov'),
    };

    for (final entry in rejected.entries) {
      test('rejects ${entry.key}', () {
        expect(idFromRelPath(entry.value), isNull);
      });
    }
  });
}
