import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';

import 'support/entry_cards_harness.dart';
import 'support/fake_audio_player.dart';
import 'support/fake_video_player.dart';

Finder cardAction(String label) => find.byWidgetPredicate(
      (Widget widget) =>
          widget is IconStickerButton && widget.semanticLabel == label,
    );

String longNote() {
  final StringBuffer buffer = StringBuffer();
  int word = 0;
  while (buffer.length < notePreviewCharLimit * 2) {
    if (buffer.isNotEmpty) {
      buffer.write(' ');
    }
    buffer.write('word${word++}');
  }
  return buffer.toString();
}

Widget scrollingCardHarness(Widget child, {double width = 360}) =>
    cardHarness(SingleChildScrollView(child: child), width: width);

List<EntryPhoto> threePhotos() => <EntryPhoto>[
      photoOf(id: 'c', mediaId: 'm-c', sortOrder: 2),
      photoOf(id: 'b', mediaId: 'm-b', sortOrder: 1),
      photoOf(id: 'a', mediaId: 'm-a', sortOrder: 0),
    ];

void main() {
  group('EntryCard', () {
    testWidgets('renders a note entry as a NoteBody inside a StickerCard',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        cardHarness(
          EntryCard(
            entry: entryOf(type: EntryType.text, textContent: 'hello world'),
            resolver: FakeMediaResolver(),
            videoSlots: const UnlimitedVideoSlots(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(StickerCard), findsOneWidget);
      expect(find.byType(NoteBody), findsOneWidget);
      expect(find.text('hello world'), findsOneWidget);
      expect(find.text('NOTE'), findsOneWidget);
    });

    testWidgets('renders the inline photo strip when photos are attached',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        cardHarness(
          EntryCard(
            entry: entryOf(type: EntryType.text, textContent: 'trip'),
            resolver: FakeMediaResolver(),
            photos: <EntryPhoto>[photoOf(id: 'p', mediaId: 'm')],
            videoSlots: const UnlimitedVideoSlots(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(InlinePhotoStrip), findsOneWidget);
    });

    testWidgets('shows Edit and Delete only when callbacks are provided',
        (WidgetTester tester) async {
      int edits = 0;
      int deletes = 0;
      await tester.pumpWidget(
        cardHarness(
          EntryCard(
            entry: entryOf(type: EntryType.text, textContent: 'edit me'),
            resolver: FakeMediaResolver(),
            onEdit: () => edits++,
            onDelete: () => deletes++,
            videoSlots: const UnlimitedVideoSlots(),
          ),
        ),
      );
      await tester.pump();

      expect(cardAction(entryEditLabel), findsOneWidget);
      expect(cardAction(entryDeleteLabel), findsOneWidget);

      await tester.tap(cardAction(entryEditLabel));
      await tester.tap(cardAction(entryDeleteLabel));
      expect(edits, 1);
      expect(deletes, 1);
    });

    testWidgets('omits actions in the read-only (Today feed) configuration',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        cardHarness(
          EntryCard(
            entry: entryOf(type: EntryType.text, textContent: 'read only'),
            resolver: FakeMediaResolver(),
            videoSlots: const UnlimitedVideoSlots(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(IconStickerButton), findsNothing);
    });

    testWidgets('dispatches a voice entry to VoiceBody with its factory',
        (WidgetTester tester) async {
      final FakeMediaResolver resolver = FakeMediaResolver()
        ..set(
          'aud',
          ResolvedMedia.available(
            blob: blobOf(id: 'aud', relPath: 'a.m4a', kind: MediaKind.audio),
            file: File('/tmp/a.m4a'),
          ),
        );

      await tester.pumpWidget(
        cardHarness(
          EntryCard(
            entry:
                entryOf(type: EntryType.voice, mediaId: 'aud', durationMs: 3000),
            resolver: resolver,
            audioPlayerFactory: () => FakeEntryAudioPlayer(),
            videoSlots: const UnlimitedVideoSlots(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(VoiceBody), findsOneWidget);
      expect(find.text('VOICE'), findsOneWidget);
    });

    testWidgets('dispatches a video entry to VideoBody with its factory',
        (WidgetTester tester) async {
      final FakeMediaResolver resolver = FakeMediaResolver()
        ..set(
          'vid',
          ResolvedMedia.available(
            blob: blobOf(id: 'vid', relPath: 'v.mp4', kind: MediaKind.video),
            file: File('/tmp/v.mp4'),
          ),
        );

      await tester.pumpWidget(
        cardHarness(
          EntryCard(
            entry:
                entryOf(type: EntryType.video, mediaId: 'vid', durationMs: 3000),
            resolver: resolver,
            videoPlayerFactory: () => FakeEntryVideoPlayer(),
            videoSlots: const UnlimitedVideoSlots(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(VideoBody), findsOneWidget);
      expect(find.text('VIDEO'), findsOneWidget);
    });

    testWidgets(
        'renders a playback-unavailable placeholder for a voice entry '
        'with no audio factory', (WidgetTester tester) async {
      await tester.pumpWidget(
        cardHarness(
          EntryCard(
            entry:
                entryOf(type: EntryType.voice, mediaId: 'aud', durationMs: 3000),
            resolver: FakeMediaResolver(),
            videoSlots: const UnlimitedVideoSlots(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(VoiceBody), findsNothing);
      expect(find.byType(CorruptMediaPlaceholder), findsOneWidget);
    });

    testWidgets('preview:true bounds the note and offers Read more',
        (WidgetTester tester) async {
      final String note = longNote();

      await tester.pumpWidget(
        scrollingCardHarness(
          EntryCard(
            entry: entryOf(type: EntryType.text, textContent: note),
            resolver: FakeMediaResolver(),
            photos: threePhotos(),
            videoSlots: const UnlimitedVideoSlots(),
            preview: true,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(NotePreview), findsOneWidget);
      expect(find.byType(NoteBody), findsNothing);
      expect(find.text(noteReadMoreLabel), findsOneWidget);
      expect(find.byType(ShaderMask), findsOneWidget);

      final NoteDocument document =
          tester.widget<NoteDocument>(find.byType(NoteDocument));
      expect(document.source.length, lessThanOrEqualTo(notePreviewCharLimit));

      final Iterable<MediaImage> images =
          tester.widgetList<MediaImage>(find.byType(MediaImage));
      expect(images.length, 1);
      expect(images.single.mediaId, 'm-a');
    });

    testWidgets('preview:false renders the whole note and every photo',
        (WidgetTester tester) async {
      final String note = longNote();

      await tester.pumpWidget(
        scrollingCardHarness(
          EntryCard(
            entry: entryOf(type: EntryType.text, textContent: note),
            resolver: FakeMediaResolver(),
            photos: threePhotos(),
            videoSlots: const UnlimitedVideoSlots(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(NoteBody), findsOneWidget);
      expect(find.byType(NotePreview), findsNothing);
      expect(find.text(noteReadMoreLabel), findsNothing);

      final NoteDocument document =
          tester.widget<NoteDocument>(find.byType(NoteDocument));
      expect(document.source, note);

      final Iterable<MediaImage> images =
          tester.widgetList<MediaImage>(find.byType(MediaImage));
      expect(images.map((MediaImage i) => i.mediaId).toList(),
          <String>['m-a', 'm-b', 'm-c']);
    });

    testWidgets('onTap fires when the card body is tapped',
        (WidgetTester tester) async {
      int taps = 0;

      await tester.pumpWidget(
        cardHarness(
          EntryCard(
            entry: entryOf(type: EntryType.text, textContent: 'a quiet day'),
            resolver: FakeMediaResolver(),
            videoSlots: const UnlimitedVideoSlots(),
            preview: true,
            onTap: () => taps++,
          ),
        ),
      );
      await tester.pump();

      await tester.tapAt(tester.getCenter(find.text('a quiet day')));
      await tester.pump();

      expect(taps, 1);
    });

    testWidgets('a card without onTap stays untappable',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        cardHarness(
          EntryCard(
            entry: entryOf(type: EntryType.text, textContent: 'a quiet day'),
            resolver: FakeMediaResolver(),
            videoSlots: const UnlimitedVideoSlots(),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.ancestor(
          of: find.byType(StickerCard),
          matching: find.byType(GestureDetector),
        ),
        findsNothing,
      );
    });
  });
}
