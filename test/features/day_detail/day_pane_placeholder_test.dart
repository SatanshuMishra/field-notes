import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/day_detail/day_detail.dart';
import 'package:field_notes/features/day_detail/day_note_pane.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
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

const Size _window = Size(1280, 800);
const String _date = '2026-07-19';
const String _openDayLabel = 'open day';
const String _voiceMedia = 'blob-voice';

final TargetPlatformVariant _mac = TargetPlatformVariant.only(
  TargetPlatform.macOS,
);

List<Entry> _oneVoiceLog() {
  return <Entry>[
    Entry(
      id: 'voice-1',
      dayId: 'day-1',
      type: EntryType.voice,
      mediaId: _voiceMedia,
      durationMs: 65000,
      createdAt: DateTime(2026, 7, 19, 7, 12).millisecondsSinceEpoch,
      updatedAt: 0,
    ),
  ];
}

FakeNoteMediaResolver _resolver() {
  final Directory folder = Directory.systemTemp.createTempSync(
    'day-pane-placeholder',
  );
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

Rect _rightColumn(WidgetTester tester) =>
    tester.getRect(find.byKey(dayNotePaneKey));

Rect _placeholderColumnHolding(WidgetTester tester, String line) {
  final Finder text = find.descendant(
    of: find.byKey(dayNotePaneKey),
    matching: find.text(line),
  );
  expect(text, findsOneWidget);
  final RenderFlex column = tester.renderObject<RenderFlex>(
    find.ancestor(of: text, matching: find.byType(Column)).first,
  );
  final List<Rect> children = <Rect>[];
  RenderBox? child = column.firstChild;
  while (child != null) {
    final Offset topLeft = child.localToGlobal(Offset.zero);
    children.add(topLeft & child.size);
    child = column.childAfter(child);
  }
  return children.reduce((Rect a, Rect b) => a.expandToInclude(b));
}

void main() {
  testWidgets('the prompt sits in the middle', (WidgetTester tester) async {
    await _openDay(tester, entries: _oneVoiceLog(), mood: Mood.calm);

    expect(
      find.descendant(
        of: find.byKey(dayNotePaneKey),
        matching: find.text('Logs open on this side.'),
      ),
      findsOneWidget,
    );
    final Rect pane = _rightColumn(tester);
    final Rect placeholder = _placeholderColumnHolding(
      tester,
      'Choose a log to read it here.',
    );
    expect(placeholder.center.dy, closeTo(pane.center.dy, 2));
    expect(placeholder.center.dx, closeTo(pane.center.dx, 2));
  }, variant: _mac);

  testWidgets('the empty day sits in the middle', (WidgetTester tester) async {
    await _openDay(tester, entries: const <Entry>[]);

    final Rect pane = _rightColumn(tester);
    final Rect placeholder = _placeholderColumnHolding(
      tester,
      'Nothing logged this day yet.',
    );
    expect(placeholder.center.dy, closeTo(pane.center.dy, 2));
    expect(placeholder.center.dx, closeTo(pane.center.dx, 2));
  }, variant: _mac);
}
