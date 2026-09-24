import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/day_detail_panel.dart';
import 'package:field_notes/features/day_detail/day_detail_providers.dart';
import 'package:field_notes/features/entry_cards/compact/compact_log_card.dart';
import 'package:field_notes/features/entry_cards/cards/note_body.dart';
import 'package:field_notes/features/entry_cards/compact/log_actions_pill.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart';
import 'package:field_notes/features/notes/notes.dart';
import 'package:field_notes/features/today/today_entry_feed.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/note_editor_driver.dart';
import '../capture/core/capture_test_support.dart' show FakeDraftStore;
import '../day_detail/support/day_detail_harness.dart'
    show FakeJournalRepository;
import 'support/today_harness.dart';

const String _date = '2026-07-19';

Entry _entry({required String id, required int hour, required String text}) {
  return Entry(
    id: id,
    dayId: 'day-1',
    type: EntryType.text,
    textContent: text,
    createdAt: DateTime(2026, 7, 19, hour, 12).millisecondsSinceEpoch,
    updatedAt: 0,
  );
}

List<Entry> _entries() {
  return <Entry>[
    _entry(id: 'entry-1', hour: 8, text: 'morning walk'),
    _entry(id: 'entry-2', hour: 14, text: 'coffee on the porch'),
  ];
}

Widget _feed() {
  return CustomScrollView(
    slivers: <Widget>[TodayEntryFeed(date: _date)],
  );
}

List<Override> _overrides(FakeJournalRepository repository) {
  final List<Entry> entries = _entries();
  return <Override>[
    entriesForDateProvider.overrideWith(
      (Ref ref, String date) => Stream<List<Entry>>.value(entries),
    ),
    photosForEntryProvider.overrideWith(
      (Ref ref, String entryId) =>
          Stream<List<EntryPhoto>>.value(const <EntryPhoto>[]),
    ),
    todayMediaResolverProvider
        .overrideWith((Ref ref) async => const StubMediaResolver()),
    notesMediaResolverProvider
        .overrideWith((Ref ref) async => const StubMediaResolver()),
    dayDetailMediaResolverProvider
        .overrideWith((Ref ref) async => const StubMediaResolver()),
    dayForDateProvider.overrideWith(
      (Ref ref, String date) => Stream<Day?>.value(
        todayTestDay(date: date, mood: Mood.calm),
      ),
    ),
    journalRepositoryProvider.overrideWithValue(repository),
    draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
    todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 19, 20)),
  ];
}

Finder _cardFor(String text) => find.ancestor(
      of: find.byWidgetPredicate(
        (Widget w) => w is NoteBody && w.text == text,
      ),
      matching: find.byType(CompactLogCard),
    );

Future<void> _hover(WidgetTester tester, Finder card) async {
  final TestGesture mouse =
      await tester.createGesture(kind: PointerDeviceKind.mouse);
  addTearDown(mouse.removePointer);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(tester.getCenter(card));
  await tester.pumpAndSettle();
}

Future<void> _drainToast(WidgetTester tester) async {
  await tester.pump(kToastLifetime);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a feed card opens view mode and never the day modal',
      (WidgetTester tester) async {
    await pumpToday(
      tester,
      _feed(),
      surface: todayDesktopSurface,
      overrides: _overrides(FakeJournalRepository(entries: _entries())),
    );

    await tester.tap(find.text('14:12 · afternoon'));
    await tester.pumpAndSettle();

    expect(find.byKey(logViewerPanelKey), findsOneWidget);
    expect(find.text('Afternoon note'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.byType(DayDetailPanel), findsNothing);
  });

  testWidgets('the feed lists compact cards with the manage pill',
      (WidgetTester tester) async {
    await pumpToday(
      tester,
      _feed(),
      surface: todayDesktopSurface,
      overrides: _overrides(FakeJournalRepository(entries: _entries())),
    );

    expect(find.byType(CompactLogCard), findsNWidgets(2));
    final CompactLogCard card =
        tester.widget<CompactLogCard>(_cardFor('morning walk'));
    expect(card.density, CompactLogDensity.feed);

    await _hover(tester, _cardFor('morning walk'));

    expect(find.byKey(logActionsDeleteKey).hitTestable(), findsOneWidget);
  });

  testWidgets('deleting from the feed asks first, then deletes and toasts',
      (WidgetTester tester) async {
    final FakeJournalRepository repository =
        FakeJournalRepository(entries: _entries());
    await pumpToday(
      tester,
      _feed(),
      surface: todayDesktopSurface,
      overrides: _overrides(repository),
    );

    await _hover(tester, _cardFor('coffee on the porch'));
    await tester.tap(find.byKey(logActionsDeleteKey).hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Delete this entry?'), findsOneWidget);
    expect(
      find.text('This log will be removed from today. This can’t be undone.'),
      findsOneWidget,
    );
    expect(repository.deletedEntryIds, isEmpty);

    await tester.tap(find.byKey(confirmDialogConfirmKey));
    await tester.pumpAndSettle();

    expect(repository.deletedEntryIds, <String>['entry-2']);
    expect(find.text('Entry deleted'), findsOneWidget);
    await _drainToast(tester);
  });

  testWidgets("the pill's Edit opens edit mode directly with Cancel",
      (WidgetTester tester) async {
    await pumpToday(
      tester,
      _feed(),
      surface: todayDesktopSurface,
      overrides: _overrides(FakeJournalRepository(entries: _entries())),
    );

    await _hover(tester, _cardFor('coffee on the porch'));
    await tester.tap(find.byKey(logActionsEditKey).hitTestable());
    await tester.pumpAndSettle();

    expect(NoteEditorDriver(tester).source, contains('coffee on the porch'));
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Afternoon note'), findsNothing);
    expect(find.text('Editing afternoon note'), findsOneWidget);
  });
}
