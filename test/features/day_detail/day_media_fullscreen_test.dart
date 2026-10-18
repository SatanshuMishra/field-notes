import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/day_detail.dart';
import 'package:field_notes/features/day_detail/day_media_pane.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart';
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

final TargetPlatformVariant _mac = TargetPlatformVariant.only(
  TargetPlatform.macOS,
);

final class _TrackingAudioPlayer extends FakeEntryAudioPlayer {
  final List<Duration> seekCalls = <Duration>[];

  bool get _open => disposeCalls == 0;

  @override
  Future<void> seek(Duration position) async {
    seekCalls.add(position);
    if (_open) {
      emitPosition(position);
    }
  }

  @override
  Future<void> play() async {
    await super.play();
    if (_open) {
      emitState(AudioPlaybackState.playing);
    }
  }

  @override
  Future<void> pause() async {
    await super.pause();
    if (_open) {
      emitState(AudioPlaybackState.paused);
    }
  }
}

final class _Players {
  final List<_TrackingAudioPlayer> voice = <_TrackingAudioPlayer>[];

  _TrackingAudioPlayer newVoice() {
    final _TrackingAudioPlayer player = _TrackingAudioPlayer();
    voice.add(player);
    return player;
  }

  FakeEntryVideoPlayer newVideo() => FakeEntryVideoPlayer();
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

Entry _voice() => _entry(
  id: 'voice-1',
  type: EntryType.voice,
  hour: 9,
  mediaId: _voiceMedia,
  durationMs: 65000,
);

Entry _note() => _entry(
  id: 'note-1',
  type: EntryType.text,
  hour: 7,
  textContent: 'Fed the robins.',
);

FakeNoteMediaResolver _resolver() {
  final Directory folder = Directory.systemTemp.createTempSync('day-full');
  addTearDown(() => folder.deleteSync(recursive: true));
  final File voice = File('${folder.path}/voice.m4a')
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

Finder _inViewer(Finder matching) =>
    find.descendant(of: find.byType(LogViewerPanel), matching: matching);

Finder _card(String id) => find.byWidgetPredicate(
  (Widget widget) => widget is CompactLogCard && widget.entry.id == id,
);

Finder _inCard(String id, Finder matching) =>
    find.descendant(of: _card(id), matching: matching);

void _pressBySemantics(WidgetTester tester, Finder finder) {
  final SemanticsNode node = tester.getSemantics(finder);
  node.owner!.performAction(node.id, SemanticsAction.tap);
}

void main() {
  testWidgets('full screen keeps the position', (WidgetTester tester) async {
    final _Players players = await _openDay(tester, entries: <Entry>[_voice()]);
    await tester.tap(_inCard('voice-1', find.byKey(compactLogPlayKey)));
    await tester.pumpAndSettle();
    expect(players.voice, hasLength(1));
    final _TrackingAudioPlayer pane = players.voice.single;
    expect(pane.state, AudioPlaybackState.playing);
    pane.emitPosition(const Duration(seconds: 19));
    await tester.pump();
    expect(_inPane(find.textContaining('0:19')), findsOneWidget);

    await tester.tap(_inPane(find.byKey(dayMediaPaneFullScreenKey)));
    for (int step = 0; step < 5; step++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(find.byType(LogViewerPanel), findsOneWidget);
    expect(_inViewer(find.byType(VoicePlayerView)), findsOneWidget);
    expect(players.voice, hasLength(2));
    final _TrackingAudioPlayer viewer = players.voice.last;
    expect(viewer.seekCalls, <Duration>[const Duration(seconds: 19)]);
    expect(viewer.playCalls, 1);
    expect(viewer.state, AudioPlaybackState.playing);
    expect(_inViewer(find.textContaining('0:19')), findsOneWidget);
    expect(pane.pauseCalls, 1);
    expect(pane.state, AudioPlaybackState.paused);
  }, variant: _mac);

  testWidgets('leaving full screen keeps the selection', (
    WidgetTester tester,
  ) async {
    final _Players players = await _openDay(
      tester,
      entries: <Entry>[_note(), _voice()],
    );
    await tester.tap(
      _inCard('voice-1', find.text('9:12 AM · morning · voice')),
    );
    await tester.pumpAndSettle();
    expect(_inPane(find.byType(VoicePlayerView)), findsOneWidget);

    await tester.tap(_inPane(find.byKey(dayMediaPaneFullScreenKey)));
    await tester.pumpAndSettle();
    expect(find.byType(LogViewerPanel), findsOneWidget);
    expect(players.voice, hasLength(2));
    players.voice.last.emitPosition(const Duration(seconds: 42));
    await tester.pump();

    await tester.tap(_inViewer(find.byKey(logViewerBackKey)));
    await tester.pumpAndSettle();

    expect(find.byType(LogViewerPanel), findsNothing);
    expect(find.byKey(dayDetailPanelKey), findsOneWidget);
    expect(_inPane(find.byType(VoicePlayerView)), findsOneWidget);
    expect(
      tester
          .widget<VoicePlayerView>(_inPane(find.byType(VoicePlayerView)))
          .scene
          .entry
          .id,
      'voice-1',
    );
    expect(_inPane(find.text('Morning voice log')), findsOneWidget);
    final _TrackingAudioPlayer resumed = players.voice.last;
    expect(resumed.seekCalls, <Duration>[const Duration(seconds: 42)]);
    expect(resumed.playCalls, 0);
    expect(_inPane(find.textContaining('0:42')), findsOneWidget);
  }, variant: _mac);

  testWidgets(
    'full screen after a late paused report leaves one player playing',
    (WidgetTester tester) async {
      final _Players players = await _openDay(
        tester,
        entries: <Entry>[_voice()],
      );
      await tester.tap(_inCard('voice-1', find.byKey(compactLogPlayKey)));
      await tester.pumpAndSettle();
      final _TrackingAudioPlayer pane = players.voice.single;
      pane.emitState(AudioPlaybackState.paused);
      pane.emitState(AudioPlaybackState.playing);
      await tester.pump();

      await tester.tap(_inPane(find.byKey(dayMediaPaneFullScreenKey)));
      await tester.pumpAndSettle();

      expect(players.voice, hasLength(2));
      expect(pane.pauseCalls, 1);
      expect(pane.state, AudioPlaybackState.paused);
      expect(players.voice.last.state, AudioPlaybackState.playing);
    },
    variant: _mac,
  );

  testWidgets('screen readers can press the card play and full screen', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    final _Players players = await _openDay(tester, entries: <Entry>[_voice()]);
    final Finder play = _inCard('voice-1', find.byKey(compactLogPlayKey));
    expect(
      tester
          .getSemantics(play)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );

    _pressBySemantics(tester, play);
    await tester.pumpAndSettle();
    expect(players.voice, hasLength(1));
    expect(players.voice.single.playCalls, 1);

    final Finder fullScreen = _inPane(find.byKey(dayMediaPaneFullScreenKey));
    expect(
      tester
          .getSemantics(fullScreen)
          .getSemanticsData()
          .hasAction(SemanticsAction.tap),
      isTrue,
    );
    _pressBySemantics(tester, fullScreen);
    await tester.pumpAndSettle();
    expect(find.byType(LogViewerPanel), findsOneWidget);
    semantics.dispose();
  }, variant: _mac);

  testWidgets('card play on the open log keeps its place', (
    WidgetTester tester,
  ) async {
    final _Players players = await _openDay(tester, entries: <Entry>[_voice()]);
    final Finder play = _inCard('voice-1', find.byKey(compactLogPlayKey));
    await tester.tap(play);
    await tester.pumpAndSettle();
    final _TrackingAudioPlayer pane = players.voice.single;
    pane.emitPosition(const Duration(seconds: 30));
    await tester.pump();

    await tester.tap(play);
    await tester.pumpAndSettle();
    expect(players.voice, hasLength(1));
    expect(pane.pauseCalls, 0);
    expect(pane.state, AudioPlaybackState.playing);

    await pane.pause();
    await tester.pump();
    await tester.tap(play);
    await tester.pumpAndSettle();

    final _TrackingAudioPlayer resumed = players.voice.last;
    expect(resumed.state, AudioPlaybackState.playing);
    expect(resumed.seekCalls, contains(const Duration(seconds: 30)));
    expect(_inPane(find.textContaining('0:30')), findsOneWidget);
  }, variant: _mac);
}
