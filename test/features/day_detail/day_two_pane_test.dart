import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/flowers/flower_bloom.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/day_detail.dart';
import 'package:field_notes/features/day_detail/day_note_pane.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart'
    show logViewerBackLabel, logViewerLaterKey;
import 'package:field_notes/features/log_viewer/note_reading.dart';
import 'package:field_notes/features/log_viewer/photo_viewer.dart';
import 'package:field_notes/features/log_viewer/video_viewer_view.dart';
import 'package:field_notes/features/log_viewer/voice_player_view.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart'
    show PhotoRect;
import 'package:field_notes/features/note_engine/render/render_note_view.dart';
import 'package:field_notes/features/notes/notes.dart'
    show notesMediaResolverProvider;
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../capture/core/capture_test_support.dart' show FakeDraftStore;
import '../entry_cards/support/fake_audio_player.dart';
import '../entry_cards/support/fake_video_player.dart';
import '../notes/support/notes_harness.dart'
    show FakeNoteMediaResolver, availablePhoto, photoIdA, photoLine, prefixOf;
import 'support/day_detail_harness.dart'
    show FakeJournalRepository, FakeMediaStore, blobOf;

const Size _window = Size(1440, 900);
const String _date = '2026-07-19';
const String _openDayLabel = 'open day';
const String _voiceMedia = 'blob-voice';
const String _videoMedia = 'blob-video';
const Color _rose = Color(0xFFB8566A);

final TargetPlatformVariant _mac = TargetPlatformVariant.only(
  TargetPlatform.macOS,
);

Entry _entry({
  required String id,
  required EntryType type,
  required int hour,
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

List<Entry> _notes() {
  return <Entry>[
    _entry(
      id: 'note-1',
      type: EntryType.text,
      hour: 8,
      textContent: 'Watered the roses.',
    ),
    _entry(
      id: 'note-2',
      type: EntryType.text,
      hour: 14,
      textContent: 'Tea under the elm.\n\n${photoLine(photoIdA)}',
    ),
    _entry(
      id: 'note-3',
      type: EntryType.text,
      hour: 19,
      textContent: 'Read by the window.',
    ),
  ];
}

List<Entry> _media() {
  return <Entry>[
    _entry(
      id: 'voice-1',
      type: EntryType.voice,
      hour: 7,
      mediaId: _voiceMedia,
      durationMs: 65000,
    ),
    _entry(
      id: 'note-1',
      type: EntryType.text,
      hour: 9,
      textContent: 'Fed the robins.',
    ),
    _entry(
      id: 'video-1',
      type: EntryType.video,
      hour: 11,
      mediaId: _videoMedia,
      durationMs: 4000,
    ),
  ];
}

FakeNoteMediaResolver _resolver() {
  final Directory folder = Directory.systemTemp.createTempSync('day-two-pane');
  addTearDown(() => folder.deleteSync(recursive: true));
  final File voice = File('${folder.path}/voice.m4a')
    ..writeAsBytesSync(const <int>[0, 1, 2, 3]);
  final File video = File('${folder.path}/video.mp4')
    ..writeAsBytesSync(const <int>[0, 1, 2, 3]);
  return FakeNoteMediaResolver(<String, ResolvedMedia>{
    prefixOf(photoIdA): availablePhoto(photoIdA, width: 1600, height: 600),
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
  })..memoizeAll();
}

class _Launcher extends StatelessWidget {
  const _Launcher();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showDayDetail(context, date: _date),
        child: const Text(_openDayLabel),
      ),
    );
  }
}

Future<void> _openDay(
  WidgetTester tester, {
  required List<Entry> entries,
  Mood? mood,
}) async {
  tester.view.physicalSize = _window;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
  addTearDown(tester.view.reset);
  final MediaResolver resolver = _resolver();
  final LruVideoSlots slots = LruVideoSlots(cap: 2);
  addTearDown(slots.dispose);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        journalRepositoryProvider.overrideWithValue(
          FakeJournalRepository(
            entries: entries,
            day: mood == null
                ? null
                : Day(
                    id: 'day-1',
                    date: _date,
                    mood: mood,
                    createdAt: 0,
                    updatedAt: 0,
                  ),
          ),
        ),
        draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
        mediaStoreProvider.overrideWith(
          (Ref ref) async => FakeMediaStore(Directory.systemTemp),
        ),
        dayDetailMediaResolverProvider.overrideWith((Ref ref) => resolver),
        notesMediaResolverProvider.overrideWith((Ref ref) async => resolver),
        todayAudioPlayerFactoryProvider.overrideWithValue(
          FakeEntryAudioPlayer.new,
        ),
        todayVideoPlayerFactoryProvider.overrideWithValue(
          FakeEntryVideoPlayer.new,
        ),
        videoSlotsProvider.overrideWithValue(slots),
        videoAspectProvider.overrideWith((Ref ref, String mediaId) => 16 / 9),
        todayClockProvider.overrideWithValue(() => DateTime(2026, 7, 23, 9)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.macOS),
        home: const _Launcher(),
      ),
    ),
  );
  await tester.tap(find.text(_openDayLabel));
  await tester.pumpAndSettle();
}

Finder _pane() => find.byKey(dayNotePaneKey);

Finder _inPane(Finder matching) =>
    find.descendant(of: _pane(), matching: matching);

Finder _card(String id) => find.byWidgetPredicate(
  (Widget widget) => widget is CompactLogCard && widget.entry.id == id,
);

Future<void> _tapCard(WidgetTester tester, String id) async {
  await tester.tapAt(tester.getTopLeft(_card(id)) + const Offset(24, 18));
  await tester.pumpAndSettle();
}

void _expectOneLine(WidgetTester tester, String text) {
  final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
    find.text(text),
  );
  final List<TextBox> boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
  );
  expect(
    <int>{for (final TextBox box in boxes) box.top.round()},
    hasLength(1),
    reason: text,
  );
}

Iterable<BoxDecoration> _outlinesOf(WidgetTester tester, String id) {
  return tester
      .widgetList<DecoratedBox>(
        find.ancestor(of: _card(id), matching: find.byType(DecoratedBox)),
      )
      .map((DecoratedBox box) => box.decoration)
      .whereType<BoxDecoration>()
      .where((BoxDecoration decoration) {
        final BoxBorder? border = decoration.border;
        return border is Border &&
            border.top.width == 2.5 &&
            border.top.color.toARGB32() == _rose.toARGB32();
      });
}

void _expectPlaceholder({required bool empty}) {
  expect(
    _inPane(find.text(empty ? dayNotePaneEmptyTitle : dayNotePanePrompt)),
    findsOneWidget,
  );
  expect(
    _inPane(find.text(empty ? dayNotePaneEmptyHint : dayNotePaneHint)),
    findsOneWidget,
  );
  expect(
    _inPane(find.text(empty ? dayNotePanePrompt : dayNotePaneEmptyTitle)),
    findsNothing,
  );
}

void main() {
  testWidgets('the Mac day panel has two panes', (WidgetTester tester) async {
    await _openDay(tester, entries: _notes(), mood: Mood.calm);

    final Rect panel = tester.getRect(find.byKey(dayDetailPanelKey));
    expect(panel.size, const Size(1060, 660));
    expect(panel.center, const Offset(720, 450));

    final Rect list = tester.getRect(find.byKey(dayDetailListPaneKey));
    expect(list.width, greaterThanOrEqualTo(320));
    expect(list.width, lessThanOrEqualTo(380));
    expect(list.left, closeTo(panel.left + 2, 0.5));
    expect(
      find.descendant(
        of: find.byKey(dayDetailListPaneKey),
        matching: _card('note-1'),
      ),
      findsOneWidget,
    );
    expect(find.text('Change mood'), findsOneWidget);
    expect(find.text(dayDetailAddNoteLabel), findsOneWidget);
    _expectOneLine(tester, 'Change mood');
    _expectOneLine(tester, dayDetailAddNoteLabel);
    expect(
      tester.getRect(find.text('Change mood')).right,
      lessThanOrEqualTo(list.right),
    );
    expect(
      tester.getRect(find.text(dayDetailAddNoteLabel)).right,
      lessThanOrEqualTo(list.right),
    );

    final DashedDivider rule = tester.widget<DashedDivider>(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is DashedDivider && widget.axis == Axis.vertical,
      ),
    );
    expect(rule.thickness, 1.5);

    final Rect pane = tester.getRect(_pane());
    expect(pane.left, greaterThan(list.right));
    expect(pane.right, closeTo(panel.right - 2, 0.5));
    final ColoredBox paper = tester.widget<ColoredBox>(
      find.ancestor(of: _pane(), matching: find.byType(ColoredBox)).first,
    );
    expect(
      paper.color.toARGB32(),
      FieldNotesColors.light.composerPaper.toARGB32(),
    );
    _expectPlaceholder(empty: false);
    expect(_inPane(find.byType(FlowerBloom)), findsOneWidget);
    expect(_inPane(find.byType(NoteReadingBody)), findsNothing);

    await _openDay(tester, entries: const <Entry>[]);

    expect(
      tester.getSize(find.byKey(dayDetailPanelKey)),
      const Size(1060, 660),
    );
    _expectPlaceholder(empty: true);
    expect(_inPane(find.byType(FlowerBloom)), findsNothing);
  }, variant: _mac);

  testWidgets('choosing a note reads it in the right pane', (
    WidgetTester tester,
  ) async {
    await _openDay(tester, entries: _notes(), mood: Mood.calm);
    expect(_outlinesOf(tester, 'note-2'), isEmpty);

    await _tapCard(tester, 'note-2');

    expect(_inPane(find.text('Afternoon note')), findsOneWidget);
    final NoteReadingBody body = tester.widget<NoteReadingBody>(
      _inPane(find.byType(NoteReadingBody)),
    );
    expect(body.entry.id, 'note-2');
    expect(
      _inPane(
        find.byWidgetPredicate(
          (Widget widget) =>
              widget is NoteBody &&
              widget.text.startsWith('Tea under the elm.'),
        ),
      ),
      findsOneWidget,
    );
    expect(_inPane(find.byType(LogActionsPill)), findsOneWidget);
    expect(_inPane(find.byKey(logActionsEditKey)), findsOneWidget);
    expect(_inPane(find.byKey(logActionsDeleteKey)), findsOneWidget);
    expect(_inPane(find.text('2 of 3')), findsOneWidget);
    expect(find.text(dayNotePanePrompt), findsNothing);
    expect(
      tester.getSize(_inPane(find.byType(NoteReadingBody))).width,
      lessThanOrEqualTo(34 * 16 + 0.5),
    );

    expect(_outlinesOf(tester, 'note-2'), hasLength(1));
    expect(_outlinesOf(tester, 'note-1'), isEmpty);
    expect(_outlinesOf(tester, 'note-3'), isEmpty);

    await tester.tap(_inPane(find.byKey(logViewerLaterKey)));
    await tester.pumpAndSettle();

    expect(_inPane(find.text('Evening note')), findsOneWidget);
    expect(_inPane(find.text('3 of 3')), findsOneWidget);
    expect(_outlinesOf(tester, 'note-3'), hasLength(1));
    expect(_outlinesOf(tester, 'note-2'), isEmpty);
  }, variant: _mac);

  testWidgets('voice and video open full window over the day', (
    WidgetTester tester,
  ) async {
    await _openDay(tester, entries: _media());

    await _tapCard(tester, 'voice-1');

    expect(find.byType(VoicePlayerView), findsOneWidget);
    expect(find.text(logViewerBackLabel), findsOneWidget);
    expect(find.byType(DayDetailPanel, skipOffstage: false), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(VoicePlayerView), findsNothing);
    expect(find.byKey(dayDetailPanelKey), findsOneWidget);
    _expectPlaceholder(empty: false);
    expect(_inPane(find.byType(NoteReadingBody)), findsNothing);

    await _tapCard(tester, 'video-1');

    expect(find.byType(VideoViewerView), findsOneWidget);
    expect(find.text(logViewerBackLabel), findsOneWidget);
    expect(find.byType(DayDetailPanel, skipOffstage: false), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(VideoViewerView), findsNothing);
    expect(find.byKey(dayDetailPanelKey), findsOneWidget);
    _expectPlaceholder(empty: false);
  }, variant: _mac);

  testWidgets('Esc unwinds photo, note, day', (WidgetTester tester) async {
    await _openDay(tester, entries: _notes(), mood: Mood.calm);
    await _tapCard(tester, 'note-2');
    expect(_inPane(find.text('Afternoon note')), findsOneWidget);

    final RenderNoteView reader = tester.renderObject<RenderNoteView>(
      _inPane(find.byType(NoteViewBody)),
    );
    final Rect image = reader.noteLayout.photoRects
        .singleWhere((PhotoRect photo) => photo.reference == prefixOf(photoIdA))
        .imageRect;
    await tester.tapAt(
      (reader.contentToGlobal(image.topLeft) & image.size).center,
    );
    await tester.pumpAndSettle();

    expect(find.byType(PhotoViewer), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(PhotoViewer), findsNothing);
    expect(_inPane(find.text('Afternoon note')), findsOneWidget);
    expect(find.byKey(dayDetailPanelKey), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byKey(dayDetailPanelKey), findsOneWidget);
    _expectPlaceholder(empty: false);
    expect(_outlinesOf(tester, 'note-2'), isEmpty);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(find.byType(DayDetailPanel), findsNothing);
    expect(find.text(_openDayLabel), findsOneWidget);
  }, variant: _mac);

  testWidgets('reading a note in the right pane pauses other playback', (
    WidgetTester tester,
  ) async {
    await _openDay(tester, entries: _notes(), mood: Mood.calm);
    final Object inline = Object();
    final List<Object> paused = <Object>[];
    playbackFocus.claim(inline, () => paused.add(inline));
    addTearDown(() => playbackFocus.release(inline));

    await _tapCard(tester, 'note-1');

    expect(_inPane(find.text('Morning note')), findsOneWidget);
    expect(paused, <Object>[inline]);

    playbackFocus.claim(inline, () => paused.add(inline));
    await tester.tap(_inPane(find.byKey(logViewerLaterKey)));
    await tester.pumpAndSettle();

    expect(_inPane(find.text('Afternoon note')), findsOneWidget);
    expect(paused, <Object>[inline, inline]);
  }, variant: _mac);
}
