import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/day_detail/day_detail_edit_note.dart';
import 'package:field_notes/state/state.dart';

import 'support/day_detail_harness.dart';

class _EditTrigger extends StatelessWidget {
  const _EditTrigger({required this.entry, required this.onResult});

  final Entry entry;
  final ValueChanged<bool?> onResult;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async => onResult(await showEditNote(context, entry: entry)),
      child: const Text('open editor'),
    );
  }
}

Widget _editApp({
  required FakeJournalRepository repository,
  required Entry entry,
  required ValueChanged<bool?> onResult,
}) {
  return ProviderScope(
    overrides: <Override>[
      journalRepositoryProvider.overrideWithValue(repository),
    ],
    child: dayDetailHarness(
      _EditTrigger(entry: entry, onResult: onResult),
    ),
  );
}

void main() {
  testWidgets('prefills the note and writes the edited text',
      (WidgetTester tester) async {
    final Entry entry = entryOf(
      type: EntryType.text,
      textContent: 'a good day',
    );
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

    expect(find.text('Edit note'), findsOneWidget);
    expect(find.text('a good day'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'a better day');
    await tester.pump();
    await tester.tap(find.text(editNoteSaveLabel));
    await tester.pumpAndSettle();

    expect(find.text(editNoteConfirmTitle), findsOneWidget);
    expect(repository.textUpdates, isEmpty);

    await tester.tap(find.byKey(editNoteConfirmSaveKey));
    await tester.pumpAndSettle();

    expect(repository.textUpdates, <({String id, String textContent})>[
      (id: 'entry-1', textContent: 'a better day'),
    ]);
    expect(result, isTrue);
    expect(find.text('Edit note'), findsNothing);
  });

  testWidgets('keeps the editor open and surfaces a message when the write fails',
      (WidgetTester tester) async {
    final Entry entry = entryOf(
      type: EntryType.text,
      textContent: 'a good day',
    );
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[entry],
    )..updateError = Exception('disk full');

    await tester.pumpWidget(
      _editApp(
        repository: repository,
        entry: entry,
        onResult: (bool? _) {},
      ),
    );

    await tester.tap(find.text('open editor'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'a better day');
    await tester.pump();
    await tester.tap(find.text(editNoteSaveLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(editNoteConfirmSaveKey));
    await tester.pumpAndSettle();

    expect(repository.textUpdates, isEmpty);
    expect(find.text(editNoteFailedMessage), findsOneWidget);
    expect(find.text('a better day'), findsOneWidget);
  });

  testWidgets('the close X shuts the editor without writing',
      (WidgetTester tester) async {
    final Entry entry = entryOf(
      type: EntryType.text,
      textContent: 'a good day',
    );
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

    expect(repository.textUpdates, isEmpty);
    expect(result, isFalse);
    expect(find.text('Edit note'), findsNothing);
  });
}
