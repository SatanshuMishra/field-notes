import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';

import 'support/entry_cards_harness.dart';
import 'support/fake_audio_player.dart';
import 'support/fake_video_player.dart';

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
      expect(find.text('Note'), findsOneWidget);
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

      expect(find.widgetWithText(StickerButton, 'Edit'), findsOneWidget);
      expect(find.widgetWithText(StickerButton, 'Delete'), findsOneWidget);

      await tester.tap(find.widgetWithText(StickerButton, 'Edit'));
      await tester.tap(find.widgetWithText(StickerButton, 'Delete'));
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

      expect(find.byType(StickerButton), findsNothing);
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
      expect(find.text('Voice note'), findsOneWidget);
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
      expect(find.text('Video'), findsOneWidget);
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
  });
}
