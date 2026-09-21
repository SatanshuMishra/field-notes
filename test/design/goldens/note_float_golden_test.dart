@Tags(<String>['golden'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/notes/note_document.dart';
import 'package:field_notes/features/notes/notes.dart';

import '../../features/notes/support/notes_harness.dart';
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
  final double steepest = notePhotoTiltsDegrees
      .map((double degrees) => degrees.abs())
      .reduce((double a, double b) => a > b ? a : b);
  for (int seed = 0;; seed++) {
    final String id = '${seed.toRadixString(16).padLeft(12, '0')}${'0' * 52}';
    if (notePhotoTiltDegrees(prefixOf(id)).abs() == steepest) {
      return id;
    }
  }
}

final class _Case {
  const _Case(
    this.name, {
    required this.width,
    this.scale = 1,
    this.side = PhotoSide.right,
    this.size = PhotoSize.medium,
    this.pixels = const Size(1200, 800),
    this.caption = '',
    this.tilted = false,
    required this.floats,
  });

  final String name;
  final double width;
  final double scale;
  final PhotoSide side;
  final PhotoSize size;
  final Size pixels;
  final String caption;
  final bool tilted;
  final bool floats;

  String get id => tilted ? _tiltedId : photoIdA;
}

const List<_Case> _cases = <_Case>[
  _Case('note_float_right_1x', width: 560, floats: true),
  _Case('note_float_left_1x', width: 560, side: PhotoSide.left, floats: true),
  _Case(
    'note_float_small_0_9x',
    width: 504,
    scale: 0.9,
    size: PhotoSize.small,
    floats: true,
  ),
  _Case(
    'note_float_large_1_15x',
    width: 644,
    scale: 1.15,
    size: PhotoSize.large,
    side: PhotoSide.left,
    floats: true,
  ),
  _Case('note_float_medium_1_5x', width: 780, scale: 1.5, floats: true),
  _Case('note_float_shrink_band', width: 490, floats: true),
  _Case('note_float_demote_above', width: 463, floats: true),
  _Case('note_float_demote_below', width: 462, floats: false),
  _Case('note_float_phone', width: 320, floats: false),
  _Case(
    'note_float_portrait_clamp',
    width: 560,
    pixels: Size(900, 1600),
    floats: true,
  ),
  _Case('note_float_tilt_reserved', width: 560, tilted: true, floats: true),
  _Case(
    'note_float_caption',
    width: 560,
    side: PhotoSide.left,
    caption: 'Low tide from the pilings',
    floats: true,
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
  final String source = '${photoLine(
    entry.id,
    side: entry.side,
    size: entry.size,
    caption: entry.caption,
  )}\n$_paragraph';
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
              child: NoteDocument(source: source),
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

  for (final _Case entry in _cases) {
    testWidgets('${entry.name} matches its golden', (
      WidgetTester tester,
    ) async {
      pinGoldenSurface(tester);

      await _pumpCase(tester, entry);

      expect(tester.takeException(), isNull);
      expect(
        find.byKey(photoWrapHeadKey),
        entry.floats ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(StackedPhoto),
        entry.floats ? findsNothing : findsOneWidget,
      );
      await expectLater(
        find.byType(RepaintBoundary).first,
        matchesGoldenFile('images/${entry.name}.png'),
      );
    });
  }
}
