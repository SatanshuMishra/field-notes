import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/text/text_composer.dart';
import 'package:field_notes/features/day_detail/day_detail.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../capture/core/capture_test_support.dart' show FakeDraftStore;
import 'support/day_detail_harness.dart';

const Size _phone = Size(384, 832);
const Size _desktop = Size(1280, 900);
const double _statusBar = 34;
const double _gestureBar = 24;
const String _date = '2026-07-19';
const String _dayTitle = 'Sunday, July 19';
const String _note = 'entry-note';
const String _voice = 'entry-voice';

void _usePhone(WidgetTester tester) {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  tester.view.viewPadding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  addTearDown(tester.view.reset);
}

void _useDesktop(WidgetTester tester) {
  tester.view.physicalSize = _desktop;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

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

List<Entry> _dayEntries() {
  return <Entry>[
    _entry(id: _note, hour: 8, textContent: 'Watered the roses.'),
    _entry(
      id: _voice,
      hour: 18,
      type: EntryType.voice,
      mediaId: 'voice-blob',
      durationMs: 4000,
    ),
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

List<Entry> _busyDay() {
  return <Entry>[
    for (int i = 0; i < 12; i++)
      _entry(
        id: 'entry-$i',
        hour: 6 + i,
        textContent: 'A long walk around the pond, number $i, with notes.',
      ),
  ];
}

Future<FakeJournalRepository> _openDay(
  WidgetTester tester, {
  required TargetPlatform platform,
  List<Entry>? entries,
}) async {
  final FakeJournalRepository repository = FakeJournalRepository(
    entries: entries ?? _dayEntries(),
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
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        home: const Scaffold(body: _DayOpener()),
      ),
    ),
  );
  await tester.tap(find.text('open day'));
  await tester.pumpAndSettle();
  return repository;
}

Finder _inSheet(Finder finder) =>
    find.descendant(of: find.byType(PhoneSheet), matching: finder);

Finder _inFooter(Finder finder) =>
    find.descendant(of: find.byKey(phoneSheetFooterKey), matching: finder);

Finder _entryAction(String entryId, String label) => find.descendant(
  of: find.byKey(ValueKey<String>(entryId)),
  matching: find.bySemanticsLabel(label),
);

Finder _faceOf(Finder action) =>
    find.descendant(of: action, matching: find.byType(Container)).first;

Finder _closeButton() => find
    .ancestor(
      of: _inFooter(find.text('Close')),
      matching: find.byType(Container),
    )
    .first;

Future<void> _drainToast(WidgetTester tester) async {
  await tester.pump(kToastLifetime);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a phone day opens as a sheet with Close and Add a note in its footer',
    (WidgetTester tester) async {
      _usePhone(tester);
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _openDay(tester, platform: TargetPlatform.android);

      expect(find.byType(PhoneSheet), findsOneWidget);
      expect(find.byKey(phoneSheetGrabberKey), findsOneWidget);
      expect(
        tester.widget<PhoneSheet>(find.byType(PhoneSheet)).color!.toARGB32(),
        FieldNotesColors.light.panelTop.toARGB32(),
      );
      expect(_inSheet(find.text('a day in the garden')), findsOneWidget);
      final Text title = tester.widget<Text>(_inSheet(find.text(_dayTitle)));
      expect(title.style!.fontSize, 22);
      expect(title.maxLines, 1);
      expect(title.overflow, TextOverflow.ellipsis);
      expect(find.byKey(dayDetailBackKey), findsNothing);
      expect(_inSheet(find.text(dayDetailMoodPrompt)), findsOneWidget);
      expect(_inSheet(find.text('2 logs that day')), findsOneWidget);
      expect(find.byType(CompactLogCard), findsNWidgets(2));

      expect(find.text('Add a note'), findsOneWidget);
      expect(_inFooter(find.text('Add a note')), findsOneWidget);
      expect(_inFooter(find.text('Close')), findsOneWidget);
      final Rect close = tester.getRect(_closeButton());
      final Rect add = tester.getRect(
        _inFooter(find.byKey(dayDetailAddNoteKey)),
      );
      expect(close.height, 48);
      expect(add.height, 48);
      expect(add.left, close.right + phoneSheetActionGap);
      expect(add.right, _phone.width - phoneSheetFooterPadding.right);
      expect(close.left, phoneSheetFooterPadding.left);

      for (final (String entryId, String label) in <(String, String)>[
        (_note, logActionsEditLabel),
        (_note, logActionsDeleteLabel),
        (_voice, logActionsDeleteLabel),
      ]) {
        final Finder action = _entryAction(entryId, label);
        expect(action, findsOneWidget, reason: '$entryId $label');
        expect(
          tester.getSize(_faceOf(action)),
          const Size(40, 40),
          reason: '$entryId $label face',
        );
        final Size reach = tester.getSize(action);
        expect(
          reach.width,
          greaterThanOrEqualTo(44),
          reason: '$entryId $label',
        );
        expect(
          reach.height,
          greaterThanOrEqualTo(44),
          reason: '$entryId $label',
        );
      }
      expect(_entryAction(_voice, logActionsEditLabel), findsNothing);
      semantics.dispose();
    },
  );

  testWidgets(
    'an entry Delete answers a tap at the edge of its 44 point area',
    (WidgetTester tester) async {
      _usePhone(tester);
      final SemanticsHandle semantics = tester.ensureSemantics();
      final FakeJournalRepository repository = await _openDay(
        tester,
        platform: TargetPlatform.android,
      );

      final Rect reach = tester.getRect(
        _entryAction(_note, logActionsDeleteLabel),
      );
      final Rect face = tester.getRect(
        _faceOf(_entryAction(_note, logActionsDeleteLabel)),
      );
      final Offset edge = reach.topLeft + const Offset(1, 1);
      expect(face.contains(edge), isFalse);
      await tester.tapAt(edge);
      await tester.pumpAndSettle();

      expect(find.text('Delete this entry?'), findsOneWidget);
      await tester.tap(find.byKey(confirmDialogConfirmKey));
      await tester.pumpAndSettle();

      expect(repository.deletedEntryIds, <String>[_note]);
      expect(_inSheet(find.text('1 log that day')), findsOneWidget);
      expect(find.byType(CompactLogCard), findsOneWidget);
      semantics.dispose();
      await _drainToast(tester);
    },
  );

  testWidgets('an entry Edit opens the note editor for that note', (
    WidgetTester tester,
  ) async {
    _usePhone(tester);
    final SemanticsHandle semantics = tester.ensureSemantics();
    await _openDay(tester, platform: TargetPlatform.android);

    await tester.tap(_entryAction(_note, logActionsEditLabel));
    await tester.pumpAndSettle();

    expect(find.text('Editing morning note'), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Add a note in the footer starts a note for that day', (
    WidgetTester tester,
  ) async {
    _usePhone(tester);
    await _openDay(tester, platform: TargetPlatform.android);

    await tester.tap(_inFooter(find.byKey(dayDetailAddNoteKey)));
    await tester.pumpAndSettle();

    expect(find.text(newNoteTitle), findsOneWidget);
    expect(find.text(_dayTitle), findsWidgets);
    expect(_inSheet(find.text('2 logs that day')), findsNothing);

    await tester.tap(find.text('Back'));
    await tester.pumpAndSettle();

    expect(find.text(newNoteTitle), findsNothing);
    expect(_inSheet(find.text('2 logs that day')), findsOneWidget);
  });

  testWidgets('Close in the footer and a scrim tap both close the day sheet', (
    WidgetTester tester,
  ) async {
    _usePhone(tester);
    await _openDay(tester, platform: TargetPlatform.android);

    await tester.tap(_closeButton());
    await tester.pumpAndSettle();

    expect(find.byType(PhoneSheet), findsNothing);
    expect(find.byType(DayDetailPanel), findsNothing);

    await tester.tap(find.text('open day'));
    await tester.pumpAndSettle();
    expect(find.byType(PhoneSheet), findsOneWidget);

    await tester.tapAt(Offset(_phone.width / 2, _statusBar + 4));
    await tester.pumpAndSettle();

    expect(find.byType(PhoneSheet), findsNothing);
  });

  testWidgets('a long day scrolls under a fixed header and footer', (
    WidgetTester tester,
  ) async {
    _usePhone(tester);
    final FakeJournalRepository repository = FakeJournalRepository(
      entries: <Entry>[
        for (int i = 0; i < 12; i++)
          _entry(
            id: 'entry-$i',
            hour: 6 + i,
            textContent: 'A long walk around the pond, number $i, with notes.',
          ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          journalRepositoryProvider.overrideWithValue(repository),
          dayDetailMediaResolverProvider.overrideWith(
            (Ref ref) => FakeMediaResolver(),
          ),
          todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 23, 9)),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: fieldNotesTheme(platform: TargetPlatform.android),
          home: const Scaffold(body: _DayOpener()),
        ),
      ),
    );
    await tester.tap(find.text('open day'));
    await tester.pumpAndSettle();

    final Rect sheet = tester.getRect(find.byType(PhoneSheet));
    expect(
      sheet.top,
      greaterThanOrEqualTo(_statusBar + phoneSheetTopClearance),
    );
    final double titleTop = tester
        .getTopLeft(_inSheet(find.text(_dayTitle)))
        .dy;
    final Rect footer = tester.getRect(find.byKey(phoneSheetFooterKey));
    expect(footer.bottom, _phone.height - _gestureBar);

    await tester.drag(find.byType(CompactLogCard).first, const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(_inSheet(find.text(_dayTitle))).dy, titleTop);
    expect(tester.getRect(find.byKey(phoneSheetFooterKey)), footer);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'a quiet day gives a short sheet and a busy day grows to near full',
    (WidgetTester tester) async {
      _usePhone(tester);
      await _openDay(
        tester,
        platform: TargetPlatform.android,
        entries: <Entry>[
          _entry(id: _note, hour: 8, textContent: 'Watered the roses.'),
        ],
      );

      expect(find.byType(CompactLogCard), findsOneWidget);
      final Rect quiet = tester.getRect(find.byType(PhoneSheet));
      expect(quiet.height, lessThan(_phone.height / 2));
      expect(quiet.bottom, _phone.height);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await _openDay(
        tester,
        platform: TargetPlatform.android,
        entries: _busyDay(),
      );

      final Rect busy = tester.getRect(find.byType(PhoneSheet));
      expect(busy.height, _phone.height - _statusBar - 8);
      expect(busy.top, _statusBar + 8);
      expect(busy.bottom, _phone.height);

      final Finder firstCard = find.byType(CompactLogCard).first;
      final double cardTop = tester.getTopLeft(firstCard).dy;
      await tester.drag(firstCard, const Offset(0, -300));
      await tester.pumpAndSettle();

      expect(tester.getTopLeft(firstCard).dy, lessThan(cardTop - 100));
      expect(tester.getRect(find.byType(PhoneSheet)), busy);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('on macOS a day keeps its centred panel', (
    WidgetTester tester,
  ) async {
    _useDesktop(tester);
    await _openDay(tester, platform: TargetPlatform.macOS);

    expect(find.byType(PhoneSheet), findsNothing);
    expect(tester.widget(find.byKey(dayDetailPanelKey)), isA<Container>());
    expect(find.byType(DayDetailHeader), findsOneWidget);
    expect(find.byKey(dayDetailBackKey), findsOneWidget);
    expect(find.byType(DayDetailEntriesBar), findsOneWidget);
    expect(tester.getSize(find.byKey(dayDetailPanelKey)).width, 560);
    expect(
      tester.getCenter(find.byKey(dayDetailPanelKey)).dx,
      _desktop.width / 2,
    );
  });
}
