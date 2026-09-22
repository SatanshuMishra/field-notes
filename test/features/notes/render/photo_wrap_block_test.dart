import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/notes/notes.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/notes/note_block_widgets.dart';
import 'package:field_notes/features/entry_cards/notes/note_document.dart';
import 'package:field_notes/features/entry_cards/notes/note_inline_span.dart';
import 'package:field_notes/features/notes/notes.dart';

import '../support/notes_harness.dart';

const double _em = 16;
const double _desktop = 560;

const String _prose = 'The tide came in slowly over the flats this morning, '
    'and the herons stood in a line along the channel as if waiting for a '
    'signal. We walked out as far as the **old pilings**, where the mud '
    'gives way to shell, and sat on the driftwood log that has been there '
    'since the storm in March. *Nothing moved for a long time.* Then the '
    'light changed, the water turned from grey to a dull green, and the '
    'birds lifted all at once and went north over the dunes. On the way back '
    'we found a whelk shell, perfect and empty, half buried in the sand near '
    'the boardwalk, and a single blue mussel still closed tight. The wind '
    'had dropped by then and the whole marsh smelled of salt and cut grass.';

String get _prosePlain => plainTextOf(_prose);

FakeNoteMediaResolver _resolver({
  int? width = 1200,
  int? height = 800,
  bool memoized = true,
}) {
  final FakeNoteMediaResolver resolver = FakeNoteMediaResolver(
    <String, ResolvedMedia>{
      prefixOf(photoIdA):
          availablePhoto(photoIdA, width: width, height: height),
    },
  );
  if (memoized) {
    resolver.memoizeAll();
  }
  return resolver;
}

String _note({
  PhotoSide side = PhotoSide.right,
  PhotoSize size = PhotoSize.medium,
  String caption = '',
  String after = _prose,
}) =>
    '${photoLine(photoIdA, side: side, size: size, caption: caption)}\n$after';

Future<void> _pumpNote(
  WidgetTester tester,
  String source, {
  double width = _desktop,
  double scale = 1,
  MediaResolver? resolver,
  bool floatEnabled = true,
  bool fillsWidth = false,
}) async {
  tester.view.physicalSize = const Size(1000, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    notesHarness(
      Builder(
        builder: (BuildContext context) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: NoteRenderBudget(
            floatEnabled: floatEnabled,
            child: NoteMeasureScope(
              fillsWidth: fillsWidth,
              child: NoteMediaScope(
                resolver: resolver ?? _resolver(),
                child: NoteDocument(source: source),
              ),
            ),
          ),
        ),
      ),
      width: width,
    ),
  );
  await tester.pump();
}

InlineSpan _headSpan(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(photoWrapHeadKey)).textSpan!;

RenderParagraph _paragraph(WidgetTester tester, Key key) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: find.byKey(key), matching: find.byType(RichText)),
    );

List<Rect> _glyphRects(RenderParagraph paragraph) {
  final Offset origin = paragraph.localToGlobal(Offset.zero);
  return <Rect>[
    for (final TextBox box in paragraph.getBoxesForSelection(
      TextSelection(
        baseOffset: 0,
        extentOffset: paragraph.text.toPlainText().length,
      ),
    ))
      box.toRect().shift(origin),
  ];
}

TextPainter _painterFor(InlineSpan span, double width, {double scale = 1}) {
  final TextPainter painter = TextPainter(
    text: span,
    textDirection: TextDirection.ltr,
    textScaler: TextScaler.linear(scale),
  )..layout(maxWidth: width);
  addTearDown(painter.dispose);
  return painter;
}

void _expectFloated(WidgetTester tester) {
  expect(find.byType(PhotoWrapBlock), findsOneWidget);
  expect(find.byKey(photoWrapHeadKey), findsOneWidget);
  expect(find.byType(StackedPhoto), findsNothing);
}

void _expectStacked(WidgetTester tester) {
  expect(find.byKey(photoWrapHeadKey), findsNothing);
  expect(find.byKey(photoWrapTailKey), findsNothing);
  expect(find.byType(StackedPhoto), findsOneWidget);
  expect(find.text(_prosePlain), findsOneWidget);
}

List<MethodCall> _captureClipboard(WidgetTester tester) {
  final List<MethodCall> log = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      log.add(call);
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null),
  );
  return log;
}

Future<void> _pressWithControl(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  await tester.pump();
  await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
  await tester.pumpAndSettle();
}

String _copiedText(List<MethodCall> log) {
  final MethodCall call =
      log.lastWhere((MethodCall c) => c.method == 'Clipboard.setData');
  return (call.arguments as Map<Object?, Object?>)['text']! as String;
}

Offset _caretPoint(RenderParagraph paragraph, int offset) {
  const Rect caret = Rect.fromLTWH(0, 0, 2, 20);
  final Offset local =
      paragraph.getOffsetForCaret(TextPosition(offset: offset), caret) +
          Offset(1, paragraph.preferredLineHeight / 2);
  return paragraph.localToGlobal(local);
}

void main() {
  group('the float', () {
    testWidgets(
        'a right photo before a paragraph renders as a Row of head and photo '
        'with the tail below', (WidgetTester tester) async {
      await _pumpNote(tester, _note());

      _expectFloated(tester);
      expect(find.byKey(photoWrapTailKey), findsOneWidget);
      final PhotoPlan plan = planFloat(
        measure: _desktop,
        em: _em,
        side: PhotoSide.right,
        size: PhotoSize.medium,
        aspect: 1.5,
        nextIsParagraph: true,
      );
      expect(plan.isStacked, isFalse);

      final Rect frame = tester.getRect(find.byKey(notePhotoFrameKey));
      final Rect head = tester.getRect(find.byKey(photoWrapHeadKey));
      final Rect tail = tester.getRect(find.byKey(photoWrapTailKey));
      final Rect document = tester.getRect(find.byType(NoteDocument));
      expect(frame.size, Size(plan.width, plan.height));
      expect(frame.width, 192);
      expect(frame.right, closeTo(document.right, 0.01));
      expect(frame.top, closeTo(head.top, 0.01));
      expect(head.left, closeTo(document.left, 0.01));
      expect(head.right + plan.gutter, lessThanOrEqualTo(frame.left + 0.01));
      expect(head.width, lessThanOrEqualTo(plan.band));
      expect(
          head.width, greaterThanOrEqualTo(photoBandResidualEm * _em - 0.01));
      expect(tail.left, closeTo(document.left, 0.01));
      expect(tail.top, greaterThanOrEqualTo(frame.bottom - 0.01));
      expect(tail.top, closeTo(head.bottom, 0.01));
    });

    testWidgets('a left photo sits at the left edge with the head after it',
        (WidgetTester tester) async {
      await _pumpNote(tester, _note(side: PhotoSide.left));

      _expectFloated(tester);
      final Rect frame = tester.getRect(find.byKey(notePhotoFrameKey));
      final Rect head = tester.getRect(find.byKey(photoWrapHeadKey));
      final Rect document = tester.getRect(find.byType(NoteDocument));
      expect(frame.left, closeTo(document.left, 0.01));
      expect(head.left, closeTo(frame.right + _em, 0.01));
      expect(head.top, closeTo(frame.top, 0.01));
      expect(head.right, lessThanOrEqualTo(document.right + 0.01));
    });

    testWidgets('no glyph of the head or the tail overlaps the photo',
        (WidgetTester tester) async {
      for (final PhotoSide side in PhotoSide.values) {
        for (final PhotoSize size in <PhotoSize>[
          PhotoSize.small,
          PhotoSize.medium,
          PhotoSize.large,
        ]) {
          await _pumpNote(
            tester,
            _note(side: side, size: size, caption: 'Low tide'),
          );
          _expectFloated(tester);
          final Rect figure = tester.getRect(find.byKey(photoWrapFigureKey));
          final Rect frame = tester.getRect(find.byKey(notePhotoFrameKey));
          expect(figure.contains(frame.topLeft), isTrue);
          for (final Key key in <Key>[photoWrapHeadKey, photoWrapTailKey]) {
            for (final Rect glyph in _glyphRects(_paragraph(tester, key))) {
              expect(
                glyph.overlaps(figure),
                isFalse,
                reason: '$side $size $key $glyph against $figure',
              );
            }
          }
        }
      }
    });

    testWidgets('the cut is always a line start of the band layout', (
      WidgetTester tester,
    ) async {
      for (final double width in <double>[470, 500, 518, 540, 560, 600]) {
        for (final PhotoSize size in <PhotoSize>[
          PhotoSize.small,
          PhotoSize.medium,
          PhotoSize.large,
        ]) {
          await _pumpNote(tester, _note(size: size), width: width);
          _expectFloated(tester);

          final RenderParagraph head = _paragraph(tester, photoWrapHeadKey);
          final RenderParagraph tail = _paragraph(tester, photoWrapTailKey);
          final int cut = head.text.toPlainText().length;
          final TextPainter whole = _painterFor(
            TextSpan(children: <InlineSpan>[head.text, tail.text]),
            head.size.width,
          );
          final TextPainter alone = _painterFor(head.text, head.size.width);

          expect(
            whole.getLineBoundary(TextPosition(offset: cut)).start,
            cut,
            reason: '$width $size',
          );
          final int headLines = alone.computeLineMetrics().length;
          for (int line = 0; line < headLines; line++) {
            final double y = alone.computeLineMetrics()[line].baseline;
            expect(
              alone.getLineBoundary(
                alone.getPositionForOffset(Offset(0, y)),
              ),
              whole.getLineBoundary(
                whole.getPositionForOffset(Offset(0, y)),
              ),
              reason: '$width $size line $line',
            );
          }
          expect(
            whole
                .getLineBoundary(
                  whole.getPositionForOffset(
                    Offset(0, whole.computeLineMetrics()[headLines].baseline),
                  ),
                )
                .start,
            cut,
          );
        }
      }
    });

    testWidgets('lines sit beside the photo while they start above its foot',
        (WidgetTester tester) async {
      await _pumpNote(tester, _note(caption: 'Low tide, from the pilings'));

      final Rect figure = tester.getRect(find.byKey(photoWrapFigureKey));
      final RenderParagraph head = _paragraph(tester, photoWrapHeadKey);
      final TextPainter alone = _painterFor(head.text, head.size.width);
      final List<LineMetrics> lines = alone.computeLineMetrics();
      final double headTop = head.localToGlobal(Offset.zero).dy;

      final LineMetrics last = lines.last;
      expect(headTop + last.baseline - last.ascent, lessThan(figure.bottom));
      expect(
        headTop + last.baseline + last.descent,
        greaterThanOrEqualTo(figure.bottom - 0.01),
      );
    });

    testWidgets('head and tail rejoin to the paragraph with styles intact',
        (WidgetTester tester) async {
      await _pumpNote(tester, _note());

      final InlineSpan head = _paragraph(tester, photoWrapHeadKey).text;
      final InlineSpan tail = _paragraph(tester, photoWrapTailKey).text;
      expect(head.toPlainText() + tail.toPlainText(), _prosePlain);

      final List<TextSpan> runs = <TextSpan>[];
      void collect(InlineSpan span) {
        if (span is TextSpan) {
          runs.add(span);
          span.children?.forEach(collect);
        }
      }

      collect(head);
      collect(tail);
      expect(
        runs.any((TextSpan s) =>
            s.style == noteBoldStyle &&
            s.toPlainText().contains('old pilings')),
        isTrue,
      );
      expect(
        runs.any((TextSpan s) =>
            s.style == noteItalicStyle &&
            s.toPlainText().contains('Nothing moved')),
        isTrue,
      );
    });

    testWidgets('a paragraph that fits beside the photo leaves no tail', (
      WidgetTester tester,
    ) async {
      await _pumpNote(tester, _note(after: 'A short line.'));

      _expectFloated(tester);
      expect(find.byKey(photoWrapTailKey), findsNothing);
      expect(
        _paragraph(tester, photoWrapHeadKey).text.toPlainText(),
        'A short line.',
      );
    });

    testWidgets('a screen reader meets the photo before the paragraph',
        (WidgetTester tester) async {
      final SemanticsHandle semantics = tester.ensureSemantics();
      await _pumpNote(tester, _note(caption: 'Low tide'));
      _expectFloated(tester);

      final List<String> labels = <String>[
        for (final SemanticsNode node
            in tester.semantics.simulatedAccessibilityTraversal())
          if (node.label.isNotEmpty) node.label,
      ];
      final int photo = labels.indexOf('Low tide');
      final int head = labels.indexWhere(
        (String label) => label.startsWith('The tide came in'),
      );
      final int tail = labels.indexWhere(
        (String label) => label.endsWith('salt and cut grass.'),
      );
      expect(photo, greaterThanOrEqualTo(0), reason: '$labels');
      expect(head, greaterThan(photo), reason: '$labels');
      expect(tail, greaterThan(head), reason: '$labels');
      semantics.dispose();
    });

    testWidgets('a system font change re-splits the paragraph',
        (WidgetTester tester) async {
      await _pumpNote(tester, _note());
      final InlineSpan before = _headSpan(tester);

      await tester.binding.handleSystemMessage(
        <String, Object?>{'type': 'fontsChange'},
      );
      await tester.pump();

      _expectFloated(tester);
      expect(identical(_headSpan(tester), before), isFalse);
      expect(
        _headSpan(tester).toPlainText(),
        before.toPlainText(),
      );
    });

    testWidgets('a full-width scope floats across the whole column',
        (WidgetTester tester) async {
      await _pumpNote(tester, _note(), width: 900, fillsWidth: true);

      _expectFloated(tester);
      final Rect frame = tester.getRect(find.byKey(notePhotoFrameKey));
      final Rect head = tester.getRect(find.byKey(photoWrapHeadKey));
      final Rect document = tester.getRect(find.byType(NoteDocument));
      expect(document.width, 900);
      expect(frame.width, 192);
      expect(frame.right, closeTo(document.right, 0.01));
      expect(head.left, closeTo(document.left, 0.01));
      expect(
        tester.getSize(find.byKey(photoWrapFloatKey)).width,
        closeTo(900, 0.01),
      );
    });

    testWidgets('outside a full-width scope the float keeps the 35 em measure',
        (WidgetTester tester) async {
      await _pumpNote(tester, _note(), width: 900);

      _expectFloated(tester);
      final Rect frame = tester.getRect(find.byKey(notePhotoFrameKey));
      final Rect document = tester.getRect(find.byType(NoteDocument));
      expect(frame.right, closeTo(document.left + 35 * _em, 0.01));
    });

    testWidgets('floats at 1.5x text on a 840 column just as it does at 1x',
        (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1000, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await _pumpNote(tester, _note(), width: 840, scale: 1.5);

      _expectFloated(tester);
      expect(tester.getSize(find.byKey(notePhotoFrameKey)).width,
          closeTo(12 * 24, 0.01));
    });
  });

  group('selection', () {
    testWidgets('a drag across the head and tail copies the paragraph exactly',
        (WidgetTester tester) async {
      final List<MethodCall> log = _captureClipboard(tester);
      await _pumpNote(tester, _note());
      await tester.pumpAndSettle();

      final RenderParagraph head = _paragraph(tester, photoWrapHeadKey);
      final RenderParagraph tail = _paragraph(tester, photoWrapTailKey);
      final int cut = head.text.toPlainText().length;
      final TestGesture gesture = await tester.startGesture(
        _caretPoint(head, 4),
        kind: PointerDeviceKind.mouse,
      );
      addTearDown(gesture.removePointer);
      await tester.pump();
      await gesture.moveTo(_caretPoint(tail, 20));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();

      await _pressWithControl(tester, LogicalKeyboardKey.keyC);

      expect(_copiedText(log), _prosePlain.substring(4, cut + 20));
    });

    testWidgets('select all copies the note with the float byte-exact', (
      WidgetTester tester,
    ) async {
      final List<MethodCall> log = _captureClipboard(tester);
      await _pumpNote(
        tester,
        'Before the walk\n\n${_note(caption: 'Low tide')}\n\nAfter the walk',
      );
      await tester.pumpAndSettle();
      _expectFloated(tester);

      final TestGesture gesture = await tester.startGesture(
        _caretPoint(_paragraph(tester, photoWrapTailKey), 2),
        kind: PointerDeviceKind.mouse,
      );
      addTearDown(gesture.removePointer);
      await gesture.up();
      await tester.pumpAndSettle();
      await _pressWithControl(tester, LogicalKeyboardKey.keyA);
      await _pressWithControl(tester, LogicalKeyboardKey.keyC);

      expect(
        _copiedText(log),
        'Before the walk\n\n$_prosePlain\n\nAfter the walk',
      );
    });
  });

  group('the one fallback', () {
    testWidgets('a Full photo stacks', (WidgetTester tester) async {
      await _pumpNote(tester, _note(size: PhotoSize.full));

      expect(find.byType(PhotoWrapBlock), findsOneWidget);
      _expectStacked(tester);
    });

    testWidgets('a photo whose next block is not a paragraph stacks',
        (WidgetTester tester) async {
      for (final String next in <String>[
        '# Heading',
        '- a list item',
        '> a quote',
        photoLine(photoIdB),
      ]) {
        await _pumpNote(tester, '${photoLine(photoIdA)}\n$next');
        expect(find.byType(PhotoWrapBlock), findsNothing, reason: next);
        expect(find.byKey(photoWrapHeadKey), findsNothing, reason: next);
        expect(find.byType(StackedPhoto), findsWidgets, reason: next);
      }
    });

    testWidgets('a photo at the end of the note stacks',
        (WidgetTester tester) async {
      await _pumpNote(tester, '$_prose\n${photoLine(photoIdA)}');

      expect(find.byType(PhotoWrapBlock), findsNothing);
      expect(find.byType(StackedPhoto), findsOneWidget);
    });

    testWidgets('a column narrower than 28.9 em stacks', (
      WidgetTester tester,
    ) async {
      for (final double width in <double>[320, 360, 430, 462]) {
        await _pumpNote(tester, _note(size: PhotoSize.large), width: width);
        _expectStacked(tester);
      }
    });

    testWidgets('missing dimensions stack', (WidgetTester tester) async {
      await _pumpNote(tester, _note(), resolver: _resolver(width: null));

      _expectStacked(tester);
    });

    testWidgets('a corrupt or missing blob stacks with its placeholder',
        (WidgetTester tester) async {
      final FakeNoteMediaResolver missing = FakeNoteMediaResolver();
      await _pumpNote(tester, _note(), resolver: missing);
      await tester.pump();

      _expectStacked(tester);
      expect(find.byKey(notePhotoUnavailableKey), findsOneWidget);
    });

    testWidgets('a photo whose file cannot be decoded falls back to StackedPhoto',
        (WidgetTester tester) async {
      final Directory root =
          Directory.systemTemp.createTempSync('fn_photo_wrap_corrupt');
      addTearDown(() => root.deleteSync(recursive: true));
      final File corrupt = File('${root.path}/corrupt.jpg')
        ..writeAsBytesSync(<int>[1, 2, 3]);
      final FakeNoteMediaResolver resolver = FakeNoteMediaResolver(
        <String, ResolvedMedia>{
          prefixOf(photoIdA): ResolvedMedia.available(
            blob: photoBlob(photoIdA, width: 1200, height: 900),
            file: corrupt,
          ),
        },
      )..memoizeAll();

      await tester.runAsync(
        () => _pumpNote(tester, _note(), resolver: resolver),
      );

      expect(find.byKey(photoWrapFloatKey), findsOneWidget);

      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byKey(photoWrapFloatKey), findsNothing);
      expect(find.byType(StackedPhoto), findsOneWidget);
      expect(find.text(_prosePlain), findsOneWidget);
    });

    testWidgets(
        'a decode failure left by the previous photo does not stack the next',
        (WidgetTester tester) async {
      final Directory root =
          Directory.systemTemp.createTempSync('fn_photo_wrap_swap');
      addTearDown(() => root.deleteSync(recursive: true));
      final File corrupt = File('${root.path}/corrupt.jpg')
        ..writeAsBytesSync(<int>[1, 2, 3]);
      final File decodable = File('${root.path}/decodable.png')
        ..writeAsBytesSync(<int>[
          137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0,
          0, 8, 0, 0, 0, 6, 8, 2, 0, 0, 0, 113, 103, 72, 172, 0, 0, 0, 17, 73,
          68, 65, 84, 120, 156, 99, 56, 145, 98, 132, 21, 49, 12, 164, 4, 0,
          87, 179, 65, 161, 177, 232, 96, 55, 0, 0, 0, 0, 73, 69, 78, 68, 174,
          66, 96, 130,
        ]);
      final FakeNoteMediaResolver resolver = FakeNoteMediaResolver(
        <String, ResolvedMedia>{
          prefixOf(photoIdA): ResolvedMedia.available(
            blob: photoBlob(photoIdA, width: 1200, height: 900),
            file: corrupt,
          ),
          prefixOf(photoIdB): ResolvedMedia.available(
            blob: photoBlob(photoIdB, width: 1200, height: 900),
            file: decodable,
          ),
        },
      )..memoizeAll();

      await tester.runAsync(
        () => _pumpNote(tester, _note(), resolver: resolver),
      );
      expect(find.byKey(photoWrapFloatKey), findsOneWidget);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );

      await tester.runAsync(
        () => _pumpNote(
          tester,
          '${photoLine(photoIdB)}\n$_prose',
          resolver: resolver,
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump();

      expect(find.byKey(photoWrapFloatKey), findsOneWidget);
      expect(find.byType(StackedPhoto), findsNothing);
    });

    testWidgets('the render budget turns every float into a stack',
        (WidgetTester tester) async {
      await _pumpNote(tester, _note(), floatEnabled: false);

      _expectStacked(tester);
    });

    testWidgets('a panorama too short to hold one line stacks, as planned',
        (WidgetTester tester) async {
      await _pumpNote(
        tester,
        _note(),
        resolver: _resolver(width: 4000, height: 200),
      );

      _expectStacked(tester);
      expect(
        planFloat(
          measure: _desktop,
          em: _em,
          side: PhotoSide.right,
          size: PhotoSize.medium,
          aspect: 20,
          nextIsParagraph: true,
        ).isStacked,
        isTrue,
      );
    });

    testWidgets('an unresolved photo stacks until its dimensions arrive',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        notesHarness(
          NoteMediaScope(
            resolver: _resolver(memoized: false),
            child: NoteDocument(source: _note()),
          ),
          width: _desktop,
        ),
      );

      _expectStacked(tester);

      await tester.pump();

      _expectFloated(tester);
    });

    testWidgets('the stacked fallback matches the unpaired rendering',
        (WidgetTester tester) async {
      await _pumpNote(tester, _note(), width: 400);

      final Rect frame = tester.getRect(find.byKey(notePhotoFrameKey));
      final Rect prose = tester.getRect(find.text(_prosePlain));
      expect(frame.width, closeTo(0.75 * 400, 0.01));
      expect(frame.center.dx, closeTo(200, 0.01));
      expect(prose.top - frame.bottom, closeTo(noteParagraphGapEm * _em, 0.01));
      expect(find.byType(NoteParagraphView), findsOneWidget);
    });
  });

  group('the split cache', () {
    testWidgets('a resize inside one band bucket keeps the same head span',
        (WidgetTester tester) async {
      await _pumpNote(tester, _note(), width: 560);
      final InlineSpan first = _headSpan(tester);
      final double firstWidth =
          tester.getSize(find.byKey(photoWrapHeadKey)).width;

      for (final double width in <double>[559, 558.5, 600, 900]) {
        await _pumpNote(tester, _note(), width: width);

        expect(
          identical(_headSpan(tester), first),
          isTrue,
          reason: '$width',
        );
        expect(
          tester.getSize(find.byKey(photoWrapHeadKey)).width,
          firstWidth,
        );
      }
    });

    testWidgets('crossing a bucket re-splits, and widening back holds it',
        (WidgetTester tester) async {
      await _pumpNote(tester, _note(), width: 560);
      final InlineSpan wide = _headSpan(tester);

      await _pumpNote(tester, _note(), width: 540);
      final InlineSpan narrow = _headSpan(tester);
      expect(identical(narrow, wide), isFalse);

      await _pumpNote(tester, _note(), width: 544);
      expect(
        identical(_headSpan(tester), narrow),
        isTrue,
      );

      await _pumpNote(tester, _note(), width: 539);
      expect(
        identical(_headSpan(tester), narrow),
        isTrue,
      );
    });
  });

  group('tilt', () {
    testWidgets('the paper and its shadow paint inside the reserved box',
        (WidgetTester tester) async {
      for (final PhotoSide side in PhotoSide.values) {
        await _pumpNote(tester, _note(side: side));
        _expectFloated(tester);

        final Rect box = tester.getRect(find.byKey(notePhotoFrameKey));
        final RenderBox paper = tester.renderObject<RenderBox>(
          find
              .descendant(
                of: find.byKey(notePhotoFrameKey),
                matching: find.byType(DecoratedBox),
              )
              .first,
        );
        final Matrix4 toGlobal = paper.getTransformTo(null);
        final List<Offset> corners = <Offset>[
          for (final Offset corner in <Offset>[
            Offset.zero,
            Offset(paper.size.width, 0),
            Offset(0, paper.size.height),
            Offset(paper.size.width, paper.size.height),
          ])
            MatrixUtils.transformPoint(toGlobal, corner),
        ];
        final Rect painted = Rect.fromPoints(corners.first, corners.first)
            .expandToInclude(Rect.fromPoints(corners[1], corners[2]))
            .expandToInclude(Rect.fromPoints(corners[3], corners[3]));

        expect(notePhotoTiltDegrees(prefixOf(photoIdA)), isNot(0));
        expect(painted.width, isNot(closeTo(paper.size.width, 1e-6)));
        expect(
          box.inflate(0.01).contains(painted.inflate(2).topLeft) &&
              box.inflate(0.01).contains(painted.inflate(2).bottomRight),
          isTrue,
          reason: '$side: $painted inside $box',
        );
      }
    });

    test('the fit scale leaves room for tilt and shadow at every aspect', () {
      for (final double degrees in notePhotoTiltsDegrees) {
        final double radians = degrees * math.pi / 180;
        for (final double aspect in <double>[4, 1.5, 1, 9 / 16]) {
          final PhotoPlan plan = planFloat(
            measure: _desktop,
            em: _em,
            side: PhotoSide.right,
            size: PhotoSize.medium,
            aspect: aspect,
            nextIsParagraph: true,
          );
          final double w = plan.width;
          final double h = plan.height;
          final double scale = notePhotoFitScale(w, h, radians);
          final double sin = math.sin(radians).abs();
          final double cos = math.cos(radians).abs();
          expect(scale * (w * cos + h * sin), lessThanOrEqualTo(w));
          expect(scale * (w * sin + h * cos), lessThanOrEqualTo(h));
          expect(
            scale * w + scale * h * sin,
            lessThanOrEqualTo(w + 1e-9),
            reason: '$degrees $aspect',
          );
        }
      }
    });
  });

  test('the frame box is the height clamp for a tall portrait', () {
    final PhotoPlan plan = planFloat(
      measure: _desktop,
      em: _em,
      side: PhotoSide.left,
      size: PhotoSize.medium,
      aspect: 9 / 16,
      nextIsParagraph: true,
    );
    expect(plan.isStacked, isFalse);
    expect(plan.height, closeTo(photoHeightClamp * plan.width, 1e-9));
  });
}
