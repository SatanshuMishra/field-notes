import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../domain/services/export_service.dart';

class ExportZipWriter {
  const ExportZipWriter();

  Uint8List toZipBytes(ExportBundle bundle) {
    final archive = Archive();

    final manifestBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(bundle.manifest.toJson()),
    );
    archive.addFile(ArchiveFile.bytes(
      ExportBundle.manifestFileName,
      manifestBytes,
    ));

    final journalBytes = utf8.encode(bundle.journalJson);
    archive.addFile(ArchiveFile.bytes(
      ExportBundle.journalFileName,
      journalBytes,
    ));

    for (final entry in bundle.mediaFiles.entries) {
      archive.addFile(ArchiveFile.bytes(entry.key, entry.value));
    }

    return ZipEncoder().encodeBytes(archive);
  }
}
