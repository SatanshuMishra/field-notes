import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/day_detail.dart';
import 'package:field_notes/features/day_detail/day_media_pane.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
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

const Size _desktop = Size(1440, 900);
const Size _phone = Size(384, 832);
const String _openDayLabel = 'open day';
const String _voiceMedia = 'blob-voice';

final TargetPlatformVariant _mac = TargetPlatformVariant.only(
  TargetPlatform.macOS,
);

final class _Players {
  final List<FakeEntryAudioPlayer> voice = <FakeEntryAudioPlayer>[];

  FakeEntryAudioPlayer newVoice() {
    final FakeEntryAudioPlayer player = FakeEntryAudioPlayer();
    voice.add(player);
    return player;
  }

  FakeEntryVideoPlayer newVideo() => FakeEntryVideoPlayer();
}

class _DaysRepository extends FakeJournalRepository {
  _DaysRepository(this.byDate);

  final Map<String, List<Entry>> byDate;

  @override
  Stream<List<Entry>> watchEntriesForDate(String date) async* {
    yield List<Entry>.unmodifiable(byDate[date] ?? const <Entry>[]);
  }
}

Entry _note(String id, DateTime at, String text) {
  return Entry(
    id: id,
    dayId: 'day-$id',
    type: EntryType.text,
    textContent: text,
    createdAt: at.millisecondsSinceEpoch,
    updatedAt: 0,
  );
}

Entry _voice(String id, DateTime at) {
  return Entry(
    id: id,
    dayId: 'day-$id',
    type: EntryType.voice,
    mediaId: _voiceMedia,
    durationMs: 65000,
    peaks: const <double>[0.2, 0.6, 0.9, 0.4, 0.7, 0.3],
    createdAt: at.millisecondsSinceEpoch,
    updatedAt: 0,
  );
}

FakeNoteMediaResolver _resolver() {
  final Directory folder = Directory.systemTemp.createTempSync('day-arrows');
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
  const _Launcher({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showDayDetail(context, date: date),
        child: const Text(_openDayLabel),
      ),
    );
  }
}

Future<_Players> _openDay(
  WidgetTester tester, {
  required String date,
  required DateTime today,
  required Map<String, List<Entry>> days,
  TargetPlatform platform = TargetPlatform.macOS,
}) async {
  final bool phone = platform == TargetPlatform.android;
  tester.view.physicalSize = phone ? _phone : _desktop;
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
        journalRepositoryProvider.overrideWithValue(_DaysRepository(days)),
        draftStoreProvider.overrideWith((Ref ref) => FakeDraftStore()),
        mediaStoreProvider.overrideWith(
          (Ref ref) async => FakeMediaStore(Directory.systemTemp),
        ),
        dayDetailMediaResolverProvider.overrideWith((Ref ref) => resolver),
        notesMediaResolverProvider.overrideWith((Ref ref) async => resolver),
        todayAudioPlayerFactoryProvider.overrideWithValue(players.newVoice),
        todayVideoPlayerFactoryProvider.overrideWithValue(players.newVideo),
        videoSlotsProvider.overrideWithValue(slots),
        todayClockProvider.overrideWithValue(() => today),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: platform),
        home: Scaffold(body: _Launcher(date: date)),
      ),
    ),
  );
  await tester.tap(find.text(_openDayLabel));
  await tester.pumpAndSettle();
  return players;
}

Finder _panel() => find.byKey(dayDetailPanelKey);

Finder _inPanel(Finder matching) =>
    find.descendant(of: _panel(), matching: matching);

Finder _card(String id) => find.byWidgetPredicate(
  (Widget widget) => widget is CompactLogCard && widget.entry.id == id,
);

Finder _inCard(String id, Finder matching) =>
    find.descendant(of: _card(id), matching: matching);

Future<void> _tapEarlier(WidgetTester tester) async {
  await tester.tap(_inPanel(find.byTooltip('Earlier day')));
  await tester.pumpAndSettle();
}

Future<void> _tapLater(WidgetTester tester) async {
  await tester.tap(_inPanel(find.byTooltip('Later day')));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('earlier moves back one day', (WidgetTester tester) async {
    await _openDay(
      tester,
      date: '2026-10-15',
      today: DateTime(2026, 10, 17, 9),
      days: <String, List<Entry>>{
        '2026-10-15': <Entry>[
          _voice('voice-15', DateTime(2026, 10, 15, 9, 12)),
        ],
        '2026-10-14': <Entry>[
          _note('note-14', DateTime(2026, 10, 14, 8, 30), 'Raked the leaves.'),
        ],
      },
    );
    expect(_inPanel(find.text('Thursday, October 15')), findsOneWidget);

    await tester.tap(
      _inCard('voice-15', find.text('9:12 AM · morning · voice')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(dayMediaPaneKey), findsOneWidget);

    await _tapEarlier(tester);

    expect(_inPanel(find.text('Wednesday, October 14')), findsOneWidget);
    expect(_inPanel(find.text('Thursday, October 15')), findsNothing);
    expect(_card('note-14'), findsOneWidget);
    expect(_card('voice-15'), findsNothing);
    expect(find.byKey(dayMediaPaneKey), findsNothing);
    expect(
      _inPanel(find.text('Choose a log to read it here.')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('day-note-pane-note-14')),
      findsNothing,
    );
  }, variant: _mac);

  testWidgets('later stops at today', (WidgetTester tester) async {
    await _openDay(
      tester,
      date: '2026-10-16',
      today: DateTime(2026, 10, 17, 9),
      days: <String, List<Entry>>{
        '2026-10-16': <Entry>[
          _note('note-16', DateTime(2026, 10, 16, 8, 30), 'Picked apples.'),
        ],
      },
    );
    expect(_inPanel(find.text('Friday, October 16')), findsOneWidget);
    expect(
      tester.widget<DayDetailHeader>(find.byType(DayDetailHeader)).onLater,
      isNotNull,
    );

    await _tapLater(tester);

    expect(_panel(), findsOneWidget);
    expect(_inPanel(find.text('Saturday, October 17')), findsOneWidget);
    expect(_inPanel(find.text('today · in your garden')), findsOneWidget);
    expect(
      tester.widget<DayDetailHeader>(find.byType(DayDetailHeader)).onLater,
      isNull,
    );

    await _tapLater(tester);

    expect(_inPanel(find.text('Saturday, October 17')), findsOneWidget);
    expect(_inPanel(find.text('Sunday, October 18')), findsNothing);
  }, variant: _mac);

  testWidgets('changing day stops playback', (WidgetTester tester) async {
    final _Players players = await _openDay(
      tester,
      date: '2026-10-15',
      today: DateTime(2026, 10, 17, 9),
      days: <String, List<Entry>>{
        '2026-10-15': <Entry>[
          _voice('voice-15', DateTime(2026, 10, 15, 9, 12)),
        ],
      },
    );

    await tester.tap(_inCard('voice-15', find.byKey(compactLogPlayKey)));
    await tester.pumpAndSettle();
    expect(find.byType(VoicePlayerView), findsOneWidget);
    expect(players.voice, hasLength(1));
    expect(players.voice.single.playCalls, 1);
    expect(players.voice.single.disposeCalls, 0);

    await _tapEarlier(tester);

    expect(_inPanel(find.text('Wednesday, October 14')), findsOneWidget);
    expect(find.byType(VoicePlayerView), findsNothing);
    expect(find.byKey(dayMediaPaneKey), findsNothing);
    expect(players.voice, hasLength(1));
    expect(players.voice.single.disposeCalls, 1);
  }, variant: _mac);

  testWidgets('empty days are not skipped', (WidgetTester tester) async {
    await _openDay(
      tester,
      date: '2026-10-15',
      today: DateTime(2026, 10, 17, 9),
      days: <String, List<Entry>>{
        '2026-10-15': <Entry>[
          _note('note-15', DateTime(2026, 10, 15, 8, 30), 'Swept the porch.'),
        ],
        '2026-10-13': <Entry>[
          _note('note-13', DateTime(2026, 10, 13, 8, 30), 'Planted bulbs.'),
        ],
      },
    );

    await _tapEarlier(tester);

    expect(_inPanel(find.text('Wednesday, October 14')), findsOneWidget);
    expect(_inPanel(find.text('Tuesday, October 13')), findsNothing);
    expect(_inPanel(find.text('Nothing logged this day yet.')), findsOneWidget);
    expect(_card('note-13'), findsNothing);
    expect(_card('note-15'), findsNothing);
  }, variant: _mac);

  testWidgets('the android sheet steps days', (WidgetTester tester) async {
    await _openDay(
      tester,
      date: '2026-10-15',
      today: DateTime(2026, 10, 17, 9),
      platform: TargetPlatform.android,
      days: <String, List<Entry>>{
        '2026-10-15': <Entry>[
          _note('note-15', DateTime(2026, 10, 15, 8, 30), 'Swept the porch.'),
        ],
      },
    );
    final Finder sheet = find.byType(PhoneSheet);
    expect(sheet, findsOneWidget);
    expect(find.byType(DayDetailSheetHeader), findsOneWidget);
    expect(
      find.descendant(of: sheet, matching: find.text('Thursday, October 15')),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(DayDetailSheetHeader),
        matching: find.byTooltip('Earlier day'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(of: sheet, matching: find.text('Wednesday, October 14')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: sheet, matching: find.text('Thursday, October 15')),
      findsNothing,
    );
    expect(_card('note-15'), findsNothing);
  });

  testWidgets('arrow keys still step logs', (WidgetTester tester) async {
    await _openDay(
      tester,
      date: '2026-10-15',
      today: DateTime(2026, 10, 17, 9),
      days: <String, List<Entry>>{
        '2026-10-15': <Entry>[
          _note('note-a', DateTime(2026, 10, 15, 8, 30), 'Swept the porch.'),
          _note('note-b', DateTime(2026, 10, 15, 18, 30), 'Lit the stove.'),
        ],
        '2026-10-16': <Entry>[
          _note('note-16', DateTime(2026, 10, 16, 8, 30), 'Picked apples.'),
        ],
      },
    );

    await tester.tap(_inCard('note-a', find.text('8:30 AM · morning · note')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('day-note-pane-note-a')),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('day-note-pane-note-b')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('day-note-pane-note-a')),
      findsNothing,
    );
    expect(_inPanel(find.text('Thursday, October 15')), findsOneWidget);
    expect(_inPanel(find.text('Friday, October 16')), findsNothing);
    expect(_card('note-a'), findsOneWidget);
    expect(_card('note-16'), findsNothing);
  }, variant: _mac);
}
