import 'package:field_notes/data/database/app_database.dart' show AppDatabase;
import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/domain/services/draft_store.dart';
import 'package:field_notes/domain/services/note_limits.dart';
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
    String? title,
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
    repository = DriftJournalRepository(
      db,
      recorder: ChangeRecorder(db),
      clock: () => 1000,
    );
    drafts = FakeDraftStore();
    writer = JournalNoteWriter(journal: repository, drafts: drafts);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'create lands through saveNote with the trimmed source and no draft left',
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
    },
  );

  test('a note too long to sync is refused and its draft is kept', () async {
    final String long = 'a' * (maxNoteCharacters + 1);
    drafts.drafts['session-2'] = long;

    await expectLater(
      writer.save(date: '2026-07-19', source: long, draftKey: 'session-2'),
      throwsA(
        isA<NoteWriteException>().having(
          (NoteWriteException error) => error.message,
          'message',
          noteTooLongMessage,
        ),
      ),
    );

    expect(drafts.drafts['session-2'], long);
    expect(await repository.activeDayForDate('2026-07-19'), isNull);
  });

  test(
    'edit lands through saveNote, keyed by the entry id for its draft',
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
    },
  );

  test('blank source is rejected with the shared blank message', () async {
    drafts.drafts['session-1'] = '   ';

    await expectLater(
      writer.save(date: '2026-07-19', source: '   ', draftKey: 'session-1'),
      throwsA(
        isA<NoteWriteException>().having(
          (NoteWriteException e) => e.message,
          'message',
          blankTextMessage,
        ),
      ),
    );
    expect(await repository.activeDayForDate('2026-07-19'), isNull);
    expect(drafts.drafts, <String, String>{'session-1': '   '});
  });

  test('a malformed date is rejected before anything is written', () async {
    await expectLater(
      writer.save(date: 'not-a-date', source: 'a good day'),
      throwsA(
        isA<NoteWriteException>().having(
          (NoteWriteException e) => e.message,
          'message',
          invalidDateMessage,
        ),
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
      failing.save(
        date: '2026-07-19',
        source: 'a good day',
        draftKey: 'session-1',
      ),
      throwsA(
        isA<NoteWriteException>()
            .having(
              (NoteWriteException e) => e.message,
              'message',
              entryWriteMessage,
            )
            .having(
              (NoteWriteException e) => e.cause,
              'cause',
              isA<StateError>(),
            ),
      ),
    );
    expect(drafts.drafts, <String, String>{'session-1': 'a good day'});
    expect(drafts.deletes, isEmpty);
  });

  test(
    'a failed draft delete after a successful save still reports success',
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
    },
  );

  group('an explicit title', () {
    test('lands through saveNote trimmed and stays out of the body', () async {
      final NoteSaveResult result = await writer.save(
        date: '2026-07-19',
        source: 'went walking',
        title: ' Tuesday ',
      );

      expect(result.entry.title, 'Tuesday');
      expect(result.entry.textContent, 'went walking');
    });

    test('when blank clears the stored one', () async {
      final NoteSaveResult created = await writer.save(
        date: '2026-07-19',
        source: 'went walking',
        title: 'Tuesday',
      );

      final NoteSaveResult edited = await writer.save(
        entryId: created.entry.id,
        date: '2026-07-19',
        source: 'went walking',
        title: '',
      );

      expect(edited.entry.title, anyOf(isNull, isEmpty));
    });

    test('counts toward the note length', () async {
      await expectLater(
        writer.save(
          date: '2026-07-19',
          source: 'a' * maxNoteCharacters,
          title: 'T',
        ),
        throwsA(
          isA<NoteWriteException>().having(
            (NoteWriteException error) => error.message,
            'message',
            noteTooLongMessage,
          ),
        ),
      );
    });

    test('with no body is refused', () async {
      await expectLater(
        writer.save(date: '2026-07-19', source: '   ', title: 'Tuesday'),
        throwsA(isA<NoteWriteException>()),
      );
    });
  });

  group('no title', () {
    test('leaves a stored title alone', () async {
      final NoteSaveResult created = await writer.save(
        date: '2026-07-19',
        source: 'went walking',
        title: 'Tuesday',
      );

      final NoteSaveResult edited = await writer.save(
        entryId: created.entry.id,
        date: '2026-07-19',
        source: 'went running',
      );

      expect(edited.entry.title, 'Tuesday');
      expect(edited.entry.textContent, 'went running');
    });

    test('keeps a leading heading in the body at the writer', () async {
      final NoteSaveResult result = await writer.save(
        date: '2026-07-19',
        source: '# Morning\n\nbody here',
      );

      expect(result.entry.title, isNull);
      expect(result.entry.textContent, '# Morning\n\nbody here');
    });
  });

  group('splitNoteSource', () {
    test('lifts a leading heading and remembers exactly what it lifted', () {
      final NoteSourceParts parts = splitNoteSource(
        '\n# Morning **light**\n\nbody here',
      );

      expect(parts.title, 'Morning light');
      expect(parts.body, 'body here');
      expect(parts.lead, '\n# Morning **light**\n\n');
      expect(
        '${parts.lead}${parts.body}',
        '\n# Morning **light**\n\nbody here',
      );
      expect(parts.carriesTitle, isTrue);
    });

    test('reads a titled source before looking for a heading', () {
      final NoteSourceParts parts = splitNoteSource(
        titledNoteSource(title: 'Tuesday', body: '# Later\n\nmore'),
      );

      expect(parts.title, 'Tuesday');
      expect(parts.body, '# Later\n\nmore');
    });

    for (final String source in <String>['', 'a line', 'a line\n\n# Later']) {
      test('leaves "$source" whole', () {
        final NoteSourceParts parts = splitNoteSource(source);

        expect(parts.title, isEmpty);
        expect(parts.body, source);
        expect(parts.carriesTitle, isFalse);
      });
    }
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
