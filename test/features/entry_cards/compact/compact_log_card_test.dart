import 'dart:io';

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/cards/note_body.dart';
import 'package:field_notes/features/entry_cards/cards/voice_body.dart';
import 'package:field_notes/features/entry_cards/compact/compact_log_card.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/entry_cards_harness.dart';
import '../support/fake_audio_player.dart';

const String _photoReference = '0123456789ab';
const String _longLead = 'The peonies finally opened along the back fence.';
const String _longSnippet =
    'I stood there with my coffee for a long while and watched the bees '
    'work the blooms.';

int _at(int hour, int minute) =>
    DateTime(2025, 7, 2, hour, minute).millisecondsSinceEpoch;

Entry _entry({
  required EntryType type,
  String id = 'e1',
  String? textContent,
  String? mediaId,
  String? thumbnailMediaId,
  int? durationMs,
  int? createdAt,
}) {
  final int at = createdAt ?? _at(8, 30);
  return Entry(
    id: id,
    dayId: 'd1',
    type: type,
    textContent: textContent,
    mediaId: mediaId,
    thumbnailMediaId: thumbnailMediaId,
    durationMs: durationMs,
    createdAt: at,
    updatedAt: at,
  );
}

String _longNoteText() {
  final String body = '$_longLead $_longSnippet ${'Petals everywhere. ' * 10}';
  final String text = body.substring(0, 300);
  return '$text\n![peonies](photo/$_photoReference "right medium")';
}

FakeMediaResolver _resolverWithPhoto() {
  final Directory dir = Directory.systemTemp.createTempSync('compact-card');
  final File file = File('${dir.path}/wide.png')
    ..writeAsBytesSync(widePngBytes());
  return FakeMediaResolver()..set(
    _photoReference,
    ResolvedMedia.available(
      blob: blobOf(id: _photoReference, relPath: 'wide.png'),
      file: file,
    ),
  );
}

Widget _host(Widget card) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: <Widget>[card],
      ),
    ),
  );
}

void main() {
  testWidgets('a long note card shows its lead, snippet, thumbnail and Read', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        CompactLogCard(
          entry: _entry(type: EntryType.text, textContent: _longNoteText()),
          resolver: _resolverWithPhoto(),
          density: CompactLogDensity.feed,
          onOpen: () {},
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text(_longLead), findsOneWidget);
    expect(find.textContaining('I stood there with my coffee'), findsOneWidget);
    expect(find.byKey(compactLogThumbnailKey), findsOneWidget);
    expect(find.text('Read ›'), findsOneWidget);
    expect(find.byType(NoteBody), findsNothing);
  });

  testWidgets('a short note card shows the note in full with no meta row', (
    WidgetTester tester,
  ) async {
    const String note =
        'Watered the basil and the tomatoes before the heat of noon!!';
    expect(note.length, 60);
    await tester.pumpWidget(
      _host(
        CompactLogCard(
          entry: _entry(type: EntryType.text, textContent: note),
          resolver: FakeMediaResolver(),
          density: CompactLogDensity.feed,
          onOpen: () {},
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(NoteBody), findsOneWidget);
    expect(find.textContaining(note, findRichText: true), findsOneWidget);
    expect(find.byKey(compactLogOpenLabelKey), findsNothing);
    expect(find.byKey(compactLogThumbnailKey), findsNothing);
  });

  testWidgets('tapping the card body opens the log', (
    WidgetTester tester,
  ) async {
    int opens = 0;
    await tester.pumpWidget(
      _host(
        CompactLogCard(
          entry: _entry(type: EntryType.text, textContent: _longNoteText()),
          resolver: _resolverWithPhoto(),
          density: CompactLogDensity.day,
          onOpen: () => opens++,
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text(_longLead));
    await tester.pump();

    expect(opens, 1);
  });

  testWidgets('the voice play control plays in place without opening the log', (
    WidgetTester tester,
  ) async {
    int opens = 0;
    final FakeEntryAudioPlayer player = FakeEntryAudioPlayer();
    final FakeMediaResolver resolver = FakeMediaResolver()
      ..set(
        'aud',
        ResolvedMedia.available(
          blob: blobOf(id: 'aud', relPath: 'a.m4a', kind: MediaKind.audio),
          file: File('/tmp/a.m4a'),
        ),
      );
    await tester.pumpWidget(
      _host(
        CompactLogCard(
          entry: _entry(
            type: EntryType.voice,
            mediaId: 'aud',
            durationMs: 65000,
          ),
          resolver: resolver,
          density: CompactLogDensity.feed,
          onOpen: () => opens++,
          onDelete: () {},
          audioPlayerFactory: () => player,
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(VoiceBody), findsOneWidget);
    await tester.tap(
      find.descendant(
        of: find.byType(VoiceBody),
        matching: find.byKey(const ValueKey<String>('voice-play-toggle')),
      ),
    );
    await tester.pump();

    expect(player.playCalls, 1);
    expect(opens, 0);
  });

  testWidgets('a video card shows its poster, its part of day and Watch', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        CompactLogCard(
          entry: _entry(
            type: EntryType.video,
            mediaId: 'vid',
            thumbnailMediaId: 'poster',
            durationMs: 83000,
            createdAt: _at(21, 20),
          ),
          resolver: FakeMediaResolver(),
          density: CompactLogDensity.feed,
          onOpen: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('A video from the night'), findsOneWidget);
    expect(find.text('Watch ›'), findsOneWidget);
    expect(find.text('1:23'), findsOneWidget);
    expect(find.byKey(compactLogThumbnailKey), findsOneWidget);
    expect(
      tester.getSize(find.byKey(compactLogThumbnailKey)),
      const Size(104, 64),
    );
  });

  testWidgets('the day density stamps the type inline and does not tilt', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      _host(
        CompactLogCard(
          entry: _entry(
            type: EntryType.text,
            id: 'tilted',
            textContent: 'A short one.',
          ),
          resolver: FakeMediaResolver(),
          density: CompactLogDensity.day,
          onOpen: () {},
          onEdit: () {},
          onDelete: () {},
        ),
      ),
    );
    await tester.pump();

    expect(find.text('08:30 · morning · note'), findsOneWidget);
    expect(find.text('NOTE'), findsNothing);
    final Iterable<Transform> transforms = tester.widgetList<Transform>(
      find.descendant(
        of: find.byType(CompactLogCard),
        matching: find.byType(Transform),
      ),
    );
    for (final Transform transform in transforms) {
      expect(transform.transform.entry(0, 1), 0);
      expect(transform.transform.entry(1, 0), 0);
    }
  });
}
