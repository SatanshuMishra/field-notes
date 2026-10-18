import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/day_detail.dart';
import 'package:field_notes/features/day_detail/day_media_pane.dart';
import 'package:field_notes/features/entry_cards/cards/voice_waveform.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart';
import 'package:field_notes/features/log_viewer/note_reading.dart'
    show LogStepFooter;
import 'package:field_notes/features/log_viewer/video_viewer_view.dart';
import 'package:field_notes/features/log_viewer/voice_player_view.dart';
import 'package:field_notes/features/notes/notes.dart'
    show notesMediaResolverProvider;
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';

import '../capture/core/capture_test_support.dart' show FakeDraftStore;
import '../entry_cards/support/fake_audio_player.dart';
import '../entry_cards/support/fake_video_player.dart';
import '../notes/support/notes_harness.dart' show FakeNoteMediaResolver;
import 'support/day_detail_harness.dart'
    show FakeJournalRepository, FakeMediaStore, blobOf;

const Size _window = Size(1440, 900);
const String _date = '2026-07-19';
const String _openDayLabel = 'open day';
const String _voiceMedia = 'blob-voice';
const String _videoMedia = 'blob-video';

final TargetPlatformVariant _mac = TargetPlatformVariant.only(
  TargetPlatform.macOS,
);

final class _Players {
  final List<FakeEntryAudioPlayer> voice = <FakeEntryAudioPlayer>[];
  final List<FakeEntryVideoPlayer> video = <FakeEntryVideoPlayer>[];

  FakeEntryAudioPlayer newVoice() {
    final FakeEntryAudioPlayer player = FakeEntryAudioPlayer();
    voice.add(player);
    return player;
  }

  FakeEntryVideoPlayer newVideo() {
    final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
    video.add(player);
    return player;
  }
}

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
    peaks: type == EntryType.voice
        ? const <double>[0.2, 0.6, 0.9, 0.4, 0.7, 0.3]
        : null,
    createdAt: DateTime(2026, 7, 19, hour, 12).millisecondsSinceEpoch,
    updatedAt: 0,
  );
}

Entry _voice({int hour = 9}) => _entry(
  id: 'voice-1',
  type: EntryType.voice,
  hour: hour,
  mediaId: _voiceMedia,
  durationMs: 65000,
);

Entry _video({int hour = 11}) => _entry(
  id: 'video-1',
  type: EntryType.video,
  hour: hour,
  mediaId: _videoMedia,
  durationMs: 4000,
);

Entry _note({int hour = 7}) => _entry(
  id: 'note-1',
  type: EntryType.text,
  hour: hour,
  textContent: 'Fed the robins.',
);

FakeNoteMediaResolver _resolver() {
  final Directory folder = Directory.systemTemp.createTempSync('day-media');
  addTearDown(() => folder.deleteSync(recursive: true));
  final File voice = File('${folder.path}/voice.m4a')
    ..writeAsBytesSync(const <int>[0, 1, 2, 3]);
  final File video = File('${folder.path}/video.mp4')
    ..writeAsBytesSync(const <int>[0, 1, 2, 3]);
  return FakeNoteMediaResolver(<String, ResolvedMedia>{
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

Future<_Players> _openDay(
  WidgetTester tester, {
  required List<Entry> entries,
}) async {
  tester.view.physicalSize = _window;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
  addTearDown(tester.view.reset);
  final MediaResolver resolver = _resolver();
  final LruVideoSlots slots = LruVideoSlots(cap: 2);
  addTearDown(slots.dispose);
  final _Players players = _Players();
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: <Override>[
        journalRepositoryProvider.overrideWithValue(
          FakeJournalRepository(entries: entries),
        ),
        draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
        mediaStoreProvider.overrideWith(
          (Ref ref) async => FakeMediaStore(Directory.systemTemp),
        ),
        dayDetailMediaResolverProvider.overrideWith((Ref ref) => resolver),
        notesMediaResolverProvider.overrideWith((Ref ref) async => resolver),
        todayAudioPlayerFactoryProvider.overrideWithValue(players.newVoice),
        todayVideoPlayerFactoryProvider.overrideWithValue(players.newVideo),
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
  return players;
}

Finder _mediaPane() => find.byKey(dayMediaPaneKey);

Finder _inPane(Finder matching) =>
    find.descendant(of: _mediaPane(), matching: matching);

Finder _card(String id) => find.byWidgetPredicate(
  (Widget widget) => widget is CompactLogCard && widget.entry.id == id,
);

Finder _inCard(String id, Finder matching) =>
    find.descendant(of: _card(id), matching: matching);

int _plays(_Players players) =>
    players.voice.fold<int>(
      0,
      (int total, FakeEntryAudioPlayer player) => total + player.playCalls,
    ) +
    players.video.fold<int>(
      0,
      (int total, FakeEntryVideoPlayer player) => total + player.playCalls,
    );

void main() {
  testWidgets('a voice card opens paused', (WidgetTester tester) async {
    final _Players players = await _openDay(tester, entries: <Entry>[_voice()]);

    await tester.tap(
      _inCard('voice-1', find.text('9:12 AM · morning · voice')),
    );
    await tester.pumpAndSettle();

    expect(_inPane(find.byType(VoicePlayerView)), findsOneWidget);
    expect(
      tester.widget<VoicePlayerView>(_inPane(find.byType(VoicePlayerView))),
      isA<VoicePlayerView>()
          .having((VoicePlayerView view) => view.embedded, 'embedded', isTrue)
          .having((VoicePlayerView view) => view.autoplay, 'autoplay', isFalse),
    );
    expect(players.voice, hasLength(1));
    expect(players.voice.single.loadCalls, hasLength(1));
    expect(_plays(players), 0);
    expect(find.byType(LogViewerPanel), findsNothing);
  }, variant: _mac);

  testWidgets('the play glyph opens playing', (WidgetTester tester) async {
    final _Players players = await _openDay(tester, entries: <Entry>[_voice()]);

    await tester.tap(_inCard('voice-1', find.byKey(compactLogPlayKey)));
    await tester.pumpAndSettle();

    expect(_inPane(find.byType(VoicePlayerView)), findsOneWidget);
    expect(players.voice, hasLength(1));
    expect(players.voice.single.playCalls, 1);
    expect(players.voice.single.pauseCalls, 0);
    expect(find.byType(LogViewerPanel), findsNothing);
  }, variant: _mac);

  testWidgets('a video card opens paused', (WidgetTester tester) async {
    final _Players players = await _openDay(tester, entries: <Entry>[_video()]);

    await tester.tap(_inCard('video-1', find.text('A video from the morning')));
    await tester.pumpAndSettle();

    expect(_inPane(find.byType(VideoViewerView)), findsOneWidget);
    expect(
      tester.widget<VideoViewerView>(_inPane(find.byType(VideoViewerView))),
      isA<VideoViewerView>()
          .having((VideoViewerView view) => view.embedded, 'embedded', isTrue)
          .having((VideoViewerView view) => view.autoplay, 'autoplay', isFalse),
    );
    expect(players.video, hasLength(1));
    expect(_plays(players), 0);
    expect(find.byType(LogViewerPanel), findsNothing);
  }, variant: _mac);

  testWidgets('the left column plays nothing', (WidgetTester tester) async {
    final _Players players = await _openDay(tester, entries: <Entry>[_voice()]);

    final CompactLogCard card = tester.widget<CompactLogCard>(_card('voice-1'));
    expect(card.audioPlayerFactory, isNull);
    expect(card.onPlay, isNotNull);
    expect(_inCard('voice-1', find.byType(VoiceBody)), findsNothing);
    expect(_inCard('voice-1', find.byType(VoiceWaveform)), findsOneWidget);
    expect(_inCard('voice-1', find.text('1:05')), findsOneWidget);
    expect(players.voice, isEmpty);
    expect(_mediaPane(), findsNothing);
  }, variant: _mac);

  testWidgets("the media pane has the note pane's chrome once", (
    WidgetTester tester,
  ) async {
    await _openDay(tester, entries: <Entry>[_note(), _voice(), _video()]);

    await tester.tap(
      _inCard('voice-1', find.text('9:12 AM · morning · voice')),
    );
    await tester.pumpAndSettle();

    expect(_inPane(find.byType(VoicePlayerView)), findsOneWidget);
    expect(_inPane(find.text('Morning voice log')), findsOneWidget);
    expect(_inPane(find.byTooltip('Full screen')), findsOneWidget);
    expect(_inPane(find.byKey(logActionsDeleteKey)), findsOneWidget);
    expect(_inPane(find.byType(LogStepFooter)), findsOneWidget);
    expect(_inPane(find.byKey(logViewerEarlierKey)), findsOneWidget);
    expect(_inPane(find.byKey(logViewerLaterKey)), findsOneWidget);
    expect(_inPane(find.text('2 of 3')), findsOneWidget);
    expect(find.byKey(logViewerBackKey), findsNothing);
    expect(find.text(logViewerBackLabel), findsNothing);
  }, variant: _mac);
  testWidgets('card play on a finished video starts it over', (
    WidgetTester tester,
  ) async {
    final _Players players = await _openDay(tester, entries: <Entry>[_video()]);
    final Finder play = _inCard('video-1', find.byKey(compactLogPlayKey));
    await tester.tap(play);
    await tester.pumpAndSettle();
    final FakeEntryVideoPlayer pane = players.video.single;
    pane.emitState(VideoPlaybackState.playing);
    pane.emitPosition(const Duration(milliseconds: 3900));
    pane.emitState(VideoPlaybackState.completed);
    await tester.pump();

    await tester.tap(play);
    await tester.pumpAndSettle();

    expect(players.video.length, greaterThan(1));
    expect(
      players.video.last.seekCalls,
      isNot(contains(const Duration(milliseconds: 3900))),
    );
    expect(players.video.last.playCalls, greaterThan(0));
  }, variant: _mac);
}
