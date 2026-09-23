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
      onTap: () async => onResult(
        await showEditNote(context, entry: entry, date: _date),
      ),
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
          pageBuilder: (
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

String _editorText(WidgetTester tester) =>
    tester.widget<EditableText>(find.byType(EditableText)).controller.text;

Future<FakeJournalRepository> _openAndEdit(WidgetTester tester) async {
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
  await tester.enterText(find.byType(EditableText), 'a better day');
  await tester.pump(draftIdleDebounceForTest);
  return repository;
}

void main() {
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

    expect(find.text('Editing afternoon note'), findsOneWidget);
    expect(find.text('Thursday, July 2'), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);
  });

  testWidgets('Save changes asks before writing', (WidgetTester tester) async {
    final FakeJournalRepository repository = await _openAndEdit(tester);

    await tester.tap(find.text(editNoteSaveLabel));
    await tester.pumpAndSettle();

    expect(find.text('Save changes?'), findsOneWidget);
    expect(find.text('Update this note with your edits?'), findsOneWidget);
    expect(repository.noteSaves, isEmpty);
  });

  testWidgets('cancelling the save question writes nothing and keeps the edit',
      (WidgetTester tester) async {
    final FakeJournalRepository repository = await _openAndEdit(tester);

    await tester.tap(find.text(editNoteSaveLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(confirmDialogCancelKey));
    await tester.pumpAndSettle();

    expect(find.text('Save changes?'), findsNothing);
    expect(repository.noteSaves, isEmpty);
    expect(_editorText(tester), 'a better day');
    expect(find.text('Editing afternoon note'), findsOneWidget);
  });

  testWidgets(
      'confirming the save question writes the edit and toasts Entry updated',
      (WidgetTester tester) async {
    final FakeJournalRepository repository = await _openAndEdit(tester);

    await tester.tap(find.text(editNoteSaveLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(confirmDialogConfirmKey));
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
    await tester.enterText(find.byType(EditableText), 'a better day');
    await tester.pump(draftIdleDebounceForTest);
    await tester.tap(find.text(editNoteSaveLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(confirmDialogConfirmKey));
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
  });
}
