import 'dart:collection';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:field_notes/data/database/app_database.dart';
import 'package:field_notes/data/database/connection.dart';
import 'package:field_notes/data/media/blob_paths.dart';
import 'package:field_notes/features/capture/core/capture.dart';
import 'package:field_notes/state/database_provider.dart';
import 'package:field_notes/state/media_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;

import 'support/integration_sandbox.dart';
import 'support/path_provider_stand_in.dart';

const Duration _bound = Duration(seconds: 30);
const String _standInPrefix = 'field-notes-standin';
const String _seedShard = 'ab';
const String _seedBlobName = 'seeded-blob';

Future<CaptureResult> _captureVoice(ProviderContainer container) async {
  final CaptureService service =
      await container.read(captureServiceProvider.future).timeout(_bound);
  final Uint8List bytes =
      Uint8List.fromList(List<int>.generate(2048, (int i) => (i * 17 + 5) % 256));
  return service
      .capture(VoiceCaptureRequest(
        date: '2026-07-21',
        audio: CaptureBytes(bytes: bytes, mime: 'audio/mp4', durationMs: 1200),
        durationMs: 1200,
      ))
      .timeout(_bound);
}

Future<Map<String, String>> _manifestOf(Directory directory) async {
  final SplayTreeMap<String, String> manifest = SplayTreeMap<String, String>();
  if (!directory.existsSync()) {
    return manifest;
  }
  await for (final FileSystemEntity entity
      in directory.list(recursive: true, followLinks: false)) {
    if (entity is! File) {
      continue;
    }
    final List<int> bytes = await entity.readAsBytes();
    manifest[p.relative(entity.path, from: directory.path)] =
        sha256.convert(bytes).toString();
  }
  return manifest;
}

List<File> _filesUnder(Directory directory) {
  if (!directory.existsSync()) {
    return const <File>[];
  }
  return directory
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .toList(growable: false);
}

Future<void> _seedStandInDocuments(Directory documents) async {
  await File(p.join(documents.path, databaseFileName))
      .writeAsString('stand-in-database', flush: true);
  final Directory shard = Directory(
    p.join(documents.path, mediaSubdir, blobsSubdir, _seedShard),
  );
  await shard.create(recursive: true);
  await File(p.join(shard.path, _seedBlobName))
      .writeAsString('stand-in-blob', flush: true);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'a container without sandbox overrides writes the database and media '
      'blobs into the application documents directory', (tester) async {
    final Directory documents = await installPathProviderStandIn(
      prefix: _standInPrefix,
      label: 'hazard',
    );

    final ProviderContainer container = ProviderContainer(retry: (_, _) => null);
    final AppDatabase database = container.read(databaseProvider);
    addTearDown(() async {
      container.dispose();
      await database.close();
    });

    final CaptureResult result = await _captureVoice(container);

    final File databaseFile = File(p.join(documents.path, databaseFileName));
    final List<File> blobs = _filesUnder(
      Directory(p.join(documents.path, mediaSubdir, blobsSubdir)),
    );

    debugPrint('INTEG hazard entryId=${result.entry.id} '
        'database=${databaseFile.existsSync()} blobs=${blobs.length}');

    expect(databaseFile.existsSync(), isTrue);
    expect(blobs, isNotEmpty);
  });

  testWidgets(
      'a container with sandbox overrides leaves the application documents '
      'directory byte-identical and stores the blob inside the sandbox',
      (tester) async {
    final Directory documents = await installPathProviderStandIn(
      prefix: _standInPrefix,
      label: 'guard',
    );
    await _seedStandInDocuments(documents);

    final Map<String, String> before = await _manifestOf(documents);
    expect(before, isNotEmpty);

    final IntegrationSandbox sandbox =
        await IntegrationSandbox.create('containment');
    addTearDown(sandbox.dispose);
    final ProviderContainer container = sandbox.createContainer();
    addTearDown(container.dispose);

    final CaptureResult result = await _captureVoice(container);

    final Map<String, String> after = await _manifestOf(documents);

    final entryRow = await (sandbox.database.select(sandbox.database.entries)
          ..where((t) => t.id.equals(result.entry.id)))
        .getSingleOrNull();
    final String? mediaId = entryRow?.mediaId;
    final blobRow = mediaId == null
        ? null
        : await (sandbox.database.select(sandbox.database.mediaBlobs)
              ..where((t) => t.id.equals(mediaId)))
            .getSingleOrNull();
    final File? blobFile = blobRow == null
        ? null
        : File(p.join(sandbox.mediaRoot.path, blobRow.relPath));

    debugPrint('INTEG guard entryId=${result.entry.id} '
        'documentsFiles=${after.length} blob=${blobFile?.path}');

    expect(after, before);
    expect(blobFile, isNotNull);
    expect(blobFile!.existsSync(), isTrue);
    expect(p.isWithin(sandbox.root.path, blobFile.path), isTrue);
  });
}
