import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart'
    show composerCloseKey;
import 'package:field_notes/features/day_detail/day_detail.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/entry_cards/transport/transport_bar.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart';
import 'package:field_notes/features/log_viewer/note_reading_room.dart';
import 'package:field_notes/features/log_viewer/voice_player_view.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../../support/composer_room.dart';
import '../capture/core/capture_test_support.dart' show FakeDraftStore;
import '../day_detail/support/day_detail_harness.dart';

const Size _phone = Size(384, 832);
const Size _desktop = Size(1280, 900);
const double _statusBar = 34;
const double _gestureBar = 24;
const String _date = '2026-07-19';
const String _roses = 'Roses at dawn';

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
  String? title,
  String? textContent,
  String? mediaId,
  int? durationMs,
}) {
  return Entry(
    id: id,
    dayId: 'day-1',
    type: type,
    title: title,
    textContent: textContent,
    mediaId: mediaId,
    durationMs: durationMs,
    createdAt: DateTime(2026, 7, 19, hour, 12).millisecondsSinceEpoch,
    updatedAt: 0,
  );
}

List<Entry> _dayEntries() {
  return <Entry>[
    _entry(
      id: 'entry-1',
      hour: 8,
      title: _roses,
      textContent: 'Watered the roses.',
    ),
    _entry(id: 'entry-2', hour: 14, textContent: 'Tea under the elm.'),
    _entry(
      id: 'entry-3',
      hour: 18,
      type: EntryType.voice,
      mediaId: 'voice-blob',
      durationMs: 65000,
    ),
  ];
}

class _Session {
  _Session(this.repository);

  final FakeJournalRepository repository;
  final List<LogViewerOutcome> outcomes = <LogViewerOutcome>[];
}

class _Opener extends StatelessWidget {
  const _Opener({
    required this.entryId,
    required this.exit,
    required this.onOutcome,
  });

  final String entryId;
  final LogViewerExit exit;
  final ValueChanged<LogViewerOutcome> onOutcome;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () async => onOutcome(
            await showLogViewer(
              context,
              date: _date,
              entryId: entryId,
              exit: exit,
            ),
          ),
          child: const Text('open log'),
        ),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => showDayDetail(context, date: _date),
          child: const Text('open day'),
        ),
      ],
    );
  }
}

Future<_Session> _pump(
  WidgetTester tester, {
  required TargetPlatform platform,
  String entryId = 'entry-1',
  LogViewerExit exit = LogViewerExit.back,
}) async {
  final _Session session = _Session(
    FakeJournalRepository(entries: _dayEntries()),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        journalRepositoryProvider.overrideWithValue(session.repository),
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
        home: Scaffold(
          body: Center(
            child: _Opener(
              entryId: entryId,
              exit: exit,
              onOutcome: session.outcomes.add,
            ),
          ),
        ),
      ),
    ),
  );
  return session;
}

Future<_Session> _openLog(
  WidgetTester tester, {
  String entryId = 'entry-1',
  LogViewerExit exit = LogViewerExit.back,
}) async {
  final _Session session = await _pump(
    tester,
    platform: TargetPlatform.android,
    entryId: entryId,
    exit: exit,
  );
  await tester.tap(find.text('open log'));
  await tester.pumpAndSettle();
  return session;
}

Finder _inRoom(Finder finder) =>
    find.descendant(of: find.byType(NoteReadingRoom), matching: finder);

Finder _noteBody(String text) => find.byWidgetPredicate(
  (Widget widget) => widget is NoteBody && widget.text == text,
);

Future<void> _drainToast(WidgetTester tester) async {
  await tester.pump(kToastLifetime);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a phone note opens full window with Back, Edit and More in its top bar',
    (WidgetTester tester) async {
      _usePhone(tester);
      await _openLog(tester);

      expect(find.byType(PhoneSheet), findsNothing);
      expect(find.byKey(logViewerPanelKey), findsOneWidget);
      expect(tester.getSize(find.byKey(composerPanelKey)), _phone);
      expect(_inRoom(find.text(_roses)), findsOneWidget);
      expect(_inRoom(find.text('Sun')), findsOneWidget);
      expect(_inRoom(find.text('Jul 19 · 8:12 AM')), findsOneWidget);
      expect(_inRoom(_noteBody('Watered the roses.')), findsOneWidget);
      expect(find.byType(LogActionsPill), findsNothing);
      expect(find.byKey(logActionsDeleteKey), findsNothing);
      expect(
        tester.widget<Pressable>(find.byKey(logViewerBackKey)).label,
        'Back',
      );

      final Rect back = tester.getRect(find.byKey(logViewerBackKey));
      final Rect edit = tester.getRect(find.byKey(logActionsEditKey));
      final Rect more = tester.getRect(find.byKey(logActionsMoreKey));
      for (final Rect control in <Rect>[back, edit, more]) {
        expect(control.width, greaterThanOrEqualTo(48));
        expect(control.height, greaterThanOrEqualTo(48));
        expect(control.top, greaterThanOrEqualTo(_statusBar));
        expect(control.center.dy, closeTo(back.center.dy, 1));
      }
      expect(back.right, lessThan(_phone.width / 2));
      expect(edit.left, greaterThan(_phone.width / 2));
      expect(more.left, greaterThanOrEqualTo(edit.right));

      for (final Key key in <Key>[logViewerEarlierKey, logViewerLaterKey]) {
        final Finder step = _inRoom(find.byKey(key));
        expect(step, findsOneWidget, reason: '$key');
        final Rect rect = tester.getRect(step);
        expect(rect.height, greaterThanOrEqualTo(44), reason: '$key');
        expect(
          rect.bottom,
          lessThanOrEqualTo(_phone.height - _gestureBar),
          reason: '$key',
        );
      }
      expect(_inRoom(find.text('1 of 3')), findsOneWidget);
    },
  );

  testWidgets('a voice log opens the voice player with Close and no Edit', (
    WidgetTester tester,
  ) async {
    _usePhone(tester);
    await _openLog(tester, entryId: 'entry-3', exit: LogViewerExit.close);

    expect(find.byType(PhoneSheet), findsNothing);
    expect(
      find.descendant(
        of: find.byType(LogViewerPanel),
        matching: find.byType(VoicePlayerView),
      ),
      findsOneWidget,
    );
    final SemanticsHandle semantics = tester.ensureSemantics();
    final Finder dock = find.byType(TransportDock);
    expect(
      find.descendant(of: dock, matching: find.byKey(transportDockBackKey)),
      findsOneWidget,
    );
    expect(find.bySemanticsLabel('Close'), findsOneWidget);
    expect(find.bySemanticsLabel('Back'), findsNothing);
    expect(find.byKey(logActionsEditKey), findsNothing);
    expect(find.byKey(logActionsDeleteKey), findsNothing);

    await tester.tap(find.byKey(transportDockMoreKey));
    await tester.pumpAndSettle();
    expect(find.byKey(logActionsDeleteKey), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('Back and the system back gesture both return', (
    WidgetTester tester,
  ) async {
    _usePhone(tester);
    final _Session session = await _openLog(tester);

    await tester.tap(find.byKey(logViewerBackKey));
    await tester.pumpAndSettle();

    expect(session.outcomes, <LogViewerOutcome>[LogViewerOutcome.returned]);
    expect(find.byType(LogViewerPanel), findsNothing);

    await tester.tap(find.text('open log'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(session.outcomes, <LogViewerOutcome>[
      LogViewerOutcome.returned,
      LogViewerOutcome.returned,
    ]);
    expect(find.byType(LogViewerPanel), findsNothing);
  });

  testWidgets('previous and next step through the day', (
    WidgetTester tester,
  ) async {
    _usePhone(tester);
    await _openLog(tester);

    await tester.tap(find.byKey(logViewerLaterKey));
    await tester.pumpAndSettle();

    expect(_inRoom(_noteBody('Tea under the elm.')), findsOneWidget);
    expect(_inRoom(find.text('2 of 3')), findsOneWidget);

    await tester.tap(find.byKey(logViewerEarlierKey));
    await tester.pumpAndSettle();

    expect(_inRoom(find.text(_roses)), findsOneWidget);
  });

  testWidgets('Delete waits in More, asks first, then deletes and leaves', (
    WidgetTester tester,
  ) async {
    _usePhone(tester);
    final _Session session = await _openLog(tester);

    await tester.tap(find.byKey(logActionsMoreKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(logActionsDeleteKey));
    await tester.pumpAndSettle();

    expect(find.text('Delete this log?'), findsOneWidget);
    expect(session.repository.deletedEntryIds, isEmpty);

    await tester.tap(find.byKey(confirmDialogConfirmKey));
    await tester.pumpAndSettle();

    expect(session.repository.deletedEntryIds, <String>['entry-1']);
    expect(session.outcomes, <LogViewerOutcome>[LogViewerOutcome.deleted]);
    expect(find.byKey(logViewerPanelKey), findsNothing);
    await _drainToast(tester);
  });

  testWidgets('Edit turns the note into the editor and leaving returns to it', (
    WidgetTester tester,
  ) async {
    _usePhone(tester);
    final _Session session = await _openLog(tester);

    await tester.tap(find.byKey(logActionsEditKey));
    await tester.pumpAndSettle();

    expect(composerTitled('Editing morning note'), findsOneWidget);
    expect(find.byType(NoteReadingRoom), findsNothing);
    expect(tester.getSize(find.byKey(composerPanelKey)), _phone);

    await tester.tap(find.byKey(composerCloseKey));
    await tester.pumpAndSettle();

    expect(composerTitled('Editing morning note'), findsNothing);
    expect(_inRoom(find.text(_roses)), findsOneWidget);
    expect(session.outcomes, isEmpty);
  });

  testWidgets('a log opened from the day sheet hands back to the day', (
    WidgetTester tester,
  ) async {
    _usePhone(tester);
    await _pump(tester, platform: TargetPlatform.android);
    await tester.tap(find.text('open day'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('8:12 AM · morning · note'));
    await tester.pumpAndSettle();

    expect(find.byType(NoteReadingRoom), findsOneWidget);
    expect(find.byType(DayDetailPanel), findsNothing);
    expect(
      tester.widget<Pressable>(find.byKey(logViewerBackKey)).label,
      'Back',
    );

    await tester.tap(find.byKey(logViewerBackKey));
    await tester.pumpAndSettle();

    expect(find.byType(LogViewerPanel), findsNothing);
    expect(find.byType(DayDetailPanel), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PhoneSheet),
        matching: find.text('3 logs that day'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('on macOS a note opens full window with Edit and More', (
    WidgetTester tester,
  ) async {
    _useDesktop(tester);
    await _pump(tester, platform: TargetPlatform.macOS);
    await tester.tap(find.text('open log'));
    await tester.pumpAndSettle();

    expect(find.byType(PhoneSheet), findsNothing);
    expect(find.byType(LogActionsPill), findsNothing);
    expect(tester.getSize(find.byKey(composerPanelKey)), _desktop);
    expect(_inRoom(find.text('Back')), findsOneWidget);
    expect(_inRoom(find.text(noteReadingEditLabel)), findsOneWidget);
    expect(_inRoom(find.byKey(logActionsMoreKey)), findsOneWidget);
  });
}
