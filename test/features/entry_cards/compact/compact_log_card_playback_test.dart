import 'dart:io';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/cards/voice_body.dart';
import 'package:field_notes/features/entry_cards/compact/compact_log_card.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/entry_cards_harness.dart';
import '../support/fake_audio_player.dart';

FakeMediaResolver _resolver() => FakeMediaResolver()
  ..set(
    'aud',
    ResolvedMedia.available(
      blob: blobOf(id: 'aud', relPath: 'a.m4a', kind: MediaKind.audio),
      file: File('/tmp/a.m4a'),
    ),
  );

Entry _voice(String id) {
  final int at = DateTime(2025, 7, 2, 8, 30).millisecondsSinceEpoch;
  return Entry(
    id: id,
    dayId: 'd1',
    type: EntryType.voice,
    mediaId: 'aud',
    durationMs: 65000,
    createdAt: at,
    updatedAt: at,
  );
}

Widget _app(List<Widget> cards) => MaterialApp(
  home: Scaffold(
    body: ListView(padding: const EdgeInsets.all(24), children: cards),
  ),
);

Finder _toggle() => find.descendant(
  of: find.byType(VoiceBody),
  matching: find.byKey(const ValueKey<String>('voice-play-toggle')),
);

void main() {
  testWidgets(
    'a day card voice log keeps playing when the pointer leaves the card',
    (WidgetTester tester) async {
      final FakeEntryAudioPlayer player = FakeEntryAudioPlayer();
      final FakeMediaResolver resolver = FakeMediaResolver()
        ..set(
          'aud',
          ResolvedMedia.available(
            blob: blobOf(id: 'aud', relPath: 'a.m4a', kind: MediaKind.audio),
            file: File('/tmp/a.m4a'),
          ),
        );
      final int at = DateTime(2025, 7, 2, 8, 30).millisecondsSinceEpoch;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(24),
              children: <Widget>[
                CompactLogCard(
                  entry: Entry(
                    id: 'e1',
                    dayId: 'd1',
                    type: EntryType.voice,
                    mediaId: 'aud',
                    durationMs: 65000,
                    createdAt: at,
                    updatedAt: at,
                  ),
                  resolver: resolver,
                  density: CompactLogDensity.day,
                  onOpen: () {},
                  onDelete: () {},
                  audioPlayerFactory: () => player,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      final Finder toggle = find.descendant(
        of: find.byType(VoiceBody),
        matching: find.byKey(const ValueKey<String>('voice-play-toggle')),
      );
      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(1, 1));
      addTearDown(mouse.removePointer);
      await mouse.moveTo(tester.getCenter(toggle));
      await tester.pump();
      await tester.pump();
      final State<StatefulWidget> before = tester.state(find.byType(VoiceBody));
      await mouse.down(tester.getCenter(toggle));
      await mouse.up();
      await tester.pump();
      expect(player.playCalls, 1);

      await mouse.moveTo(const Offset(1, 1));
      await tester.pump();

      expect(tester.state(find.byType(VoiceBody)), same(before));
      expect(player.pauseCalls, 0);
      expect(player.disposeCalls, 0);
    },
  );

  testWidgets(
    'a log started by touch keeps playing as the mouse comes and goes until the pop-up closes',
    (WidgetTester tester) async {
      final List<FakeEntryAudioPlayer> players = <FakeEntryAudioPlayer>[];
      await tester.pumpWidget(
        _app(<Widget>[
          CompactLogCard(
            entry: _voice('e1'),
            resolver: _resolver(),
            density: CompactLogDensity.day,
            onOpen: () {},
            onDelete: () {},
            audioPlayerFactory: () {
              final FakeEntryAudioPlayer made = FakeEntryAudioPlayer();
              players.add(made);
              return made;
            },
          ),
        ]),
      );
      await tester.pump();
      final double restingTop = tester.getTopLeft(find.byType(VoiceBody)).dy;
      final State<StatefulWidget> before = tester.state(find.byType(VoiceBody));

      await tester.tap(_toggle());
      await tester.pump();
      expect(players.length, 1);
      expect(players.first.playCalls, 1);

      void expectStillPlaying(double top) {
        expect(players.length, 1);
        expect(tester.state(find.byType(VoiceBody)), same(before));
        expect(players.first.playCalls, 1);
        expect(players.first.pauseCalls, 0);
        expect(players.first.disposeCalls, 0);
        expect(tester.getTopLeft(find.byType(VoiceBody)).dy, top);
      }

      expectStillPlaying(restingTop);

      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(1, 1));
      addTearDown(mouse.removePointer);

      final Offset center = tester.getCenter(find.byType(VoiceBody));
      await mouse.moveTo(center);
      await tester.pump();
      await tester.pump();
      expectStillPlaying(restingTop - 1);

      await mouse.moveTo(center + const Offset(6, 0));
      await tester.pump();
      expectStillPlaying(restingTop - 1);

      await mouse.moveTo(const Offset(1, 1));
      await tester.pump();
      await tester.pump();
      expectStillPlaying(restingTop);

      await mouse.moveTo(center);
      await tester.pump();
      await tester.pump();
      expectStillPlaying(restingTop - 1);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(players.first.disposeCalls, 1);
    },
  );

  testWidgets(
    'hover lifts the day card without rebuilding its log and leaves the feed card flat',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _app(<Widget>[
          CompactLogCard(
            key: const ValueKey<String>('day'),
            entry: _voice('e1'),
            resolver: _resolver(),
            density: CompactLogDensity.day,
            onOpen: () {},
            onDelete: () {},
            audioPlayerFactory: FakeEntryAudioPlayer.new,
          ),
          CompactLogCard(
            key: const ValueKey<String>('feed'),
            entry: _voice('e2'),
            resolver: _resolver(),
            density: CompactLogDensity.feed,
            onOpen: () {},
            onDelete: () {},
            audioPlayerFactory: FakeEntryAudioPlayer.new,
          ),
        ]),
      );
      await tester.pump();

      final Finder dayBody = find.descendant(
        of: find.byKey(const ValueKey<String>('day')),
        matching: find.byType(VoiceBody),
      );
      final Finder feedBody = find.descendant(
        of: find.byKey(const ValueKey<String>('feed')),
        matching: find.byType(VoiceBody),
      );
      final double dayTop = tester.getTopLeft(dayBody).dy;
      final double feedTop = tester.getTopLeft(feedBody).dy;
      final State<StatefulWidget> dayState = tester.state(dayBody);
      final State<StatefulWidget> feedState = tester.state(feedBody);

      final TestGesture mouse = await tester.createGesture(
        kind: PointerDeviceKind.mouse,
      );
      await mouse.addPointer(location: const Offset(1, 1));
      addTearDown(mouse.removePointer);

      await mouse.moveTo(tester.getCenter(dayBody));
      await tester.pump();
      await tester.pump();
      expect(tester.getTopLeft(dayBody).dy, dayTop - 1);
      expect(tester.state(dayBody), same(dayState));
      expect(tester.getTopLeft(feedBody).dy, feedTop);

      await mouse.moveTo(tester.getCenter(feedBody));
      await tester.pump();
      await tester.pump();
      expect(tester.getTopLeft(feedBody).dy, feedTop);
      expect(tester.state(feedBody), same(feedState));
      expect(tester.getTopLeft(dayBody).dy, dayTop);
      expect(tester.state(dayBody), same(dayState));
    },
  );
}
