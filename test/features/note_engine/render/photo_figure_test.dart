import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/entry_cards/media/media_image.dart';
import 'package:field_notes/features/entry_cards/media/media_placeholders.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/render/photo_figure.dart';

import '../../notes/support/notes_harness.dart';

const String _lowTide = '![Low tide](photo/a1b2c3d4e5f6 "right medium")';
const double _photoWidth = 344;
const double _photoHeight = 344 / 1.5;
const double _tolerance = 0.01;

class _ThrowingResolver implements MediaResolver {
  const _ThrowingResolver();

  @override
  Future<ResolvedMedia> resolve(String? mediaId) =>
      throw StateError('resolve called for $mediaId');

  @override
  ResolvedMedia? resolved(String? mediaId) =>
      throw StateError('resolved called for $mediaId');
}

MdPhotoLine _lineOf(String source) {
  final MdTree tree = parseNoteTree(source);
  return MdPhotoLine.ofBlock(tree.blocks.single, source);
}

PhotoRect _availableRect(String source, MdPhotoLine line) {
  return PhotoRect(
    sourceRange: MdRange(0, source.length),
    reference: line.reference,
    occurrence: 0,
    rect: const Rect.fromLTWH(0, 0, _photoWidth, _photoHeight + 28),
    imageRect: const Rect.fromLTWH(0, 0, _photoWidth, _photoHeight),
    flow: PhotoFlow.floatRight,
  );
}

PhotoRect _unavailableRect(String source, MdPhotoLine line) {
  return PhotoRect(
    sourceRange: MdRange(0, source.length),
    reference: line.reference,
    occurrence: 0,
    rect: const Rect.fromLTWH(0, 0, _photoWidth, 56 + 28),
    imageRect: const Rect.fromLTWH(0, 0, _photoWidth, 56),
    flow: PhotoFlow.block,
  );
}

FakeNoteMediaResolver _resolver() {
  return FakeNoteMediaResolver(<String, ResolvedMedia>{
    prefixOf(photoIdA): availablePhoto(photoIdA),
  })..memoizeAll();
}

void _pinSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _pumpFigure(
  WidgetTester tester,
  PhotoFigure figure, {
  bool material = false,
}) async {
  final Widget aligned = Align(alignment: Alignment.topLeft, child: figure);
  await tester.pumpWidget(
    MaterialApp(home: material ? Material(child: aligned) : aligned),
  );
}

PhotoFigure _lowTideFigure({
  MediaResolver? resolver,
  ResolvedMedia? media,
  bool selected = false,
  bool captionHidden = false,
  VoidCallback? onActivate,
  SemanticsSortKey? semanticsSortKey,
  VoidCallback? onDecodeError,
  String source = _lowTide,
}) {
  final MdPhotoLine line = _lineOf(source);
  return PhotoFigure(
    line: line,
    rect: _availableRect(source, line),
    media: media,
    resolver: resolver,
    selected: selected,
    captionHidden: captionHidden,
    onActivate: onActivate,
    semanticsSortKey: semanticsSortKey,
    onDecodeError: onDecodeError,
  );
}

Finder _underFrame(Finder matching) {
  return find.descendant(
    of: find.byKey(photoFigureFrameKey),
    matching: matching,
  );
}

Finder _underFigure(Finder matching) {
  return find.descendant(of: find.byType(PhotoFigure), matching: matching);
}

double _rotationOf(Matrix4 matrix) {
  return math.atan2(matrix.storage[1], matrix.storage[0]);
}

void _expectClose(Size actual, Size expected) {
  expect(actual.width, closeTo(expected.width, _tolerance));
  expect(actual.height, closeTo(expected.height, _tolerance));
}

void main() {
  testWidgets(
    'the figure tilts and captions the photo as the reader does today',
    (WidgetTester tester) async {
      _pinSurface(tester);
      await _pumpFigure(
        tester,
        _lowTideFigure(resolver: _resolver(), media: availablePhoto(photoIdA)),
      );

      final Finder frame = find.byKey(photoFigureFrameKey);
      _expectClose(
        tester.getSize(frame),
        const Size(_photoWidth, _photoHeight),
      );

      final List<Transform> transforms = tester
          .widgetList<Transform>(_underFrame(find.byType(Transform)))
          .toList();
      expect(_rotationOf(transforms[0].transform), closeTo(0.01919862, 1e-6));
      expect(transforms[1].transform.storage[0], closeTo(0.955227, 1e-5));

      final Iterable<DecoratedBox> shadowed = tester
          .widgetList<DecoratedBox>(_underFrame(find.byType(DecoratedBox)))
          .where(
            (DecoratedBox box) =>
                box.decoration is BoxDecoration &&
                (box.decoration as BoxDecoration).boxShadow ==
                    Shadows.cardDefault,
          );
      expect(shadowed, hasLength(1));

      expect(find.byType(MediaImage), findsOneWidget);
      final MediaImage image = tester.widget<MediaImage>(
        find.byType(MediaImage),
      );
      expect(image.mediaId, 'a1b2c3d4e5f6');
      expect(image.errorLabel, 'Photo unavailable');
      expect(image.borderRadius, BorderRadius.zero);

      final Finder caption = find.byKey(photoFigureCaptionKey);
      final Rect captionRect = tester.getRect(caption);
      expect(captionRect.width, closeTo(_photoWidth, _tolerance));
      expect(
        captionRect.top,
        closeTo(tester.getRect(frame).bottom + 8, _tolerance),
      );
      final Text text = tester.widget<Text>(
        find.descendant(of: caption, matching: find.byType(Text)),
      );
      expect(text.data, 'Low tide');
      expect(text.style, TypographyTokens.captionSans);
      expect(text.textAlign, TextAlign.center);

      expect(photoFigureTiltDegrees('000001111111'), -1.2);
      expect(photoFigureTiltDegrees('000002222222'), 1.1);
      expect(photoFigureTiltDegrees('000003333333'), 0.5);
      expect(photoFigureTiltDegrees('000004444444'), -0.6);
      expect(photoFigureTiltDegrees('A1B2C3D4E5F6'), 1.1);
      expect(photoFigureTiltDegrees('a1b2c3d4e5f6'), 1.1);
      expect(photoFigureTiltDegrees('a1b2c3d4e5f6${'0' * 51}'), 1.1);
      expect(
        photoFigureFitScale(344, 258, 1.1 * math.pi / 180),
        closeTo(0.960098, 1e-5),
      );
      expect(photoFigureFitScale(0, 10, 0.1), 1);
    },
  );

  testWidgets('an unresolvable reference draws the unavailable placeholder', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    for (final String source in <String>[
      '![Gone](photo/ABC123ABC123 "left medium")',
      '![](photo/abc)',
    ]) {
      final MdPhotoLine line = _lineOf(source);
      await _pumpFigure(
        tester,
        PhotoFigure(
          line: line,
          rect: _unavailableRect(source, line),
          media: null,
          resolver: const _ThrowingResolver(),
        ),
      );

      final Finder placeholder = find.byType(CorruptMediaPlaceholder);
      expect(placeholder, findsOneWidget);
      expect(
        tester.widget<CorruptMediaPlaceholder>(placeholder).key,
        photoFigureUnavailableKey,
      );
      _expectClose(tester.getSize(placeholder), const Size(_photoWidth, 56));
      expect(
        find.descendant(
          of: placeholder,
          matching: find.text('Photo unavailable'),
        ),
        findsOneWidget,
      );
      expect(find.byKey(photoFigureFrameKey), findsNothing);
      expect(find.byType(MediaImage), findsNothing);
      expect(_underFigure(find.byType(Transform)), findsNothing);
      expect(tester.takeException(), isNull);

      if (line.caption.isNotEmpty) {
        expect(find.text('Gone'), findsOneWidget);
        expect(
          tester.getRect(find.byKey(photoFigureCaptionKey)).top,
          closeTo(tester.getRect(placeholder).bottom + 8, _tolerance),
        );
      }
    }

    const String missing = '![Gone](photo/a1b2c3d4e5f6)';
    final MdPhotoLine missingLine = _lineOf(missing);
    await _pumpFigure(
      tester,
      PhotoFigure(
        line: missingLine,
        rect: _unavailableRect(missing, missingLine),
        media: const ResolvedMedia.missing(),
        resolver: _resolver(),
      ),
    );
    final Finder placeholder = find.byKey(photoFigureUnavailableKey);
    expect(find.byType(CorruptMediaPlaceholder), findsOneWidget);
    expect(placeholder, findsOneWidget);
    _expectClose(tester.getSize(placeholder), const Size(_photoWidth, 56));
    expect(find.text('Photo unavailable'), findsOneWidget);
    expect(find.byKey(photoFigureFrameKey), findsNothing);
    expect(find.byType(MediaImage), findsNothing);
  });

  testWidgets('a pending import draws the loading placeholder', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    const String source = '![](photo/a1b2c3d4e5f6 "right medium")';
    final FakeNoteMediaResolver resolver = _resolver();
    await _pumpFigure(
      tester,
      _lowTideFigure(source: source, resolver: resolver),
    );

    final Finder frame = find.byKey(photoFigureFrameKey);
    final Size pendingSize = tester.getSize(frame);
    _expectClose(pendingSize, const Size(_photoWidth, _photoHeight));
    final Transform rotation = tester.widget<Transform>(
      _underFrame(find.byType(Transform)).first,
    );
    expect(_rotationOf(rotation.transform), closeTo(0.01919862, 1e-6));
    expect(_underFrame(find.byType(NeutralMediaPlaceholder)), findsOneWidget);
    expect(find.byType(MediaImage), findsNothing);
    expect(find.byType(CorruptMediaPlaceholder), findsNothing);
    expect(find.byKey(photoFigureCaptionKey), findsNothing);

    await _pumpFigure(
      tester,
      _lowTideFigure(
        source: source,
        resolver: resolver,
        media: availablePhoto(photoIdA),
      ),
    );
    expect(_underFrame(find.byType(MediaImage)), findsOneWidget);
    expect(find.byType(NeutralMediaPlaceholder), findsNothing);
    expect(tester.getSize(frame), pendingSize);
  });

  group('selection ring', () {
    testWidgets('a selected photo has a coral ring turned with the tilt', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      await _pumpFigure(
        tester,
        _lowTideFigure(
          resolver: _resolver(),
          media: availablePhoto(photoIdA),
          selected: true,
        ),
      );

      final Finder ring = find.byKey(photoFigureRingKey);
      expect(ring, findsOneWidget);
      final BoxDecoration decoration =
          tester.widget<DecoratedBox>(ring).decoration as BoxDecoration;
      final Border border = decoration.border! as Border;
      expect(border.top.color, Palette.coral);
      expect(border.top.width, 2.5);
      expect(border.isUniform, isTrue);
      expect(
        decoration.borderRadius,
        const BorderRadius.all(Radius.circular(Shapes.radiusSm)),
      );

      final double radians = 1.1 * math.pi / 180;
      final double scale = photoFigureFitScale(
        _photoWidth,
        _photoHeight,
        radians,
      );
      final RenderBox box = tester.renderObject<RenderBox>(ring);
      _expectClose(box.size, Size(_photoWidth * scale, _photoHeight * scale));
      final Offset ringCentre = tester.getCenter(ring);
      final Offset frameCentre = tester.getCenter(
        find.byKey(photoFigureFrameKey),
      );
      expect(ringCentre.dx, closeTo(frameCentre.dx, _tolerance));
      expect(ringCentre.dy, closeTo(frameCentre.dy, _tolerance));
      final double degrees =
          _rotationOf(box.getTransformTo(null)) * 180 / math.pi;
      expect(degrees, closeTo(1.1, 0.1));
    });

    testWidgets('an unselected photo has no ring', (WidgetTester tester) async {
      _pinSurface(tester);
      await _pumpFigure(
        tester,
        _lowTideFigure(resolver: _resolver(), media: availablePhoto(photoIdA)),
      );
      expect(find.byKey(photoFigureRingKey), findsNothing);
    });

    testWidgets('a selected unavailable photo has an unrotated ring', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      const String source = '![Gone](photo/ABC123ABC123 "left medium")';
      final MdPhotoLine line = _lineOf(source);
      await _pumpFigure(
        tester,
        PhotoFigure(
          line: line,
          rect: _unavailableRect(source, line),
          media: null,
          resolver: const _ThrowingResolver(),
          selected: true,
        ),
      );
      final Finder ring = find.byKey(photoFigureRingKey);
      expect(ring, findsOneWidget);
      _expectClose(tester.getSize(ring), const Size(_photoWidth, 56));
      final RenderBox box = tester.renderObject<RenderBox>(ring);
      expect(_rotationOf(box.getTransformTo(null)), 0);
    });
  });

  testWidgets('a hidden caption keeps its box and place', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final FakeNoteMediaResolver resolver = _resolver();
    await _pumpFigure(
      tester,
      _lowTideFigure(resolver: resolver, media: availablePhoto(photoIdA)),
    );
    final Rect shown = tester.getRect(find.byKey(photoFigureCaptionKey));

    await _pumpFigure(
      tester,
      _lowTideFigure(
        resolver: resolver,
        media: availablePhoto(photoIdA),
        captionHidden: true,
      ),
    );
    expect(tester.getRect(find.byKey(photoFigureCaptionKey)), shown);
    expect(find.text('Low tide'), findsOneWidget);
    final Visibility visibility = tester.widget<Visibility>(
      find.descendant(
        of: find.byKey(photoFigureCaptionKey),
        matching: find.byType(Visibility),
      ),
    );
    expect(visibility.visible, isFalse);
  });

  group('semantics', () {
    testWidgets('the editor figure is one selected button', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      int activations = 0;
      await _pumpFigure(
        tester,
        _lowTideFigure(
          resolver: _resolver(),
          media: availablePhoto(photoIdA),
          selected: true,
          onActivate: () => activations++,
          semanticsSortKey: const OrdinalSortKey(7),
        ),
      );

      final SemanticsNode node = tester.getSemantics(find.byType(PhotoFigure));
      expect(
        node,
        isSemantics(label: 'Photo, Low tide', isButton: true, isSelected: true),
      );
      expect(node.sortKey, const OrdinalSortKey(7));
      expect(node.childrenCount, 0);

      tester.semantics.tap(find.semantics.byLabel('Photo, Low tide'));
      expect(activations, 1);
      handle.dispose();
    });

    testWidgets('a read-only figure is one image', (WidgetTester tester) async {
      _pinSurface(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      final FakeNoteMediaResolver resolver = _resolver();
      await _pumpFigure(
        tester,
        _lowTideFigure(
          resolver: resolver,
          media: availablePhoto(photoIdA),
          semanticsSortKey: const OrdinalSortKey(7),
        ),
      );

      final SemanticsNode node = tester.getSemantics(find.byType(PhotoFigure));
      expect(node, isSemantics(label: 'Photo, Low tide', isImage: true));
      expect(node.sortKey, const OrdinalSortKey(7));
      expect(node.childrenCount, 0);

      await _pumpFigure(
        tester,
        _lowTideFigure(
          source: '![](photo/a1b2c3d4e5f6 "right medium")',
          resolver: resolver,
          media: availablePhoto(photoIdA),
        ),
      );
      expect(
        tester.getSemantics(find.byType(PhotoFigure)),
        isSemantics(label: 'Photo', isImage: true),
      );
      handle.dispose();
    });

    testWidgets('an unavailable figure reports the placeholder as its value', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      const String source = '![Gone](photo/ABC123ABC123 "left medium")';
      final MdPhotoLine line = _lineOf(source);
      await _pumpFigure(
        tester,
        PhotoFigure(
          line: line,
          rect: _unavailableRect(source, line),
          media: null,
          resolver: const _ThrowingResolver(),
        ),
      );
      final SemanticsNode node = tester.getSemantics(find.byType(PhotoFigure));
      expect(node.label, 'Photo, Gone');
      expect(node.value, 'Photo unavailable');
      expect(node.childrenCount, 0);
      handle.dispose();
    });

    test('the label is Photo alone for an empty caption', () {
      expect(photoFigureSemanticsLabelFor(''), 'Photo');
      expect(photoFigureSemanticsLabelFor('  '), 'Photo');
      expect(photoFigureSemanticsLabelFor(' Low tide '), 'Photo, Low tide');
    });
  });

  testWidgets('the decode callback reaches the media image', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    void onDecodeError() {}
    await _pumpFigure(
      tester,
      _lowTideFigure(
        resolver: _resolver(),
        media: availablePhoto(photoIdA),
        onDecodeError: onDecodeError,
      ),
    );
    expect(
      tester.widget<MediaImage>(find.byType(MediaImage)).onDecodeError,
      same(onDecodeError),
    );
  });

  testWidgets('a Material text theme leaves the caption height unchanged', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    await _pumpFigure(
      tester,
      _lowTideFigure(resolver: _resolver(), media: availablePhoto(photoIdA)),
      material: true,
    );
    final TextPainter painter = TextPainter(
      text: const TextSpan(
        text: 'Low tide',
        style: TypographyTokens.captionSans,
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: _photoWidth);
    addTearDown(painter.dispose);
    expect(tester.getSize(find.text('Low tide')).height, painter.height);
  });

  testWidgets('a null resolver draws the pending placeholder', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    await _pumpFigure(tester, _lowTideFigure());
    expect(_underFrame(find.byType(NeutralMediaPlaceholder)), findsOneWidget);
    expect(find.byType(MediaImage), findsNothing);
  });

  testWidgets('a selected figure at rest schedules no frames', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    await _pumpFigure(
      tester,
      _lowTideFigure(
        resolver: _resolver(),
        media: availablePhoto(photoIdA),
        selected: true,
      ),
    );
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });
}
