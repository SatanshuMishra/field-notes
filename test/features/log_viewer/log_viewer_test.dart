import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/composer_guard.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart'
    show composerCloseKey;
import 'package:field_notes/features/day_detail/day_detail_edit_note.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart';
import 'package:field_notes/features/log_viewer/note_panel_view.dart';
import 'package:field_notes/features/log_viewer/note_sheet_view.dart';
import 'package:field_notes/features/log_viewer/video_viewer_view.dart';
import 'package:field_notes/features/log_viewer/viewer_waveform.dart';
import 'package:field_notes/features/log_viewer/voice_player_view.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteEditorView;
import 'package:field_notes/features/notes/notes.dart'
    show notesMediaResolverProvider;
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../capture/core/capture_test_support.dart'
    show FakeDraftStore, draftIdleDebounceForTest;
import '../../support/note_editor_driver.dart';
import '../day_detail/support/day_detail_harness.dart';
import '../entry_cards/support/fake_audio_player.dart';
import '../entry_cards/support/fake_video_player.dart';

const String _date = '2026-07-19';
const String _lastWord = 'finale';
const String _voiceMedia = 'blob-voice';
const String _videoMedia = 'blob-video';

final TargetPlatformVariant _bothLayouts = TargetPlatformVariant(
  <TargetPlatform>{TargetPlatform.android, TargetPlatform.macOS},
);

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

void _useClockFormat(WidgetTester tester, {required bool twentyFourHour}) {
  tester.platformDispatcher.alwaysUse24HourFormatTestValue = twentyFourHour;
  tester.binding.handleMetricsChanged();
  addTearDown(() {
    tester.platformDispatcher.clearAlwaysUse24HourTestValue();
    tester.binding.handleMetricsChanged();
  });
}

Future<void> _drainToast(WidgetTester tester) async {
  await tester.pump(kToastLifetime);
  await tester.pumpAndSettle();
}

Finder _noteText(String text) => find.byWidgetPredicate(
  (Widget w) => w is NoteBody && w.text.contains(text),
);

Finder _inPanel(Finder matching) =>
    find.descendant(of: find.byType(LogViewerPanel), matching: matching);

bool get _sidebar => defaultTargetPlatform == TargetPlatform.macOS;

List<Entry> _mixedEntries() {
  return <Entry>[
    _entry(
      id: 'voice-log',
      type: EntryType.voice,
      hour: 7,
      minute: 40,
      mediaId: _voiceMedia,
      durationMs: 65000,
    ),
    _entry(
      id: 'note-log',
      type: EntryType.text,
      hour: 9,
      minute: 15,
      textContent: 'Fed the robins.',
    ),
    _entry(
      id: 'video-log',
      type: EntryType.video,
      hour: 11,
      minute: 30,
      mediaId: _videoMedia,
      durationMs: 4000,
    ),
  ];
}

FakeMediaResolver _mediaResolver() {
  final Directory folder = Directory.systemTemp.createTempSync(
    'log-viewer-media',
  );
  addTearDown(() => folder.deleteSync(recursive: true));
  final File voice = File('${folder.path}/voice.m4a')
    ..writeAsBytesSync(const <int>[0, 1, 2, 3]);
  final File video = File('${folder.path}/video.mp4')
    ..writeAsBytesSync(const <int>[0, 1, 2, 3]);
  return FakeMediaResolver(<String, ResolvedMedia>{
    _voiceMedia: ResolvedMedia.available(
      blob: blobOf(
        id: _voiceMedia,
        relPath: 'voice.m4a',
        kind: MediaKind.audio,
      ),
      file: voice,
    ),
    _videoMedia: ResolvedMedia.available(
      blob: blobOf(
        id: _videoMedia,
        relPath: 'video.mp4',
        kind: MediaKind.video,
      ),
      file: video,
    ),
  });
}

class _Mixed {
  _Mixed(this.repository);

  final _DayRepository repository;
  final List<LogViewerOutcome> outcomes = <LogViewerOutcome>[];
  final List<String> readNotes = <String>[];
  final List<FakeEntryAudioPlayer> voicePlayers = <FakeEntryAudioPlayer>[];
  final List<FakeEntryVideoPlayer> videoPlayers = <FakeEntryVideoPlayer>[];

  FakeEntryAudioPlayer buildVoice() {
    final FakeEntryAudioPlayer player = FakeEntryAudioPlayer();
    voicePlayers.add(player);
    return player;
  }

  FakeEntryVideoPlayer buildVideo() {
    final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
    videoPlayers.add(player);
    return player;
  }
}

class _MixedOpener extends StatelessWidget {
  const _MixedOpener({
    required this.session,
    required this.entryId,
    required this.exit,
    required this.readNotes,
    this.inline,
  });

  final _Mixed session;
  final String entryId;
  final LogViewerExit exit;
  final bool readNotes;
  final Widget? inline;

  Future<void> _open(BuildContext context) async {
    session.outcomes.add(
      await showLogViewer(
        context,
        date: _date,
        entryId: entryId,
        exit: exit,
        onReadNote: readNotes ? session.readNotes.add : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget? inline = this.inline;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ?inline,
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _open(context),
            child: const Text('open log'),
          ),
        ],
      ),
    );
  }
}

Future<_Mixed> _openMixed(
  WidgetTester tester, {
  required String entryId,
  LogViewerExit exit = LogViewerExit.back,
  bool readNotes = false,
  Widget Function(MediaResolver resolver)? inline,
  bool open = true,
}) async {
  final _Mixed session = _Mixed(_DayRepository(_mixedEntries()));
  final MediaResolver resolver = _mediaResolver();
  final LruVideoSlots slots = LruVideoSlots(cap: 2);
  addTearDown(slots.dispose);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        journalRepositoryProvider.overrideWithValue(session.repository),
        draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
        mediaStoreProvider.overrideWith(
          (Ref ref) async => FakeMediaStore(Directory.systemTemp),
        ),
        notesMediaResolverProvider.overrideWith((Ref ref) async => resolver),
        todayAudioPlayerFactoryProvider.overrideWithValue(session.buildVoice),
        todayVideoPlayerFactoryProvider.overrideWithValue(session.buildVideo),
        videoSlotsProvider.overrideWithValue(slots),
        videoAspectProvider.overrideWith((Ref ref, String mediaId) => 16 / 9),
        todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 23, 9)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _MixedOpener(
          session: session,
          entryId: entryId,
          exit: exit,
          readNotes: readNotes,
          inline: inline?.call(resolver),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  if (open) {
    await tester.tap(find.text('open log'));
    await tester.pumpAndSettle();
  }
  return session;
}

Finder _noteView() => find.byType(_sidebar ? NotePanelView : NoteSheetView);

void _expectUnboxed(WidgetTester tester, Finder media) {
  expect(media, findsOneWidget);
  final Iterable<DecoratedBox> boxes = tester.widgetList<DecoratedBox>(
    find.ancestor(of: media, matching: find.byType(DecoratedBox)),
  );
  expect(
    boxes.where((DecoratedBox box) {
      final Decoration decoration = box.decoration;
      return decoration is BoxDecoration && decoration.border != null;
    }),
    isEmpty,
  );
}

void main() {
  testWidgets('view mode text carries no fallback underline', (
    WidgetTester tester,
  ) async {
    await _open(tester, entryId: 'entry-2');

    final Finder title = find.text('Afternoon note');
    expect(title, findsOneWidget);
    final TextStyle style = DefaultTextStyle.of(tester.element(title)).style;
    expect(style.decoration ?? TextDecoration.none, TextDecoration.none);
  }, variant: _bothLayouts);

  testWidgets('view mode shows the heading, the meta and the whole note', (
    WidgetTester tester,
  ) async {
    await _open(tester, entryId: 'entry-2');

    expect(find.text('Afternoon note'), findsOneWidget);
    expect(find.text('Sunday, July 19'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Text && (widget.data ?? '').startsWith('2:30 PM'),
      ),
      findsOneWidget,
    );
    expect(_noteText(_lastWord), findsOneWidget);
  }, variant: _bothLayouts);

  testWidgets("Earlier and Later step through the day's logs", (
    WidgetTester tester,
  ) async {
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
  }, variant: _bothLayouts);

  testWidgets('Edit switches to edit mode without moving the panel', (
    WidgetTester tester,
  ) async {
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
  }, variant: _bothLayouts);

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

      expect(session.repository.noteSaves, hasLength(1));
      expect(driver.find, findsNothing);
      expect(find.text('Afternoon note'), findsOneWidget);
      expect(_noteText('a better day'), findsOneWidget);
      expect(find.byKey(logViewerPanelKey), findsOneWidget);
      expect(session.outcomes, isEmpty);
      await _drainToast(tester);
    },
    variant: _bothLayouts,
  );

  testWidgets(
    'on macOS Keep editing after Back in an inline edit returns focus to the editor',
    (WidgetTester tester) async {
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _open(tester, entryId: 'entry-2');
      await tester.tap(find.byKey(logActionsEditKey));
      await tester.pumpAndSettle();
      await driver.typeText(' never mind');
      final TextSelection before = driver.selection;

      await driver.press(
        find.byKey(composerCloseKey),
        const Duration(milliseconds: 110),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      expect(find.text(composerDiscardTitle), findsOneWidget);

      await driver.press(
        find.byKey(composerKeepEditingKey),
        const Duration(milliseconds: 110),
        kind: PointerDeviceKind.mouse,
      );
      await tester.pumpAndSettle();

      expect(find.text(composerDiscardTitle), findsNothing);
      expect(driver.find, findsOneWidget);
      expect(
        tester
            .widget<NoteEditorView>(find.byType(NoteEditorView))
            .focusNode
            .hasPrimaryFocus,
        isTrue,
      );
      expect(driver.selection, before);

      await driver.typeText('!');

      expect(driver.source, '${_longNote()} never mind!');
      await tester.pump(draftIdleDebounceForTest);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets('Delete asks first, then deletes the log and leaves', (
    WidgetTester tester,
  ) async {
    final _Session session = await _open(tester, entryId: 'entry-2');

    await tester.tap(find.byKey(logActionsDeleteKey));
    await tester.pumpAndSettle();

    expect(find.text('Delete this entry?'), findsOneWidget);
    expect(
      find.text('This log will be removed from July 19. This can’t be undone.'),
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
  }, variant: _bothLayouts);

  testWidgets('Escape leaves and the arrow keys step', (
    WidgetTester tester,
  ) async {
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
  }, variant: _bothLayouts);

  testWidgets('a scrim tap closes view mode and reports closing everything', (
    WidgetTester tester,
  ) async {
    final _Session session = await _open(tester);

    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    expect(session.outcomes, <LogViewerOutcome>[LogViewerOutcome.closedAll]);
    expect(find.byKey(logViewerPanelKey), findsNothing);
  }, variant: _bothLayouts);

  testWidgets('a voice log shows the voice player and no Edit', (
    WidgetTester tester,
  ) async {
    await _open(tester, entryId: 'entry-3', exit: LogViewerExit.close);

    expect(_inPanel(find.byType(VoicePlayerView)), findsOneWidget);
    expect(find.text('Close'), findsOneWidget);
    expect(find.byKey(logActionsDeleteKey), findsOneWidget);
    expect(find.byKey(logActionsEditKey), findsNothing);
  }, variant: _bothLayouts);

  testWidgets('view mode plays voice and video through the injected players', (
    WidgetTester tester,
  ) async {
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
      tester
          .widget<VoicePlayerView>(find.byType(VoicePlayerView))
          .playerFactory,
      same(audio),
    );
  }, variant: _bothLayouts);

  testWidgets('the viewer header time follows the system setting', (
    WidgetTester tester,
  ) async {
    _useClockFormat(tester, twentyFourHour: false);
    await _open(tester, entryId: 'entry-2');

    expect(find.text('2:30 PM'), findsOneWidget);
    expect(find.text('8:12 AM · note'), findsOneWidget);

    _useClockFormat(tester, twentyFourHour: true);
    await tester.pumpAndSettle();

    expect(find.text('14:30'), findsOneWidget);
    expect(find.text('08:12 · note'), findsOneWidget);
  }, variant: _bothLayouts);

  testWidgets('each log type opens its own viewer', (
    WidgetTester tester,
  ) async {
    await _openMixed(tester, entryId: 'voice-log');
    expect(_inPanel(find.byType(VoicePlayerView)), findsOneWidget);
    expect(find.byType(VideoViewerView), findsNothing);
    expect(find.byType(NoteSheetView), findsNothing);
    expect(find.byType(NotePanelView), findsNothing);

    await _openMixed(tester, entryId: 'video-log');
    expect(_inPanel(find.byType(VideoViewerView)), findsOneWidget);
    expect(find.byType(VoicePlayerView), findsNothing);

    await _openMixed(tester, entryId: 'note-log');
    expect(_inPanel(_noteView()), findsOneWidget);
    expect(find.byType(_sidebar ? NoteSheetView : NotePanelView), findsNothing);
    expect(find.byType(VoicePlayerView), findsNothing);
    expect(find.byType(VideoViewerView), findsNothing);
  }, variant: _bothLayouts);

  testWidgets('no viewer boxes its media', (WidgetTester tester) async {
    await _openMixed(tester, entryId: 'voice-log');
    _expectUnboxed(tester, _inPanel(find.byType(ViewerWaveform)));

    await _openMixed(tester, entryId: 'video-log');
    _expectUnboxed(tester, _inPanel(find.byKey(videoFrameKey)));
  }, variant: _bothLayouts);

  testWidgets('earlier and later cross log types', (WidgetTester tester) async {
    await _openMixed(tester, entryId: 'voice-log');
    expect(find.byType(VoicePlayerView), findsOneWidget);
    expect(find.byKey(logViewerEarlierKey), findsNothing);

    await tester.tap(find.byKey(logViewerLaterKey));
    await tester.pumpAndSettle();

    expect(find.byType(VoicePlayerView), findsNothing);
    expect(_inPanel(_noteView()), findsOneWidget);
    expect(find.text('Morning note'), findsOneWidget);
    expect(find.text('2 of 3'), findsOneWidget);

    await tester.tap(find.byKey(logViewerEarlierKey));
    await tester.pumpAndSettle();

    expect(_inPanel(find.byType(VoicePlayerView)), findsOneWidget);
    expect(_noteView(), findsNothing);
  }, variant: _bothLayouts);

  testWidgets('delete asks first and Back or Close follows the origin', (
    WidgetTester tester,
  ) async {
    _Mixed session = await _openMixed(
      tester,
      entryId: 'voice-log',
      exit: LogViewerExit.back,
    );
    expect(find.text(logViewerBackLabel), findsOneWidget);
    expect(find.text(logViewerCloseLabel), findsNothing);
    await tester.tap(find.byKey(logViewerBackKey));
    await tester.pumpAndSettle();
    expect(session.outcomes, <LogViewerOutcome>[LogViewerOutcome.returned]);
    expect(find.byType(LogViewerPanel), findsNothing);

    session = await _openMixed(
      tester,
      entryId: 'voice-log',
      exit: LogViewerExit.close,
    );
    expect(find.text(logViewerCloseLabel), findsOneWidget);
    expect(find.text(logViewerBackLabel), findsNothing);
    await tester.tap(find.byKey(logViewerBackKey));
    await tester.pumpAndSettle();
    expect(session.outcomes, <LogViewerOutcome>[LogViewerOutcome.returned]);
    expect(find.byType(LogViewerPanel), findsNothing);

    session = await _openMixed(tester, entryId: 'voice-log');
    await tester.tap(find.byKey(logActionsDeleteKey));
    await tester.pumpAndSettle();

    expect(find.text(logViewerDeleteTitle), findsOneWidget);
    expect(session.repository.deletedEntryIds, isEmpty);

    await tester.tap(find.byKey(confirmDialogConfirmKey));
    await tester.pumpAndSettle();

    expect(session.repository.deletedEntryIds, <String>['voice-log']);
    expect(find.text(logViewerDeletedMessage), findsOneWidget);
    expect(session.outcomes, <LogViewerOutcome>[LogViewerOutcome.deleted]);
    expect(find.byType(LogViewerPanel), findsNothing);
    await _drainToast(tester);
  }, variant: _bothLayouts);

  testWidgets(
    'a note reached from a day-panel viewer goes back to the day panel',
    (WidgetTester tester) async {
      final _Mixed session = await _openMixed(
        tester,
        entryId: 'voice-log',
        readNotes: true,
      );
      expect(find.byType(VoicePlayerView), findsOneWidget);

      await tester.tap(find.byKey(logViewerLaterKey));
      await tester.pumpAndSettle();

      if (_sidebar) {
        expect(find.byType(LogViewerPanel), findsNothing);
        expect(find.byType(NotePanelView), findsNothing);
        expect(session.outcomes, <LogViewerOutcome>[LogViewerOutcome.returned]);
        expect(session.readNotes, <String>['note-log']);
      } else {
        expect(_inPanel(find.byType(NoteSheetView)), findsOneWidget);
        expect(session.outcomes, isEmpty);
        expect(session.readNotes, isEmpty);
      }
    },
    variant: _bothLayouts,
  );

  testWidgets(
    'opening a log pauses an inline voice note and closing stops its own',
    (WidgetTester tester) async {
      final FakeEntryAudioPlayer inline = FakeEntryAudioPlayer();
      final Entry inlineEntry = _entry(
        id: 'inline-voice',
        type: EntryType.voice,
        hour: 6,
        minute: 5,
        mediaId: _voiceMedia,
        durationMs: 30000,
      );
      final _Mixed session = await _openMixed(
        tester,
        entryId: 'voice-log',
        open: false,
        inline: (MediaResolver resolver) => SizedBox(
          width: 320,
          child: VoiceBody(
            entry: inlineEntry,
            resolver: resolver,
            playerFactory: () => inline,
          ),
        ),
      );
      expect(inline.loadCalls, hasLength(1));

      await tester.tap(find.byKey(const ValueKey<String>('voice-play-toggle')));
      await tester.pump();
      inline.emitState(AudioPlaybackState.playing);
      await tester.pump();
      expect(inline.playCalls, 1);
      expect(inline.pauseCalls, 0);

      await tester.tap(find.text('open log'));
      await tester.pumpAndSettle();

      expect(inline.pauseCalls, 1);
      expect(_inPanel(find.byType(VoicePlayerView)), findsOneWidget);
      final FakeEntryAudioPlayer own = session.voicePlayers.single;
      expect(own.loadCalls, hasLength(1));
      expect(own.disposeCalls, 0);

      await tester.tap(find.byKey(logViewerBackKey));
      await tester.pumpAndSettle();

      expect(find.byType(LogViewerPanel), findsNothing);
      expect(own.disposeCalls, 1);
      expect(inline.disposeCalls, 0);
      expect(session.outcomes, <LogViewerOutcome>[LogViewerOutcome.returned]);
    },
    variant: _bothLayouts,
  );

  testWidgets('keys reach the viewer through the host', (
    WidgetTester tester,
  ) async {
    final NoteEditorDriver driver = NoteEditorDriver(tester);
    final _Session session = await _open(tester);
    expect(find.text('Morning note'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Afternoon note'), findsOneWidget);
    expect(find.text('2 of 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pumpAndSettle();
    expect(find.text('Morning note'), findsOneWidget);
    expect(find.text('1 of 3'), findsOneWidget);

    await tester.tap(find.byKey(logActionsEditKey));
    await tester.pumpAndSettle();
    expect(driver.find, findsOneWidget);
    await driver.enterText('Watered the roses twice.');
    await tester.pump(draftIdleDebounceForTest);
    await tester.tap(find.text(editNoteSaveLabel));
    await tester.pumpAndSettle();

    expect(driver.find, findsNothing);
    expect(session.repository.noteSaves, hasLength(1));
    expect(_noteText('Watered the roses twice.'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(find.text('Afternoon note'), findsOneWidget);
    expect(find.text('2 of 3'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(session.outcomes, <LogViewerOutcome>[LogViewerOutcome.returned]);
    expect(find.byKey(logViewerPanelKey), findsNothing);
    await _drainToast(tester);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
}
