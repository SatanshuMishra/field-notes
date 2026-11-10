import 'package:field_notes/data/database/app_database.dart' show AppDatabase;
import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/data/sync/change_recorder.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/journal_note_writer.dart';
import 'package:field_notes/features/entry_cards/task_toggle.dart';
import 'package:field_notes/features/notes/notes_providers.dart'
    show NotePhotoStore;
import 'package:flutter_test/flutter_test.dart';

import '../capture/core/capture_test_support.dart'
    show FakeDraftStore, newTestDatabase;

const String _date = '2026-07-19';
const String _unticked = 'x\n- [ ] milk';
const String _ticked = 'x\n- [x] milk';

Future<NotePhotoStore> _noPhotoStore() =>
    Future<NotePhotoStore>.error(StateError('no photo is referenced'));

void main() {
  late AppDatabase db;
  late DriftJournalRepository repository;
  late JournalNoteWriter writer;

  setUp(() {
    db = newTestDatabase();
    repository = DriftJournalRepository(
      db,
      recorder: ChangeRecorder(db),
      clock: () => 1000,
    );
    writer = JournalNoteWriter(journal: repository, drafts: FakeDraftStore());
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'ticking and unticking a task in a titled note changes only the box',
    () async {
      final Entry entry = await repository.saveNote(
        date: _date,
        source: _unticked,
        photoMediaIds: const <String>[],
        title: 'Trip',
      );

      final TaskToggle? toggle = await toggleEntryTask(
        entry: entry,
        date: _date,
        boxOffset: _unticked.indexOf('['),
        writer: writer,
        photoStore: _noPhotoStore,
      );

      expect(toggle?.ticked, isTrue);
      final Entry? ticked = await repository.entryById(entry.id);
      expect(ticked?.title, 'Trip');
      expect(ticked?.textContent, _ticked);

      await saveEntrySource(
        entry: entry,
        date: _date,
        source: toggle!.previousSource,
        writer: writer,
        photoStore: _noPhotoStore,
      );

      final Entry? undone = await repository.entryById(entry.id);
      expect(undone?.title, 'Trip');
      expect(undone?.textContent, _unticked);
    },
  );
}
