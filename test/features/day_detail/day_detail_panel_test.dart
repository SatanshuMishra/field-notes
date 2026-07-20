import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/day_detail_panel.dart';
import 'package:field_notes/features/day_detail/day_detail_providers.dart';
import 'package:field_notes/state/state.dart';

import 'support/day_detail_harness.dart';

Widget _panelApp(
  FakeJournalRepository repository, {
  Override? mediaResolver,
}) {
  return ProviderScope(
    overrides: <Override>[
      journalRepositoryProvider.overrideWithValue(repository),
      mediaResolver ??
          dayDetailMediaResolverProvider.overrideWith(
            (Ref ref) => FakeMediaResolver(),
          ),
    ],
    child: dayDetailHarness(const DayDetailPanel(date: '2026-07-19')),
  );
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

    expect(find.text('Write a note'), findsOneWidget);
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

    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    expect(find.text('Edit note'), findsOneWidget);
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

    await tester.tap(find.text('Delete'));
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

    await tester.tap(find.text('Delete').first);
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

    await tester.tap(find.text('Delete'));
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
}
