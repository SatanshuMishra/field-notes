import 'dart:io';

import 'package:field_notes/data/database/app_database.dart' show AppDatabase;
import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_test_support.dart';

void main() {
  late AppDatabase db;
  late Directory root;
  late ProviderContainer container;

  setUp(() async {
    db = newTestDatabase();
    root = await newTempMediaRoot();
    container = ProviderContainer(
      overrides: <Override>[
        databaseProvider.overrideWithValue(db),
        mediaRootProvider.overrideWith((Ref ref) async => root),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('captureServiceProvider writes through the real provider graph',
      () async {
    final CaptureService service =
        await container.read(captureServiceProvider.future);

    final CaptureResult result = await service.capture(
      TextCaptureRequest(date: '2026-07-19', text: 'through the graph'),
    );

    final DriftJournalRepository journal = DriftJournalRepository(db);
    final List<Entry> stored = await journal.entriesForDay(result.day.id);
    expect(stored.single.textContent, 'through the graph');
  });
}
