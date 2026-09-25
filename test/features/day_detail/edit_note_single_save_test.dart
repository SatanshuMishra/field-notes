import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/repositories/journal_repository.dart';
import 'package:field_notes/features/day_detail/day_detail_edit_note.dart';
import 'package:field_notes/state/state.dart';

import '../capture/core/capture_test_support.dart'
    show FakeDraftStore, draftIdleDebounceForTest;
import '../../support/note_editor_driver.dart';
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
    ],
    child: dayDetailHarness(child),
  );
}

void main() {
  testWidgets('Save changes writes without a second question',
      (WidgetTester tester) async {
    final NoteEditorDriver driver = NoteEditorDriver(tester);
    final Entry entry = Entry(
      id: 'entry-1',
      dayId: 'day-1',
      type: EntryType.text,
      textContent: 'a good day',
      createdAt: DateTime(2026, 7, 19, 14, 30).millisecondsSinceEpoch,
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
    await driver.enterText('a better day');
    await tester.pump(draftIdleDebounceForTest);

    await tester.tap(find.text(editNoteSaveLabel));
    await tester.pumpAndSettle();

    expect(repository.noteSaves, <NoteSaveRecord>[
      (
        entryId: 'entry-1',
        date: '2026-07-19',
        source: 'a better day',
        photoMediaIds: const <String>[],
      ),
    ]);
    expect(find.text('Save changes?'), findsNothing);
  });
}
