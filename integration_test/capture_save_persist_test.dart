import 'package:field_notes/features/capture/core/capture.dart';
import 'package:field_notes/state/database_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/integration_sandbox.dart';
import 'support/path_provider_stand_in.dart';

const Duration _bound = Duration(seconds: 30);
const String _standInPrefix = 'field-notes-guard';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'note save persists an entry row on the real macOS build without hanging',
      (tester) async {
    await installPathProviderStandIn(
      prefix: _standInPrefix,
      label: 'note-save',
    );
    final sandbox = await IntegrationSandbox.create('note-save');
    addTearDown(sandbox.dispose);
    final container = sandbox.createContainer();
    addTearDown(container.dispose);
    final db = container.read(databaseProvider);

    final service =
        await container.read(captureServiceProvider.future).timeout(_bound);
    final text = 'integ-note-${DateTime.now().microsecondsSinceEpoch}';
    final result = await service
        .capture(TextCaptureRequest(date: '2026-07-21', text: text))
        .timeout(_bound);

    final row = await (db.select(db.entries)
          ..where((t) => t.id.equals(result.entry.id)))
        .getSingleOrNull();

    debugPrint('INTEG note entryId=${result.entry.id} persisted=${row != null}');

    expect(row, isNotNull);
    expect(row!.textContent, text);
  });

  testWidgets(
      'voice save persists an entry row and media blob on the real macOS build',
      (tester) async {
    await installPathProviderStandIn(
      prefix: _standInPrefix,
      label: 'voice-save',
    );
    final sandbox = await IntegrationSandbox.create('voice-save');
    addTearDown(sandbox.dispose);
    final container = sandbox.createContainer();
    addTearDown(container.dispose);
    final db = container.read(databaseProvider);

    final service =
        await container.read(captureServiceProvider.future).timeout(_bound);
    final bytes =
        Uint8List.fromList(List<int>.generate(4096, (i) => (i * 31 + 7) % 256));
    final result = await service
        .capture(VoiceCaptureRequest(
          date: '2026-07-21',
          audio: CaptureBytes(bytes: bytes, mime: 'audio/mp4', durationMs: 1500),
          durationMs: 1500,
        ))
        .timeout(_bound);

    final row = await (db.select(db.entries)
          ..where((t) => t.id.equals(result.entry.id)))
        .getSingleOrNull();
    final mediaId = row?.mediaId;
    final blob = mediaId == null
        ? null
        : await (db.select(db.mediaBlobs)..where((t) => t.id.equals(mediaId)))
            .getSingleOrNull();

    debugPrint('INTEG voice entryId=${result.entry.id} '
        'mediaId=$mediaId blob=${blob != null}');

    expect(row, isNotNull);
    expect(row!.durationMs, 1500);
    expect(mediaId, isNotNull);
    expect(blob, isNotNull);
  });
}
