import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/day_detail_header.dart';
import 'package:field_notes/features/day_detail/day_detail_panel.dart';
import 'package:field_notes/features/day_detail/day_detail_providers.dart';
import 'package:field_notes/features/day_detail/show_day_detail.dart';
import 'package:field_notes/features/entry_cards/cards/note_body.dart';
import 'package:field_notes/features/entry_cards/compact/compact_log_card.dart';
import 'package:field_notes/features/entry_cards/compact/log_actions_pill.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../capture/core/capture_test_support.dart' show FakeDraftStore;
import 'support/day_detail_harness.dart';

const String _date = '2026-07-19';
const String _dayTitle = 'Sunday, July 19';

Entry _entry({
  required String id,
  required int hour,
  EntryType type = EntryType.text,
  String? textContent,
  String? mediaId,
  int? durationMs,
}) {
  return Entry(
    id: id,
    dayId: 'day-1',
    type: type,
    textContent: textContent,
    mediaId: mediaId,
    durationMs: durationMs,
    createdAt: DateTime(2026, 7, 19, hour, 12).millisecondsSinceEpoch,
    updatedAt: 0,
  );
}

String _longNote(int index) {
  final StringBuffer buffer = StringBuffer(
    'Walked the long path round the pond number $index.',
  );
  int word = 0;
  while (buffer.length < 600) {
    buffer.write(' ripple${word++}');
  }
  return buffer.toString();
}

List<Entry> _threeNotes() {
  return <Entry>[
    _entry(id: 'entry-1', hour: 8, textContent: 'Watered the roses.'),
    _entry(id: 'entry-2', hour: 14, textContent: 'Tea under the elm.'),
    _entry(id: 'entry-3', hour: 19, textContent: 'Fireflies at dusk.'),
  ];
}

class _DayOpener extends StatelessWidget {
  const _DayOpener();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showDayDetail(context, date: _date),
        child: const Text('open day'),
      ),
    );
  }
}

Future<FakeJournalRepository> _openDay(
  WidgetTester tester, {
  required List<Entry> entries,
}) async {
  final FakeJournalRepository repository = FakeJournalRepository(
    entries: entries,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        journalRepositoryProvider.overrideWithValue(repository),
        draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
        mediaStoreProvider.overrideWith(
          (Ref ref) async => FakeMediaStore(Directory.systemTemp),
        ),
        dayDetailMediaResolverProvider.overrideWith(
          (Ref ref) => FakeMediaResolver(),
        ),
        todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 23, 9)),
      ],
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _DayOpener(),
      ),
    ),
  );
  await tester.tap(find.text('open day'));
  await tester.pumpAndSettle();
  return repository;
}

void _useWindow(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Finder _dayTitleInPanel() => find.descendant(
  of: find.byType(DayDetailPanel),
  matching: find.text(_dayTitle),
);

Finder _panel() => find.byKey(dayDetailPanelKey);

final TargetPlatformVariant _bothLayouts = TargetPlatformVariant(
  <TargetPlatform>{TargetPlatform.android, TargetPlatform.macOS},
);

final TargetPlatformVariant _macOS = TargetPlatformVariant.only(
  TargetPlatform.macOS,
);

void main() {
  testWidgets('the day modal carries no fallback underline', (
    WidgetTester tester,
  ) async {
    await _openDay(tester, entries: _threeNotes());

    final Finder title = _dayTitleInPanel();
    expect(title, findsOneWidget);
    final TextStyle style = DefaultTextStyle.of(tester.element(title)).style;
    expect(style.decoration ?? TextDecoration.none, TextDecoration.none);
  }, variant: _bothLayouts);

  testWidgets('a long day stays inside 86 percent of the window under a '
      'fixed header', (WidgetTester tester) async {
    _useWindow(tester, const Size(1280, 800));
    await _openDay(
      tester,
      entries: <Entry>[
        for (int i = 0; i < 12; i++)
          _entry(id: 'entry-$i', hour: 6 + i, textContent: _longNote(i)),
      ],
    );

    expect(tester.getSize(_panel()).height, lessThanOrEqualTo(688));
    expect(find.byType(CompactLogCard), findsWidgets);

    final double headerTop = tester.getTopLeft(find.byType(DayDetailHeader)).dy;
    await tester.drag(find.byType(CompactLogCard).first, const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.byType(DayDetailHeader)).dy, headerTop);
    expect(tester.getSize(_panel()).height, lessThanOrEqualTo(688));
  }, variant: _macOS);

  testWidgets('every card stays inside the panel at a narrow window and '
      'doubled text', (WidgetTester tester) async {
    _useWindow(tester, const Size(360, 740));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _openDay(
      tester,
      entries: <Entry>[
        _entry(id: 'entry-1', hour: 8, textContent: 'Watered the roses.'),
        _entry(
          id: 'entry-2',
          hour: 12,
          textContent:
              'Pruned the climbing rose back to the trellis and tied '
              'the new canes in before the rain came through the valley.',
        ),
        _entry(id: 'entry-3', hour: 18, textContent: _longNote(3)),
        _entry(
          id: 'entry-4',
          hour: 20,
          type: EntryType.voice,
          mediaId: 'voice-that-is-gone',
        ),
      ],
    );

    expect(find.byType(CompactLogCard, skipOffstage: false), findsWidgets);
    final Rect panel = tester.getRect(_panel());
    expect(panel.width, lessThanOrEqualTo(360 - 32));
    for (final (String stamp, bool fitsWhole) in <(String, bool)>[
      ('8:12 AM · morning · note', true),
      ('12:12 PM · afternoon · note', true),
      ('6:12 PM · evening · note', false),
      ('8:12 PM · evening · voice', true),
    ]) {
      await tester.scrollUntilVisible(
        find.text(stamp),
        80,
        scrollable: find.descendant(
          of: _panel(),
          matching: find.byType(Scrollable),
        ),
      );
      final Finder card = find.ancestor(
        of: find.text(stamp),
        matching: find.byType(CompactLogCard),
      );
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      final Rect rect = tester.getRect(card);
      expect(panel.left, lessThanOrEqualTo(rect.left));
      expect(panel.right, greaterThanOrEqualTo(rect.right));
      expect(panel.top, lessThanOrEqualTo(rect.top));
      if (fitsWhole) {
        expect(panel.bottom, greaterThanOrEqualTo(rect.bottom));
      }
    }
    expect(tester.getRect(_panel()), panel);
    expect(tester.takeException(), isNull);
  }, variant: _macOS);

  testWidgets('on the phone every card and its actions stay inside the sheet '
      'at a narrow window and doubled text', (WidgetTester tester) async {
    _useWindow(tester, const Size(360, 740));
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await _openDay(
      tester,
      entries: <Entry>[
        _entry(id: 'entry-1', hour: 8, textContent: 'Watered the roses.'),
        _entry(
          id: 'entry-2',
          hour: 12,
          textContent:
              'Pruned the climbing rose back to the trellis and tied '
              'the new canes in before the rain came through the valley.',
        ),
        _entry(id: 'entry-3', hour: 18, textContent: _longNote(3)),
        _entry(
          id: 'entry-4',
          hour: 20,
          type: EntryType.voice,
          mediaId: 'voice-that-is-gone',
        ),
      ],
    );

    final Rect sheet = tester.getRect(find.byType(PhoneSheet));
    expect(sheet.width, 360);
    for (final String id in <String>[
      'entry-1',
      'entry-2',
      'entry-3',
      'entry-4',
    ]) {
      final Finder card = find.descendant(
        of: find.byKey(ValueKey<String>(id)),
        matching: find.byType(CompactLogCard),
      );
      await tester.ensureVisible(card);
      await tester.pumpAndSettle();
      final Rect rect = tester.getRect(card);
      expect(rect.left, greaterThanOrEqualTo(sheet.left), reason: id);
      expect(rect.right, lessThanOrEqualTo(sheet.right), reason: id);
      final Rect delete = tester.getRect(find.byKey(daySheetDeleteKeyFor(id)));
      expect(delete.right, lessThanOrEqualTo(rect.right), reason: id);
      expect(delete.top, lessThan(rect.top), reason: id);
      expect(delete.bottom, greaterThan(rect.top), reason: id);
    }
    expect(tester.takeException(), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('the day modal lists compact cards', (WidgetTester tester) async {
    await _openDay(tester, entries: _threeNotes());

    expect(find.byType(CompactLogCard), findsNWidgets(3));
    for (final String text in <String>[
      'Watered the roses.',
      'Tea under the elm.',
      'Fireflies at dusk.',
    ]) {
      expect(
        find.descendant(
          of: find.byType(CompactLogCard),
          matching: find.byWidgetPredicate(
            (Widget w) => w is NoteBody && w.text.contains(text),
          ),
        ),
        findsOneWidget,
      );
    }
  }, variant: _bothLayouts);

  testWidgets('a card hands over to view mode and Back returns to the day', (
    WidgetTester tester,
  ) async {
    await _openDay(tester, entries: _threeNotes());

    await tester.tap(find.text('8:12 AM · morning · note'));
    await tester.pumpAndSettle();

    expect(find.text('Morning note'), findsOneWidget);
    expect(_dayTitleInPanel(), findsNothing);
    expect(find.byType(DayDetailPanel), findsNothing);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Morning note'), findsNothing);
    expect(_dayTitleInPanel(), findsOneWidget);
  }, variant: _bothLayouts);

  testWidgets('a scrim tap in view mode closes the day modal too', (
    WidgetTester tester,
  ) async {
    await _openDay(tester, entries: _threeNotes());

    await tester.tap(find.text('8:12 AM · morning · note'));
    await tester.pumpAndSettle();
    expect(find.text('Morning note'), findsOneWidget);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(find.text('Morning note'), findsNothing);
    expect(find.byType(DayDetailPanel, skipOffstage: false), findsNothing);
    expect(find.text('open day'), findsOneWidget);
  }, variant: _bothLayouts);

  testWidgets('deleting from a pill asks first, then deletes and toasts', (
    WidgetTester tester,
  ) async {
    final FakeJournalRepository repository = await _openDay(
      tester,
      entries: _threeNotes(),
    );

    await tester.longPress(find.byType(CompactLogCard).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(logActionsDeleteKey).hitTestable());
    await tester.pumpAndSettle();

    expect(find.text('Delete this entry?'), findsOneWidget);
    expect(
      find.text('This log will be removed from July 19. This can’t be undone.'),
      findsOneWidget,
    );
    expect(repository.deletedEntryIds, isEmpty);

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    expect(repository.deletedEntryIds, <String>['entry-1']);
    expect(find.text('Entry deleted'), findsOneWidget);
    expect(find.byType(CompactLogCard), findsNWidgets(2));

    await tester.pump(kToastLifetime);
    await tester.pumpAndSettle();
  }, variant: _bothLayouts);

  testWidgets('Add a note opens edit mode with Back and returns to the day', (
    WidgetTester tester,
  ) async {
    await _openDay(tester, entries: _threeNotes());

    await tester.tap(find.text('Add a note'));
    await tester.pumpAndSettle();

    expect(find.text('Back'), findsOneWidget);
    expect(_dayTitleInPanel(), findsNothing);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text('Back'), findsNothing);
    expect(_dayTitleInPanel(), findsOneWidget);
  }, variant: _bothLayouts);
}
