import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/composer_guard.dart';
import 'package:field_notes/features/capture/core/draft_restored_chip.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/notes/notes.dart';
import 'package:field_notes/state/draft_provider.dart';
import 'package:field_notes/state/media_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../notes/support/notes_harness.dart'
    show FakeNoteMediaStore, photoBlob, photoIdA, photoIdB, photoLine;
import '../photo/photo_test_support.dart' show FakePhotoPicker, tinyPngBytes;
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
  List<Override> overrides = const <Override>[],
}) {
  return ProviderScope(
    overrides: <Override>[
      noteWriterProvider.overrideWith((Ref ref) => writer),
      draftStoreProvider.overrideWith((Ref ref) => drafts ?? FakeDraftStore()),
      ...overrides,
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

  testWidgets(
      'a new-note draft left by a crash is restored when the composer reopens '
      'for the same date', (WidgetTester tester) async {
    final FakeNoteWriter writer = FakeNoteWriter();
    final FakeDraftStore drafts = FakeDraftStore(
      drafts: <String, String>{'new-2026-07-19': 'left by a crash'},
    );
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

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'left by a crash',
    );
    expect(find.byType(DraftRestoredChip), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(writer.saves.single.draftKey, 'new-2026-07-19');
    expect(writer.saves.single.source, 'left by a crash');
    expect(result, 'entry-1');
  });

  testWidgets('a new-note draft for another date stays out of this composer',
      (WidgetTester tester) async {
    final FakeDraftStore drafts = FakeDraftStore(
      drafts: <String, String>{'new-2026-07-20': 'another day'},
    );
    String? result = 'unset';

    await tester.pumpWidget(
      _composerApp(
        writer: FakeNoteWriter(),
        drafts: drafts,
        onResult: (String? id) => result = id,
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      isEmpty,
    );
    expect(find.byType(DraftRestoredChip), findsNothing);
    expect(drafts.drafts, <String, String>{'new-2026-07-20': 'another day'});

    await tester.tap(find.byKey(composerCloseKey));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(drafts.drafts, <String, String>{'new-2026-07-20': 'another day'});
  });

  testWidgets(
      'closing before a stored draft has loaded keeps it and asks first',
      (WidgetTester tester) async {
    final FakeDraftStore drafts = FakeDraftStore(
      drafts: <String, String>{'new-2026-07-19': 'left by a crash'},
      readDelay: const Duration(milliseconds: 150),
    );
    String? result = 'unset';

    await tester.pumpWidget(
      _composerApp(
        writer: FakeNoteWriter(),
        drafts: drafts,
        onResult: (String? id) => result = id,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(composerCloseKey), warnIfMissed: false);
    await tester.pump();

    expect(find.text(composerDiscardTitle), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.text(composerDiscardTitle), findsOneWidget);
    expect(result, 'unset');
    expect(drafts.drafts, <String, String>{'new-2026-07-19': 'left by a crash'});

    await tester.tap(find.byKey(composerKeepEditingKey));
    await tester.pumpAndSettle();

    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'left by a crash',
    );
    expect(find.byType(DraftRestoredChip), findsOneWidget);
  });

  testWidgets(
      'tapping Save while the discard confirm is up saves nothing and keeps '
      'the note', (WidgetTester tester) async {
    final FakeNoteWriter writer = FakeNoteWriter();
    final FakeDraftStore drafts = FakeDraftStore(
      drafts: <String, String>{'new-2026-07-19': 'left by a crash'},
      readDelay: const Duration(milliseconds: 300),
    );
    String? result = 'unset';

    await tester.pumpWidget(
      _composerApp(
        writer: writer,
        drafts: drafts,
        onResult: (String? id) => result = id,
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(composerCloseKey), warnIfMissed: false);
    await tester.pump();
    await tester.tap(find.text('Save'), warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(writer.saves, isEmpty);
    expect(result, 'unset');
    expect(find.text(composerDiscardTitle), findsNothing);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'left by a crash',
    );
    expect(drafts.drafts, <String, String>{'new-2026-07-19': 'left by a crash'});
  });

  testWidgets(
      'a discarded new-note draft stays deleted when the app goes inactive '
      'during the close', (WidgetTester tester) async {
    final FakeDraftStore drafts = FakeDraftStore();

    await tester.pumpWidget(
      _composerApp(
        writer: FakeNoteWriter(),
        drafts: drafts,
        onResult: (String? _) {},
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'throw this away');
    await tester.pump(draftIdleDebounceForTest);
    expect(drafts.drafts, <String, String>{'new-2026-07-19': 'throw this away'});

    await tester.tap(find.byKey(composerCloseKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(composerDiscardKey));
    await tester.pump(const Duration(milliseconds: 50));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    expect(drafts.drafts, isEmpty);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(DraftRestoredChip), findsNothing);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      isEmpty,
    );
  });

  testWidgets(
      'a saved new note leaves no draft when the app goes inactive during the '
      'close', (WidgetTester tester) async {
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
    await tester.enterText(find.byType(EditableText), 'saved once');
    await tester.pump(draftIdleDebounceForTest);
    await tester.enterText(find.byType(EditableText), 'saved once more');

    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 50));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pumpAndSettle();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);

    expect(result, 'entry-1');
    expect(writer.saves.single.source, 'saved once more');
    expect(drafts.drafts, isEmpty);
  });

  testWidgets('a scrim tap on a dirty composer asks first and keeps the note',
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
    expect(find.text(composerDiscardTitle), findsOneWidget);
    expect(result, 'unset');

    await tester.tap(find.byKey(composerKeepEditingKey));
    await tester.pumpAndSettle();

    expect(find.text(composerDiscardTitle), findsNothing);
    expect(find.byType(TextComposerSheet), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'still here',
    );
    expect(result, 'unset');

    await tester.tap(find.byKey(composerCloseKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(composerDiscardKey));
    await tester.pumpAndSettle();
  });

  testWidgets('a scrim tap on a clean composer closes it',
      (WidgetTester tester) async {
    final FakeNoteWriter writer = FakeNoteWriter();
    String? result = 'unset';

    await tester.pumpWidget(
      _composerApp(writer: writer, onResult: (String? id) => result = id),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.byType(TextComposerSheet), findsNothing);
    expect(find.text(composerDiscardTitle), findsNothing);
    expect(result, isNull);
    expect(writer.saves, isEmpty);
  });

  group('photos in the new-note composer', () {
    List<Override> mediaOverrides(
      FakeNoteMediaStore store, {
      FakePhotoPicker? picker,
    }) {
      return <Override>[
        mediaStoreProvider.overrideWith((Ref ref) async => store),
        notePhotoPickerProvider.overrideWithValue(
          picker ?? FakePhotoPicker(),
        ),
      ];
    }

    testWidgets('mounts the photo rail under the writing surface, Add first',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _composerApp(
          writer: FakeNoteWriter(),
          onResult: (String? _) {},
          overrides: mediaOverrides(FakeNoteMediaStore()),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.byType(PhotoRail), findsOneWidget);
      expect(find.byKey(photoRailAddKey), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(photoRailKey)).dy,
        greaterThan(tester.getBottomLeft(find.byType(EditableText)).dy),
      );
      expect(find.byType(EditableText), findsOneWidget);
    });

    testWidgets(
        'Add photo stores the pick, inserts its line, and the save hands the '
        'full media id to the writer for the reachability index',
        (WidgetTester tester) async {
      final FakeNoteWriter writer = FakeNoteWriter();
      final FakeNoteMediaStore store =
          FakeNoteMediaStore(assignIds: <String>[photoIdA]);
      final FakePhotoPicker picker = FakePhotoPicker(
        libraryResult: <CaptureMedia>[
          CaptureBytes(
            bytes: tinyPngBytes,
            mime: 'image/png',
            width: 1,
            height: 1,
          ),
        ],
      );
      await tester.pumpWidget(
        _composerApp(
          writer: writer,
          onResult: (String? _) {},
          overrides: mediaOverrides(store, picker: picker),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'a good day');
      await tester.pump();

      await tester.tap(find.byKey(photoRailAddKey));
      await tester.pumpAndSettle();

      final String expected = 'a good day\n${photoLine(photoIdA)}\n';
      expect(picker.libraryCalls, 1);
      expect(store.blobs.single.id, photoIdA);
      expect(store.blobs.single.width, 1);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        expected,
      );
      expect(find.byKey(photoRailThumbKey(0)), findsOneWidget);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(writer.saves.single.source, expected);
      expect(writer.saves.single.photoMediaIds, <String>[photoIdA]);
    });

    testWidgets('every referenced photo is indexed once, in source order',
        (WidgetTester tester) async {
      final FakeNoteWriter writer = FakeNoteWriter();
      final FakeNoteMediaStore store = FakeNoteMediaStore()
        ..register(photoBlob(photoIdA))
        ..register(photoBlob(photoIdB));
      await tester.pumpWidget(
        _composerApp(
          writer: writer,
          onResult: (String? _) {},
          overrides: mediaOverrides(store),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(EditableText),
        '${photoLine(photoIdB)}\nthen\n${photoLine(photoIdA)}\n'
        '${photoLine(photoIdB, size: PhotoSize.full)}\n'
        '![](photo/0123456789ab)',
      );
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(writer.saves.single.photoMediaIds, <String>[photoIdB, photoIdA]);
    });

    testWidgets('a note without a photo line never looks a reference up',
        (WidgetTester tester) async {
      final FakeNoteWriter writer = FakeNoteWriter();
      final FakeNoteMediaStore store = FakeNoteMediaStore();
      await tester.pumpWidget(
        _composerApp(
          writer: writer,
          onResult: (String? _) {},
          overrides: mediaOverrides(store),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText), 'just words');
      await tester.pump();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(writer.saves.single.photoMediaIds, isEmpty);
      expect(store.prefixLookups, isEmpty);
    });
  });
}
