import 'dart:io';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/notes/note_photos.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart';
import 'package:field_notes/features/log_viewer/note_reading.dart';
import 'package:field_notes/features/log_viewer/photo_viewer.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart';
import 'package:field_notes/features/log_viewer/video_viewer_view.dart';
import 'package:field_notes/features/log_viewer/viewer_waveform.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../accessibility/states/viewer_states.dart'
    show openA11yViewer, openA11yViewerAmong;
import '../../accessibility/support/a11y_variants.dart';
import '../notes/support/notes_harness.dart'
    show FakeNoteMediaResolver, availablePhoto, photoIdA, photoLine, prefixOf;

const A11yVariant _phone = A11yVariant(platform: TargetPlatform.android);
const A11yVariant _phoneLargeText = A11yVariant(
  platform: TargetPlatform.android,
  textScale: A11yTextScale.doubled,
);

const String _voiceId = 'voice-1';
const String _videoId = 'video-1';
const String _photoId = 'a1b2c3d4e5f6';

final DateTime _now = DateTime(2026, 9, 18, 9, 30);

enum _Viewer { note, noteWithPhoto, voice, video }

Entry _entry({
  required String id,
  required EntryType type,
  required DateTime createdAt,
  String? textContent,
  String? mediaId,
  int? durationMs,
}) => Entry(
  id: id,
  dayId: 'day-1',
  type: type,
  textContent: textContent,
  mediaId: mediaId,
  durationMs: durationMs,
  createdAt: createdAt.millisecondsSinceEpoch,
  updatedAt: 0,
);

File _mediaFile(String name) {
  final Directory dir = Directory.systemTemp.createTempSync('phone_actions');
  addTearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
  final File file = File('${dir.path}/$name');
  file.writeAsBytesSync(<int>[0, 1, 2, 3]);
  return file;
}

MediaBlob _blob(String id, MediaKind kind, String mime) => MediaBlob(
  id: id,
  relPath: '$id.bin',
  mime: mime,
  kind: kind,
  bytes: 4,
  createdAt: 0,
);

Entry _subject(_Viewer viewer, {String id = 'entry-1', DateTime? at}) {
  final DateTime createdAt = at ?? _now;
  return switch (viewer) {
    _Viewer.note => _entry(
      id: id,
      type: EntryType.text,
      createdAt: createdAt,
      textContent: 'The fog lifted over the harbour.',
    ),
    _Viewer.noteWithPhoto => _entry(
      id: id,
      type: EntryType.text,
      createdAt: createdAt,
      textContent: 'A harbour morning.\n${photoLine(photoIdA)}',
    ),
    _Viewer.voice => _entry(
      id: id,
      type: EntryType.voice,
      createdAt: createdAt,
      mediaId: _voiceId,
      durationMs: 65000,
    ),
    _Viewer.video => _entry(
      id: id,
      type: EntryType.video,
      createdAt: createdAt,
      mediaId: _videoId,
      durationMs: 4000,
    ),
  };
}

MediaResolver _resolver() => FakeNoteMediaResolver(<String, ResolvedMedia>{
  prefixOf(photoIdA): availablePhoto(photoIdA),
  _voiceId: ResolvedMedia.available(
    blob: _blob(_voiceId, MediaKind.audio, 'audio/mp4'),
    file: _mediaFile('voice.m4a'),
  ),
  _videoId: ResolvedMedia.available(
    blob: _blob(_videoId, MediaKind.video, 'video/mp4'),
    file: _mediaFile('video.mp4'),
  ),
});

Future<void> _open(WidgetTester tester, _Viewer viewer) async {
  await openA11yViewer(
    tester,
    _phone,
    entry: _subject(viewer),
    resolver: _resolver(),
  );
  await tester.pump();
}

Future<void> _openMiddle(WidgetTester tester, _Viewer viewer) async {
  await openA11yViewerAmong(
    tester,
    _phoneLargeText,
    entries: <Entry>[
      _subject(viewer, id: 'e1', at: DateTime(2026, 9, 18, 8)),
      _subject(viewer, id: 'e2', at: DateTime(2026, 9, 18, 9)),
      _subject(viewer, id: 'e3', at: DateTime(2026, 9, 18, 10)),
    ],
    entryId: 'e2',
    resolver: _resolver(),
  );
  await tester.pump();
}

Finder _content(_Viewer viewer) => switch (viewer) {
  _Viewer.note || _Viewer.noteWithPhoto => find.byType(NoteReadingBody),
  _Viewer.voice => find.byType(ViewerWaveform),
  _Viewer.video => find.byKey(videoFrameKey),
};

Finder _filledInside(Finder scope) => find.descendant(
  of: scope,
  matching: find.byWidgetPredicate(
    (Widget widget) =>
        widget is DecoratedBox &&
        widget.decoration is BoxDecoration &&
        (widget.decoration as BoxDecoration).color == Palette.coral,
  ),
);

Rect _rectOf(WidgetTester tester, Finder finder) =>
    tester.getRect(finder.first);

class _PhotoLauncher extends StatelessWidget {
  const _PhotoLauncher({required this.resolver});

  final MediaResolver resolver;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showPhotoViewer(
          context,
          photos: const <NotePhoto>[
            NotePhoto(reference: _photoId, caption: 'The harbour wall'),
            NotePhoto(reference: 'b2c3d4e5f6a1', caption: ''),
          ],
          initialIndex: 0,
          dayTitle: 'Friday, September 18',
          resolver: resolver,
        ),
        child: const Text('open'),
      ),
    );
  }
}

Future<void> _openPhotoViewer(WidgetTester tester) async {
  _phone.useWindow(tester);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: _phone.theme,
      builder: _phone.scaleText,
      home: _PhotoLauncher(resolver: FakeNoteMediaResolver()),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group('phone viewers put delete in the top bar', () {
    for (final _Viewer viewer in _Viewer.values) {
      testWidgets('${viewer.name} viewer', (WidgetTester tester) async {
        await _open(tester, viewer);

        final Finder delete = find.byKey(logActionsDeleteKey);
        expect(delete, findsOneWidget);
        expect(find.bySemanticsLabel('Delete'), findsOneWidget);
        final Rect deleteRect = tester.getRect(delete);
        final Rect closeRect = tester.getRect(find.byKey(logViewerBackKey));
        final Rect contentRect = _rectOf(tester, _content(viewer));
        final double width =
            tester.view.physicalSize.width / tester.view.devicePixelRatio;

        expect(deleteRect.bottom, lessThanOrEqualTo(contentRect.top));
        expect(deleteRect.bottom, lessThanOrEqualTo(closeRect.top));
        expect(deleteRect.right, greaterThan(width * 0.75));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('photo viewer has no delete', (WidgetTester tester) async {
      await _openPhotoViewer(tester);

      expect(find.byType(PhotoViewer), findsOneWidget);
      expect(find.bySemanticsLabel('Delete'), findsNothing);
      expect(find.byKey(logActionsDeleteKey), findsNothing);
    });
  });

  group('phone viewers keep one primary in the bottom row', () {
    testWidgets('note viewer: edit is the one primary, close is secondary', (
      WidgetTester tester,
    ) async {
      await _open(tester, _Viewer.note);

      final Finder viewerRoot = find.byType(LogViewerPanel);
      expect(_filledInside(viewerRoot), findsOneWidget);
      expect(_filledInside(find.byKey(logActionsEditKey)), findsOneWidget);
      expect(_filledInside(find.byKey(logViewerBackKey)), findsNothing);
      expect(find.bySemanticsLabel('Edit note'), findsOneWidget);
      expect(find.bySemanticsLabel('Close'), findsOneWidget);
    });

    testWidgets('note viewer with a photo gains no second primary', (
      WidgetTester tester,
    ) async {
      await _open(tester, _Viewer.noteWithPhoto);

      expect(_filledInside(find.byType(LogViewerPanel)), findsOneWidget);
      expect(_filledInside(find.byKey(logActionsEditKey)), findsOneWidget);
    });

    for (final _Viewer viewer in <_Viewer>[_Viewer.voice, _Viewer.video]) {
      testWidgets('${viewer.name} viewer: play is the one primary, '
          'close is secondary, and no edit', (WidgetTester tester) async {
        await _open(tester, viewer);

        final Finder viewerRoot = find.byType(LogViewerPanel);
        expect(_filledInside(viewerRoot), findsOneWidget);
        expect(_filledInside(find.byType(ViewerPrimaryButton)), findsOneWidget);
        expect(find.bySemanticsLabel('Play'), findsOneWidget);
        expect(_filledInside(find.byKey(logViewerBackKey)), findsNothing);
        expect(find.bySemanticsLabel('Close'), findsOneWidget);
        expect(find.byKey(logActionsEditKey), findsNothing);
        expect(find.bySemanticsLabel('Edit note'), findsNothing);
      });
    }

    testWidgets('photo viewer: close alone, as a secondary', (
      WidgetTester tester,
    ) async {
      await _openPhotoViewer(tester);

      final Finder viewerRoot = find.byType(PhotoViewer);
      expect(_filledInside(viewerRoot), findsNothing);
      expect(find.bySemanticsLabel('Back to note'), findsOneWidget);
      expect(find.bySemanticsLabel('Edit note'), findsNothing);
    });
  });

  group('viewer entry navigation does not overlap at 2x text', () {
    for (final _Viewer viewer in <_Viewer>[
      _Viewer.note,
      _Viewer.voice,
      _Viewer.video,
    ]) {
      testWidgets('${viewer.name} viewer', (WidgetTester tester) async {
        await _openMiddle(tester, viewer);
        expect(tester.takeException(), isNull);

        final Finder position = find.text('2 of 3');
        final Finder play = find.byType(ViewerPrimaryButton);
        final Finder scrubberBar = find.byKey(videoScrubberBarKey);
        final Map<String, Rect> parts = <String, Rect>{
          'earlier': tester.getRect(find.byKey(logViewerEarlierKey)),
          'later': tester.getRect(find.byKey(logViewerLaterKey)),
          'delete': tester.getRect(find.byKey(logActionsDeleteKey)),
          'close': tester.getRect(find.byKey(logViewerBackKey)),
          if (position.evaluate().isNotEmpty)
            'position': tester.getRect(position),
          if (play.evaluate().isNotEmpty) 'play': tester.getRect(play),
          if (scrubberBar.evaluate().isNotEmpty)
            'scrubber': tester.getRect(scrubberBar),
        };
        final List<String> names = parts.keys.toList();
        for (int first = 0; first < names.length; first++) {
          for (int second = first + 1; second < names.length; second++) {
            final Rect a = parts[names[first]]!;
            final Rect b = parts[names[second]]!;
            expect(
              a.overlaps(b),
              isFalse,
              reason: '${names[first]} $a overlaps ${names[second]} $b',
            );
          }
        }
        if (viewer == _Viewer.note) {
          expect(find.byType(LogStepFooter), findsOneWidget);
        }
      });
    }
  });
}
