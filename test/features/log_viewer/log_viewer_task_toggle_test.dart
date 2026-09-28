import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/domain/services/note_writer.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/note_engine/reader/note_reader_view.dart';
import 'package:field_notes/features/notes/notes.dart'
    show notesMediaResolverProvider;
import 'package:field_notes/features/note_engine/render/render_note_view.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../capture/core/capture_test_support.dart'
    show FakeDraftStore, FakeNoteWriter, NoteSaveCall;
import '../day_detail/support/day_detail_harness.dart';

const String _date = '2026-07-19';
const String _photoId =
    'abc123abc123000000000000000000000000000000000000000000000000beef';

Entry _note(String source) => Entry(
  id: 'entry-1',
  dayId: 'day-1',
  type: EntryType.text,
  textContent: source,
  createdAt: DateTime(2026, 7, 19, 8, 12).millisecondsSinceEpoch,
  updatedAt: 0,
);

Future<void> _open(
  WidgetTester tester, {
  required String source,
  required NoteWriter writer,
  Map<String, MediaBlob> blobs = const <String, MediaBlob>{},
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        journalRepositoryProvider.overrideWithValue(
          FakeJournalRepository(entries: <Entry>[_note(source)]),
        ),
        draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
        mediaStoreProvider.overrideWith(
          (Ref ref) async => FakeMediaStore(Directory.systemTemp, blobs: blobs),
        ),
        noteWriterProvider.overrideWith((Ref ref) async => writer),
        notesMediaResolverProvider.overrideWith(
          (Ref ref) async => FakeMediaResolver(),
        ),
        todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 23, 9)),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => showLogViewer(
                context,
                date: _date,
                entryId: 'entry-1',
                exit: LogViewerExit.back,
              ),
              child: const Text('open log'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open log'));
  await tester.pumpAndSettle();
}

Future<void> _tapBox(WidgetTester tester, int boxStart) async {
  final RenderNoteView render = tester.renderObject<RenderNoteView>(
    find.descendant(
      of: find.byType(NoteReaderView),
      matching: find.byType(NoteViewBody),
    ),
  );
  final Rect box = render.noteLayout.rangeBounds(
    MdRange(boxStart, boxStart + 3),
  );
  await tester.tapAt(render.contentToGlobal(box.center));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('ticking a to-do in the viewer saves it and offers undo', (
    WidgetTester tester,
  ) async {
    final FakeNoteWriter writer = FakeNoteWriter();
    await _open(tester, source: '- [ ] call the ferry office', writer: writer);

    await _tapBox(tester, 2);

    expect(writer.saves, hasLength(1));
    expect(writer.saves.single.entryId, 'entry-1');
    expect(writer.saves.single.date, _date);
    expect(writer.saves.single.source, '- [x] call the ferry office');
    expect(find.text('Task ticked'), findsOneWidget);
    expect(find.text('Undo'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(writer.saves, hasLength(2));
    expect(writer.saves.last.entryId, 'entry-1');
    expect(writer.saves.last.source, '- [ ] call the ferry office');
    expect(
      writer.saves.map((NoteSaveCall save) => save.draftKey),
      everyElement(allOf(isNotNull, isNot('entry-1'))),
    );
    await tester.pump(kToastLifetime);
    await tester.pumpAndSettle();
  });

  testWidgets('ticking a to-do keeps the note photos', (
    WidgetTester tester,
  ) async {
    final FakeNoteWriter writer = FakeNoteWriter();
    await _open(
      tester,
      source: '![](photo/abc123abc123)\n- [ ] pack',
      writer: writer,
      blobs: <String, MediaBlob>{
        _photoId: blobOf(id: _photoId, relPath: 'missing.png'),
      },
    );

    await _tapBox(tester, 26);

    expect(writer.saves, hasLength(1));
    expect(writer.saves.single.source, '![](photo/abc123abc123)\n- [x] pack');
    expect(writer.saves.single.photoMediaIds, contains(_photoId));
    await tester.pump(kToastLifetime);
    await tester.pumpAndSettle();
  });

  testWidgets('a failed tick says so and saves nothing more', (
    WidgetTester tester,
  ) async {
    final FakeNoteWriter writer = FakeNoteWriter(
      failure: const NoteWriteException('disk full'),
    );
    await _open(tester, source: '- [x] call the ferry office', writer: writer);

    await _tapBox(tester, 2);

    expect(writer.saves, hasLength(1));
    expect(find.text('Could not save the change'), findsOneWidget);
    expect(find.text('Undo'), findsNothing);
    await tester.pump(kToastLifetime);
    await tester.pumpAndSettle();
  });
}
