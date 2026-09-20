import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/composer_guard.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/state/draft_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'capture_test_support.dart';

class _ComposerTrigger extends StatelessWidget {
  const _ComposerTrigger({required this.date, required this.onResult});

  final String date;
  final ValueChanged<String?> onResult;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () async => onResult(await showTextComposer(context, date)),
      child: const Text('open'),
    );
  }
}

Widget _composerApp({
  required NoteWriter writer,
  required ValueChanged<String?> onResult,
  FakeDraftStore? drafts,
}) {
  return ProviderScope(
    overrides: <Override>[
      noteWriterProvider.overrideWith((Ref ref) => writer),
      draftStoreProvider.overrideWith((Ref ref) => drafts ?? FakeDraftStore()),
    ],
    child: captureHarness(
      _ComposerTrigger(date: '2026-07-19', onResult: onResult),
    ),
  );
}

void main() {
  testWidgets('saving an empty note announces the guard instead of writing',
      (WidgetTester tester) async {
    final List<String> saved = <String>[];

    await tester.pumpWidget(
      captureHarness(
        TextComposerSheet(onSave: saved.add, onCancel: () {}),
      ),
    );

    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved, isEmpty);
    expect(find.text(emptySaveGuardMessage), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'a good day');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pump();
    expect(saved, <String>['a good day']);

    await tester.pump(composerToastLifetime);
  });

  testWidgets('a successful save closes the composer with the new entry id',
      (WidgetTester tester) async {
    final FakeNoteWriter writer = FakeNoteWriter();
    String? result = 'unset';

    await tester.pumpWidget(
      _composerApp(writer: writer, onResult: (String? id) => result = id),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'a good day');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(result, 'entry-1');
    expect(writer.saves, hasLength(1));
    final NoteSaveCall call = writer.saves.single;
    expect(call.entryId, isNull);
    expect(call.date, '2026-07-19');
    expect(call.source, 'a good day');
    expect(call.draftKey, isNotNull);
    expect(find.byType(TextComposerSheet), findsNothing);
  });

  testWidgets('a failed save shows the reason and keeps the typed note',
      (WidgetTester tester) async {
    final FakeNoteWriter writer = FakeNoteWriter(
      failure: const NoteWriteException('Could not save your entry.'),
    );
    String? result = 'unset';

    await tester.pumpWidget(
      _composerApp(writer: writer, onResult: (String? id) => result = id),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'do not lose me');
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Could not save your entry.'), findsOneWidget);
    expect(find.byType(TextComposerSheet), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'do not lose me',
    );
    expect(result, 'unset');
  });

  testWidgets('the close X on a clean composer shuts it without capturing',
      (WidgetTester tester) async {
    final FakeNoteWriter writer = FakeNoteWriter();
    String? result = 'unset';

    await tester.pumpWidget(
      _composerApp(writer: writer, onResult: (String? id) => result = id),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(composerCloseKey));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(writer.saves, isEmpty);
    expect(find.byType(TextComposerSheet), findsNothing);
  });

  testWidgets(
      'the close X on a dirty composer asks first, and Discard drops the note '
      'and its draft file', (WidgetTester tester) async {
    final FakeNoteWriter writer = FakeNoteWriter();
    final FakeDraftStore drafts = FakeDraftStore();
    String? result = 'unset';

    await tester.pumpWidget(
      _composerApp(
        writer: writer,
        drafts: drafts,
        onResult: (String? id) => result = id,
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'never mind');
    await tester.pump(draftIdleDebounceForTest);
    expect(drafts.drafts.values, <String>['never mind']);

    await tester.tap(find.byKey(composerCloseKey));
    await tester.pumpAndSettle();

    expect(find.text(composerDiscardTitle), findsOneWidget);
    expect(find.byType(TextComposerSheet), findsOneWidget);
    expect(result, 'unset');

    await tester.tap(find.byKey(composerDiscardKey));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(writer.saves, isEmpty);
    expect(drafts.drafts, isEmpty);
    expect(find.byType(TextComposerSheet), findsNothing);
  });

  testWidgets('a barrier tap no longer dismisses the composer',
      (WidgetTester tester) async {
    final FakeNoteWriter writer = FakeNoteWriter();
    String? result = 'unset';

    await tester.pumpWidget(
      _composerApp(writer: writer, onResult: (String? id) => result = id),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'still here');
    await tester.pump(draftIdleDebounceForTest);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.byType(TextComposerSheet), findsOneWidget);
    expect(find.text(composerDiscardTitle), findsNothing);
    expect(result, 'unset');

    await tester.tap(find.byKey(composerCloseKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(composerDiscardKey));
    await tester.pumpAndSettle();
  });
}
