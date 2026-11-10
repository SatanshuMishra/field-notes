import 'dart:io';

import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/cards/note_body.dart';
import 'package:field_notes/features/entry_cards/cards/video_body.dart';
import 'package:field_notes/features/entry_cards/cards/video_controls_overlay.dart';
import 'package:field_notes/features/entry_cards/cards/voice_body.dart';
import 'package:field_notes/features/entry_cards/compact/compact_log_card.dart';
import 'package:field_notes/features/entry_cards/compact/log_actions_pill.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/video_playback.dart';
import 'package:field_notes/features/entry_cards/playback/video_slots.dart';
import 'package:field_notes/features/entry_cards/playback/video_slots_provider.dart';
import 'package:field_notes/features/entry_cards/transport/transport.dart';
import 'package:field_notes/features/entry_cards/transport/transport_bar.dart'
    show
        transportBack10Key,
        transportForward10Key,
        transportMuteKey,
        transportSpeedKey,
        transportVolumeKey;
import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteReaderView;
import 'package:field_notes/features/today/today_providers.dart';
import 'package:field_notes/state/state.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../day_detail/support/day_detail_harness.dart'
    show FakeJournalRepository;
import '../support/entry_cards_harness.dart' show FakeMediaResolver, blobOf;
import '../support/fake_audio_player.dart';
import '../support/fake_video_player.dart';
import '../support/video_card_harness.dart'
    show videoFixtureFile, videoResolverFor;

const String _longNote =
    'The peonies finally opened along the back fence. I stood there with my '
    'coffee for a long while and watched the bees work the blooms until the '
    'sun came over the shed and the whole garden went gold and quiet again. '
    'Nothing else needed doing that day.';

final TargetPlatformVariant _mac = TargetPlatformVariant.only(
  TargetPlatform.macOS,
);

Entry _entry({
  required EntryType type,
  String id = 'e1',
  String? title,
  String? textContent,
  String? mediaId,
  String? thumbnailMediaId,
  int? durationMs,
}) {
  final int at = DateTime(2025, 7, 2, 21, 20).millisecondsSinceEpoch;
  return Entry(
    id: id,
    dayId: 'd1',
    type: type,
    title: title,
    textContent: textContent,
    mediaId: mediaId,
    thumbnailMediaId: thumbnailMediaId,
    durationMs: durationMs,
    createdAt: at,
    updatedAt: at,
  );
}

Entry _video({String? title}) => _entry(
  type: EntryType.video,
  title: title,
  mediaId: 'vid',
  thumbnailMediaId: 'thumb',
  durationMs: 80000,
);

final class _Card {
  _Card({required this.repository, required this.players});

  final FakeJournalRepository repository;
  final List<FakeEntryVideoPlayer> players;
  int opens = 0;
  int edits = 0;
  int deletes = 0;
}

Future<_Card> _pump(
  WidgetTester tester,
  Entry entry, {
  CompactLogDensity density = CompactLogDensity.feed,
  MediaResolver? resolver,
  double textScale = 1,
  EntryAudioPlayerFactoryOverride? audio,
}) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final VideoSlots slots = LruVideoSlots(cap: 2);
  addTearDown(slots.dispose);
  final _Card card = _Card(
    repository: FakeJournalRepository(entries: <Entry>[entry]),
    players: <FakeEntryVideoPlayer>[],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        journalRepositoryProvider.overrideWithValue(card.repository),
        todayVideoPlayerFactoryProvider.overrideWithValue(() {
          final FakeEntryVideoPlayer player = FakeEntryVideoPlayer();
          card.players.add(player);
          return player;
        }),
        videoSlotsProvider.overrideWithValue(slots),
      ],
      child: MaterialApp(
        home: Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: ListView(
                padding: const EdgeInsets.all(24),
                children: <Widget>[
                  CompactLogCard(
                    entry: entry,
                    resolver: resolver ?? FakeMediaResolver(),
                    density: density,
                    audioPlayerFactory: audio,
                    onOpen: () => card.opens++,
                    onEdit: entry.type == EntryType.text
                        ? () => card.edits++
                        : null,
                    onDelete: () => card.deletes++,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return card;
}

typedef EntryAudioPlayerFactoryOverride = FakeEntryAudioPlayer Function();

Future<void> _settleVideo(WidgetTester tester) async {
  for (int frame = 0; frame < 8; frame += 1) {
    await tester.pump();
  }
}

Future<FakeEntryVideoPlayer> _startVideo(
  WidgetTester tester,
  _Card card,
) async {
  await tester.tap(find.byKey(compactLogPosterKey));
  await _settleVideo(tester);
  final FakeEntryVideoPlayer player = card.players.single;
  player.emitState(VideoPlaybackState.playing);
  await _settleVideo(tester);
  return player;
}

Future<TestGesture> _mouseAt(WidgetTester tester, Offset start) async {
  final TestGesture mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
  );
  await mouse.addPointer(location: start);
  addTearDown(mouse.removePointer);
  return mouse;
}

Future<void> _hoverTo(
  WidgetTester tester,
  TestGesture mouse,
  Offset target,
) async {
  await mouse.moveTo(target);
  await tester.pump();
  await tester.pump();
}

bool _highlighted(WidgetTester tester) =>
    tester.widget<LogCardHighlight>(find.byType(LogCardHighlight)).active;

List<BoxShadow>? _shadow(WidgetTester tester) =>
    tester.widget<StickerCard>(find.byType(StickerCard)).shadow;

double _tilt(WidgetTester tester) =>
    tester.widget<StickerCard>(find.byType(StickerCard)).rotationDegrees;

Future<void> _chooseRename(WidgetTester tester) async {
  await tester.tap(find.byKey(logActionsMoreKey));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(logActionsRenameKey));
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

String _titleFieldText(WidgetTester tester) => tester
    .widget<TextField>(find.byKey(compactLogTitleFieldKey))
    .controller!
    .text;

LogicalKeyboardKey _keyTyping(String character) => character == ' '
    ? LogicalKeyboardKey.space
    : LogicalKeyboardKey.findKeyByKeyId(character.toLowerCase().codeUnitAt(0))!;

Future<void> _typeIntoTitleField(WidgetTester tester, String text) async {
  await tester.showKeyboard(find.byKey(compactLogTitleFieldKey));
  for (final String character in text.split('')) {
    final bool keptByApp = await tester.sendKeyEvent(
      _keyTyping(character),
      character: character,
    );
    if (!keptByApp) {
      final TextEditingValue typed = tester
          .widget<TextField>(find.byKey(compactLogTitleFieldKey))
          .controller!
          .value;
      tester.testTextInput.updateEditingValue(
        typed.replaced(typed.selection, character),
      );
    }
    await tester.pump();
  }
}

Future<void> _pressEnterInTitleField(WidgetTester tester) async {
  final bool keptByApp = await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  if (!keptByApp) {
    await tester.testTextInput.receiveAction(TextInputAction.done);
  }
  await tester.pump();
}

File _videoFile() => videoFixtureFile(prefix: 'log_card_rules');

final Map<Key, String> _namedControls = <Key, String>{
  logActionsOpenKey: 'Open',
  logActionsMoreKey: 'More',
  voicePlayToggleKey: 'Play',
  transportBack10Key: 'Back',
  transportForward10Key: 'Forward',
  transportMuteKey: 'Mute',
  transportVolumeKey: 'Volume',
  transportSpeedKey: 'Speed',
};

String _focusedControl() {
  final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
  if (focused is! Element) {
    return 'none';
  }
  final Finder holder = find.byElementPredicate(
    (Element element) => identical(element, focused),
  );
  final List<String> touching = <String>[
    for (final MapEntry<Key, String> control in _namedControls.entries)
      if (find
              .descendant(of: holder, matching: find.byKey(control.key))
              .evaluate()
              .isNotEmpty ||
          find
              .ancestor(of: holder, matching: find.byKey(control.key))
              .evaluate()
              .isNotEmpty)
        control.value,
  ];
  return switch (touching.length) {
    0 => 'other',
    1 => touching.single,
    _ => 'card',
  };
}

void _useKeyboardHighlight() {
  final FocusHighlightStrategy previous =
      FocusManager.instance.highlightStrategy;
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => FocusManager.instance.highlightStrategy = previous);
}

void main() {
  group('an honest title', () {
    testWidgets('a video without a title invents none', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _video());

      expect(find.byKey(compactLogTitleKey), findsNothing);
      expect(find.textContaining('A video from'), findsNothing);
    });

    testWidgets('a voice log without a title invents none', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _entry(type: EntryType.voice, mediaId: 'aud', durationMs: 4000),
        audio: FakeEntryAudioPlayer.new,
      );

      expect(find.byKey(compactLogTitleKey), findsNothing);
      expect(find.byType(VoiceBody), findsOneWidget);
    });

    testWidgets('a note without a heading styles nothing as a heading', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _entry(type: EntryType.text, textContent: _longNote));

      expect(find.byKey(compactLogTitleKey), findsNothing);
      final Text snippet = tester.widget<Text>(
        find.textContaining('The peonies finally opened'),
      );
      expect(snippet.style?.fontSize, 13);
      expect(snippet.style?.fontWeight, FontWeight.w400);
    });

    testWidgets('a long note with a real heading shows it as the title', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _entry(type: EntryType.text, textContent: '# Peonies\n\n$_longNote'),
      );

      expect(
        tester.widget<Text>(find.byKey(compactLogTitleKey)).data,
        'Peonies',
      );
      expect(find.textContaining('# Peonies'), findsNothing);
    });

    testWidgets('a short note with a heading renders it once, in the note', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _entry(type: EntryType.text, textContent: '# Peonies\n\nThey opened.'),
      );

      expect(find.byKey(compactLogTitleKey), findsNothing);
      expect(find.byType(NoteReaderView), findsOneWidget);
    });

    testWidgets('a titled log of every type shows its title', (
      WidgetTester tester,
    ) async {
      for (final Entry entry in <Entry>[
        _entry(type: EntryType.text, title: 'Named', textContent: 'Short.'),
        _entry(type: EntryType.text, title: 'Named', textContent: _longNote),
        _video(title: 'Named'),
        _entry(type: EntryType.voice, title: 'Named', mediaId: 'aud'),
      ]) {
        await _pump(tester, entry, audio: FakeEntryAudioPlayer.new);

        expect(
          tester.widget<Text>(find.byKey(compactLogTitleKey)).data,
          'Named',
          reason: '${entry.type}',
        );
      }
    });
  });

  group('every region does its own job', () {
    testWidgets('the body and the Open icon open the same full view', (
      WidgetTester tester,
    ) async {
      final _Card card = await _pump(
        tester,
        _entry(type: EntryType.text, textContent: _longNote),
      );

      await tester.tap(find.textContaining('The peonies finally opened'));
      await tester.pump(const Duration(milliseconds: 400));
      expect(card.opens, 1);

      await tester.tap(find.byKey(logActionsOpenKey));
      await tester.pump(const Duration(milliseconds: 400));
      expect(card.opens, 2);
    }, variant: _mac);

    testWidgets('More opens the menu and never the log', (
      WidgetTester tester,
    ) async {
      final _Card card = await _pump(
        tester,
        _entry(type: EntryType.text, textContent: _longNote),
      );

      await tester.tap(find.byKey(logActionsMoreKey));
      await tester.pumpAndSettle();

      expect(find.byKey(logActionsMenuKey), findsOneWidget);
      expect(find.text(logActionsAddTitleLabel), findsOneWidget);
      expect(find.text(logActionsEditLabel), findsOneWidget);
      expect(find.text(logMenuDeleteLabel), findsOneWidget);
      expect(card.opens, 0);

      await tester.tap(find.byKey(logActionsDeleteKey));
      await tester.pumpAndSettle();
      expect(card.deletes, 1);
      expect(card.opens, 0);
    }, variant: _mac);

    testWidgets('a voice or video log has no Edit note in its menu', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _video());

      await tester.tap(find.byKey(logActionsMoreKey));
      await tester.pumpAndSettle();

      expect(find.text(logActionsEditLabel), findsNothing);
      expect(find.text(logMenuDeleteLabel), findsOneWidget);
    }, variant: _mac);

    testWidgets('the poster plays and pauses and never opens', (
      WidgetTester tester,
    ) async {
      final _Card card = await _pump(
        tester,
        _video(),
        resolver: videoResolverFor(_videoFile()),
      );
      expect(find.byType(VideoBody), findsNothing);

      final FakeEntryVideoPlayer player = await _startVideo(tester, card);
      expect(find.byType(VideoBody), findsOneWidget);
      expect(player.playCalls, 1);
      expect(card.opens, 0);

      await tester.tap(
        find.byWidgetPredicate(
          (Widget widget) => widget is VideoControlsOverlay,
        ),
      );
      await _settleVideo(tester);
      expect(player.pauseCalls, 1);
      expect(card.opens, 0);
    }, variant: _mac);

    testWidgets('the Transport play control plays and never opens', (
      WidgetTester tester,
    ) async {
      final _Card card = await _pump(
        tester,
        _video(),
        resolver: videoResolverFor(_videoFile()),
      );

      await tester.tap(find.byKey(compactLogVideoPlayKey));
      await _settleVideo(tester);

      expect(card.players.single.playCalls, 1);
      expect(card.opens, 0);
    }, variant: _mac);

    testWidgets('the timeline scrubs a loaded video and never opens', (
      WidgetTester tester,
    ) async {
      final _Card card = await _pump(
        tester,
        _video(),
        resolver: videoResolverFor(_videoFile()),
      );
      final FakeEntryVideoPlayer player = await _startVideo(tester, card);

      await tester.tap(find.byKey(transportVideoTimelineKey));
      await _settleVideo(tester);

      expect(player.seekCalls, hasLength(1));
      final Duration target = player.seekCalls.single;
      expect(target.inSeconds, inInclusiveRange(38, 42));
      expect(card.opens, 0);
    }, variant: _mac);

    testWidgets('a scrub on an unstarted video starts it at that place', (
      WidgetTester tester,
    ) async {
      final _Card card = await _pump(
        tester,
        _video(),
        resolver: videoResolverFor(_videoFile()),
      );

      await tester.tap(find.byKey(transportVideoTimelineKey));
      await _settleVideo(tester);

      final FakeEntryVideoPlayer player = card.players.single;
      expect(player.playCalls, 1);
      expect(player.seekCalls, hasLength(1));
      expect(player.seekCalls.single.inSeconds, inInclusiveRange(38, 42));
      expect(card.opens, 0);
    }, variant: _mac);

    testWidgets('empty space inside the player opens nothing', (
      WidgetTester tester,
    ) async {
      final _Card card = await _pump(
        tester,
        _video(),
        resolver: videoResolverFor(_videoFile()),
      );
      final Rect poster = tester.getRect(find.byKey(compactLogThumbnailKey));
      final Rect transport = tester.getRect(find.byType(Transport));

      await tester.tapAt(
        Offset((poster.right + transport.left) / 2, poster.center.dy),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(card.opens, 0);
      expect(card.players, isEmpty);
    }, variant: _mac);

    testWidgets('a long press on the player does nothing to the card', (
      WidgetTester tester,
    ) async {
      final _Card card = await _pump(
        tester,
        _video(),
        resolver: videoResolverFor(_videoFile()),
      );

      await tester.longPress(find.byKey(compactLogPosterKey));
      await tester.pumpAndSettle();

      expect(find.byKey(logActionsMenuKey), findsNothing);
      expect(card.opens, 0);
    }, variant: _mac);

    testWidgets('a voice card uses the shared Transport and never opens', (
      WidgetTester tester,
    ) async {
      final FakeEntryAudioPlayer audio = FakeEntryAudioPlayer();
      final _Card card = await _pump(
        tester,
        _entry(type: EntryType.voice, mediaId: 'aud', durationMs: 4000),
        audio: () => audio,
        resolver: FakeMediaResolver()
          ..set(
            'aud',
            ResolvedMedia.available(
              blob: blobOf(id: 'aud', relPath: 'a.m4a', kind: MediaKind.audio),
              file: File('/tmp/a.m4a'),
            ),
          ),
      );

      expect(find.byType(Transport), findsOneWidget);
      await tester.tap(find.byKey(voicePlayToggleKey));
      await tester.pump();

      expect(audio.playCalls, 1);
      expect(card.opens, 0);
    }, variant: _mac);

    testWidgets('Tab visits every control in order and leaves the card', (
      WidgetTester tester,
    ) async {
      final FakeEntryAudioPlayer audio = FakeEntryAudioPlayer();
      await _pump(
        tester,
        _entry(type: EntryType.voice, mediaId: 'aud', durationMs: 4000),
        audio: () => audio,
        resolver: FakeMediaResolver()
          ..set(
            'aud',
            ResolvedMedia.available(
              blob: blobOf(id: 'aud', relPath: 'a.m4a', kind: MediaKind.audio),
              file: File('/tmp/a.m4a'),
            ),
          ),
      );

      _useKeyboardHighlight();

      final List<String> walk = <String>[];
      for (int press = 0; press < 12; press += 1) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump(const Duration(milliseconds: 400));
        walk.add(_focusedControl());
      }

      expect(walk.take(10), <String>[
        'card',
        'Open',
        'More',
        'other',
        'Play',
        'Back',
        'Forward',
        'Mute',
        'Volume',
        'Speed',
      ]);
      expect(walk[10], 'card');
    }, variant: _mac);
  });

  group('hover', () {
    testWidgets('hovering the player clears the card highlight', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _video());
      final List<BoxShadow>? rest = _shadow(tester);
      final Offset body = tester.getCenter(find.textContaining('night'));
      final Offset player = tester.getCenter(find.byType(Transport));
      final TestGesture mouse = await _mouseAt(tester, const Offset(1, 1));

      await _hoverTo(tester, mouse, body);
      expect(_highlighted(tester), isTrue);
      expect(_shadow(tester), isNot(equals(rest)));

      await _hoverTo(tester, mouse, player);
      expect(_highlighted(tester), isFalse);
      expect(_shadow(tester), equals(rest));

      await _hoverTo(tester, mouse, body);
      expect(_highlighted(tester), isTrue);
    }, variant: _mac);

    testWidgets('hovering the card actions clears the card highlight', (
      WidgetTester tester,
    ) async {
      await _pump(tester, _entry(type: EntryType.text, textContent: _longNote));
      final TestGesture mouse = await _mouseAt(tester, const Offset(1, 1));

      await _hoverTo(
        tester,
        mouse,
        tester.getCenter(find.textContaining('The peonies')),
      );
      expect(_highlighted(tester), isTrue);

      await _hoverTo(
        tester,
        mouse,
        tester.getCenter(find.byKey(logActionsMoreKey)),
      );
      expect(_highlighted(tester), isFalse);
    }, variant: _mac);
  });

  group('rename', () {
    testWidgets('a title typed with Space and Enter saves and never opens', (
      WidgetTester tester,
    ) async {
      final _Card card = await _pump(tester, _video());

      await _chooseRename(tester);
      await _typeIntoTitleField(tester, ' The pier ');

      expect(card.opens, 0);
      expect(_titleFieldText(tester), ' The pier ');

      await _pressEnterInTitleField(tester);

      expect(card.opens, 0);
      expect(card.repository.titleUpdates.single.id, 'e1');
      expect(card.repository.titleUpdates.single.title, 'The pier');
      expect(find.byKey(compactLogTitleFieldKey), findsNothing);
      expect(
        tester.widget<Text>(find.byKey(compactLogTitleKey)).data,
        'The pier',
      );
    }, variant: _mac);

    testWidgets('an existing title starts in the field and can be cleared', (
      WidgetTester tester,
    ) async {
      final _Card card = await _pump(tester, _video(title: 'Old name'));

      await tester.tap(find.byKey(logActionsMoreKey));
      await tester.pumpAndSettle();
      expect(find.text(logActionsRenameLabel), findsOneWidget);
      await tester.tap(find.byKey(logActionsRenameKey));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final TextField field = tester.widget<TextField>(
        find.byKey(compactLogTitleFieldKey),
      );
      expect(field.controller!.text, 'Old name');
      await tester.enterText(find.byKey(compactLogTitleFieldKey), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(card.repository.titleUpdates.single.title, isNull);
      expect(find.byKey(compactLogTitleKey), findsNothing);
    });

    testWidgets('an unchanged title writes nothing', (
      WidgetTester tester,
    ) async {
      final _Card card = await _pump(tester, _video(title: 'Old name'));

      await _chooseRename(tester);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(card.repository.titleUpdates, isEmpty);
      expect(find.byKey(compactLogTitleFieldKey), findsNothing);
    });

    testWidgets('Escape cancels the rename without a write', (
      WidgetTester tester,
    ) async {
      final _Card card = await _pump(tester, _video());

      await _chooseRename(tester);
      await tester.enterText(find.byKey(compactLogTitleFieldKey), 'Nope');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();

      expect(card.repository.titleUpdates, isEmpty);
      expect(find.byKey(compactLogTitleFieldKey), findsNothing);
      expect(find.byKey(compactLogTitleKey), findsNothing);
    });

    testWidgets('clicking inside the field does not open the log', (
      WidgetTester tester,
    ) async {
      final _Card card = await _pump(tester, _video());

      await _chooseRename(tester);
      await tester.tap(find.byKey(compactLogTitleFieldKey));
      await tester.pump(const Duration(milliseconds: 400));

      expect(card.opens, 0);
      expect(find.byKey(compactLogTitleFieldKey), findsOneWidget);
    });

    testWidgets('a failed save puts the title back and says so', (
      WidgetTester tester,
    ) async {
      final _Card card = await _pump(tester, _video());
      card.repository.updateError = StateError('disk full');

      await _chooseRename(tester);
      await tester.enterText(find.byKey(compactLogTitleFieldKey), 'The pier');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      await tester.pump();

      expect(find.byKey(compactLogTitleKey), findsNothing);
      expect(find.text(compactLogRenameFailedMessage), findsOneWidget);
      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
    });

    testWidgets('a card outside the app scope offers no rename', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              children: <Widget>[
                CompactLogCard(
                  entry: _video(),
                  resolver: FakeMediaResolver(),
                  density: CompactLogDensity.feed,
                  onOpen: () {},
                  onDelete: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(logActionsMoreKey));
      await tester.pumpAndSettle();

      expect(find.byKey(logActionsRenameKey), findsNothing);
      expect(find.byKey(logActionsDeleteKey), findsOneWidget);
    });
  });

  group('tilt', () {
    testWidgets('Today cards keep their tilt by id', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _entry(type: EntryType.text, id: 'a', textContent: 'Tide.'),
      );
      expect(_tilt(tester), -0.5);

      await _pump(
        tester,
        _entry(type: EntryType.text, id: 'b', textContent: 'Moon.'),
      );
      expect(_tilt(tester), 0.4);
    });

    testWidgets('day sheet cards stay straight', (WidgetTester tester) async {
      await _pump(
        tester,
        _entry(type: EntryType.text, id: 'a', textContent: 'Tide.'),
        density: CompactLogDensity.day,
      );

      expect(_tilt(tester), 0);
      expect(find.byType(NoteBody), findsOneWidget);
    });

    testWidgets('enlarged text straightens the card', (
      WidgetTester tester,
    ) async {
      await _pump(
        tester,
        _entry(type: EntryType.text, id: 'a', textContent: 'Tide.'),
        textScale: 1.4,
      );

      expect(_tilt(tester), 0);
    });
  });
}
