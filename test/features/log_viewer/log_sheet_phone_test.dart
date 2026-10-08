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
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart'
    show composerCloseKey;
import 'package:field_notes/features/day_detail/day_detail.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart';
import 'package:field_notes/features/log_viewer/note_panel_view.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart';
import 'package:field_notes/features/log_viewer/voice_player_view.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../../support/note_editor_driver.dart';
import '../capture/core/capture_test_support.dart'
    show FakeDraftStore, draftIdleDebounceForTest;
import '../day_detail/support/day_detail_harness.dart';

const Size _phone = Size(384, 832);
const Size _desktop = Size(1280, 900);
const double _statusBar = 34;
const double _gestureBar = 24;
const String _date = '2026-07-19';
const String _dayTitle = 'Sunday, July 19';

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
    _entry(id: 'entry-1', hour: 8, textContent: 'Watered the roses.'),
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

Finder _inSheet(Finder finder) =>
    find.descendant(of: find.byType(PhoneSheet), matching: finder);

Finder _inFooter(Finder finder) =>
    find.descendant(of: find.byKey(phoneSheetFooterKey), matching: finder);

Finder _buttonOf(Finder label) =>
    find.ancestor(of: label, matching: find.byType(Container)).first;

Finder _faceOf(Finder action) =>
    find.descendant(of: action, matching: find.byType(Container)).first;

Future<void> _drainToast(WidgetTester tester) async {
  await tester.pump(kToastLifetime);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'a phone log opens as a sheet with back, edit and delete in its footer',
    (WidgetTester tester) async {
      _usePhone(tester);
      await _openLog(tester);

      expect(find.byType(PhoneSheet), findsOneWidget);
      expect(find.byKey(phoneSheetGrabberKey), findsOneWidget);
      expect(
        tester.widget<PhoneSheet>(find.byType(PhoneSheet)).color!.toARGB32(),
        FieldNotesColors.light.composerPaper.toARGB32(),
      );
      expect(find.byKey(logViewerPanelKey), findsOneWidget);
      final Text eyebrow = tester.widget<Text>(_inSheet(find.text(_dayTitle)));
      expect(eyebrow.style!.fontSize, 13);
      expect(eyebrow.maxLines, 1);
      final Text heading = tester.widget<Text>(
        _inSheet(find.text('Morning note')),
      );
      expect(heading.style!.fontSize, 21);
      expect(heading.style!.height, 1.1);
      expect(heading.maxLines, isNull);
      expect(
        _inSheet(
          find.byWidgetPredicate(
            (Widget widget) =>
                widget is NoteBody && widget.text == 'Watered the roses.',
          ),
        ),
        findsOneWidget,
      );
      expect(find.byType(LogActionsPill), findsNothing);

      expect(find.text('Back'), findsOneWidget);
      final Rect back = tester.getRect(_buttonOf(_inFooter(find.text('Back'))));
      final Rect edit = tester.getRect(
        _inFooter(find.byKey(logActionsEditKey)),
      );
      final Rect delete = tester.getRect(
        _inFooter(find.byKey(logActionsDeleteKey)),
      );
      expect(back.height, 48);
      expect(edit.size, const Size(48, 48));
      expect(delete.size, const Size(48, 48));
      expect(back.left, phoneSheetFooterPadding.left);
      expect(edit.left, back.right + phoneSheetActionGap);
      expect(delete.left, edit.right + phoneSheetActionGap);
      expect(delete.right, _phone.width - phoneSheetFooterPadding.right);
      for (final Key key in <Key>[logActionsEditKey, logActionsDeleteKey]) {
        final BoxDecoration face =
            tester.widget<Container>(_faceOf(find.byKey(key))).decoration!
                as BoxDecoration;
        expect(face.color!.toARGB32(), 0xFF2A241D, reason: '$key');
      }

      final Rect footer = tester.getRect(find.byKey(phoneSheetFooterKey));
      for (final Key key in <Key>[logViewerEarlierKey, logViewerLaterKey]) {
        final Finder step = _inSheet(find.byKey(key));
        expect(step, findsOneWidget, reason: '$key');
        final Rect rect = tester.getRect(step);
        expect(rect.height, greaterThanOrEqualTo(44), reason: '$key');
        expect(rect.bottom, lessThanOrEqualTo(footer.top), reason: '$key');
      }
      expect(_inSheet(find.text('1 of 3')), findsOneWidget);
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
    final Finder dock = find.byType(ViewerDock);
    expect(find.descendant(of: dock, matching: find.text('Close')), findsOne);
    expect(find.text('Back'), findsNothing);
    expect(find.byKey(logActionsEditKey), findsNothing);
    expect(
      find.descendant(of: dock, matching: find.byKey(logActionsDeleteKey)),
      findsOneWidget,
    );
    expect(
      tester.getRect(find.byKey(logActionsDeleteKey)).bottom,
      lessThan(_phone.height - _gestureBar),
    );
  });

  testWidgets('Back returns and a scrim tap reports closing everything', (
    WidgetTester tester,
  ) async {
    _usePhone(tester);
    final _Session session = await _openLog(tester);

    await tester.tap(_inFooter(find.text('Back')));
    await tester.pumpAndSettle();

    expect(session.outcomes, <LogViewerOutcome>[LogViewerOutcome.returned]);
    expect(find.byType(PhoneSheet), findsNothing);

    await tester.tap(find.text('open log'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(4, _statusBar + 4));
    await tester.pumpAndSettle();

    expect(session.outcomes, <LogViewerOutcome>[
      LogViewerOutcome.returned,
      LogViewerOutcome.closedAll,
    ]);
    expect(find.byType(PhoneSheet), findsNothing);
  });

  testWidgets('previous and next step through the day', (
    WidgetTester tester,
  ) async {
    _usePhone(tester);
    await _openLog(tester);

    await tester.tap(find.byKey(logViewerLaterKey));
    await tester.pumpAndSettle();

    expect(_inSheet(find.text('Afternoon note')), findsOneWidget);
    expect(_inSheet(find.text('2 of 3')), findsOneWidget);

    await tester.tap(find.byKey(logViewerEarlierKey));
    await tester.pumpAndSettle();

    expect(_inSheet(find.text('Morning note')), findsOneWidget);
  });

  testWidgets('Delete asks first, then deletes the log and leaves', (
    WidgetTester tester,
  ) async {
    _usePhone(tester);
    final _Session session = await _openLog(tester);

    await tester.tap(_inFooter(find.byKey(logActionsDeleteKey)));
    await tester.pumpAndSettle();

    expect(find.text('Delete this entry?'), findsOneWidget);
    expect(session.repository.deletedEntryIds, isEmpty);

    await tester.tap(find.byKey(confirmDialogConfirmKey));
    await tester.pumpAndSettle();

    expect(session.repository.deletedEntryIds, <String>['entry-1']);
    expect(session.outcomes, <LogViewerOutcome>[LogViewerOutcome.deleted]);
    expect(find.byKey(logViewerPanelKey), findsNothing);
    await _drainToast(tester);
  });

  testWidgets('Edit opens the note editor and closing it returns to the log', (
    WidgetTester tester,
  ) async {
    _usePhone(tester);
    final _Session session = await _openLog(tester);

    await tester.tap(_inFooter(find.byKey(logActionsEditKey)));
    await tester.pumpAndSettle();

    expect(find.text('Editing morning note'), findsOneWidget);

    await tester.tap(find.byKey(composerCloseKey));
    await tester.pumpAndSettle();

    expect(find.text('Editing morning note'), findsNothing);
    expect(_inSheet(find.text('Morning note')), findsOneWidget);
    expect(session.outcomes, isEmpty);
  });

  testWidgets('an expanded note sheet stays expanded after an edit is saved', (
    WidgetTester tester,
  ) async {
    _usePhone(tester);
    final NoteEditorDriver driver = NoteEditorDriver(tester);
    final _Session session = await _openLog(tester);
    final double resting = tester.getSize(find.byType(PhoneSheet)).height;

    await tester.tap(find.byKey(phoneSheetGrabberToggleKey));
    await tester.pumpAndSettle();
    expect(tester.widget<PhoneSheet>(find.byType(PhoneSheet)).expanded, isTrue);
    final double expanded = tester.getSize(find.byType(PhoneSheet)).height;
    expect(expanded, greaterThan(resting));

    await tester.tap(_inFooter(find.byKey(logActionsEditKey)));
    await tester.pumpAndSettle();
    await driver.enterText('Watered the roses twice.');
    await tester.pump(draftIdleDebounceForTest);
    await tester.tap(find.text(editNoteSaveLabel));
    await tester.pumpAndSettle();

    expect(session.repository.noteSaves, hasLength(1));
    expect(find.text('Editing morning note'), findsNothing);
    expect(tester.widget<PhoneSheet>(find.byType(PhoneSheet)).expanded, isTrue);
    expect(tester.getSize(find.byType(PhoneSheet)).height, expanded);
    expect(session.outcomes, isEmpty);
    await _drainToast(tester);
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

    expect(find.byType(PhoneSheet), findsOneWidget);
    expect(find.byType(LogViewerPanel), findsOneWidget);
    expect(find.byType(DayDetailPanel), findsNothing);
    expect(_inFooter(find.text('Back')), findsOneWidget);

    await tester.tap(_inFooter(find.text('Back')));
    await tester.pumpAndSettle();

    expect(find.byType(LogViewerPanel), findsNothing);
    expect(find.byType(DayDetailPanel), findsOneWidget);
    expect(_inSheet(find.text('3 logs that day')), findsOneWidget);

    await tester.tap(find.text('8:12 AM · morning · note'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(4, _statusBar + 4));
    await tester.pumpAndSettle();

    expect(find.byType(LogViewerPanel), findsNothing);
    expect(find.byType(DayDetailPanel, skipOffstage: false), findsNothing);
    expect(find.byType(PhoneSheet, skipOffstage: false), findsNothing);
  });

  testWidgets('on macOS a note opens the note panel and its header toolbar', (
    WidgetTester tester,
  ) async {
    _useDesktop(tester);
    await _pump(tester, platform: TargetPlatform.macOS);
    await tester.tap(find.text('open log'));
    await tester.pumpAndSettle();

    expect(find.byType(PhoneSheet), findsNothing);
    expect(find.byKey(composerPanelKey), findsOneWidget);
    expect(find.byType(LogActionsPill), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(LogActionsPill),
        matching: find.byKey(logActionsEditKey),
      ),
      findsOneWidget,
    );
    expect(find.text('Back'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(composerPanelKey)).width,
      notePanelWidthFor(_desktop.width),
    );
  });
}
