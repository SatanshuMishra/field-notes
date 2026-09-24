@Tags(<String>['golden'])
library;

import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart'
    show MdPhotoSide, MdPhotoSize;
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteReaderView;
import 'package:field_notes/features/note_engine/render/photo_figure.dart'
    show PhotoFigure, photoFigureTiltDegrees, photoFigureTiltsDegrees;
import 'package:field_notes/features/notes/render/note_photo_block.dart'
    show NoteMediaScope;

import '../../features/notes/support/notes_harness.dart'
    show FakeNoteMediaResolver, availablePhoto, prefixOf, photoIdA;
import '../../support/photo_line_fixture.dart';
import 'golden_harness.dart';

const EdgeInsets _boundaryPadding = EdgeInsets.all(8);

const String _paragraph = 'The tide came in slowly over the flats, and the '
    'herons stood in a line along the channel as if waiting for a signal. We '
    'walked out as far as the **old pilings**, where the mud gives way to '
    'shell, and sat on the driftwood log that has been there since March. '
    '*Nothing moved for a long time.* Then the light changed and the birds '
    'lifted all at once and went north over the dunes.';

final String _tiltedId = _mostTiltedId();

String _mostTiltedId() {
  final double steepest = photoFigureTiltsDegrees
      .map((double degrees) => degrees.abs())
      .reduce((double a, double b) => a > b ? a : b);
  for (int seed = 0;; seed++) {
    final String id = '${seed.toRadixString(16).padLeft(12, '0')}${'0' * 52}';
    if (photoFigureTiltDegrees(prefixOf(id)).abs() == steepest) {
      return id;
    }
  }
}

final class _Case {
  const _Case(
    this.name, {
    required this.width,
    this.scale = 1,
    this.side = MdPhotoSide.right,
    this.size = MdPhotoSize.medium,
    this.pixels = const Size(1200, 800),
    this.caption = '',
    this.tilted = false,
    required this.left,
    required this.figureWidth,
    required this.photoHeight,
  });

  final String name;
  final double width;
  final double scale;
  final MdPhotoSide side;
  final MdPhotoSize size;
  final Size pixels;
  final String caption;
  final bool tilted;
  final double left;
  final double figureWidth;
  final double photoHeight;

  String get id => tilted ? _tiltedId : photoIdA;
}

const List<_Case> _cases = <_Case>[
  _Case(
    'note_float_right_1x',
    width: 560,
    left: 280,
    figureWidth: 280,
    photoHeight: 186.67,
  ),
  _Case(
    'note_float_left_1x',
    width: 560,
    side: MdPhotoSide.left,
    left: 0,
    figureWidth: 280,
    photoHeight: 186.67,
  ),
  _Case(
    'note_float_small_0_9x',
    width: 504,
    scale: 0.9,
    size: MdPhotoSize.small,
    left: 336,
    figureWidth: 168,
    photoHeight: 112,
  ),
  _Case(
    'note_float_large_1_15x',
    width: 644,
    scale: 1.15,
    size: MdPhotoSize.large,
    side: MdPhotoSide.left,
    left: 107.33,
    figureWidth: 429.33,
    photoHeight: 286.22,
  ),
  _Case(
    'note_float_medium_1_5x',
    width: 780,
    scale: 1.5,
    left: 390,
    figureWidth: 390,
    photoHeight: 260,
  ),
  _Case(
    'note_float_shrink_band',
    width: 630,
    size: MdPhotoSize.large,
    left: 210,
    figureWidth: 420,
    photoHeight: 280,
  ),
  _Case(
    'note_float_demote_above',
    width: 480,
    left: 240,
    figureWidth: 240,
    photoHeight: 160,
  ),
  _Case(
    'note_float_demote_below',
    width: 479,
    left: 0,
    figureWidth: 479,
    photoHeight: 319.33,
  ),
  _Case(
    'note_float_phone',
    width: 320,
    left: 0,
    figureWidth: 320,
    photoHeight: 213.33,
  ),
  _Case(
    'note_float_portrait_clamp',
    width: 560,
    pixels: Size(900, 1600),
    left: 280,
    figureWidth: 280,
    photoHeight: 448,
  ),
  _Case(
    'note_float_tilt_reserved',
    width: 560,
    tilted: true,
    left: 280,
    figureWidth: 280,
    photoHeight: 186.67,
  ),
  _Case(
    'note_float_caption',
    width: 560,
    side: MdPhotoSide.left,
    caption: 'Low tide from the pilings',
    left: 0,
    figureWidth: 280,
    photoHeight: 186.67,
  ),
];

Future<void> _pumpCase(WidgetTester tester, _Case entry) async {
  final FakeNoteMediaResolver resolver = FakeNoteMediaResolver(
    <String, ResolvedMedia>{
      prefixOf(entry.id): availablePhoto(
        entry.id,
        width: entry.pixels.width.toInt(),
        height: entry.pixels.height.toInt(),
      ),
    },
  )..memoizeAll();
  final String line = mdPhotoLine(
    entry.id,
    caption: entry.caption,
    side: entry.side,
    size: entry.size,
  );
  final String source = '$line\n$_paragraph';
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pumpWidget(
    goldenHarness(
      MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(entry.scale)),
        child: ColoredBox(
          color: Palette.cardWarm,
          child: NoteMediaScope(
            resolver: resolver,
            child: SizedBox(
              width: entry.width,
              child: NoteReaderView(source: source, selectable: false),
            ),
          ),
        ),
      ),
      padding: _boundaryPadding,
    ),
  );
  await tester.pump();
}

void main() {
  test('there are twelve captures, each named once', () {
    expect(_cases, hasLength(12));
    expect(_cases.map((_Case entry) => entry.name).toSet(), hasLength(12));
  });

  testWidgets('twelve float cases render through the note engine', (
    WidgetTester tester,
  ) async {
    pinGoldenSurface(tester);

    for (final _Case entry in _cases) {
      await _pumpCase(tester, entry);

      expect(tester.takeException(), isNull, reason: entry.name);
      expect(find.byType(NoteReaderView), findsOneWidget, reason: entry.name);
      expect(find.byType(PhotoFigure), findsOneWidget, reason: entry.name);
      final Rect reader = tester.getRect(find.byType(NoteReaderView));
      final Rect figure = tester
          .getRect(find.byType(PhotoFigure))
          .shift(-reader.topLeft);
      expect(figure.left, closeTo(entry.left, 0.5), reason: entry.name);
      expect(figure.top, closeTo(0, 0.5), reason: entry.name);
      expect(figure.width, closeTo(entry.figureWidth, 0.5), reason: entry.name);
      if (entry.caption.isEmpty) {
        expect(
          figure.height,
          closeTo(entry.photoHeight, 0.5),
          reason: entry.name,
        );
      } else {
        expect(figure.height, greaterThan(194.67), reason: entry.name);
      }
      if (entry.tilted) {
        final Iterable<Transform> transforms = tester.widgetList<Transform>(
          find.descendant(
            of: find.byType(PhotoFigure),
            matching: find.byType(Transform),
          ),
        );
        expect(
          transforms.any(
            (Transform transform) =>
                (math.atan2(
                          transform.transform.storage[1],
                          transform.transform.storage[0],
                        ) -
                        -1.2 * math.pi / 180)
                    .abs() <
                1e-9,
          ),
          isTrue,
          reason: entry.name,
        );
      }
      await expectLater(
        find.byType(RepaintBoundary).first,
        matchesGoldenFile('images/${entry.name}.png'),
      );
    }
  });
}
