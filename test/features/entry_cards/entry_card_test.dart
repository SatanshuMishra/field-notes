import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/notes/notes.dart';

import '../notes/support/notes_harness.dart'
    show availablePhoto, photoIdA, photoIdB, photoLine, prefixOf;
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

    testWidgets('renders no photo surface for a note entry',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        cardHarness(
          EntryCard(
            entry: entryOf(type: EntryType.text, textContent: 'trip'),
            resolver: FakeMediaResolver(),
            videoSlots: const UnlimitedVideoSlots(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(MediaImage), findsNothing);
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
      expect(find.byType(MediaImage), findsNothing);
    });

    testWidgets('preview:false renders the whole note',
        (WidgetTester tester) async {
      final String note = longNote();

      await tester.pumpWidget(
        scrollingCardHarness(
          EntryCard(
            entry: entryOf(type: EntryType.text, textContent: note),
            resolver: FakeMediaResolver(),
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
      expect(find.byType(MediaImage), findsNothing);
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

  group('EntryCard note photos', () {
    const double phoneMeasure = 320;
    const double cardWidth = phoneMeasure + 30;

    FakeMediaResolver photoResolver() {
      return FakeMediaResolver()
        ..set(prefixOf(photoIdA), availablePhoto(photoIdA))
        ..set(prefixOf(photoIdB), availablePhoto(photoIdB, width: 900, height: 1600));
    }

    Future<void> pumpNote(
      WidgetTester tester,
      String text, {
      bool preview = false,
      MediaResolver? resolver,
    }) async {
      await tester.pumpWidget(
        scrollingCardHarness(
          EntryCard(
            entry: entryOf(type: EntryType.text, textContent: text),
            resolver: resolver ?? photoResolver(),
            videoSlots: const UnlimitedVideoSlots(),
            preview: preview,
          ),
          width: cardWidth,
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets(
        'a photo line renders as one centred block image at each size '
        'fraction, four distinct widths at a 320pt measure',
        (WidgetTester tester) async {
      final List<double> widths = <double>[];
      for (final PhotoSize size in PhotoSize.values) {
        await pumpNote(tester, 'before\n${photoLine(photoIdA, size: size)}\nafter');

        final double measure = tester.getSize(find.byType(NoteDocument)).width;
        final Finder frame = find.byKey(notePhotoFrameKey);
        expect(measure, phoneMeasure);
        expect(frame, findsOneWidget);
        expect(
          tester.getSize(frame).width,
          closeTo(size.measureFraction * measure, 0.01),
          reason: size.name,
        );
        expect(
          tester.getCenter(frame).dx,
          closeTo(tester.getCenter(find.byType(NoteDocument)).dx, 0.01),
        );
        widths.add(tester.getSize(frame).width);
      }

      expect(widths.toSet(), hasLength(4));
    });

    testWidgets('the block keeps the photo aspect and clamps a tall portrait',
        (WidgetTester tester) async {
      await pumpNote(
        tester,
        '${photoLine(photoIdA, size: PhotoSize.full)}\n'
        '${photoLine(photoIdB, size: PhotoSize.full)}',
      );

      final List<Size> frames = tester
          .widgetList<SizedBox>(find.byKey(notePhotoFrameKey))
          .map((SizedBox box) => Size(box.width!, box.height!))
          .toList();
      expect(frames[0].height, closeTo(phoneMeasure / 1.5, 0.01));
      expect(frames[1].height, closeTo(1.6 * phoneMeasure, 0.01));
    });

    testWidgets('renders the photo inline and nowhere else',
        (WidgetTester tester) async {
      await pumpNote(tester, 'before\n${photoLine(photoIdA)}\nafter');

      expect(find.byType(StackedPhoto), findsOneWidget);
      expect(find.byType(MediaImage), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(StackedPhoto),
          matching: find.byType(MediaImage),
        ),
        findsOneWidget,
      );
      expect(find.text('before'), findsOneWidget);
      expect(find.text('after'), findsOneWidget);
    });

    testWidgets('the Today preview card renders the photo the same way',
        (WidgetTester tester) async {
      await pumpNote(
        tester,
        'before\n${photoLine(photoIdA, size: PhotoSize.small)}',
        preview: true,
      );

      expect(find.byType(NotePreview), findsOneWidget);
      expect(
        tester.getSize(find.byKey(notePhotoFrameKey)).width,
        closeTo(0.55 * phoneMeasure, 0.01),
      );
    });

    testWidgets('the alt slot is the caption and the screen-reader label',
        (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await pumpNote(tester, photoLine(photoIdA, caption: 'the porch at dusk'));

      expect(find.text('the porch at dusk'), findsOneWidget);
      expect(
        find.bySemanticsLabel('the porch at dusk'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('an unresolvable reference renders the unavailable chip',
        (WidgetTester tester) async {
      await pumpNote(
        tester,
        'before\n![](photo/0123456789ab "right medium")\nafter',
      );

      expect(find.byKey(notePhotoUnavailableKey), findsOneWidget);
      expect(find.text(notePhotoUnavailableLabel), findsOneWidget);
      expect(find.byKey(notePhotoFrameKey), findsNothing);
      expect(find.text('after'), findsOneWidget);
    });

    testWidgets('an unavailable photo still announces its caption',
        (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await pumpNote(
        tester,
        '![the porch at dusk](photo/0123456789ab "right medium")',
      );

      expect(find.byKey(notePhotoUnavailableKey), findsOneWidget);
      expect(find.bySemanticsLabel('the porch at dusk'), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('a pending resolve holds the planned box instead of jumping',
        (WidgetTester tester) async {
      await pumpNote(
        tester,
        photoLine(photoIdA, size: PhotoSize.large),
        resolver: const _NeverResolver(),
      );

      expect(
        tester.getSize(find.byKey(notePhotoFrameKey)),
        Size(0.92 * phoneMeasure, 0.92 * phoneMeasure / photoFallbackAspect),
      );
    });
  });
}

class _NeverResolver implements MediaResolver {
  const _NeverResolver();

  @override
  ResolvedMedia? resolved(String? mediaId) => null;

  @override
  Future<ResolvedMedia> resolve(String? mediaId) =>
      Completer<ResolvedMedia>().future;
}
