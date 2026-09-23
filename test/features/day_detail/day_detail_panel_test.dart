import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/day_detail/day_detail_entry_tile.dart';
import 'package:field_notes/features/day_detail/day_detail_panel.dart';
import 'package:field_notes/features/day_detail/day_detail_providers.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/state/state.dart';

import '../capture/core/capture_test_support.dart' show FakeDraftStore;
import 'support/day_detail_harness.dart';

Finder _tileAction(String label) => find.byWidgetPredicate(
      (Widget widget) =>
          widget is IconStickerButton && widget.semanticLabel == label,
    );

Finder _panelConstraints() => find
    .descendant(
      of: find.byType(DayDetailPanel),
      matching: find.byType(ConstrainedBox),
    )
    .first;

Finder _panelCard() => find
    .descendant(
      of: find.byType(DayDetailPanel),
      matching: find.byType(StickerCard),
    )
    .first;

Widget _panelApp(
  FakeJournalRepository repository, {
  Override? mediaResolver,
  String? focusEntryId,
}) {
  return ProviderScope(
    overrides: <Override>[
      journalRepositoryProvider.overrideWithValue(repository),
      draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
      mediaResolver ??
          dayDetailMediaResolverProvider.overrideWith(
            (Ref ref) => FakeMediaResolver(),
          ),
    ],
    child: dayDetailHarness(
      DayDetailPanel(date: '2026-07-19', focusEntryId: focusEntryId),
    ),
  );
}

String _longNote(int index) {
  final StringBuffer buffer = StringBuffer('journal note number $index');
  int word = 0;
  while (buffer.length < notePreviewCharLimit * 2) {
    buffer.write(' word${word++}');
  }
  return buffer.toString();
}

void main() {
  testWidgets('renders the day heading, mood prompt, count and entries',
      (WidgetTester tester) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        entryOf(id: 'entry-1', type: EntryType.text, textContent: 'a good day'),
        entryOf(id: 'entry-2', type: EntryType.text, textContent: 'and a walk'),
      ],
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    expect(find.text('Sunday, July 19'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
    expect(find.text(dayDetailMoodPrompt), findsOneWidget);
    expect(find.text('2 entries'), findsOneWidget);
    expect(find.text('a good day'), findsOneWidget);
    expect(find.text('and a walk'), findsOneWidget);
  });

  testWidgets('shows the dashed empty state when the day has no entries',
      (WidgetTester tester) async {
    await tester.pumpWidget(_panelApp(FakeJournalRepository()));
    await tester.pumpAndSettle();

    expect(find.text('No entries yet'), findsOneWidget);
    expect(find.byType(EmptyStatePlaceholder), findsOneWidget);
    expect(find.text(dayDetailEmptyMessage), findsOneWidget);
  });

  testWidgets('tapping add a note opens the note composer',
      (WidgetTester tester) async {
    await tester.pumpWidget(_panelApp(FakeJournalRepository()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add a note'));
    await tester.pumpAndSettle();

    expect(find.text(newNoteTitle), findsOneWidget);
    expect(find.text('Sunday, July 19'), findsWidgets);
  });

  testWidgets('tapping edit opens the note editor prefilled',
      (WidgetTester tester) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        entryOf(type: EntryType.text, textContent: 'a good day'),
      ],
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(_tileAction(entryEditLabel));
    await tester.pumpAndSettle();

    expect(
      find.textContaining(
        RegExp(r'^Editing (morning|afternoon|evening|night) note$'),
      ),
      findsOneWidget,
    );
    expect(find.text('a good day'), findsWidgets);
  });

  testWidgets('deleting an entry soft-deletes it and updates the list',
      (WidgetTester tester) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        entryOf(type: EntryType.text, textContent: 'a good day'),
      ],
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();
    expect(find.text('1 entry'), findsOneWidget);

    await tester.tap(_tileAction(entryDeleteLabel));
    await tester.pumpAndSettle();

    expect(repository.deletedEntryIds, <String>['entry-1']);
    expect(find.text('a good day'), findsNothing);
    expect(find.text('No entries yet'), findsOneWidget);
  });

  testWidgets('a delete rebuilds the surviving tiles by id, not by position',
      (WidgetTester tester) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        entryOf(id: 'entry-1', type: EntryType.text, textContent: 'a good day'),
        entryOf(
          id: 'entry-2',
          type: EntryType.voice,
          mediaId: 'blob-1',
          durationMs: 4000,
        ),
      ],
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    final Finder survivor = find.byKey(const ValueKey<String>('entry-2'));
    expect(survivor, findsOneWidget);
    final Element survivorElement = tester.element(survivor);

    await tester.tap(_tileAction(entryDeleteLabel).first);
    await tester.pumpAndSettle();

    expect(repository.deletedEntryIds, <String>['entry-1']);
    expect(find.byKey(const ValueKey<String>('entry-1')), findsNothing);
    expect(find.text('a good day'), findsNothing);
    expect(survivor, findsOneWidget);
    expect(identical(tester.element(survivor), survivorElement), isTrue);
  });

  testWidgets('surfaces a non-destructive message when the delete fails',
      (WidgetTester tester) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        entryOf(type: EntryType.text, textContent: 'a good day'),
      ],
    )..deleteError = Exception('locked');

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    await tester.tap(_tileAction(entryDeleteLabel));
    await tester.pumpAndSettle();

    expect(repository.deletedEntryIds, isEmpty);
    expect(find.text(dayDetailDeleteErrorMessage), findsOneWidget);
    expect(find.text('a good day'), findsOneWidget);
  });

  testWidgets('surfaces a load error and never claims the day is empty',
      (WidgetTester tester) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      entriesError: Exception('database unavailable'),
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    expect(find.text(dayDetailEntriesErrorMessage), findsOneWidget);
    expect(find.text('Sunday, July 19'), findsOneWidget);
    expect(find.byType(EmptyStatePlaceholder), findsNothing);
    expect(find.text(dayDetailEmptyMessage), findsNothing);
    expect(find.text('No entries yet'), findsNothing);
  });

  testWidgets('surfaces a media error instead of mounting unplayable tiles',
      (WidgetTester tester) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        entryOf(type: EntryType.text, textContent: 'a good day'),
      ],
    );

    await tester.pumpWidget(
      _panelApp(
        repository,
        mediaResolver: dayDetailMediaResolverProvider.overrideWith(
          (Ref ref) async => throw Exception('no media directory'),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(dayDetailMediaErrorMessage), findsOneWidget);
    expect(find.text('a good day'), findsNothing);
    expect(find.byKey(const ValueKey<String>('entry-1')), findsNothing);
    expect(find.text('1 entry'), findsOneWidget);
    expect(find.text('Sunday, July 19'), findsOneWidget);
  });

  testWidgets('builds only a bounded subset of tiles for a large day',
      (WidgetTester tester) async {
    const int entryCount = 40;
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        for (int i = 0; i < entryCount; i++)
          entryOf(
            id: 'entry-$i',
            type: EntryType.text,
            textContent: 'journal note number $i for the day',
          ),
      ],
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    final int builtTiles = find.byType(DayDetailEntryTile).evaluate().length;
    expect(builtTiles, greaterThan(0));
    expect(builtTiles, lessThan(entryCount));
  });

  testWidgets('the panel is capped at 640 wide and only by the viewport tall',
      (WidgetTester tester) async {
    await tester.pumpWidget(_panelApp(FakeJournalRepository()));
    await tester.pumpAndSettle();

    final ConstrainedBox box = tester.widget<ConstrainedBox>(
      _panelConstraints(),
    );
    expect(box.constraints, const BoxConstraints(maxWidth: 640));
    expect(box.constraints.maxWidth, dayDetailPanelMaxWidth);
    expect(box.constraints.hasBoundedHeight, isFalse);
    expect(tester.getSize(_panelCard()).width, 640);
  });

  testWidgets('a long day fills the viewport less a vertical margin',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        for (int i = 0; i < 40; i++)
          entryOf(
            id: 'entry-$i',
            type: EntryType.text,
            textContent: 'journal note number $i for the day',
          ),
      ],
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    final Size panel = tester.getSize(_panelCard());
    expect(panel.height, 900 - 2 * dayDetailPanelVerticalMargin);
    expect(panel.height, greaterThan(520));
  });

  testWidgets('a day-detail note reads in a 560 column inside the panel',
      (WidgetTester tester) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        entryOf(type: EntryType.text, textContent: 'a good day'),
      ],
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    expect(tester.getSize(find.byType(DayDetailEntryTile)).width, 600);
    expect(tester.getSize(find.text('a good day')).width, 560);
  });

  testWidgets('a one-entry day keeps the list shrink-wrapped to its content',
      (WidgetTester tester) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        entryOf(id: 'entry-1', type: EntryType.text, textContent: 'a good day'),
      ],
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    final double listHeight = tester.getSize(find.byType(ListView)).height;
    final double tileHeight =
        tester.getSize(find.byKey(const ValueKey<String>('entry-1'))).height;
    expect(listHeight, tileHeight);
  });

  testWidgets('a long note reads in full, never behind a preview fade',
      (WidgetTester tester) async {
    final String note = _longNote(0);
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        entryOf(type: EntryType.text, textContent: note),
      ],
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    expect(find.byType(NoteBody), findsOneWidget);
    expect(find.byType(NotePreview), findsNothing);
    expect(find.text(noteReadMoreLabel), findsNothing);
    expect(
      tester.widget<NoteDocument>(find.byType(NoteDocument)).source,
      note,
    );
  });

  testWidgets('opening with focusEntryId scrolls that entry into view',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    const String focused = 'entry-30';
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        for (int i = 0; i < 40; i++)
          entryOf(
            id: 'entry-$i',
            type: EntryType.text,
            textContent: 'journal note number $i for the day',
          ),
      ],
    );

    await tester.pumpWidget(
      _panelApp(repository, focusEntryId: focused),
    );
    await tester.pumpAndSettle();

    final Finder tile = find.byKey(const ValueKey<String>(focused));
    expect(tile, findsOneWidget);
    final Rect tileRect = tester.getRect(tile);
    final Rect listRect = tester.getRect(find.byType(ListView));
    expect(tileRect.top, greaterThanOrEqualTo(listRect.top - 1));
    expect(tileRect.bottom, lessThanOrEqualTo(listRect.bottom + 1));
  });

  testWidgets('opening without focusEntryId stays at the top of the day',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        for (int i = 0; i < 40; i++)
          entryOf(
            id: 'entry-$i',
            type: EntryType.text,
            textContent: 'journal note number $i for the day',
          ),
      ],
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('entry-0')), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('entry-30')), findsNothing);
  });
}
