import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
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
import 'package:field_notes/features/mood/mood_banner_for_date.dart';
import 'package:field_notes/features/note_engine/reader/note_reader_view.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';
import 'package:field_notes/features/notes/notes.dart'
    show notesMediaResolverProvider;
import 'package:field_notes/features/sound/sound_providers.dart';
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

void _useNote10Surface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2280);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
}

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
  WidgetTester tester, {
  required Entry entry,
  MediaResolver? resolver,
}) => _openViewerAmong(
  tester,
  entries: <Entry>[entry],
  entryId: entry.id,
  resolver: resolver,
);

Future<void> _openViewerAmong(
  WidgetTester tester, {
  required List<Entry> entries,
  required String entryId,
  MediaResolver? resolver,
}) async {
  _useNote10Surface(tester);
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
          FakeEntryVideoPlayer.new,
        ),
        videoSlotsProvider.overrideWithValue(slots),
        todayClockProvider.overrideWithValue(() => _now),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _Launcher(
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

Future<void> _openDay(WidgetTester tester, List<Entry> entries) async {
  _useNote10Surface(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        journalRepositoryProvider.overrideWithValue(
          FakeJournalRepository(entries: entries),
        ),
        draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
        dayDetailMediaResolverProvider.overrideWith(
          (Ref ref) => FakeMediaResolver(),
        ),
        todayClockProvider.overrideWithValue(() => _now),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _Launcher(
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
  MoodBannerForDate banner, {
  Mood? mood,
}) async {
  _useNote10Surface(tester);
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
      child: mood_support.moodHarness(banner),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

final List<A11yState> viewerStates = <A11yState>[
  A11yState(
    id: 'd1-viewer-todos',
    pump: (WidgetTester tester) => _openViewer(tester, entry: _note(_todoNote)),
    proof: <A11yProof>[A11yProof(find.byType(LogViewerPanel))],
    stateful: const <A11yStatefulControl>[
      A11yStatefulControl.label(_firstTodo, A11yStateKind.checked),
      A11yStatefulControl.label(_secondTodo, A11yStateKind.checked),
    ],
  ),
  A11yState(
    id: 'd2-viewer-photo',
    pump: (WidgetTester tester) => _openViewer(
      tester,
      entry: _note('A harbour morning.\n${photoLine(photoIdA)}'),
      resolver: FakeNoteMediaResolver(<String, ResolvedMedia>{
        prefixOf(photoIdA): availablePhoto(photoIdA),
      }),
    ),
    proof: <A11yProof>[A11yProof(find.byType(LogViewerPanel))],
  ),
  A11yState(
    id: 'd3-viewer-voice',
    pump: (WidgetTester tester) => _openViewer(
      tester,
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
    proof: <A11yProof>[A11yProof(find.byType(VoiceBody))],
  ),
  A11yState(
    id: 'd4-viewer-video',
    pump: (WidgetTester tester) => _openViewer(
      tester,
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
    proof: <A11yProof>[A11yProof(find.byType(VideoBody))],
  ),
  A11yState(
    id: 'd5-reader-menu',
    pump: (WidgetTester tester) async {
      await _openViewer(tester, entry: _note(_plainNote));
      await _longPressText(tester, _plainNote.indexOf('harbour') + 2);
    },
    proof: <A11yProof>[A11yProof(find.text('Select all'))],
  ),
  A11yState(
    id: 'd6-task-toast',
    pump: (WidgetTester tester) async {
      await _openViewer(tester, entry: _note(_todoNote));
      await _tickTask(tester, 2);
    },
    proof: <A11yProof>[A11yProof(find.text('Task ticked'))],
  ),
  A11yState(
    id: 'd7-day-with-entries',
    pump: (WidgetTester tester) => _openDay(tester, <Entry>[
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
    ]),
    proof: <A11yProof>[A11yProof(find.byType(DayDetailPanel))],
  ),
  A11yState(
    id: 'd8-day-empty',
    pump: (WidgetTester tester) => _openDay(tester, const <Entry>[]),
    proof: <A11yProof>[A11yProof(find.text(dayDetailEmptyMessage))],
  ),
  A11yState(
    id: 'd9-mood-prompt-today',
    pump: (WidgetTester tester) =>
        _pumpMood(tester, const MoodBannerForDate(date: _today)),
    proof: <A11yProof>[A11yProof(find.text('How are you feeling today?'))],
  ),
  A11yState(
    id: 'd10-mood-prompt-past',
    pump: (WidgetTester tester) => _pumpMood(
      tester,
      const MoodBannerForDate(date: _pastDay, promptText: dayDetailMoodPrompt),
    ),
    proof: <A11yProof>[A11yProof(find.text("tap to plant this day's bloom"))],
  ),
  A11yState(
    id: 'd11-mood-picker',
    pump: (WidgetTester tester) async {
      await _pumpMood(tester, const MoodBannerForDate(date: _today));
      await _tapText(tester, 'How are you feeling today?');
    },
    proof: <A11yProof>[A11yProof(find.text('Grateful'))],
  ),
  A11yState(
    id: 'd12-mood-set',
    pump: (WidgetTester tester) => _pumpMood(
      tester,
      const MoodBannerForDate(date: _today),
      mood: Mood.calm,
    ),
    proof: <A11yProof>[A11yProof(find.text('change'))],
  ),
  A11yState(
    id: 'd13-change-mood-dialog',
    pump: (WidgetTester tester) async {
      await _pumpMood(
        tester,
        const MoodBannerForDate(date: _today),
        mood: Mood.calm,
      );
      await _tapText(tester, 'change');
      await _tapText(tester, 'Happy');
    },
    proof: <A11yProof>[A11yProof(find.text('Change mood'))],
  ),
  A11yState(
    id: 'd14-delete-entry-dialog',
    pump: (WidgetTester tester) async {
      await _openViewer(tester, entry: _note(_plainNote));
      await tester.tap(find.byKey(logActionsDeleteKey));
      await tester.pumpAndSettle();
    },
    proof: <A11yProof>[A11yProof(find.byKey(confirmDialogConfirmKey))],
  ),
  A11yState(
    id: 'd15-viewer-middle-entry',
    pump: (WidgetTester tester) => _openViewerAmong(
      tester,
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
    ),
    proof: <A11yProof>[
      A11yProof(find.byType(LogViewerPanel)),
      A11yProof(find.text('2 of 3')),
    ],
  ),
];
