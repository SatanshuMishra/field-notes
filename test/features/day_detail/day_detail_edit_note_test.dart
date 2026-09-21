import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/data/database/app_database.dart' as db;
import 'package:field_notes/data/journal/drift_journal_repository.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/features/capture/core/composer_guard.dart';
import 'package:field_notes/features/capture/core/draft_restored_chip.dart';
import 'package:field_notes/features/capture/core/journal_capture_service.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/day_detail/day_detail_edit_note.dart';
import 'package:field_notes/features/notes/notes.dart';
import 'package:field_notes/state/state.dart';

import '../../data/journal/journal_test_db.dart'
    show newTestDatabase, seedMediaBlob;
import '../capture/core/capture_test_support.dart'
    show FakeDraftStore, draftIdleDebounceForTest;
import '../notes/support/notes_harness.dart'
    show FakeNoteMediaStore, photoBlob, photoIdA, photoIdB, photoLine;
import 'support/day_detail_harness.dart';

class _EditTrigger extends StatelessWidget {
  const _EditTrigger({required this.entry, required this.onResult});

  final Entry entry;
  final ValueChanged<bool?> onResult;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async => onResult(
        await showEditNote(context, entry: entry, date: '2026-07-19'),
      ),
      child: const Text('open editor'),
    );
  }
}

Widget _editApp({
  required JournalRepository repository,
  required Entry entry,
  required ValueChanged<bool?> onResult,
  FakeDraftStore? drafts,
  List<Override> overrides = const <Override>[],
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: <Override>[
      journalRepositoryProvider.overrideWithValue(repository),
      draftStoreProvider.overrideWith((Ref ref) => drafts ?? FakeDraftStore()),
      ...overrides,
    ],
    child: dayDetailHarness(
      _EditTrigger(entry: entry, onResult: onResult),
    ),
  );
}

Entry _noteEntry() => entryOf(type: EntryType.text, textContent: 'a good day');

String _editorText(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller.text;

void main() {
  testWidgets('prefills the note and saves the edit through NoteWriter',
      (WidgetTester tester) async {
    final Entry entry = _noteEntry();
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[entry],
    );
    final FakeDraftStore drafts = FakeDraftStore();
    Object? result = 'unset';

    await tester.pumpWidget(
      _editApp(
        repository: repository,
        entry: entry,
        drafts: drafts,
        onResult: (bool? value) => result = value,
      ),
    );

    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();

    expect(find.text('Edit note'), findsOneWidget);
    expect(find.text('a good day'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), '  a better day  ');
    await tester.pump(draftIdleDebounceForTest);
    expect(drafts.drafts, <String, String>{'entry-1': '  a better day  '});

    await tester.tap(find.text(editNoteSaveLabel));
    await tester.pumpAndSettle();

    expect(repository.textUpdates, isEmpty);
    expect(repository.noteSaves, <NoteSaveRecord>[
      (
        entryId: 'entry-1',
        date: '2026-07-19',
        source: 'a better day',
        photoMediaIds: const <String>[],
      ),
    ]);
    expect(drafts.drafts, isEmpty);
    expect(result, isTrue);
    expect(find.text('Edit note'), findsNothing);
  });

  testWidgets(
      'keeps the editor, the typed text and the draft when the write fails',
      (WidgetTester tester) async {
    final Entry entry = _noteEntry();
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[entry],
    )..saveError = Exception('disk full');
    final FakeDraftStore drafts = FakeDraftStore();

    await tester.pumpWidget(
      _editApp(
        repository: repository,
        entry: entry,
        drafts: drafts,
        onResult: (bool? _) {},
      ),
    );

    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'a better day');
    await tester.pump(draftIdleDebounceForTest);
    await tester.tap(find.text(editNoteSaveLabel));
    await tester.pumpAndSettle();

    expect(repository.textUpdates, isEmpty);
    expect(find.text(entryWriteMessage), findsOneWidget);
    expect(find.text('a better day'), findsOneWidget);
    expect(drafts.drafts, <String, String>{'entry-1': 'a better day'});
  });

  testWidgets('a blank edit is rejected before it reaches the repository',
      (WidgetTester tester) async {
    final Entry entry = _noteEntry();
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[entry],
    );

    await tester.pumpWidget(
      _editApp(
        repository: repository,
        entry: entry,
        onResult: (bool? _) {},
      ),
    );

    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), '   ');
    await tester.pump(draftIdleDebounceForTest);
    await tester.tap(find.text(editNoteSaveLabel));
    await tester.pumpAndSettle();

    expect(repository.noteSaves, isEmpty);
    expect(find.text(emptySaveGuardMessage), findsOneWidget);
    await tester.pump(composerToastLifetime);
  });

  testWidgets('the close X on a clean editor shuts it without writing',
      (WidgetTester tester) async {
    final Entry entry = _noteEntry();
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[entry],
    );
    Object? result = 'unset';

    await tester.pumpWidget(
      _editApp(
        repository: repository,
        entry: entry,
        onResult: (bool? value) => result = value,
      ),
    );

    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(composerCloseKey));
    await tester.pumpAndSettle();

    expect(repository.noteSaves, isEmpty);
    expect(repository.textUpdates, isEmpty);
    expect(result, isFalse);
    expect(find.text('Edit note'), findsNothing);
  });

  testWidgets(
      'the close X on a dirty editor asks first: Keep editing stays, '
      'Discard deletes the draft and closes', (WidgetTester tester) async {
    final Entry entry = _noteEntry();
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[entry],
    );
    final FakeDraftStore drafts = FakeDraftStore();
    Object? result = 'unset';

    await tester.pumpWidget(
      _editApp(
        repository: repository,
        entry: entry,
        drafts: drafts,
        onResult: (bool? value) => result = value,
      ),
    );

    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'a better day');
    await tester.pump(draftIdleDebounceForTest);
    expect(drafts.drafts, <String, String>{'entry-1': 'a better day'});

    await tester.tap(find.byKey(composerCloseKey));
    await tester.pumpAndSettle();
    expect(find.text(composerDiscardTitle), findsOneWidget);

    await tester.tap(find.byKey(composerKeepEditingKey));
    await tester.pumpAndSettle();
    expect(find.text(composerDiscardTitle), findsNothing);
    expect(find.text('Edit note'), findsOneWidget);
    expect(_editorText(tester), 'a better day');
    expect(drafts.drafts, <String, String>{'entry-1': 'a better day'});
    expect(result, 'unset');

    await tester.tap(find.byKey(composerCloseKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(composerDiscardKey));
    await tester.pumpAndSettle();

    expect(drafts.drafts, isEmpty);
    expect(repository.noteSaves, isEmpty);
    expect(result, isFalse);
    expect(find.text('Edit note'), findsNothing);
  });

  testWidgets(
      'the android system back button on a dirty editor routes through the '
      'same confirm instead of dropping the edit', (WidgetTester tester) async {
    final Entry entry = _noteEntry();
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[entry],
    );
    final FakeDraftStore drafts = FakeDraftStore();
    Object? result = 'unset';

    await tester.pumpWidget(
      _editApp(
        repository: repository,
        entry: entry,
        drafts: drafts,
        onResult: (bool? value) => result = value,
      ),
    );

    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'a better day');
    await tester.pump(draftIdleDebounceForTest);

    await sendSystemBack(tester);

    expect(find.text('Edit note'), findsOneWidget);
    expect(find.text(composerDiscardTitle), findsOneWidget);
    expect(result, 'unset');

    await tester.tap(find.byKey(composerDiscardKey));
    await tester.pumpAndSettle();

    expect(drafts.drafts, isEmpty);
    expect(result, isFalse);
    expect(find.text('Edit note'), findsNothing);
  });

  testWidgets(
      'a stored draft is restored behind an inline chip whose Discard reverts '
      'to the saved text and deletes the file', (WidgetTester tester) async {
    final Entry entry = _noteEntry();
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[entry],
    );
    final FakeDraftStore drafts = FakeDraftStore(
      drafts: <String, String>{'entry-1': 'a half-typed edit'},
    );
    Object? result = 'unset';

    await tester.pumpWidget(
      _editApp(
        repository: repository,
        entry: entry,
        drafts: drafts,
        onResult: (bool? value) => result = value,
      ),
    );

    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();

    expect(_editorText(tester), 'a half-typed edit');
    expect(find.byType(DraftRestoredChip), findsOneWidget);
    expect(find.text(draftRestoredLabel), findsOneWidget);

    await tester.tap(find.byKey(draftRestoredDiscardKey));
    await tester.pumpAndSettle();

    expect(_editorText(tester), 'a good day');
    expect(find.byType(DraftRestoredChip), findsNothing);
    expect(drafts.drafts, isEmpty);
    expect(find.text('Edit note'), findsOneWidget);

    await tester.tap(find.byKey(composerCloseKey));
    await tester.pumpAndSettle();
    expect(result, isFalse);
  });

  group('photos in the edit-note route', () {
    testWidgets('the editor mounts the same photo rail',
        (WidgetTester tester) async {
      final Entry entry = _noteEntry();

      await tester.pumpWidget(
        _editApp(
          repository: FakeJournalRepository(entries: <Entry>[entry]),
          entry: entry,
          onResult: (bool? _) {},
          overrides: <Override>[
            mediaStoreProvider
                .overrideWith((Ref ref) async => FakeNoteMediaStore()),
          ],
        ),
      );
      await tester.tap(find.text('open editor'));
      await tester.pumpAndSettle();

      expect(find.byKey(photoRailAddKey), findsOneWidget);
      expect(find.byType(EditableText), findsOneWidget);
    });

    testWidgets('an existing photo line shows as a rail thumbnail',
        (WidgetTester tester) async {
      final Entry entry = entryOf(
        type: EntryType.text,
        textContent: 'a good day\n${photoLine(photoIdA)}',
      );

      await tester.pumpWidget(
        _editApp(
          repository: FakeJournalRepository(entries: <Entry>[entry]),
          entry: entry,
          onResult: (bool? _) {},
          overrides: <Override>[
            mediaStoreProvider.overrideWith(
              (Ref ref) async =>
                  FakeNoteMediaStore()..register(photoBlob(photoIdA)),
            ),
          ],
        ),
      );
      await tester.tap(find.text('open editor'));
      await tester.pumpAndSettle();

      expect(find.byKey(photoRailThumbKey(0)), findsOneWidget);
      expect(find.byKey(photoRailThumbKey(1)), findsNothing);
    });

    testWidgets(
        'receipt: saving a photo line indexes it in entry_photos, and removing '
        'the line on a later save removes the row', (WidgetTester tester) async {
      final db.AppDatabase database = newTestDatabase();
      addTearDown(database.close);
      final DriftJournalRepository journal = DriftJournalRepository(database);
      await seedMediaBlob(database, photoIdA);
      await seedMediaBlob(database, photoIdB);
      final Entry created = await journal.saveNote(
        date: '2026-07-19',
        source: 'a good day',
        photoMediaIds: const <String>[],
      );
      final FakeNoteMediaStore media = FakeNoteMediaStore()
        ..register(photoBlob(photoIdA))
        ..register(photoBlob(photoIdB));

      Future<List<String>> indexed() async {
        final List<db.EntryPhoto> rows = await (database.select(
          database.entryPhotos,
        )..where((db.$EntryPhotosTable t) => t.entryId.equals(created.id)))
            .get();
        return <String>[for (final db.EntryPhoto row in rows) row.mediaId];
      }

      Future<void> saveAs(String source) async {
        await tester.pumpWidget(
          _editApp(
            repository: journal,
            entry: created,
            onResult: (bool? _) {},
            overrides: <Override>[
              mediaStoreProvider.overrideWith((Ref ref) async => media),
            ],
          ),
        );
        await tester.tap(find.text('open editor'));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(EditableText), source);
        await tester.pump();
        await tester.tap(find.text(editNoteSaveLabel));
        await tester.pumpAndSettle();
        expect(find.text(editNoteTitle), findsNothing);
      }

      expect(await indexed(), isEmpty);

      await saveAs(
        'a good day\n${photoLine(photoIdA)}\nand later\n${photoLine(photoIdB)}',
      );
      expect(await indexed(), <String>[photoIdA, photoIdB]);

      await saveAs('a good day\nand later\n${photoLine(photoIdB)}');
      expect(await indexed(), <String>[photoIdB]);

      await saveAs('a good day');
      expect(await indexed(), isEmpty);
    });
  });
}
