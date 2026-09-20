import 'package:field_notes/data/database/app_database.dart' show AppDatabase;
import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/domain/services/draft_store.dart';
import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/features/capture/core/journal_capture_service.dart';
import 'package:field_notes/features/capture/core/journal_note_writer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_test_support.dart';

class _FailingSaveRepository implements JournalRepository {
  @override
  Future<Entry> saveNote({
    String? entryId,
    required String date,
    required String source,
    required List<String> photoMediaIds,
  }) {
    return Future<Entry>.error(StateError('saveNote failed'));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late AppDatabase db;
  late DriftJournalRepository repository;
  late FakeDraftStore drafts;
  late JournalNoteWriter writer;

  setUp(() {
    db = newTestDatabase();
    repository = DriftJournalRepository(db, clock: () => 1000);
    drafts = FakeDraftStore();
    writer = JournalNoteWriter(journal: repository, drafts: drafts);
  });

  tearDown(() async {
    await db.close();
  });

  test('create lands through saveNote with the trimmed source and no draft left',
      () async {
    drafts.drafts['session-1'] = '  a good day  ';

    final NoteSaveResult result = await writer.save(
      date: '2026-07-19',
      source: '  a good day  ',
      draftKey: 'session-1',
    );

    expect(result.entry.type, EntryType.text);
    expect(result.entry.textContent, 'a good day');
    final Day? day = await repository.activeDayForDate('2026-07-19');
    expect(day, isNotNull);
    expect(result.entry.dayId, day!.id);
    expect(await repository.entriesForDay(day.id), <Entry>[result.entry]);
    expect(drafts.drafts, isEmpty);
    expect(drafts.deletes, <String>['session-1']);
  });

  test('edit lands through saveNote, keyed by the entry id for its draft',
      () async {
    final NoteSaveResult created = await writer.save(
      date: '2026-07-19',
      source: 'a good day',
    );
    drafts.drafts[created.entry.id] = 'a better day';

    final NoteSaveResult edited = await writer.save(
      entryId: created.entry.id,
      date: '2026-07-19',
      source: 'a better day\n',
    );

    expect(edited.entry.id, created.entry.id);
    expect(edited.entry.textContent, 'a better day');
    expect(
      (await repository.entryById(created.entry.id))!.textContent,
      'a better day',
    );
    expect(drafts.drafts, isEmpty);
  });

  test('blank source is rejected with the shared blank message', () async {
    drafts.drafts['session-1'] = '   ';

    await expectLater(
      writer.save(date: '2026-07-19', source: '   ', draftKey: 'session-1'),
      throwsA(
        isA<NoteWriteException>()
            .having((NoteWriteException e) => e.message, 'message',
                blankTextMessage),
      ),
    );
    expect(await repository.activeDayForDate('2026-07-19'), isNull);
    expect(drafts.drafts, <String, String>{'session-1': '   '});
  });

  test('a malformed date is rejected before anything is written', () async {
    await expectLater(
      writer.save(date: 'not-a-date', source: 'a good day'),
      throwsA(
        isA<NoteWriteException>()
            .having((NoteWriteException e) => e.message, 'message',
                invalidDateMessage),
      ),
    );
  });

  test('a repository failure surfaces the entry write message and leaves the '
      'draft intact', () async {
    final JournalNoteWriter failing = JournalNoteWriter(
      journal: _FailingSaveRepository(),
      drafts: drafts,
    );
    drafts.drafts['session-1'] = 'a good day';

    await expectLater(
      failing.save(date: '2026-07-19', source: 'a good day', draftKey: 'session-1'),
      throwsA(
        isA<NoteWriteException>()
            .having((NoteWriteException e) => e.message, 'message',
                entryWriteMessage)
            .having((NoteWriteException e) => e.cause, 'cause',
                isA<StateError>()),
      ),
    );
    expect(drafts.drafts, <String, String>{'session-1': 'a good day'});
    expect(drafts.deletes, isEmpty);
  });

  test('a failed draft delete after a successful save still reports success',
      () async {
    final _ThrowingDeleteDraftStore throwing = _ThrowingDeleteDraftStore();
    final JournalNoteWriter tolerant = JournalNoteWriter(
      journal: repository,
      drafts: throwing,
    );

    final NoteSaveResult result = await tolerant.save(
      date: '2026-07-19',
      source: 'a good day',
      draftKey: 'session-1',
    );

    expect(result.entry.textContent, 'a good day');
    expect(throwing.attempted, <String>['session-1']);
  });
}

class _ThrowingDeleteDraftStore extends FakeDraftStore {
  final List<String> attempted = <String>[];

  @override
  Future<void> delete(String key) async {
    attempted.add(key);
    throw DraftWriteException('locked');
  }
}
