import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/focus/focus_ring.dart' show focusRingKey;
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart'
    show composerPanelKey;
import 'package:field_notes/features/capture/text/editor/format_bar.dart'
    show FormatBar;
import 'package:field_notes/features/capture/text/text_composer_sheet.dart'
    show ComposerDayLine, composerKeepNewLabel, composerTitleFieldKey;
import 'package:field_notes/features/day_detail/day_detail_edit_note.dart'
    show editNoteSaveLabel;
import 'package:field_notes/features/entry_cards/entry_cards.dart'
    show
        NoteBody,
        logActionsDeleteKey,
        logActionsEditKey,
        logActionsMoreKey,
        logActionsRenameKey;
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart'
    show LogViewerPanel, logViewerBackKey;
import 'package:field_notes/features/log_viewer/note_reading_room.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart'
    show viewerTitleFieldKey;
import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteEditorView, NoteReaderView;
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../../support/note_editor_driver.dart';
import '../capture/core/capture_test_support.dart' show FakeDraftStore;
import '../day_detail/support/day_detail_harness.dart'
    show FakeJournalRepository, FakeMediaStore;

const String _date = '2026-11-10';
const String _title = 'Night Cap';
const String _body = 'This is an example note.';
const Size _window = Size(1280, 800);

final TargetPlatformVariant _bothLayouts = TargetPlatformVariant(
  <TargetPlatform>{TargetPlatform.android, TargetPlatform.macOS},
);

bool get _phone => defaultTargetPlatform == TargetPlatform.android;

Entry _note({required String id, required int hour, String? title}) {
  return Entry(
    id: id,
    dayId: 'day-1',
    type: EntryType.text,
    title: title,
    textContent: id == 'night-cap' ? _body : 'An earlier note.',
    createdAt: DateTime(2026, 11, 10, hour, 4).millisecondsSinceEpoch,
    updatedAt: 0,
  );
}

class _Room {
  _Room(this.repository);

  final FakeJournalRepository repository;
  final List<LogViewerOutcome> outcomes = <LogViewerOutcome>[];
}

Future<_Room> _open(WidgetTester tester) async {
  tester.view.physicalSize = _window;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
  addTearDown(tester.view.reset);
  final _Room room = _Room(
    FakeJournalRepository(
      entries: <Entry>[
        _note(id: 'earlier', hour: 9),
        _note(id: 'night-cap', hour: 12, title: _title),
      ],
    ),
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        journalRepositoryProvider.overrideWithValue(room.repository),
        draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
        mediaStoreProvider.overrideWith(
          (Ref ref) async => FakeMediaStore(Directory.systemTemp),
        ),
        todayClockProvider.overrideWithValue(() => DateTime(2026, 11, 10, 15)),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => unawaited(
              showLogViewer(
                context,
                date: _date,
                entryId: 'night-cap',
                exit: LogViewerExit.close,
              ).then(room.outcomes.add),
            ),
            child: const Text('open log'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open log'));
  await tester.pumpAndSettle();
  return room;
}

Future<void> _edit(WidgetTester tester) async {
  await tester.tap(find.byKey(logActionsEditKey));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a note opens full window to read, with its title, day and '
      'time, Edit and no toolbar', (WidgetTester tester) async {
    final _Room room = await _open(tester);

    expect(find.byType(NoteReadingRoom), findsOneWidget);
    expect(tester.getSize(find.byKey(composerPanelKey)), _window);
    expect(find.text(_title), findsOneWidget);
    expect(find.text(_phone ? 'Tue' : 'Tuesday'), findsOneWidget);
    expect(
      find.text(_phone ? 'Nov 10 · 12:04 PM' : 'November 10 · 12:04 PM'),
      findsOneWidget,
    );
    expect(
      tester.widget<Pressable>(find.byKey(logViewerBackKey)).label,
      'Close',
    );
    expect(find.byKey(logActionsEditKey), findsOneWidget);
    expect(find.byKey(logActionsMoreKey), findsOneWidget);
    expect(find.byKey(noteReadingRuleKey), findsOneWidget);
    expect(find.byType(FormatBar), findsNothing);
    expect(find.byType(NoteEditorView), findsNothing);
    expect(find.text(composerKeepNewLabel), findsNothing);
    expect(find.text(editNoteSaveLabel), findsNothing);
    expect(
      find.byWidgetPredicate((Widget w) => w is NoteBody && w.text == _body),
      findsOneWidget,
    );
    expect(find.text('2 of 2'), findsOneWidget);
    expect(room.outcomes, isEmpty);
    final Rect day = tester.getRect(find.byType(ComposerDayLine));
    for (final Key key in <Key>[
      logViewerBackKey,
      logActionsEditKey,
      logActionsMoreKey,
    ]) {
      expect(day.overlaps(tester.getRect(find.byKey(key))), isFalse);
    }
  }, variant: _bothLayouts);

  testWidgets('Edit turns the same page into the editor without leaving', (
    WidgetTester tester,
  ) async {
    final NoteEditorDriver driver = NoteEditorDriver(tester);
    final _Room room = await _open(tester);

    await _edit(tester);

    expect(find.byType(LogViewerPanel), findsOneWidget);
    expect(find.byType(NoteReadingRoom), findsNothing);
    expect(find.byType(FormatBar), findsOneWidget);
    expect(find.text(editNoteSaveLabel), findsOneWidget);
    expect(tester.getSize(find.byKey(composerPanelKey)), _window);
    expect(driver.title, _title);
    expect(driver.pageFocused, isTrue);
    expect(driver.selection, const TextSelection.collapsed(offset: 24));
    expect(room.outcomes, isEmpty);
  }, variant: _bothLayouts);

  testWidgets('the E key edits the note, but not with Command held', (
    WidgetTester tester,
  ) async {
    await _open(tester);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pumpAndSettle();

    expect(find.byType(NoteReadingRoom), findsOneWidget);
    expect(find.byType(FormatBar), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.pumpAndSettle();

    expect(find.byType(FormatBar), findsOneWidget);
    expect(find.text(editNoteSaveLabel), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a click in the note draws no ring and Tab back to it does', (
    WidgetTester tester,
  ) async {
    await _open(tester);
    final Finder note = find.byKey(
      const ValueKey<String>('log-viewer-content-night-cap'),
    );
    final Finder ring = find.descendant(
      of: note,
      matching: find.byKey(focusRingKey),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
    expect(FocusManager.instance.highlightMode, FocusHighlightMode.traditional);
    await tester.tap(note, kind: PointerDeviceKind.mouse);
    await tester.pump();

    expect(ring, findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();

    expect(ring, findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('the title and the page stay put when editing starts', (
    WidgetTester tester,
  ) async {
    await _open(tester);
    final Offset title = tester.getCenter(find.text(_title));
    final Offset page = tester.getTopLeft(find.byType(NoteReaderView));

    await _edit(tester);

    expect(
      tester.getCenter(find.byKey(composerTitleFieldKey)).dy,
      closeTo(title.dy, 1),
    );
    expect(
      tester.getCenter(find.byKey(composerTitleFieldKey)).dx,
      closeTo(title.dx, 1),
    );
    final Offset editor = tester.getTopLeft(find.byType(NoteEditorView));
    expect(editor.dx, closeTo(page.dx, 1));
    expect(editor.dy, closeTo(page.dy, 1));
  }, variant: _bothLayouts);

  testWidgets('More renames the note in place and offers delete', (
    WidgetTester tester,
  ) async {
    final _Room room = await _open(tester);

    await tester.tap(find.byKey(logActionsMoreKey));
    await tester.pumpAndSettle();

    expect(find.byKey(logActionsRenameKey), findsOneWidget);
    expect(find.byKey(logActionsDeleteKey), findsOneWidget);

    await tester.tap(find.byKey(logActionsRenameKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(viewerTitleFieldKey), 'Night Owl');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(room.repository.titleUpdates, <({String id, String? title})>[
      (id: 'night-cap', title: 'Night Owl'),
    ]);
    expect(find.byKey(viewerTitleFieldKey), findsNothing);
    expect(find.text('Night Owl'), findsOneWidget);
    expect(find.byType(NoteReadingRoom), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('Close leaves the room', (WidgetTester tester) async {
    final _Room room = await _open(tester);

    await tester.tap(find.byKey(logViewerBackKey));
    await tester.pumpAndSettle();

    expect(find.byType(LogViewerPanel), findsNothing);
    expect(room.outcomes, <LogViewerOutcome>[LogViewerOutcome.returned]);
  }, variant: _bothLayouts);
}
