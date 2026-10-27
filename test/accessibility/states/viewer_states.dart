import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart' show MdRange;
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/day_detail/day_detail_panel.dart';
import 'package:field_notes/features/day_detail/day_detail_providers.dart';
import 'package:field_notes/features/day_detail/show_day_detail.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart';
import 'package:field_notes/features/log_viewer/note_panel_view.dart';
import 'package:field_notes/features/log_viewer/video_viewer_view.dart';
import 'package:field_notes/features/log_viewer/viewer_waveform.dart';
import 'package:field_notes/features/log_viewer/voice_player_view.dart';
import 'package:field_notes/features/mood/mood_banner.dart';
import 'package:field_notes/features/mood/mood_banner_for_date.dart';
import 'package:field_notes/features/mood/mood_picker_sheet.dart';
import 'package:field_notes/features/note_engine/reader/note_reader_view.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';
import 'package:field_notes/features/notes/notes.dart'
    show notesMediaResolverProvider;
import 'package:field_notes/features/sound/sound_providers.dart';
import 'package:field_notes/features/today/today_mood_dock.dart';
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../../features/capture/core/capture_test_support.dart'
    show FakeDraftStore, FakeNoteWriter;
import '../../features/day_detail/support/day_detail_harness.dart'
    show FakeJournalRepository, FakeMediaResolver, FakeMediaStore;
import '../../features/entry_cards/support/fake_audio_player.dart';
import '../../features/entry_cards/support/fake_video_player.dart';
import '../../features/mood/support/mood_harness.dart' as mood_support;
import '../../features/notes/support/notes_harness.dart'
    show FakeNoteMediaResolver, availablePhoto, photoIdA, photoLine, prefixOf;
import '../../features/sound/support/fake_sound_player.dart';
import '../support/a11y_state.dart';

final DateTime _now = DateTime(2026, 9, 18, 9, 30);
const String _today = '2026-09-18';
const String _pastDay = '2026-09-17';

const String _launchLabel = 'open';
const String _firstTodo = 'call the ferry office';
const String _secondTodo = 'pack the tide tables';
const String _todoNote = '- [ ] $_firstTodo\n- [ ] $_secondTodo';
const String _plainNote = 'The fog lifted over the harbour.';
const String _voiceId = 'voice-1';
const String _videoId = 'video-1';

MaterialApp _app(A11yVariant variant, Widget home) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: variant.theme,
  builder: variant.scaleText,
  home: home,
);

Entry _entry({
  required String id,
  required EntryType type,
  required DateTime createdAt,
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
    createdAt: createdAt.millisecondsSinceEpoch,
    updatedAt: 0,
  );
}

Entry _note(String source) => _entry(
  id: 'entry-1',
  type: EntryType.text,
  createdAt: _now,
  textContent: source,
);

MediaBlob _blob(String id, MediaKind kind, String mime) => MediaBlob(
  id: id,
  relPath: '$id.bin',
  mime: mime,
  kind: kind,
  bytes: 4,
  createdAt: 0,
);

File _writtenMediaFile(String name) {
  final Directory dir = Directory.systemTemp.createTempSync('viewer_sweep');
  addTearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
  final File file = File('${dir.path}/$name');
  file.writeAsBytesSync(<int>[0, 1, 2, 3]);
  return file;
}

class _Launcher extends StatelessWidget {
  const _Launcher({required this.open});

  final Future<void> Function(BuildContext context) open;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => open(context),
        child: const Text(_launchLabel),
      ),
    );
  }
}

Future<void> _launch(WidgetTester tester) async {
  await tester.tap(find.text(_launchLabel));
  await tester.pumpAndSettle();
}

Future<void> _openViewer(
  WidgetTester tester,
  A11yVariant variant, {
  required Entry entry,
  MediaResolver? resolver,
}) => _openViewerAmong(
  tester,
  variant,
  entries: <Entry>[entry],
  entryId: entry.id,
  resolver: resolver,
);

Future<void> _openViewerAmong(
  WidgetTester tester,
  A11yVariant variant, {
  required List<Entry> entries,
  required String entryId,
  MediaResolver? resolver,
  EntryVideoPlayerFactory? videoPlayer,
}) async {
  variant.useWindow(tester);
  final LruVideoSlots slots = LruVideoSlots(cap: 1);
  addTearDown(slots.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        journalRepositoryProvider.overrideWithValue(
          FakeJournalRepository(entries: entries),
        ),
        draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
        mediaStoreProvider.overrideWith(
          (Ref ref) async => FakeMediaStore(Directory.systemTemp),
        ),
        noteWriterProvider.overrideWith((Ref ref) async => FakeNoteWriter()),
        notesMediaResolverProvider.overrideWith(
          (Ref ref) async => resolver ?? FakeMediaResolver(),
        ),
        todayAudioPlayerFactoryProvider.overrideWithValue(
          FakeEntryAudioPlayer.new,
        ),
        todayVideoPlayerFactoryProvider.overrideWithValue(
          videoPlayer ?? FakeEntryVideoPlayer.new,
        ),
        videoSlotsProvider.overrideWithValue(slots),
        videoAspectProvider.overrideWith((Ref ref, String mediaId) => null),
        todayClockProvider.overrideWithValue(() => _now),
      ],
      child: _app(
        variant,
        _Launcher(
          open: (BuildContext context) => showLogViewer(
            context,
            date: _today,
            entryId: entryId,
            exit: LogViewerExit.close,
          ),
        ),
      ),
    ),
  );
  await _launch(tester);
}

Future<void> openA11yViewer(
  WidgetTester tester,
  A11yVariant variant, {
  required Entry entry,
  required MediaResolver resolver,
  EntryVideoPlayerFactory? videoPlayer,
}) => _openViewerAmong(
  tester,
  variant,
  entries: <Entry>[entry],
  entryId: entry.id,
  resolver: resolver,
  videoPlayer: videoPlayer,
);

RenderNoteView _reader(WidgetTester tester) => tester.renderObject(
  find.descendant(
    of: find.byType(NoteReaderView),
    matching: find.byType(NoteViewBody),
  ),
);

Future<void> _tickTask(WidgetTester tester, int boxStart) async {
  final RenderNoteView render = _reader(tester);
  final Rect box = render.noteLayout.rangeBounds(
    MdRange(boxStart, boxStart + 3),
  );
  await tester.tapAt(render.contentToGlobal(box.center));
  await tester.pumpAndSettle();
}

Future<void> _longPressText(WidgetTester tester, int sourceOffset) async {
  final RenderNoteView render = _reader(tester);
  final Rect caret = render.noteLayout.caretRect(
    sourceOffset,
    TextAffinity.downstream,
  );
  final TestGesture gesture = await tester.startGesture(
    render.contentToGlobal(caret.center),
    kind: PointerDeviceKind.touch,
  );
  await tester.pump(const Duration(milliseconds: 600));
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _openDay(
  WidgetTester tester,
  A11yVariant variant,
  List<Entry> entries, {
  Day? day,
}) async {
  variant.useWindow(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        journalRepositoryProvider.overrideWithValue(
          FakeJournalRepository(entries: entries, day: day),
        ),
        draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
        dayDetailMediaResolverProvider.overrideWith(
          (Ref ref) => FakeMediaResolver(),
        ),
        todayClockProvider.overrideWithValue(() => _now),
      ],
      child: _app(
        variant,
        _Launcher(
          open: (BuildContext context) =>
              showDayDetail(context, date: _pastDay),
        ),
      ),
    ),
  );
  await _launch(tester);
}

Future<void> _pumpMood(
  WidgetTester tester,
  A11yVariant variant,
  MoodBannerForDate banner, {
  Mood? mood,
}) async {
  variant.useWindow(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        journalRepositoryProvider.overrideWithValue(
          mood_support.FakeJournalRepository(
            initialDay: mood_support.testDay(date: banner.date, mood: mood),
          ),
        ),
        appSettingsProvider.overrideWith(
          (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
        ),
        soundPlayerProvider.overrideWithValue(FakeSoundPlayer()),
        todayClockProvider.overrideWithValue(() => _now),
      ],
      child: _app(variant, Scaffold(body: Center(child: banner))),
    ),
  );
  await tester.pumpAndSettle();
}

class _TodayDockPage extends StatelessWidget {
  const _TodayDockPage();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned(
          left: todayMoodDockSideInset,
          right: todayMoodDockSideInset,
          bottom: MediaQuery.viewPaddingOf(context).bottom + todayMoodDockLift,
          child: const TodayMoodDock(),
        ),
      ],
    );
  }
}

Future<void> _pumpDock(
  WidgetTester tester,
  A11yVariant variant, {
  Mood? mood,
}) async {
  variant.useWindow(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        journalRepositoryProvider.overrideWithValue(
          mood_support.FakeJournalRepository(
            initialDay: mood_support.testDay(date: _today, mood: mood),
          ),
        ),
        appSettingsProvider.overrideWith(
          (Ref ref) => Stream<AppSettings>.value(AppSettings.defaults),
        ),
        soundPlayerProvider.overrideWithValue(FakeSoundPlayer()),
        todayClockProvider.overrideWithValue(() => _now),
      ],
      child: _app(variant, const Scaffold(body: _TodayDockPage())),
    ),
  );
  await tester.pumpAndSettle();
}

final Finder _logSheet = find.descendant(
  of: find.byType(LogViewerPanel),
  matching: find.byType(PhoneSheet),
);

Finder _inViewer(Finder matching) =>
    find.descendant(of: find.byType(LogViewerPanel), matching: matching);

final Finder _daySheet = find.descendant(
  of: find.byType(DayDetailPanel),
  matching: find.byType(PhoneSheet),
);

final Finder _notePanel = _inViewer(find.byType(NotePanelView));

final Finder _dayPanel = find.descendant(
  of: find.byType(DayDetailPanel),
  matching: find.byKey(dayDetailListPaneKey),
);

final Finder _desktopMoodPicker = find.descendant(
  of: find.byType(DialogHost),
  matching: find.byWidgetPredicate(
    (Widget widget) =>
        widget is MoodPickerSheet && widget.layout == ShellLayout.sidebar,
  ),
);

Finder _confirmIn(Type host) => find.descendant(
  of: find.byType(host),
  matching: find.byKey(confirmDialogConfirmKey),
);

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

const List<A11yStatefulControl> _todoChecks = <A11yStatefulControl>[
  A11yStatefulControl.label(_firstTodo, A11yStateKind.checked),
  A11yStatefulControl.label(_secondTodo, A11yStateKind.checked),
];

Future<void> _pumpTodos(WidgetTester tester, A11yVariant variant) =>
    _openViewer(tester, variant, entry: _note(_todoNote));

Future<void> _pumpPhoto(WidgetTester tester, A11yVariant variant) =>
    _openViewer(
      tester,
      variant,
      entry: _note('A harbour morning.\n${photoLine(photoIdA)}'),
      resolver: FakeNoteMediaResolver(<String, ResolvedMedia>{
        prefixOf(photoIdA): availablePhoto(photoIdA),
      }),
    );

Future<void> _pumpReaderMenu(WidgetTester tester, A11yVariant variant) async {
  await _openViewer(tester, variant, entry: _note(_plainNote));
  await _longPressText(tester, _plainNote.indexOf('harbour') + 2);
}

Future<void> _pumpTaskToast(WidgetTester tester, A11yVariant variant) =>
    _openViewer(tester, variant, entry: _note(_todoNote));

Future<void> _tickSecondTask(WidgetTester tester, A11yVariant variant) =>
    _tickTask(tester, 2);

Future<void> _pumpDayWithEntries(WidgetTester tester, A11yVariant variant) =>
    _openDay(tester, variant, <Entry>[
      _entry(
        id: 'entry-1',
        type: EntryType.text,
        createdAt: DateTime(2026, 9, 17, 9, 30),
        textContent: 'a good day',
      ),
      _entry(
        id: 'entry-2',
        type: EntryType.text,
        createdAt: DateTime(2026, 9, 17, 14, 30),
        textContent: 'and a walk',
      ),
    ]);

Future<void> _pumpDayEmpty(WidgetTester tester, A11yVariant variant) =>
    _openDay(tester, variant, const <Entry>[]);

Future<void> _pumpMoodPicker(WidgetTester tester, A11yVariant variant) async {
  await _pumpDock(tester, variant);
  await _tapText(tester, todayMoodDockChooseLabel);
}

Future<void> _pumpChangeMood(WidgetTester tester, A11yVariant variant) async {
  await _pumpDock(tester, variant, mood: Mood.calm);
  await _tapText(tester, todayMoodDockChangeLabel);
  await _tapText(tester, 'Happy');
}

Future<void> _pumpDeleteEntry(WidgetTester tester, A11yVariant variant) async {
  await _openViewer(tester, variant, entry: _note(_plainNote));
  await tester.tap(find.byKey(logActionsDeleteKey));
  await tester.pumpAndSettle();
}

Future<void> _pumpMiddleEntry(WidgetTester tester, A11yVariant variant) =>
    _openViewerAmong(
      tester,
      variant,
      entries: <Entry>[
        _entry(
          id: 'n1',
          type: EntryType.text,
          createdAt: DateTime(2026, 9, 18, 8),
          textContent: 'First light.',
        ),
        _entry(
          id: 'n2',
          type: EntryType.text,
          createdAt: DateTime(2026, 9, 18, 9),
          textContent: 'The fog lifted.',
        ),
        _entry(
          id: 'n3',
          type: EntryType.text,
          createdAt: DateTime(2026, 9, 18, 10),
          textContent: 'Ferry at ten.',
        ),
      ],
      entryId: 'n2',
    );

Future<void> _pumpDayPastMood(WidgetTester tester, A11yVariant variant) =>
    _openDay(
      tester,
      variant,
      <Entry>[
        _entry(
          id: 'entry-1',
          type: EntryType.text,
          createdAt: DateTime(2026, 9, 17, 9, 30),
          textContent: 'a good day',
        ),
      ],
      day: const Day(
        id: 'day-1',
        date: _pastDay,
        mood: Mood.grateful,
        createdAt: 0,
        updatedAt: 0,
      ),
    );

final List<A11yState> viewerStates = <A11yState>[
  ...a11yInBothLayouts(
    id: 'd1-viewer-todos',
    desktopId: 'd1-viewer-todos-sidebar',
    phone: A11yLayoutHalf(
      pump: _pumpTodos,
      proof: <A11yProof>[A11yProof(_logSheet)],
      stateful: _todoChecks,
    ),
    desktop: A11yLayoutHalf(
      pump: _pumpTodos,
      proof: <A11yProof>[A11yProof(_notePanel)],
      stateful: _todoChecks,
    ),
  ),
  ...a11yInBothLayouts(
    id: 'd2-viewer-photo',
    desktopId: 'd2-viewer-photo-sidebar',
    phone: A11yLayoutHalf(
      pump: _pumpPhoto,
      proof: <A11yProof>[A11yProof(_logSheet)],
    ),
    desktop: A11yLayoutHalf(
      pump: _pumpPhoto,
      proof: <A11yProof>[A11yProof(_notePanel)],
    ),
  ),
  A11yState(
    id: 'd3-viewer-voice',
    pump: (WidgetTester tester, A11yVariant variant) => _openViewer(
      tester,
      variant,
      entry: _entry(
        id: 'entry-1',
        type: EntryType.voice,
        createdAt: _now,
        mediaId: _voiceId,
        durationMs: 65000,
      ),
      resolver: FakeNoteMediaResolver(<String, ResolvedMedia>{
        _voiceId: ResolvedMedia.available(
          blob: _blob(_voiceId, MediaKind.audio, 'audio/mp4'),
          file: _writtenMediaFile('voice.m4a'),
        ),
      }),
    ),
    proof: <A11yProof>[
      A11yProof(_inViewer(find.byType(VoicePlayerView))),
      A11yProof(find.byType(ViewerWaveform)),
    ],
  ),
  A11yState(
    id: 'd4-viewer-video',
    pump: (WidgetTester tester, A11yVariant variant) => _openViewer(
      tester,
      variant,
      entry: _entry(
        id: 'entry-1',
        type: EntryType.video,
        createdAt: _now,
        mediaId: _videoId,
        durationMs: 4000,
      ),
      resolver: FakeNoteMediaResolver(<String, ResolvedMedia>{
        _videoId: ResolvedMedia.available(
          blob: _blob(_videoId, MediaKind.video, 'video/mp4'),
          file: _writtenMediaFile('video.mp4'),
        ),
      }),
    ),
    proof: <A11yProof>[
      A11yProof(_inViewer(find.byType(VideoViewerView))),
      A11yProof(find.byType(VideoBody)),
    ],
  ),
  ...a11yInBothLayouts(
    id: 'd5-reader-menu',
    desktopId: 'd5-reader-menu-sidebar',
    phone: A11yLayoutHalf(
      pump: _pumpReaderMenu,
      proof: <A11yProof>[A11yProof(_logSheet), A11yProof(find.text('Copy'))],
    ),
    desktop: A11yLayoutHalf(
      pump: _pumpReaderMenu,
      proof: <A11yProof>[A11yProof(_notePanel), A11yProof(find.text('Copy'))],
    ),
  ),
  ...a11yInBothLayouts(
    id: 'd6-task-toast',
    desktopId: 'd6-task-toast-sidebar',
    phone: A11yLayoutHalf(
      pump: _pumpTaskToast,
      act: _tickSecondTask,
      proof: <A11yProof>[
        A11yProof(_logSheet),
        A11yProof(find.text('Task ticked')),
      ],
    ),
    desktop: A11yLayoutHalf(
      pump: _pumpTaskToast,
      act: _tickSecondTask,
      proof: <A11yProof>[
        A11yProof(_notePanel),
        A11yProof(find.text('Task ticked')),
      ],
    ),
  ),
  ...a11yInBothLayouts(
    id: 'd7-day-with-entries',
    desktopId: 'd7-day-with-entries-sidebar',
    phone: A11yLayoutHalf(
      pump: _pumpDayWithEntries,
      proof: <A11yProof>[A11yProof(_daySheet)],
    ),
    desktop: A11yLayoutHalf(
      pump: _pumpDayWithEntries,
      proof: <A11yProof>[A11yProof(_dayPanel)],
    ),
  ),
  ...a11yInBothLayouts(
    id: 'd8-day-empty',
    desktopId: 'd8-day-empty-sidebar',
    phone: A11yLayoutHalf(
      pump: _pumpDayEmpty,
      proof: <A11yProof>[
        A11yProof(_daySheet),
        A11yProof(find.text(dayDetailEmptyMessage)),
      ],
    ),
    desktop: A11yLayoutHalf(
      pump: _pumpDayEmpty,
      proof: <A11yProof>[
        A11yProof(_dayPanel),
        A11yProof(find.text(dayDetailEmptyMessage)),
      ],
    ),
  ),
  A11yState(
    id: 'd9-mood-prompt-today',
    pump: _pumpDock,
    proof: <A11yProof>[
      A11yProof(find.text(todayMoodDockPrompt)),
      A11yProof(find.text(todayMoodDockChooseLabel)),
    ],
  ),
  A11yState(
    id: 'd10-mood-prompt-past',
    pump: (WidgetTester tester, A11yVariant variant) => _pumpMood(
      tester,
      variant,
      const MoodBannerForDate(date: _pastDay, promptText: dayDetailMoodPrompt),
    ),
    proof: <A11yProof>[A11yProof(find.text("tap to plant this day's bloom"))],
  ),
  ...a11yInBothLayouts(
    id: 'd11-mood-picker',
    desktopId: 'd11-mood-picker-sidebar',
    phone: A11yLayoutHalf(
      pump: _pumpMoodPicker,
      proof: <A11yProof>[
        A11yProof(
          find.descendant(
            of: find.byType(MoodPickerSheet),
            matching: find.byType(PhoneSheet),
          ),
        ),
        A11yProof(find.text('Grateful')),
      ],
    ),
    desktop: A11yLayoutHalf(
      pump: _pumpMoodPicker,
      proof: <A11yProof>[
        A11yProof(_desktopMoodPicker),
        A11yProof(find.text('Grateful')),
      ],
    ),
  ),
  A11yState(
    id: 'd12-mood-set',
    pump: (WidgetTester tester, A11yVariant variant) =>
        _pumpDock(tester, variant, mood: Mood.calm),
    proof: <A11yProof>[
      A11yProof(find.text('Feeling ${Mood.calm.label}')),
      A11yProof(find.text(todayMoodDockChangeLabel)),
    ],
  ),
  ...a11yInBothLayouts(
    id: 'd13-change-mood-dialog',
    desktopId: 'd13-change-mood-dialog-sidebar',
    phone: A11yLayoutHalf(
      pump: _pumpChangeMood,
      proof: <A11yProof>[
        A11yProof(_confirmIn(PhoneSheet)),
        A11yProof(find.text('Change mood')),
      ],
    ),
    desktop: A11yLayoutHalf(
      pump: _pumpChangeMood,
      proof: <A11yProof>[
        A11yProof(
          find.descendant(
            of: find.byType(StickerCard),
            matching: find.widgetWithText(StickerButton, 'Change mood'),
          ),
        ),
      ],
    ),
  ),
  ...a11yInBothLayouts(
    id: 'd14-delete-entry-dialog',
    desktopId: 'd14-delete-entry-dialog-sidebar',
    phone: A11yLayoutHalf(
      pump: _pumpDeleteEntry,
      proof: <A11yProof>[A11yProof(_confirmIn(PhoneSheet))],
    ),
    desktop: A11yLayoutHalf(
      pump: _pumpDeleteEntry,
      proof: <A11yProof>[A11yProof(_confirmIn(DialogHost))],
    ),
  ),
  ...a11yInBothLayouts(
    id: 'd15-viewer-middle-entry',
    desktopId: 'd15-viewer-middle-entry-sidebar',
    phone: A11yLayoutHalf(
      pump: _pumpMiddleEntry,
      proof: <A11yProof>[A11yProof(_logSheet), A11yProof(find.text('2 of 3'))],
    ),
    desktop: A11yLayoutHalf(
      pump: _pumpMiddleEntry,
      proof: <A11yProof>[A11yProof(_notePanel), A11yProof(find.text('2 of 3'))],
    ),
  ),
  ...a11yInBothLayouts(
    id: 'd16-day-past-mood',
    desktopId: 'd16-day-past-mood-sidebar',
    phone: A11yLayoutHalf(
      pump: _pumpDayPastMood,
      proof: <A11yProof>[
        A11yProof(_daySheet),
        A11yProof(find.byType(DayMoodCard)),
      ],
    ),
    desktop: A11yLayoutHalf(
      pump: _pumpDayPastMood,
      proof: <A11yProof>[
        A11yProof(_dayPanel),
        A11yProof(find.byType(DayMoodCard)),
      ],
    ),
  ),
];
