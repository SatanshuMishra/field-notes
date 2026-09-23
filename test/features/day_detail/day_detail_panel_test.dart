import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/day_detail/day_detail_edit_note.dart';
import 'package:field_notes/features/day_detail/day_detail_header.dart';
import 'package:field_notes/features/day_detail/day_detail_panel.dart';
import 'package:field_notes/features/day_detail/day_detail_providers.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../capture/core/capture_test_support.dart' show FakeDraftStore;
import 'support/day_detail_harness.dart';

Finder _panelCard() => find.byKey(dayDetailPanelKey);

Future<void> _revealPillOn(WidgetTester tester, Finder card) async {
  await tester.longPress(card);
  await tester.pumpAndSettle();
}

Future<void> _confirmDelete(WidgetTester tester) async {
  await tester.tap(find.byKey(logActionsDeleteKey).hitTestable());
  await tester.pumpAndSettle();
  expect(find.text('Delete this entry?'), findsOneWidget);
  await tester.tap(find.byKey(confirmDialogConfirmKey));
  await tester.pumpAndSettle();
}

Future<void> _drainToast(WidgetTester tester) async {
  await tester.pump(kToastLifetime);
  await tester.pumpAndSettle();
}

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
      todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 23, 9)),
    ],
    child: dayDetailHarness(
      DayDetailPanel(date: '2026-07-19', focusEntryId: focusEntryId),
    ),
  );
}

String _longNote(int index) {
  final StringBuffer buffer = StringBuffer('journal note number $index');
  int word = 0;
  while (buffer.length < 600) {
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
    expect(find.text('a day in the garden'), findsOneWidget);
    expect(find.text('2026'), findsNothing);
    expect(find.text(dayDetailMoodPrompt), findsOneWidget);
    expect(find.text('2 logs that day'), findsOneWidget);
    expect(find.byType(CompactLogCard), findsNWidgets(2));
    expect(find.text('a good day'), findsOneWidget);
    expect(find.text('and a walk'), findsOneWidget);
  });

  testWidgets('shows the dashed empty state when the day has no entries',
      (WidgetTester tester) async {
    await tester.pumpWidget(_panelApp(FakeJournalRepository()));
    await tester.pumpAndSettle();

    expect(find.text('0 logs that day'), findsOneWidget);
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
    expect(find.text('Back'), findsOneWidget);
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

    await _revealPillOn(tester, find.byType(CompactLogCard));
    await tester.tap(find.byKey(logActionsEditKey).hitTestable());
    await tester.pumpAndSettle();

    expect(
      find.text(
        editNoteTitleFor(
          entryOf(type: EntryType.text, textContent: 'a good day'),
        ),
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
    expect(find.text('1 log that day'), findsOneWidget);

    await _revealPillOn(tester, find.byType(CompactLogCard));
    await _confirmDelete(tester);

    expect(repository.deletedEntryIds, <String>['entry-1']);
    expect(find.text('a good day'), findsNothing);
    expect(find.text('0 logs that day'), findsOneWidget);
    await _drainToast(tester);
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

    await _revealPillOn(
      tester,
      find.descendant(
        of: find.byKey(const ValueKey<String>('entry-1')),
        matching: find.byType(CompactLogCard),
      ),
    );
    await _confirmDelete(tester);

    expect(repository.deletedEntryIds, <String>['entry-1']);
    expect(find.byKey(const ValueKey<String>('entry-1')), findsNothing);
    expect(find.text('a good day'), findsNothing);
    expect(survivor, findsOneWidget);
    expect(identical(tester.element(survivor), survivorElement), isTrue);
    await _drainToast(tester);
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

    await _revealPillOn(tester, find.byType(CompactLogCard));
    await _confirmDelete(tester);

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
    expect(find.text('0 logs that day'), findsNothing);
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
    expect(find.text('1 log that day'), findsOneWidget);
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

    final int builtTiles = find
        .byType(CompactLogCard, skipOffstage: false)
        .evaluate()
        .length;
    expect(builtTiles, greaterThan(0));
    expect(builtTiles, lessThan(entryCount));
  });

  testWidgets('the panel is capped at 560 wide and 86 percent tall',
      (WidgetTester tester) async {
    await tester.pumpWidget(_panelApp(FakeJournalRepository()));
    await tester.pumpAndSettle();

    expect(dayDetailPanelMaxWidth, 560);
    expect(tester.getSize(_panelCard()).width, 560);
    expect(tester.getSize(_panelCard()).height, lessThanOrEqualTo(600 * 0.86));
  });

  testWidgets('a narrow window leaves a 16 gutter either side of the panel',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_panelApp(FakeJournalRepository()));
    await tester.pumpAndSettle();

    expect(tester.getSize(_panelCard()).width, 400 - 32);
  });

  testWidgets('a long day fills 86 percent of the window',
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
    expect(panel.height, closeTo(900 * dayDetailPanelHeightShare, 0.01));
    expect(panel.height, greaterThan(520));
  });

  testWidgets('a day-detail card reads in the padded column of the panel',
      (WidgetTester tester) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        entryOf(type: EntryType.text, textContent: 'a good day'),
      ],
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    final Rect panel = tester.getRect(_panelCard());
    final Rect card = tester.getRect(find.byType(CompactLogCard));
    expect(card.width, 560 - 2 * 2 - 2 * 18);
    expect(card.left, panel.left + 2 + 18);
    expect(
      tester.widget<CompactLogCard>(find.byType(CompactLogCard)).density,
      CompactLogDensity.day,
    );
  });

  testWidgets('a one-entry day keeps the body shrink-wrapped to its content',
      (WidgetTester tester) async {
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        entryOf(id: 'entry-1', type: EntryType.text, textContent: 'a good day'),
      ],
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    final double bodyBottom = tester.getBottomLeft(find.byType(ListView)).dy;
    final double cardBottom = tester
        .getBottomLeft(find.byKey(const ValueKey<String>('entry-1')))
        .dy;
    expect(bodyBottom, cardBottom + 20);
    expect(
      tester.getSize(_panelCard()).height,
      lessThan(600 * dayDetailPanelHeightShare),
    );
  });

  testWidgets('a long note reads as a compact lead with a Read link',
      (WidgetTester tester) async {
    final String note = _longNote(0);
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        entryOf(type: EntryType.text, textContent: note),
      ],
    );

    await tester.pumpWidget(_panelApp(repository));
    await tester.pumpAndSettle();

    expect(find.byType(CompactLogCard), findsOneWidget);
    expect(find.byKey(compactLogOpenLabelKey), findsOneWidget);
    expect(find.text('journal note number 0 word0 word1 word2 word3 word4…'),
        findsNothing);
    expect(find.byType(NoteDocument), findsNothing);
    expect(find.textContaining('word60'), findsNothing);
  });

  testWidgets('the header stays fixed while the body scrolls',
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

    final double headerTop = tester.getTopLeft(find.byType(DayDetailHeader)).dy;
    await tester.drag(find.byType(ListView), const Offset(0, -400));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byType(DayDetailHeader)).dy, headerTop);
    expect(find.byKey(const ValueKey<String>('entry-0')), findsNothing);
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
