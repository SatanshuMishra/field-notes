import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/day_detail_entry_tile.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/state/state.dart';

import 'support/day_detail_harness.dart';

Finder _tileAction(String label) => find.byWidgetPredicate(
      (Widget widget) =>
          widget is IconStickerButton && widget.semanticLabel == label,
    );

Widget _tileApp({
  required FakeJournalRepository repository,
  required Entry entry,
  MediaResolver? resolver,
  VoidCallback? onEdit,
  VoidCallback? onDelete,
  List<Override> overrides = const <Override>[],
}) {
  return ProviderScope(
    overrides: <Override>[
      journalRepositoryProvider.overrideWithValue(repository),
      ...overrides,
    ],
    child: dayDetailHarness(
      SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: DayDetailEntryTile(
            entry: entry,
            resolver: resolver ?? FakeMediaResolver(),
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('a note offers edit and delete and forwards both',
      (WidgetTester tester) async {
    int edits = 0;
    int deletes = 0;
    final Entry entry = entryOf(
      type: EntryType.text,
      textContent: 'a good day',
    );

    await tester.pumpWidget(
      _tileApp(
        repository: FakeJournalRepository(entries: <Entry>[entry]),
        entry: entry,
        onEdit: () => edits++,
        onDelete: () => deletes++,
      ),
    );
    await tester.pump();

    expect(find.text('a good day'), findsOneWidget);

    await tester.tap(_tileAction(entryEditLabel));
    await tester.pump();
    await tester.tap(_tileAction(entryDeleteLabel));
    await tester.pump();

    expect(edits, 1);
    expect(deletes, 1);
  });

  testWidgets('a voice entry hides edit but keeps delete',
      (WidgetTester tester) async {
    final Entry entry = entryOf(
      type: EntryType.voice,
      mediaId: 'blob-1',
      durationMs: 4000,
    );

    await tester.pumpWidget(
      _tileApp(
        repository: FakeJournalRepository(entries: <Entry>[entry]),
        entry: entry,
        onEdit: () {},
        onDelete: () {},
      ),
    );
    await tester.pump();

    expect(isEditableEntry(entry), isFalse);
    expect(_tileAction(entryEditLabel), findsNothing);
    expect(_tileAction(entryDeleteLabel), findsOneWidget);
  });

  testWidgets('an indexed photo renders no strip on the card',
      (WidgetTester tester) async {
    final Entry entry = entryOf(
      type: EntryType.text,
      textContent: 'a good day',
    );

    await tester.pumpWidget(
      _tileApp(
        repository: FakeJournalRepository(
          entries: <Entry>[entry],
          photos: <String, List<EntryPhoto>>{
            'entry-1': <EntryPhoto>[
              photoOf(id: 'photo-1', mediaId: 'blob-1'),
            ],
          },
        ),
        entry: entry,
      ),
    );
    await tester.pump();

    expect(find.byType(MediaImage), findsNothing);
  });

  testWidgets('a video entry receives the shared decoder slot registry',
      (WidgetTester tester) async {
    final Directory dir = Directory.systemTemp.createTempSync('day_video');
    addTearDown(() {
      if (dir.existsSync()) {
        dir.deleteSync(recursive: true);
      }
    });
    final File file = File('${dir.path}/v.mp4');
    file.writeAsBytesSync(<int>[0, 1, 2, 3]);

    final LruVideoSlots slots = LruVideoSlots(cap: 1);
    addTearDown(slots.dispose);
    final VideoSlotToken? occupant = slots.acquire(
      onEvicted: () {},
      evictionRights: VideoSlotEvictionRights.evictUnpinned,
    );
    slots.pin(occupant);

    final Entry entry = entryOf(
      type: EntryType.video,
      mediaId: 'vid',
      durationMs: 4000,
    );

    await tester.pumpWidget(
      _tileApp(
        repository: FakeJournalRepository(entries: <Entry>[entry]),
        entry: entry,
        resolver: FakeMediaResolver(<String, ResolvedMedia>{
          'vid': ResolvedMedia.available(
            blob: blobOf(id: 'vid', relPath: 'v.mp4', kind: MediaKind.video),
            file: file,
          ),
        }),
        overrides: <Override>[videoSlotsProvider.overrideWithValue(slots)],
      ),
    );
    await tester.pump();

    expect(find.byType(VideoBody), findsOneWidget);
    expect(find.byType(CorruptMediaPlaceholder), findsNothing);
    expect(find.byType(NeutralMediaPlaceholder), findsOneWidget);
  });

  testWidgets('hands EntryCard preview:false so the note renders in full',
      (WidgetTester tester) async {
    final StringBuffer buffer = StringBuffer();
    int word = 0;
    while (buffer.length < notePreviewCharLimit * 2) {
      if (buffer.isNotEmpty) {
        buffer.write(' ');
      }
      buffer.write('word${word++}');
    }
    final String note = buffer.toString();
    final Entry entry = entryOf(type: EntryType.text, textContent: note);

    await tester.pumpWidget(
      _tileApp(
        repository: FakeJournalRepository(entries: <Entry>[entry]),
        entry: entry,
      ),
    );
    await tester.pump();

    final EntryCard card = tester.widget<EntryCard>(find.byType(EntryCard));
    expect(card.preview, isFalse);
    expect(find.byType(NoteBody), findsOneWidget);
    expect(find.byType(NotePreview), findsNothing);
    expect(find.text(noteReadMoreLabel), findsNothing);
    expect(
      tester.widget<NoteDocument>(find.byType(NoteDocument)).source,
      note,
    );
  });
}
