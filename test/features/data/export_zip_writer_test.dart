import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:field_notes/domain/services/export_service.dart';
import 'package:field_notes/features/data/export_zip_writer.dart';
import 'package:flutter_test/flutter_test.dart';

ExportBundle sampleBundle() => ExportBundle(
  manifest: const ExportManifest(
    formatVersion: 1,
    appName: 'Field Notes',
    exportedAt: 1751000000000,
    stats: ExportStats(
      dayCount: 1,
      entryCount: 1,
      photoCount: 0,
      mediaBlobCount: 1,
    ),
  ),
  journalJson: '{"days":[{"id":"d1"}]}',
  mediaFiles: {
    'blobs/ab/cdef': [7, 8, 9],
  },
);

ExportBundle windowsBundle() => ExportBundle(
  manifest: sampleBundle().manifest,
  journalJson: '{"days":[{"id":"d1"}]}',
  mediaFiles: {
    r'blobs\ab\cdef.jpg': [7, 8, 9],
  },
);

void main() {
  const writer = ExportZipWriter();

  test(
    'toZipBytes emits a decodable zip with manifest, journal, and media',
    () {
      final bytes = writer.toZipBytes(sampleBundle());

      final archive = ZipDecoder().decodeBytes(bytes);
      final byName = {
        for (final f in archive.files)
          if (f.isFile) f.name: f.content,
      };

      expect(
        byName.keys,
        containsAll(<String>['manifest.json', 'journal.json', 'blobs/ab/cdef']),
      );
      expect(byName['blobs/ab/cdef'], [7, 8, 9]);
      expect(utf8.decode(byName['journal.json']!), '{"days":[{"id":"d1"}]}');

      final manifest = jsonDecode(
        utf8.decode(byName['manifest.json']!),
      ) as Map<String, Object?>;
      expect(manifest['formatVersion'], 1);
      expect((manifest['counts'] as Map)['days'], 1);
    },
  );

  test('media entries use forward slashes even from a Windows path', () {
    final bytes = writer.toZipBytes(windowsBundle());

    final archive = ZipDecoder().decodeBytes(bytes);
    final names = <String>[
      for (final f in archive.files)
        if (f.isFile) f.name,
    ];

    expect(names, contains('blobs/ab/cdef.jpg'));
    expect(names.any((String n) => n.contains(r'\')), isFalse);
    expect(zipEntryName('blobs/ab/cdef.jpg'), 'blobs/ab/cdef.jpg');
    expect(zipEntryName(r'blobs\ab\cdef.jpg'), 'blobs/ab/cdef.jpg');
  });
}
