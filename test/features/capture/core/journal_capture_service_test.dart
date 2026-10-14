import 'dart:io';

import 'package:field_notes/data/database/app_database.dart' show AppDatabase;
import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/data/media/filesystem_media_store.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/core/journal_capture_service.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_test_support.dart';

class _PeaksJournal implements JournalRepository {
  _PeaksJournal(this._inner);

  final JournalRepository _inner;
  final List<List<double>?> createdPeaks = <List<double>?>[];

  @override
  Future<Day> ensureDayForDate(String date) => _inner.ensureDayForDate(date);

  @override
  Future<Entry> createEntry({
    required String dayId,
    required EntryType type,
    String? textContent,
    String? mediaId,
    String? thumbnailMediaId,
    int? durationMs,
    List<double>? peaks,
  }) {
    createdPeaks.add(peaks);
    return _inner.createEntry(
      dayId: dayId,
      type: type,
      textContent: textContent,
      mediaId: mediaId,
      thumbnailMediaId: thumbnailMediaId,
      durationMs: durationMs,
      peaks: peaks,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late Directory root;
  late DriftJournalRepository journal;
  late FilesystemMediaStore media;
  late JournalCaptureService service;

  setUp(() async {
    db = newTestDatabase();
    root = await newTempMediaRoot();
    final ChangeRecorder recorder = ChangeRecorder(db);
    journal = DriftJournalRepository(db, recorder: recorder);
    media = FilesystemMediaStore(database: db, recorder: recorder, root: root);
    service = JournalCaptureService(journal: journal, media: media);
  });

  tearDown(() async {
    await db.close();
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('a text capture creates the day and stores the trimmed note', () async {
    final CaptureResult result = await service.capture(
      TextCaptureRequest(date: '2026-07-19', text: '  first light  '),
    );

    expect(result.day.date, '2026-07-19');
    expect(result.entry.type, EntryType.text);
    expect(result.entry.textContent, 'first light');
    expect(result.entry.mediaId, isNull);
    expect(result.photos, isEmpty);

    final List<Entry> stored = await journal.entriesForDay(result.day.id);
    expect(stored.single.id, result.entry.id);
    expect(stored.single.textContent, 'first light');
  });

  test('a second capture on the same date reuses the existing day', () async {
    final CaptureResult first = await service.capture(
      TextCaptureRequest(date: '2026-07-19', text: 'morning'),
    );
    final CaptureResult second = await service.capture(
      TextCaptureRequest(date: '2026-07-19', text: 'evening'),
    );

    expect(second.day.id, first.day.id);
    expect(await journal.entriesForDay(first.day.id), hasLength(2));
  });

  test('blank text is rejected and nothing is written', () async {
    await expectLater(
      service.capture(TextCaptureRequest(date: '2026-07-19', text: '   ')),
      throwsA(
        isA<CaptureException>().having(
          (CaptureException e) => e.message,
          'message',
          blankTextMessage,
        ),
      ),
    );

    expect(await journal.activeDayForDate('2026-07-19'), isNull);
  });

  test('a malformed date is rejected and nothing is written', () async {
    await expectLater(
      service.capture(TextCaptureRequest(date: '19-07-2026', text: 'hello')),
      throwsA(
        isA<CaptureException>().having(
          (CaptureException e) => e.message,
          'message',
          invalidDateMessage,
        ),
      ),
    );

    expect(await journal.activeDayForDate('19-07-2026'), isNull);
  });

  test('the capture service passes peaks to the journal', () async {
    final _PeaksJournal recording = _PeaksJournal(journal);
    final JournalCaptureService peaksService = JournalCaptureService(
      journal: recording,
      media: media,
    );

    await peaksService.capture(
      VoiceCaptureRequest(
        date: '2026-07-19',
        audio: const CaptureBytes(bytes: <int>[1, 2, 3], mime: 'audio/mp4'),
        durationMs: 4200,
        peaks: const <double>[0.3, 0.6],
      ),
    );
    await peaksService.capture(
      VoiceCaptureRequest(
        date: '2026-07-19',
        audio: const CaptureBytes(bytes: <int>[4, 5, 6], mime: 'audio/mp4'),
        durationMs: 4200,
        peaks: const <double>[],
      ),
    );

    expect(recording.createdPeaks, <List<double>?>[
      <double>[0.3, 0.6],
      <double>[],
    ]);
  });
}
