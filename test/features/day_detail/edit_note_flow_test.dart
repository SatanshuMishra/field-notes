import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/day_detail/day_detail_edit_note.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../capture/core/capture_test_support.dart'
    show FakeDraftStore, draftIdleDebounceForTest;
import '../../support/note_editor_driver.dart';
import '../../support/composer_room.dart';
import 'support/day_detail_harness.dart';

const String _date = '2026-07-02';

Entry _afternoonNote() {
  return Entry(
    id: 'entry-1',
    dayId: 'day-1',
    type: EntryType.text,
    textContent: 'a good day',
    createdAt: DateTime(2026, 7, 2, 14, 30).millisecondsSinceEpoch,
    updatedAt: 0,
  );
}

class _EditTrigger extends StatelessWidget {
  const _EditTrigger({required this.entry, required this.onResult});

  final Entry entry;
  final ValueChanged<bool?> onResult;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async =>
          onResult(await showEditNote(context, entry: entry, date: _date)),
      child: const Text('open editor'),
    );
  }
}

class _RouteTrigger extends StatelessWidget {
  const _RouteTrigger({required this.entry, required this.onDone});

  final Entry entry;
  final ValueChanged<bool> onDone;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).push<void>(
        PageRouteBuilder<void>(
          opaque: false,
          pageBuilder:
              (
                BuildContext routeContext,
                Animation<double> animation,
                Animation<double> secondaryAnimation,
              ) {
                return DialogHost(
                  child: ComposerShell(
                    closeOnScrimTap: true,
                    responsive: true,
                    child: EditNoteConnector(
                      entry: entry,
                      date: _date,
                      onDone: onDone,
                    ),
                  ),
                );
              },
        ),
      ),
      child: const Text('open route'),
    );
  }
}

Widget _app({
  required JournalRepository repository,
  required Widget child,
  FakeDraftStore? drafts,
}) {
  return ProviderScope(
    key: UniqueKey(),
    overrides: <Override>[
      journalRepositoryProvider.overrideWithValue(repository),
      draftStoreProvider.overrideWith((Ref ref) => drafts ?? FakeDraftStore()),
      todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 19, 9)),
    ],
    child: dayDetailHarness(child),
  );
}

Future<FakeJournalRepository> _openAndEdit(WidgetTester tester) async {
  final NoteEditorDriver driver = NoteEditorDriver(tester);
  final Entry entry = _afternoonNote();
  final FakeJournalRepository repository = FakeJournalRepository(
    entries: <Entry>[entry],
  );
  await tester.pumpWidget(
    _app(
      repository: repository,
      child: _EditTrigger(entry: entry, onResult: (bool? _) {}),
    ),
  );
  await tester.tap(find.text('open editor'));
  await tester.pumpAndSettle();
  await driver.enterText('a better day');
  await tester.pump(draftIdleDebounceForTest);
  return repository;
}

void main() {
  testWidgets('a stored title opens in the title field and can be cleared', (
    WidgetTester tester,
  ) async {
    final Entry entry = Entry(
      id: 'entry-1',
      dayId: 'day-1',
      type: EntryType.text,
      textContent: 'a good day',
      createdAt: DateTime(2026, 7, 2, 14, 30).millisecondsSinceEpoch,
      updatedAt: 0,
      title: 'River walk',
    );
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[entry],
    );
    await tester.pumpWidget(
      _app(
        repository: repository,
        child: _EditTrigger(entry: entry, onResult: (bool? _) {}),
      ),
    );
    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();
    final NoteEditorDriver driver = NoteEditorDriver(tester);

    expect(driver.title, 'River walk');

    await driver.enterTitle('');
    await tester.pump(draftIdleDebounceForTest);
    await tester.tap(find.text(editNoteSaveLabel));
    await tester.pumpAndSettle();

    expect(repository.noteSaveTitles.single, '');
    expect(repository.noteSaves.single.source, 'a good day');
  });

  testWidgets('a stored body that begins with a private-use mark opens whole '
      'in the page and saves untitled', (WidgetTester tester) async {
    const String body = 'Dear diary\nToday...';
    final Entry entry = Entry(
      id: 'entry-1',
      dayId: 'day-1',
      type: EntryType.text,
      textContent: body,
      createdAt: DateTime(2026, 7, 2, 14, 30).millisecondsSinceEpoch,
      updatedAt: 0,
    );
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[entry],
    );
    await tester.pumpWidget(
      _app(
        repository: repository,
        child: _EditTrigger(entry: entry, onResult: (bool? _) {}),
      ),
    );
    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();
    final NoteEditorDriver driver = NoteEditorDriver(tester);

    expect(driver.title, isEmpty);
    expect(driver.source, body);

    await tester.tap(find.text(editNoteSaveLabel));
    await tester.pumpAndSettle();

    expect(repository.noteSaveTitles.single, anyOf(isNull, isEmpty));
    expect(repository.noteSaves.single.source, body);
  });

  testWidgets('a note that is only a heading keeps it in the page and saves '
      'with a new title', (WidgetTester tester) async {
    final Entry entry = Entry(
      id: 'entry-1',
      dayId: 'day-1',
      type: EntryType.text,
      textContent: '# Groceries',
      createdAt: DateTime(2026, 7, 2, 14, 30).millisecondsSinceEpoch,
      updatedAt: 0,
    );
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[entry],
    );
    await tester.pumpWidget(
      _app(
        repository: repository,
        child: _EditTrigger(entry: entry, onResult: (bool? _) {}),
      ),
    );
    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();
    final NoteEditorDriver driver = NoteEditorDriver(tester);

    await driver.enterTitle('Shopping');
    await tester.tap(find.text(editNoteSaveLabel));
    await tester.pumpAndSettle();

    expect(find.text(emptySaveGuardMessage), findsNothing);
    expect(repository.noteSaveTitles.single, 'Shopping');
    expect(repository.noteSaves.single.source, '# Groceries');
  });

  testWidgets('a draft of a note whose heading opened as its title comes '
      'back with that title', (WidgetTester tester) async {
    final Entry entry = Entry(
      id: 'entry-1',
      dayId: 'day-1',
      type: EntryType.text,
      textContent: '# Groceries\n\nmilk',
      createdAt: DateTime(2026, 7, 2, 14, 30).millisecondsSinceEpoch,
      updatedAt: 0,
    );
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[entry],
    );
    await tester.pumpWidget(
      _app(
        repository: repository,
        drafts: FakeDraftStore(
          drafts: <String, String>{'entry-1': '# Groceries\n\nmilk and eggs'},
        ),
        child: _EditTrigger(entry: entry, onResult: (bool? _) {}),
      ),
    );
    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();
    final NoteEditorDriver driver = NoteEditorDriver(tester);

    expect(driver.title, 'Groceries');
    expect(driver.source, 'milk and eggs');

    await tester.tap(find.text(editNoteSaveLabel));
    await tester.pumpAndSettle();

    expect(repository.noteSaveTitles.single, 'Groceries');
    expect(repository.noteSaves.single.source, 'milk and eggs');
  });

  testWidgets("editing a note is titled for its part of day under the day's "
      'kicker', (WidgetTester tester) async {
    final Entry entry = _afternoonNote();
    await tester.pumpWidget(
      _app(
        repository: FakeJournalRepository(entries: <Entry>[entry]),
        child: _EditTrigger(entry: entry, onResult: (bool? _) {}),
      ),
    );
    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();

    expect(composerTitled('Editing afternoon note'), findsOneWidget);
    expect(
      tester.widget<TextComposerSheet>(find.byType(TextComposerSheet)).kicker,
      'Thursday, July 2',
    );
    expect(find.text('Save changes'), findsOneWidget);
  });

  testWidgets('Save changes writes the edit and toasts Entry updated', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = await _openAndEdit(tester);

    await tester.tap(find.text(editNoteSaveLabel));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(repository.noteSaves, <NoteSaveRecord>[
      (
        entryId: 'entry-1',
        date: _date,
        source: 'a better day',
        photoMediaIds: const <String>[],
      ),
    ]);
    expect(find.text('Entry updated'), findsOneWidget);
    await tester.pumpAndSettle();
    await tester.pump(kToastLifetime);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'with a done callback the editor reports instead of closing its route',
    (WidgetTester tester) async {
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      final Entry entry = _afternoonNote();
      final FakeJournalRepository repository = FakeJournalRepository(
        entries: <Entry>[entry],
      );
      final List<bool> reports = <bool>[];

      await tester.pumpWidget(
        _app(
          repository: repository,
          child: _RouteTrigger(entry: entry, onDone: reports.add),
        ),
      );
      await tester.tap(find.text('open route'));
      await tester.pumpAndSettle();
      await driver.enterText('a better day');
      await tester.pump(draftIdleDebounceForTest);
      await tester.tap(find.text(editNoteSaveLabel));
      await tester.pumpAndSettle();

      expect(repository.noteSaves, hasLength(1));
      expect(reports, <bool>[true]);
      expect(find.byType(EditNoteConnector), findsOneWidget);
      await tester.pump(kToastLifetime);
      await tester.pumpAndSettle();

      final List<bool> closeReports = <bool>[];
      await tester.pumpWidget(
        _app(
          repository: FakeJournalRepository(entries: <Entry>[entry]),
          child: _RouteTrigger(entry: entry, onDone: closeReports.add),
        ),
      );
      await tester.tap(find.text('open route'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(composerCloseKey));
      await tester.pumpAndSettle();

      expect(closeReports, <bool>[false]);
      expect(find.byType(EditNoteConnector), findsOneWidget);
    },
  );
}
