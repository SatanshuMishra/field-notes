import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/day_detail_edit_note.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../capture/core/capture_test_support.dart'
    show FakeDraftStore, draftIdleDebounceForTest;
import '../../support/note_editor_driver.dart';
import '../day_detail/support/day_detail_harness.dart';

const String _date = '2026-07-19';
const String _lastWord = 'finale';

String _longNote() {
  final StringBuffer buffer = StringBuffer('An afternoon by the pond');
  int word = 0;
  while (buffer.length < 390) {
    buffer.write(' ripple${word++}');
  }
  buffer.write(' $_lastWord');
  return buffer.toString();
}

Entry _entry({
  required String id,
  required EntryType type,
  required int hour,
  required int minute,
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
    createdAt: DateTime(2026, 7, 19, hour, minute).millisecondsSinceEpoch,
    updatedAt: 0,
  );
}

List<Entry> _dayEntries() {
  return <Entry>[
    _entry(
      id: 'entry-1',
      type: EntryType.text,
      hour: 8,
      minute: 12,
      textContent: 'Watered the roses.',
    ),
    _entry(
      id: 'entry-2',
      type: EntryType.text,
      hour: 14,
      minute: 30,
      textContent: _longNote(),
    ),
    _entry(
      id: 'entry-3',
      type: EntryType.voice,
      hour: 18,
      minute: 5,
      mediaId: 'blob-voice',
      durationMs: 65000,
    ),
  ];
}

class _DayRepository extends FakeJournalRepository {
  _DayRepository(List<Entry> entries)
      : _current = List<Entry>.unmodifiable(entries),
        super(entries: entries);

  List<Entry> _current;
  final StreamController<List<Entry>> _changes =
      StreamController<List<Entry>>.broadcast();

  void _publish(List<Entry> next) {
    _current = List<Entry>.unmodifiable(next);
    _changes.add(_current);
  }

  @override
  Stream<List<Entry>> watchEntriesForDate(String date) async* {
    yield _current;
    yield* _changes.stream;
  }

  @override
  Future<void> softDeleteEntry(String id) async {
    await super.softDeleteEntry(id);
    _publish(<Entry>[
      for (final Entry entry in _current)
        if (entry.id != id) entry,
    ]);
  }

  @override
  Future<Entry> saveNote({
    String? entryId,
    required String date,
    required String source,
    required List<String> photoMediaIds,
  }) async {
    final Entry saved = await super.saveNote(
      entryId: entryId,
      date: date,
      source: source,
      photoMediaIds: photoMediaIds,
    );
    _publish(<Entry>[
      for (final Entry entry in _current)
        if (entry.id == entryId)
          Entry(
            id: entry.id,
            dayId: entry.dayId,
            type: entry.type,
            textContent: source,
            createdAt: entry.createdAt,
            updatedAt: 1,
          )
        else
          entry,
    ]);
    return saved;
  }
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
    return Center(
      child: GestureDetector(
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
    );
  }
}

class _Session {
  _Session(this.repository);

  final _DayRepository repository;
  final List<LogViewerOutcome> outcomes = <LogViewerOutcome>[];
}

Future<_Session> _open(
  WidgetTester tester, {
  String entryId = 'entry-1',
  LogViewerExit exit = LogViewerExit.back,
  List<Override> overrides = const <Override>[],
}) async {
  final _Session session = _Session(_DayRepository(_dayEntries()));
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        journalRepositoryProvider.overrideWithValue(session.repository),
        draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
        mediaStoreProvider.overrideWith(
          (Ref ref) async => FakeMediaStore(Directory.systemTemp),
        ),
        todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 23, 9)),
        ...overrides,
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _Opener(
          entryId: entryId,
          exit: exit,
          onOutcome: session.outcomes.add,
        ),
      ),
    ),
  );
  await tester.tap(find.text('open log'));
  await tester.pumpAndSettle();
  return session;
}

Future<void> _drainToast(WidgetTester tester) async {
  await tester.pump(kToastLifetime);
  await tester.pumpAndSettle();
}

Finder _noteText(String text) => find.byWidgetPredicate(
      (Widget w) => w is NoteBody && w.text.contains(text),
    );

void main() {
  testWidgets('view mode text carries no fallback underline',
      (WidgetTester tester) async {
    await _open(tester, entryId: 'entry-2');

    final Finder title = find.text('Afternoon note');
    expect(title, findsOneWidget);
    final TextStyle style = DefaultTextStyle.of(tester.element(title)).style;
    expect(style.decoration ?? TextDecoration.none, TextDecoration.none);
  });

  testWidgets('view mode shows the heading, the meta and the whole note',
      (WidgetTester tester) async {
    await _open(tester, entryId: 'entry-2');

    expect(find.text('Afternoon note'), findsOneWidget);
    expect(find.text('Sunday, July 19'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Text && (widget.data ?? '').startsWith('14:30'),
      ),
      findsOneWidget,
    );
    expect(_noteText(_lastWord), findsOneWidget);
  });

  testWidgets("Earlier and Later step through the day's logs",
      (WidgetTester tester) async {
    await _open(tester);

    expect(find.text('Morning note'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget);

    await tester.tap(find.byKey(logViewerLaterKey));
    await tester.pumpAndSettle();

    expect(find.text('Afternoon note'), findsOneWidget);
    expect(find.text('2 of 3'), findsOneWidget);

    await tester.tap(find.byKey(logViewerEarlierKey));
    await tester.pumpAndSettle();

    expect(find.text('Morning note'), findsOneWidget);
  });

  testWidgets('Edit switches to edit mode without moving the panel',
      (WidgetTester tester) async {
    final NoteEditorDriver driver = NoteEditorDriver(tester);
    await _open(tester, entryId: 'entry-2');
    final Rect before = tester.getRect(find.byKey(logViewerPanelKey));

    await tester.tap(find.byKey(logActionsEditKey));
    await tester.pumpAndSettle();

    final Rect after = tester.getRect(find.byKey(logViewerPanelKey));
    expect(driver.find, findsOneWidget);
    expect(find.text('Editing afternoon note'), findsOneWidget);
    expect(after.left, before.left);
    expect(after.right, before.right);
    expect(after.center.dx, before.center.dx);
  });

  testWidgets(
      'Back from edit mode returns to view mode showing the saved text',
      (WidgetTester tester) async {
    final NoteEditorDriver driver = NoteEditorDriver(tester);
    final _Session session = await _open(tester, entryId: 'entry-2');

    await tester.tap(find.byKey(logActionsEditKey));
    await tester.pumpAndSettle();
    await driver.enterText('a better day');
    await tester.pump(draftIdleDebounceForTest);
    await tester.tap(find.text(editNoteSaveLabel));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(confirmDialogConfirmKey));
    await tester.pumpAndSettle();

    expect(session.repository.noteSaves, hasLength(1));
    expect(driver.find, findsNothing);
    expect(find.text('Afternoon note'), findsOneWidget);
    expect(_noteText('a better day'), findsOneWidget);
    expect(find.byKey(logViewerPanelKey), findsOneWidget);
    expect(session.outcomes, isEmpty);
    await _drainToast(tester);
  });

  testWidgets('Delete asks first, then deletes the log and leaves',
      (WidgetTester tester) async {
    final _Session session = await _open(tester, entryId: 'entry-2');

    await tester.tap(find.byKey(logActionsDeleteKey));
    await tester.pumpAndSettle();

    expect(find.text('Delete this entry?'), findsOneWidget);
    expect(
      find.text(
        'This log will be removed from July 19. This can’t be undone.',
      ),
      findsOneWidget,
    );
    expect(session.repository.deletedEntryIds, isEmpty);

    await tester.tap(find.byKey(confirmDialogConfirmKey));
    await tester.pumpAndSettle();

    expect(session.repository.deletedEntryIds, <String>['entry-2']);
    expect(find.text('Entry deleted'), findsOneWidget);
    expect(session.outcomes, <LogViewerOutcome>[LogViewerOutcome.deleted]);
    expect(find.byKey(logViewerPanelKey), findsNothing);
    await _drainToast(tester);
  });

  testWidgets('Escape leaves and the arrow keys step',
      (WidgetTester tester) async {
    final _Session session = await _open(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(find.text('Afternoon note'), findsOneWidget);
    expect(session.outcomes, isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();

    expect(find.text('Morning note'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(session.outcomes, <LogViewerOutcome>[LogViewerOutcome.returned]);
    expect(find.byKey(logViewerPanelKey), findsNothing);
  });

  testWidgets('a scrim tap closes view mode and reports closing everything',
      (WidgetTester tester) async {
    final _Session session = await _open(tester);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(session.outcomes, <LogViewerOutcome>[LogViewerOutcome.closedAll]);
    expect(find.byKey(logViewerPanelKey), findsNothing);
  });

  testWidgets('a voice log shows the voice player and no Edit',
      (WidgetTester tester) async {
    await _open(tester, entryId: 'entry-3', exit: LogViewerExit.close);

    expect(find.text('Evening voice log'), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.byType(VoiceBody), findsOneWidget);
    expect(find.byKey(logActionsDeleteKey), findsOneWidget);
    expect(find.byKey(logActionsEditKey), findsNothing);
  });

  testWidgets('view mode plays voice and video through the injected players',
      (WidgetTester tester) async {
    EntryAudioPlayer audio() => throw UnimplementedError();
    EntryVideoPlayer video() => throw UnimplementedError();
    await _open(
      tester,
      entryId: 'entry-3',
      exit: LogViewerExit.close,
      overrides: <Override>[
        todayAudioPlayerFactoryProvider.overrideWithValue(audio),
        todayVideoPlayerFactoryProvider.overrideWithValue(video),
      ],
    );

    expect(
      tester.widget<VoiceBody>(find.byType(VoiceBody)).playerFactory,
      same(audio),
    );
  });
}
