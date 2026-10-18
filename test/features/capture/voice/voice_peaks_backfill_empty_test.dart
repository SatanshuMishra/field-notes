import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:field_notes/data/database/app_database.dart' as db;
import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/data/media/audio_peaks_decoder.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/features/capture/voice/voice_peaks_backfill.dart';
import 'package:field_notes/state/media_provider.dart';
import 'package:field_notes/state/repository_providers.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Entry _voice(String id, {String? mediaId, List<double>? peaks}) => Entry(
  id: id,
  dayId: 'day-1',
  type: EntryType.voice,
  createdAt: 1,
  updatedAt: 1,
  mediaId: mediaId,
  durationMs: 1000,
  peaks: peaks,
);

final class _Journal implements JournalRepository {
  _Journal(this._entries);

  final List<Entry> _entries;
  final List<({String entryId, List<double> peaks})> saved =
      <({String entryId, List<double> peaks})>[];

  @override
  Stream<List<Entry>> watchVoiceEntriesWithoutPeaks() async* {
    yield _entries;
  }

  @override
  Future<void> setVoicePeaks(String entryId, List<double> peaks) async {
    saved.add((entryId: entryId, peaks: peaks));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _Decoder implements AudioPeaksDecoder {
  _Decoder(this._answer);

  final List<double> _answer;
  final List<String> paths = <String>[];

  @override
  Future<List<double>> windowRms(String path) async {
    paths.add(path);
    return _answer;
  }
}

void main() {
  test('an empty waveform is listed for backfill', () async {
    final db.AppDatabase database = db.AppDatabase(NativeDatabase.memory());
    addTearDown(database.close);
    int clock = 100;
    int ids = 0;
    final DriftJournalRepository repo = DriftJournalRepository(
      database,
      recorder: ChangeRecorder(database),
      idGenerator: () => 'id-${ids++}',
      clock: () => clock,
    );
    final Day day = await repo.ensureDayForDate('2026-07-12');
    clock = 30;
    final Entry none = await repo.createEntry(
      dayId: day.id,
      type: EntryType.voice,
      mediaId: 'blob-none',
    );
    clock = 20;
    final Entry empty = await repo.createEntry(
      dayId: day.id,
      type: EntryType.voice,
      mediaId: 'blob-empty',
      peaks: <double>[],
    );
    clock = 10;
    await repo.createEntry(
      dayId: day.id,
      type: EntryType.voice,
      mediaId: 'blob-filled',
      peaks: <double>[0.4],
    );

    final List<Entry> listed = await repo.watchVoiceEntriesWithoutPeaks().first;

    expect(listed.map((Entry entry) => entry.id).toSet(), <String>{
      none.id,
      empty.id,
    });
    expect(listed, hasLength(2));
  });

  testWidgets('an empty waveform is filled from the file', (
    WidgetTester tester,
  ) async {
    final ({
      db.AppDatabase database,
      Directory root,
      FilesystemMediaStore store,
    })?
    opened = await tester.runAsync(() async {
      final db.AppDatabase database = db.AppDatabase(NativeDatabase.memory());
      final Directory root = await Directory.systemTemp.createTemp(
        'fn_voice_peaks_empty',
      );
      return (
        database: database,
        root: root,
        store: FilesystemMediaStore(
          database: database,
          recorder: ChangeRecorder(database),
          root: root,
        ),
      );
    });
    addTearDown(
      () => tester.runAsync(() async {
        await opened!.database.close();
        await opened.root.delete(recursive: true);
      }),
    );
    final MediaBlob? blob = await tester.runAsync(
      () => opened!.store.putBytes(
        bytes: List<int>.generate(64, (int index) => (index * 31 + 7) % 251),
        mime: 'audio/mp4',
        kind: MediaKind.audio,
        durationMs: 1000,
      ),
    );
    final _Decoder decoder = _Decoder(<double>[0.01, 0.1]);
    final _Journal journal = _Journal(<Entry>[
      _voice('voice-empty', mediaId: blob!.id, peaks: <double>[]),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        key: UniqueKey(),
        overrides: <Override>[
          journalRepositoryProvider.overrideWithValue(journal),
          mediaStoreProvider.overrideWith((Ref ref) async => opened!.store),
          audioPeaksDecoderProvider.overrideWithValue(decoder),
        ],
        child: const VoicePeaksBackfill(child: SizedBox.shrink()),
      ),
    );
    for (int attempt = 0; attempt < 100 && journal.saved.isEmpty; attempt++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    for (int round = 0; round < 5; round++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(decoder.paths, <String>[p.join(opened!.root.path, blob.relPath)]);
    expect(journal.saved, hasLength(1));
    expect(journal.saved.single.entryId, 'voice-empty');
    expect(journal.saved.single.peaks, <double>[0.25, 0.75]);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(seconds: 1));
  });
}
