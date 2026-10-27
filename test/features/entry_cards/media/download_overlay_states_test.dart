import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:field_notes/data/sync/media/download_service.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart';
import 'package:field_notes/features/entry_cards/media/live_media.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../../../accessibility/states/viewer_states.dart' show openA11yViewer;
import '../../../accessibility/support/a11y_variants.dart';

const String _videoId = 'video-1';
const String _posterId = 'poster-1';
const int _megabyte = 1024 * 1024;
const double _minimumTrackContrast = 3;
const double _groundOffset = 3;
const double _strokeMiddle = 1.5;
const String _downloadingLabel = 'Video · 1:04 · downloading 3.0 of 12.0 MB';
const String _downloadedLabel = 'Video downloaded, ready to play';

const MediaDownloadProgress _threeOfTwelve = MediaDownloadProgress(
  blobId: _videoId,
  received: 3 * _megabyte,
  total: 12 * _megabyte,
);

const MediaDownloadProgress _twelveOfTwelve = MediaDownloadProgress(
  blobId: _videoId,
  received: 12 * _megabyte,
  total: 12 * _megabyte,
);

const List<A11yVariant> _variants = <A11yVariant>[
  A11yVariant(platform: TargetPlatform.android),
  A11yVariant(platform: TargetPlatform.macOS),
  A11yVariant(platform: TargetPlatform.windows),
];

double _linear(double channel) => channel <= 0.03928
    ? channel / 12.92
    : math.pow((channel + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color color) =>
    0.2126 * _linear(color.r) +
    0.7152 * _linear(color.g) +
    0.0722 * _linear(color.b);

double _contrast(Color first, Color second) {
  final double a = _luminance(first);
  final double b = _luminance(second);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

final class _DownloadingResolver implements MediaResolver, LiveMedia {
  _DownloadingResolver(this._poster, this._progress);

  final ResolvedMedia _poster;
  final Stream<MediaDownloadProgress> _progress;

  @override
  ResolvedMedia? resolved(String? mediaId) =>
      mediaId == _posterId ? _poster : null;

  @override
  Future<ResolvedMedia> resolve(String? mediaId) async =>
      mediaId == _posterId ? _poster : const ResolvedMedia.missing();

  @override
  Stream<String> get arrivals => const Stream<String>.empty();

  @override
  Stream<MediaDownloadProgress>? downloadProgress(String mediaId) =>
      mediaId == _videoId ? _progress : null;
}

ResolvedMedia _poster(img.Color fill) {
  final Directory dir = Directory.systemTemp.createTempSync('download_states');
  addTearDown(() {
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });
  final File file = File('${dir.path}/poster.png');
  file.writeAsBytesSync(
    img.encodePng(img.fill(img.Image(width: 8, height: 6), color: fill)),
  );
  return ResolvedMedia.available(
    blob: const MediaBlob(
      id: _posterId,
      relPath: '$_posterId.png',
      mime: 'image/png',
      kind: MediaKind.photo,
      bytes: 4,
      createdAt: 0,
    ),
    file: file,
  );
}

Entry _video() => Entry(
  id: 'entry-1',
  dayId: 'day-1',
  type: EntryType.video,
  mediaId: _videoId,
  thumbnailMediaId: _posterId,
  durationMs: 64000,
  createdAt: DateTime(2026, 9, 18, 9, 30).millisecondsSinceEpoch,
  updatedAt: 0,
);

Future<void> _settle(WidgetTester tester) async {
  for (int round = 0; round < 8; round++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 40)),
    );
    await tester.pump();
  }
}

Future<StreamController<MediaDownloadProgress>> _openDownloading(
  WidgetTester tester,
  A11yVariant variant,
  img.Color frame,
) async {
  final StreamController<MediaDownloadProgress> progress =
      StreamController<MediaDownloadProgress>.broadcast();
  addTearDown(progress.close);
  await openA11yViewer(
    tester,
    variant,
    entry: _video(),
    resolver: _DownloadingResolver(_poster(frame), progress.stream),
  );
  progress.add(_threeOfTwelve);
  await _settle(tester);
  return progress;
}

Future<Color Function(Offset)> _pixels(WidgetTester tester) async {
  final double ratio = tester.view.devicePixelRatio;
  final ui.Image image = await captureImage(tester.binding.rootElement!);
  late ByteData bytes;
  await tester.runAsync(() async {
    bytes = (await image.toByteData())!;
  });
  final int width = image.width;
  image.dispose();
  return (Offset point) {
    final int index =
        ((point.dy * ratio).round() * width + (point.dx * ratio).round()) * 4;
    return Color.fromARGB(
      255,
      bytes.getUint8(index),
      bytes.getUint8(index + 1),
      bytes.getUint8(index + 2),
    );
  };
}

SemanticsData _semanticsOf(WidgetTester tester, Finder finder) =>
    tester.getSemantics(finder).getSemanticsData();

void main() {
  for (final A11yVariant variant in _variants) {
    for (final (String name, img.Color frame) in <(String, img.Color)>[
      ('pure black', img.ColorRgb8(0, 0, 0)),
      ('pure white', img.ColorRgb8(255, 255, 255)),
    ]) {
      testWidgets(
        'the download ring track reaches 3:1 over pure black and pure white '
        'frames ($name, ${variant.platformName})',
        (WidgetTester tester) async {
          await _openDownloading(tester, variant, frame);

          final Finder rings = find.byType(VideoDownloadRing);
          expect(
            find.descendant(of: find.byKey(videoFrameKey), matching: rings),
            findsOneWidget,
          );
          final List<Rect> bounds = <Rect>[
            for (final Element ring in rings.evaluate())
              tester.getRect(find.byWidget(ring.widget)),
          ];
          final Color Function(Offset) pixelAt = await _pixels(tester);
          for (final Rect ring in bounds) {
            final Color track = pixelAt(
              Offset(ring.left + _strokeMiddle, ring.center.dy),
            );
            final Color ground = pixelAt(
              Offset(ring.left - _groundOffset, ring.center.dy),
            );
            expect(
              _contrast(track, ground),
              greaterThanOrEqualTo(_minimumTrackContrast),
              reason: 'ring at $ring: track $track over $ground',
            );
          }
        },
      );
    }

    testWidgets(
      'play and the scrubber are unavailable while the video downloads '
      '(${variant.platformName})',
      (WidgetTester tester) async {
        final SemanticsHandle semantics = tester.ensureSemantics();
        await _openDownloading(tester, variant, img.ColorRgb8(0, 0, 0));

        expect(
          find.descendant(
            of: find.byType(ViewerPrimaryButton),
            matching: find.byType(VideoDownloadRing),
          ),
          findsOneWidget,
        );
        final SemanticsData play = _semanticsOf(
          tester,
          find.bySemanticsLabel('Play'),
        );
        expect(play.flagsCollection.isEnabled, ui.Tristate.isFalse);
        expect(play.hasAction(SemanticsAction.tap), isFalse);
        final SemanticsData scrubber = _semanticsOf(
          tester,
          find.bySemanticsLabel('Video position'),
        );
        expect(scrubber.flagsCollection.isEnabled, ui.Tristate.isFalse);
        semantics.dispose();
      },
    );

    testWidgets(
      'download progress and completion are announced as a live region '
      '(${variant.platformName})',
      (WidgetTester tester) async {
        final SemanticsHandle semantics = tester.ensureSemantics();
        final StreamController<MediaDownloadProgress> progress =
            await _openDownloading(tester, variant, img.ColorRgb8(0, 0, 0));
        final FocusNode? focusBefore = FocusManager.instance.primaryFocus;

        final SemanticsData downloading = _semanticsOf(
          tester,
          find.bySemanticsLabel(_downloadingLabel),
        );
        expect(downloading.flagsCollection.isLiveRegion, isTrue);
        expect(downloading.value, '25%');

        progress.add(_twelveOfTwelve);
        await _settle(tester);

        expect(find.bySemanticsLabel(_downloadingLabel), findsNothing);
        final SemanticsData downloaded = _semanticsOf(
          tester,
          find.bySemanticsLabel(_downloadedLabel),
        );
        expect(downloaded.flagsCollection.isLiveRegion, isTrue);
        expect(FocusManager.instance.primaryFocus, same(focusBefore));
        semantics.dispose();
      },
    );
  }
}
