import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/layout/block_layout.dart';
import 'package:field_notes/features/note_engine/layout/line_fragments.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/note_layout_engine.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/render/note_view.dart';
import 'package:field_notes/features/note_engine/render/photo_figure.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';

import '../../notes/support/notes_harness.dart';

const String _lowTide = '![Low tide](photo/a1b2c3d4e5f6 "right medium")';
const String _tideNote = 'A\n\n$_lowTide\n\nB';

void _pinSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

FakeNoteMediaResolver _tideResolver() =>
    FakeNoteMediaResolver(<String, ResolvedMedia>{
      prefixOf(photoIdA): availablePhoto(photoIdA),
      'bbbbbbbbbbbb': availablePhoto('bbbbbbbbbbbb'),
    })..memoizeAll();

final class _Harness {
  _Harness();

  final NoteLayoutEngine engine = NoteLayoutEngine(
    projector: const NoteVisibleProjector(),
  );
  final GlobalKey renderKey = GlobalKey();
  final List<LayoutInputs> inputs = <LayoutInputs>[];

  LaidOutNote runLayout(LayoutInputs given) {
    inputs.add(given);
    return engine.layout(given);
  }

  RenderNoteView get view =>
      renderKey.currentContext!.findRenderObject()! as RenderNoteView;
}

Widget _app(Widget child, {required double width, double? height}) =>
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );

NoteView _noteView(
  _Harness harness,
  String source, {
  MediaResolver? mediaResolver,
  int? activeLine,
  int? projectedLine,
  NoteSelection? selection,
  bool focused = false,
  bool readOnly = false,
  ScrollController? scrollController,
  double bottomInset = 0,
  String hintText = '',
  Color? selectionColor,
  NoteViewDelegate? delegate,
  LayerLink? startHandleLayerLink,
  LayerLink? endHandleLayerLink,
  bool selectedCaptionHidden = false,
  List<NoteViewDecoration> decorations = const <NoteViewDecoration>[],
  VoidCallback? onFontsChanged,
}) {
  final MdTree tree = parseNoteTree(source);
  return NoteView(
    source: source,
    tree: tree,
    visibleText: const NoteVisibleProjector().project(
      source,
      tree,
      projectedLine ?? activeLine,
    ),
    runLayout: harness.runLayout,
    mediaResolver: mediaResolver,
    activeLine: activeLine,
    selection: selection,
    focused: focused,
    readOnly: readOnly,
    scrollController: scrollController,
    bottomInset: bottomInset,
    hintText: hintText,
    selectionColor: selectionColor,
    delegate: delegate,
    startHandleLayerLink: startHandleLayerLink,
    endHandleLayerLink: endHandleLayerLink,
    selectedCaptionHidden: selectedCaptionHidden,
    decorations: decorations,
    renderKey: harness.renderKey,
    onFontsChanged: onFontsChanged,
  );
}

PhotoRect _photoRect(RenderNoteView view, String reference, int occurrence) =>
    view.noteLayout.photoRects.singleWhere(
      (PhotoRect rect) =>
          rect.reference == reference && rect.occurrence == occurrence,
    );

List<Symbol> _paintCalls(RenderNoteView view) {
  final List<Symbol> calls = <Symbol>[];
  expect(
    view,
    paints..everything((Symbol method, List<dynamic> arguments) {
      calls.add(method);
      return true;
    }),
  );
  return List<Symbol>.unmodifiable(calls);
}

List<Rect> _paintedRects(RenderNoteView view, Color color) {
  final List<Rect> rects = <Rect>[];
  expect(
    view,
    paints..everything((Symbol method, List<dynamic> arguments) {
      if (method == #drawRect &&
          (arguments[1] as Paint).color.toARGB32() == color.toARGB32()) {
        rects.add(arguments[0] as Rect);
      }
      return true;
    }),
  );
  return List<Rect>.unmodifiable(rects);
}

final class _RecordingDelegate implements NoteViewDelegate {
  final List<String> calls = <String>[];

  @override
  void copySelection() => calls.add('copy');

  @override
  void cutSelection() => calls.add('cut');

  @override
  void pasteClipboard() => calls.add('paste');

  @override
  void replaceVisibleText(String text) => calls.add('replace $text');

  @override
  void selectPhoto(int lineStart) => calls.add('selectPhoto $lineStart');

  @override
  void selectVisible(TextSelection selection) => calls.add('select $selection');

  @override
  void toggleCheckbox(int boxStart) => calls.add('toggle $boxStart');
}

final class _MarkDecoration extends NoteViewDecoration {
  const _MarkDecoration(this.rect, {this.log});

  final Rect rect;
  final List<(NoteLayout, Rect?)>? log;

  @override
  void paint(
    Canvas canvas,
    NoteLayout layout,
    Rect? Function(Rect contentRect) place,
  ) {
    log?.add((layout, place(rect)));
    canvas.drawCircle(rect.center, 3, Paint()..color = const Color(0xFF123456));
  }

  @override
  bool shouldRepaint(_MarkDecoration oldDecoration) =>
      oldDecoration.rect != rect;
}

final class _OtherDecoration extends NoteViewDecoration {
  const _OtherDecoration();

  @override
  void paint(
    Canvas canvas,
    NoteLayout layout,
    Rect? Function(Rect contentRect) place,
  ) {}

  @override
  bool shouldRepaint(_OtherDecoration oldDecoration) => false;
}

final class _CountingResolver implements MediaResolver {
  _CountingResolver(this.results);

  final Map<String, ResolvedMedia> results;
  final List<String?> asked = <String?>[];

  @override
  Future<ResolvedMedia> resolve(String? mediaId) async {
    asked.add(mediaId);
    return results[mediaId] ?? const ResolvedMedia.missing();
  }

  @override
  ResolvedMedia? resolved(String? mediaId) {
    asked.add(mediaId);
    return null;
  }
}

String _tableRow() =>
    '| ${List<String>.filled(20, 'abcdefghij').join(' | ')} |';

String _tableSource() => <String>[
  _tableRow(),
  '|${List<String>.filled(20, ' --- ').join('|')}|',
  _tableRow(),
].join('\n');

LaidOutRow _tableRowOf(RenderNoteView view) => view.noteLayout.flow.rows
    .firstWhere((LaidOutRow row) => row.row.kind == LayoutRowKind.table);

double? _orderOf(PhotoFigure figure) {
  final SemanticsSortKey? key = figure.semanticsSortKey;
  return key is OrdinalSortKey ? key.order : null;
}

Offset _layerGlobal(Layer layer, Offset offset) {
  Offset total = offset;
  Layer? parent = layer.parent;
  while (parent != null) {
    if (parent is OffsetLayer) {
      total += parent.offset;
    }
    parent = parent.parent;
  }
  return total;
}

void main() {
  testWidgets('photo figures are keyed by reference and occurrence', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final _Harness harness = _Harness();
    final String source = <String>[
      '![a](photo/aaaaaaaaaaaa "right medium")',
      '![b](photo/bbbbbbbbbbbb "left small")',
      '![c](photo/aaaaaaaaaaaa "centre large")',
      '![d](photo/ABC123ABC123)',
    ].join('\n\n');
    final FakeNoteMediaResolver resolver =
        FakeNoteMediaResolver(<String, ResolvedMedia>{
          'aaaaaaaaaaaa': availablePhoto('aaaaaaaaaaaa'),
          'bbbbbbbbbbbb': availablePhoto('bbbbbbbbbbbb'),
        })..memoizeAll();
    await tester.pumpWidget(
      _app(_noteView(harness, source, mediaResolver: resolver), width: 688),
    );
    await tester.pump();

    expect(
      notePhotoKey('aaaaaaaaaaaa', 1),
      const ValueKey<String>('photo-aaaaaaaaaaaa-1'),
    );
    final RenderNoteView view = harness.view;
    final List<(String, int, String)> expected = <(String, int, String)>[
      ('aaaaaaaaaaaa', 0, 'a'),
      ('bbbbbbbbbbbb', 0, 'b'),
      ('aaaaaaaaaaaa', 1, 'c'),
      ('ABC123ABC123', 0, 'd'),
    ];
    for (final (String reference, int occurrence, String caption) in expected) {
      final Finder figure = find.byKey(notePhotoKey(reference, occurrence));
      expect(figure, findsOneWidget);
      final Finder text = find.descendant(
        of: find.descendant(
          of: figure,
          matching: find.byKey(photoFigureCaptionKey),
        ),
        matching: find.byType(Text),
      );
      expect(tester.widget<Text>(text).data, caption);
      final Offset expectedTopLeft = view.contentToGlobal(
        _photoRect(view, reference, occurrence).rect.topLeft,
      );
      final Offset actual = tester.getTopLeft(figure);
      expect(actual.dx, closeTo(expectedTopLeft.dx, 0.5));
      expect(actual.dy, closeTo(expectedTopLeft.dy, 0.5));
    }
    expect(find.byKey(notePhotoKey('aaaaaaaaaaaa', 2)), findsNothing);
    expect(find.byKey(notePhotoKey('abc123abc123', 0)), findsNothing);
  });

  testWidgets('pressing enter above a photo keeps its element mounted', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final _Harness harness = _Harness();
    final FakeNoteMediaResolver resolver = _tideResolver();
    expect(_tideNote.length, 52);
    await tester.pumpWidget(
      _app(
        _noteView(
          harness,
          _tideNote,
          mediaResolver: resolver,
          activeLine: 0,
          selection: const NoteSelection.collapsed(1),
          focused: true,
        ),
        width: 688,
      ),
    );
    await tester.pump();
    final Finder figure = find.byKey(notePhotoKey('a1b2c3d4e5f6', 0));
    final Element element = figure.evaluate().single;
    final Finder stateful = find
        .descendant(
          of: figure,
          matching: find.byWidgetPredicate(
            (Widget widget) => widget is StatefulWidget,
          ),
        )
        .first;
    final State<StatefulWidget> state = tester.state(stateful);
    final double top = tester.getTopLeft(figure).dy;

    final String entered = '\n$_tideNote';
    await tester.pumpWidget(
      _app(
        _noteView(
          harness,
          entered,
          mediaResolver: resolver,
          activeLine: 1,
          selection: const NoteSelection.collapsed(1),
          focused: true,
        ),
        width: 688,
      ),
    );
    await tester.pump();
    expect(identical(figure.evaluate().single, element), isTrue);
    expect(element.mounted, isTrue);
    expect(identical(tester.state(stateful), state), isTrue);
    expect(tester.getTopLeft(figure).dy - top, closeTo(25.6, 0.5));

    await tester.pumpWidget(
      _app(
        _noteView(
          harness,
          '![x](photo/bbbbbbbbbbbb)\n$entered',
          mediaResolver: resolver,
          activeLine: 2,
          selection: const NoteSelection.collapsed(26),
          focused: true,
        ),
        width: 688,
      ),
    );
    await tester.pump();
    expect(identical(figure.evaluate().single, element), isTrue);
    expect(element.mounted, isTrue);
    final Element inserted = find
        .byKey(notePhotoKey('bbbbbbbbbbbb', 0))
        .evaluate()
        .single;
    expect(identical(inserted, element), isFalse);
  });

  testWidgets('only fragments near the viewport are painted', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final _Harness harness = _Harness();
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    final String source = <String>[
      for (int i = 0; i < 400; i++) 'Paragraph $i of the harbour log.',
    ].join('\n\n');
    await tester.pumpWidget(
      _app(
        _noteView(harness, source, scrollController: controller),
        width: 600,
        height: 400,
      ),
    );
    final RenderNoteView view = harness.view;
    controller.jumpTo(view.noteLayout.size.height / 2);
    await tester.pump();
    final double pixels = controller.offset;
    final List<Rect> painted = view.debugPaintedFragmentRects;
    expect(painted, isNotEmpty);
    final Rect window = Rect.fromLTRB(0, pixels - 400, 600, pixels + 800);
    for (final Rect rect in painted) {
      expect(rect.overlaps(window), isTrue, reason: '$rect');
    }
    final Rect visible = Rect.fromLTRB(0, pixels, 600, pixels + 400);
    expect(painted.any((Rect rect) => rect.overlaps(visible)), isTrue);
    expect(
      painted.length,
      lessThan(view.noteLayout.flow.fragments.length / 10),
    );
    expect(painted.any((Rect rect) => rect.top == 0), isFalse);
  });

  testWidgets('a whole-note selection is painted only near the viewport', (
    WidgetTester tester,
  ) async {
    _pinSurface(tester);
    final _Harness harness = _Harness();
    final ScrollController controller = ScrollController();
    addTearDown(controller.dispose);
    const Color highlight = Color(0x663366CC);
    final String source = <String>[
      for (int i = 0; i < 200; i++)
        'Paragraph $i of the harbour log, where the fog lifted over the '
            'moorings and the gulls came back to the pier at noon.',
    ].join('\n\n');
    final NoteSelection all = NoteSelection(anchor: 0, head: source.length);
    await tester.pumpWidget(
      _app(
        _noteView(
          harness,
          source,
          selection: all,
          selectionColor: highlight,
          scrollController: controller,
        ),
        width: 600,
        height: 400,
      ),
    );
    final RenderNoteView view = harness.view;
    controller.jumpTo(view.noteLayout.size.height / 2 + 7);
    await tester.pump();
    final Rect window = view.paintWindow;
    final List<Rect> painted = _paintedRects(view, highlight);
    expect(painted, isNotEmpty);
    for (final Rect rect in painted) {
      expect(rect.overlaps(window), isTrue, reason: '$rect outside $window');
    }
    final List<Rect> whole = view.noteLayout.selectionBoxes(all);
    expect(painted.length, lessThan(whole.length / 10));
    final Rect visible = view.visibleContentRect;
    expect(
      <Rect>[
        for (final Rect rect in painted)
          if (rect.overlaps(visible)) rect,
      ],
      <Rect>[
        for (final Rect rect in whole)
          if (rect.overlaps(visible)) rect,
      ],
    );
  });

  testWidgets(
    'the view attaches one scroll position and reserves the bottom inset',
    (WidgetTester tester) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      final String source = <String>[
        for (int i = 1; i <= 60; i++) 'Line $i',
      ].join('\n');
      await tester.pumpWidget(
        _app(
          _noteView(
            harness,
            source,
            scrollController: controller,
            bottomInset: 120,
          ),
          width: 600,
          height: 400,
        ),
      );
      final RenderNoteView view = harness.view;
      expect(controller.positions.length, 1);
      expect(
        controller.position.maxScrollExtent,
        closeTo(view.noteLayout.size.height + 120 - 400, 0.01),
      );
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(
        view.contentToLocal(Offset(0, view.noteLayout.size.height)).dy,
        closeTo(280, 0.01),
      );
      expect(
        find.descendant(
          of: find.byType(NoteView),
          matching: find.byWidgetPredicate(
            (Widget widget) => widget is RawScrollbar,
          ),
        ),
        findsNothing,
      );

      await tester.pumpWidget(
        _app(
          _noteView(
            harness,
            'Line 1',
            scrollController: controller,
            bottomInset: 120,
          ),
          width: 600,
          height: 400,
        ),
      );
      await tester.pump();
      expect(controller.position.maxScrollExtent, 0);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  group('media', () {
    testWidgets('waits for stored dimensions before the first layout', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      final FakeNoteMediaResolver resolver = FakeNoteMediaResolver(
        <String, ResolvedMedia>{
          prefixOf(photoIdA): availablePhoto(
            photoIdA,
            width: 1600,
            height: 1200,
          ),
        },
      );
      await tester.pumpWidget(
        _app(
          _noteView(
            harness,
            '![](photo/a1b2c3d4e5f6 "centre medium")',
            mediaResolver: resolver,
          ),
          width: 688,
        ),
      );
      expect(find.byType(NoteViewBody), findsNothing);
      expect(harness.inputs, isEmpty);
      await tester.pump();
      expect(harness.inputs, hasLength(1));
      final Rect image = harness.view.noteLayout.photoRects.single.imageRect;
      expect(image.width, closeTo(344, 0.01));
      expect(image.height, closeTo(258, 0.01));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(harness.inputs, hasLength(1));
    });

    testWidgets('a null resolver lays out at once with pending figures', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      await tester.pumpWidget(_app(_noteView(harness, _tideNote), width: 688));
      expect(harness.inputs, hasLength(1));
      final PhotoFigure figure = tester.widget<PhotoFigure>(
        find.byType(PhotoFigure),
      );
      expect(figure.media, isNull);
      expect(find.byKey(photoFigureFrameKey), findsOneWidget);
    });

    testWidgets('null stored dimensions reflow once after a header read', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final File file = (await tester.runAsync(() async {
        final Directory directory = await Directory.systemTemp.createTemp(
          'note-view-test',
        );
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 4, 3),
          Paint()..color = const Color(0xFF336699),
        );
        final ui.Image image = await recorder.endRecording().toImage(4, 3);
        final ByteData? bytes = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        image.dispose();
        final File written = File('${directory.path}/tide.png');
        await written.writeAsBytes(bytes!.buffer.asUint8List());
        return written;
      }))!;
      expect(
        await tester.runAsync(() => readImageFileSize(file)),
        const Size(4, 3),
      );
      expect(
        await tester.runAsync(
          () => readImageFileSize(File('${file.path}.missing')),
        ),
        isNull,
      );

      final _Harness harness = _Harness();
      final FakeNoteMediaResolver resolver =
          FakeNoteMediaResolver(<String, ResolvedMedia>{
            prefixOf(photoIdA): ResolvedMedia.available(
              blob: photoBlob(photoIdA, width: null, height: null),
              file: file,
            ),
          })..memoizeAll();
      await tester.pumpWidget(
        _app(
          _noteView(
            harness,
            '![](photo/a1b2c3d4e5f6 "centre medium")',
            mediaResolver: resolver,
          ),
          width: 688,
        ),
      );
      expect(harness.inputs, hasLength(1));
      final Rect placeholder =
          harness.view.noteLayout.photoRects.single.imageRect;
      expect(placeholder.width, closeTo(344, 0.01));
      expect(placeholder.height, closeTo(229.33, 0.01));
      for (int i = 0; i < 20 && harness.inputs.length < 2; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
      }
      expect(harness.inputs, hasLength(2));
      final Rect read = harness.view.noteLayout.photoRects.single.imageRect;
      expect(read.width, closeTo(344, 0.01));
      expect(read.height, closeTo(258, 0.01));
      await tester.pump();
      expect(harness.inputs, hasLength(2));
    });

    testWidgets('a missing photo lays out as unavailable at once', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      final FakeNoteMediaResolver resolver = FakeNoteMediaResolver(
        <String, ResolvedMedia>{
          prefixOf(photoIdA): const ResolvedMedia.missing(),
        },
      );
      await tester.pumpWidget(
        _app(
          _noteView(
            harness,
            '![](photo/a1b2c3d4e5f6 "centre medium")',
            mediaResolver: resolver,
          ),
          width: 688,
        ),
      );
      await tester.pump();
      expect(harness.inputs, hasLength(1));
      expect(harness.inputs.single.unavailableMedia, <String>{'a1b2c3d4e5f6'});
      final Rect image = harness.view.noteLayout.photoRects.single.imageRect;
      expect(image.width, closeTo(344, 0.01));
      expect(image.height, closeTo(56, 0.01));
    });

    testWidgets('a decode failure lays out once more and then stays still', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      await tester.pumpWidget(
        _app(
          _noteView(harness, _tideNote, mediaResolver: _tideResolver()),
          width: 688,
        ),
      );
      expect(harness.inputs, hasLength(1));
      final VoidCallback onDecodeError = tester
          .widget<PhotoFigure>(find.byType(PhotoFigure))
          .onDecodeError!;
      onDecodeError();
      await tester.pump();
      expect(harness.inputs, hasLength(2));
      expect(harness.inputs.last.unavailableMedia, <String>{'a1b2c3d4e5f6'});
      expect(
        tester.widget<PhotoFigure>(find.byType(PhotoFigure)).media?.isAvailable,
        isFalse,
      );
      onDecodeError();
      expect(tester.binding.hasScheduledFrame, isFalse);
      await tester.binding.delayed(const Duration(seconds: 1));
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(harness.inputs, hasLength(2));
    });

    testWidgets('an unresolvable reference never reaches the resolver', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      final _CountingResolver resolver = _CountingResolver(
        <String, ResolvedMedia>{prefixOf(photoIdA): availablePhoto(photoIdA)},
      );
      await tester.pumpWidget(
        _app(
          _noteView(
            harness,
            '![d](photo/ABC123ABC123)\n\n$_lowTide',
            mediaResolver: resolver,
          ),
          width: 688,
        ),
      );
      await tester.pump();
      expect(resolver.asked, contains('a1b2c3d4e5f6'));
      expect(resolver.asked, isNot(contains('ABC123ABC123')));
      expect(harness.inputs.last.unavailableMedia, contains('ABC123ABC123'));
    });
  });

  group('painting and sizing', () {
    testWidgets('the hint paints only while the source is empty', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      await tester.pumpWidget(_app(_noteView(harness, ''), width: 600));
      final int without = _paintCalls(
        harness.view,
      ).where((Symbol call) => call == #drawParagraph).length;
      await tester.pumpWidget(
        _app(_noteView(harness, '', hintText: 'Write something'), width: 600),
      );
      final int withHint = _paintCalls(
        harness.view,
      ).where((Symbol call) => call == #drawParagraph).length;
      expect(withHint, without + 1);
      await tester.pumpWidget(
        _app(_noteView(harness, 'A', hintText: 'Write something'), width: 600),
      );
      final int typed = _paintCalls(
        harness.view,
      ).where((Symbol call) => call == #drawParagraph).length;
      expect(typed, without);
    });

    testWidgets('without a scroll controller the box fits its content', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      await tester.pumpWidget(
        _app(
          _noteView(harness, 'One\n\nTwo\n\nThree', bottomInset: 40),
          width: 600,
        ),
      );
      final RenderNoteView view = harness.view;
      expect(view.size.height, view.noteLayout.size.height + 40);
      expect(view.getDryLayout(const BoxConstraints(maxWidth: 600)), view.size);
    });

    testWidgets('a decoration paints after the photos and repaints on change', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      final List<(NoteLayout, Rect?)> log = <(NoteLayout, Rect?)>[];
      final _MarkDecoration mark = _MarkDecoration(
        const Rect.fromLTWH(10, 10, 20, 20),
        log: log,
      );
      await tester.pumpWidget(
        _app(
          _noteView(
            harness,
            '![](photo/a1b2c3d4e5f6 "centre medium")',
            decorations: <NoteViewDecoration>[mark],
          ),
          width: 688,
        ),
      );
      final RenderNoteView view = harness.view;
      expect(log, isNotEmpty);
      expect(identical(log.last.$1, view.noteLayout), isTrue);
      expect(log.last.$2, const Rect.fromLTWH(10, 10, 20, 20));
      final List<Symbol> calls = _paintCalls(view);
      final int circle = calls.indexOf(#drawCircle);
      expect(circle, greaterThan(0));
      const Set<Symbol> neutral = <Symbol>{
        #save,
        #restore,
        #translate,
        #clipRect,
        #transform,
        #scale,
        #rotate,
        #saveLayer,
      };
      final List<Symbol> draws = <Symbol>[
        for (final Symbol call in calls)
          if (!neutral.contains(call)) call,
      ];
      expect(draws.length, greaterThan(1));
      expect(draws.last, #drawCircle);

      await tester.pumpWidget(
        _app(
          _noteView(
            harness,
            '![](photo/a1b2c3d4e5f6 "centre medium")',
            decorations: <NoteViewDecoration>[
              const _MarkDecoration(Rect.fromLTWH(10, 10, 20, 20)),
            ],
          ),
          width: 688,
        ),
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
      view.decorations = <NoteViewDecoration>[
        const _MarkDecoration(Rect.fromLTWH(10, 10, 20, 20)),
      ];
      expect(view.debugNeedsPaint, isFalse);
      expect(tester.binding.hasScheduledFrame, isFalse);
      view.decorations = const <NoteViewDecoration>[];
      expect(view.debugNeedsPaint, isTrue);
      await tester.pump();
      view.decorations = <NoteViewDecoration>[
        const _MarkDecoration(Rect.fromLTWH(10, 10, 20, 20)),
      ];
      await tester.pump();
      view.decorations = const <NoteViewDecoration>[_OtherDecoration()];
      expect(view.debugNeedsPaint, isTrue);
      await tester.pump();
    });

    testWidgets('a font change lays the note out again', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      int fontChanges = 0;
      await tester.pumpWidget(
        _app(
          _noteView(
            harness,
            'The harbour was quiet.',
            onFontsChanged: () => fontChanges++,
          ),
          width: 600,
        ),
      );
      expect(harness.inputs, hasLength(1));
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/system',
        SystemChannels.system.codec.encodeMessage(const <String, dynamic>{
          'type': 'fontsChange',
        }),
        (ByteData? data) {},
      );
      await tester.pump();
      expect(fontChanges, 1);
      expect(harness.inputs, hasLength(2));
      expect(harness.inputs.last, harness.inputs.first);
    });

    testWidgets('a read-only view ignores the active line', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      await tester.pumpWidget(
        _app(
          _noteView(harness, '**Harbour** day', activeLine: 0, readOnly: true),
          width: 600,
        ),
      );
      expect(tester.takeException(), isNull);
      final LayoutInputs inputs = harness.inputs.single;
      expect(inputs.activeLine, isNull);
      expect(inputs.visibleText.activeLine, isNull);
      expect(inputs.visibleText.text, 'Harbour day');
      expect(inputs.readerMode, isTrue);
      expect(harness.view.activeLine, isNull);
    });

    testWidgets(
      'selection colour follows the text field on each platform',
      (WidgetTester tester) async {
        _pinSurface(tester);
        final _Harness harness = _Harness();
        await tester.pumpWidget(
          _app(
            DefaultSelectionStyle(child: _noteView(harness, 'Harbour')),
            width: 600,
          ),
        );
        final BuildContext context = tester.element(find.byType(NoteView));
        final Color expected = Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.4);
        expect(harness.view.selectionColor, expected);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets(
      'selection colour follows the cupertino theme on macOS',
      (WidgetTester tester) async {
        _pinSurface(tester);
        final _Harness harness = _Harness();
        await tester.pumpWidget(
          _app(
            DefaultSelectionStyle(child: _noteView(harness, 'Harbour')),
            width: 600,
          ),
        );
        final BuildContext context = tester.element(find.byType(NoteView));
        expect(
          harness.view.selectionColor,
          CupertinoTheme.of(context).primaryColor.withValues(alpha: 0.4),
        );
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  });

  group('selected photos', () {
    test('noteSelectedPhotoRange takes the line or the line and its break', () {
      final MdTree tree = parseNoteTree(_tideNote);
      const TextRange line = TextRange(start: 3, end: 49);
      TextRange? selected(NoteSelection? selection) =>
          noteSelectedPhotoRange(tree, _tideNote, selection);
      expect(selected(null), isNull);
      expect(selected(const NoteSelection.collapsed(3)), line);
      expect(selected(const NoteSelection.collapsed(20)), line);
      expect(selected(const NoteSelection.collapsed(49)), line);
      expect(selected(const NoteSelection(anchor: 3, head: 49)), line);
      expect(selected(const NoteSelection(anchor: 50, head: 3)), line);
      expect(selected(const NoteSelection(anchor: 3, head: 52)), isNull);
      expect(selected(const NoteSelection(anchor: 4, head: 49)), isNull);
      expect(selected(const NoteSelection.collapsed(0)), isNull);

      const String crlf = 'A\r\n\r\n$_lowTide\r\n\r\nB';
      final MdTree crlfTree = parseNoteTree(crlf);
      const TextRange crlfLine = TextRange(start: 5, end: 51);
      expect(
        noteSelectedPhotoRange(
          crlfTree,
          crlf,
          const NoteSelection(anchor: 5, head: 53),
        ),
        crlfLine,
      );
      expect(
        noteSelectedPhotoRange(
          crlfTree,
          crlf,
          const NoteSelection(anchor: 5, head: 52),
        ),
        isNull,
      );
    });

    testWidgets('the selected figure and every sort key', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      final String source = '$_tideNote\n\n![x](photo/bbbbbbbbbbbb)';
      List<PhotoFigure> figures() => tester
          .widgetList<PhotoFigure>(find.byType(PhotoFigure))
          .toList(growable: false);
      Future<void> pump({required bool hidden, bool readOnly = false}) =>
          tester.pumpWidget(
            _app(
              _noteView(
                harness,
                source,
                mediaResolver: _tideResolver(),
                selection: const NoteSelection.collapsed(10),
                selectedCaptionHidden: hidden,
                readOnly: readOnly,
                activeLine: readOnly ? null : 2,
              ),
              width: 688,
            ),
          );
      await pump(hidden: true);
      expect(figures()[0].selected, isTrue);
      expect(figures()[0].captionHidden, isTrue);
      expect(figures()[1].selected, isFalse);
      expect(figures()[1].captionHidden, isFalse);
      await pump(hidden: false);
      expect(figures()[0].captionHidden, isFalse);
      expect(_orderOf(figures()[0]), 3);
      expect(_orderOf(figures()[1]), 54);
      await pump(hidden: false, readOnly: true);
      expect(_orderOf(figures()[0]), 3);
      expect(_orderOf(figures()[1]), 54);
      expect(figures()[0].onActivate, isNull);
    });
  });

  group('layers and hit testing', () {
    testWidgets('handle leaders sit at the clamped selection endpoints', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      final LayerLink start = LayerLink();
      final LayerLink end = LayerLink();
      final String source = <String>[
        for (int i = 0; i < 60; i++) 'Line $i of the harbour log.',
      ].join('\n');
      Future<void> pump() => tester.pumpWidget(
        _app(
          _noteView(
            harness,
            source,
            selection: const NoteSelection(anchor: 2, head: 40),
            scrollController: controller,
            startHandleLayerLink: start,
            endHandleLayerLink: end,
          ),
          width: 600,
          height: 400,
        ),
      );
      await pump();
      final RenderNoteView view = harness.view;
      final SelectionEndpoints endpoints = view.noteLayout.selectionEndpoints(
        const NoteSelection(anchor: 2, head: 40),
      );
      final List<LeaderLayer> leaders = tester.layers
          .whereType<LeaderLayer>()
          .toList(growable: false);
      expect(leaders, hasLength(2));
      for (final (LayerLink link, Offset point) in <(LayerLink, Offset)>[
        (start, endpoints.start.point),
        (end, endpoints.end.point),
      ]) {
        final LeaderLayer leader = leaders.singleWhere(
          (LeaderLayer layer) => identical(layer.link, link),
        );
        final Offset local = view.contentToLocal(point);
        final Offset clamped = Offset(
          local.dx.clamp(0, view.size.width),
          local.dy.clamp(0, view.size.height),
        );
        expect(
          _layerGlobal(leader, leader.offset),
          view.localToGlobal(clamped),
        );
      }
      expect(view.selectionStartInViewport.value, isTrue);
      controller.jumpTo(300);
      await tester.pump();
      expect(view.selectionStartInViewport.value, isFalse);
    });

    testWidgets('a scrolled photo is hit and activated', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      final _Harness harness = _Harness();
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      final _RecordingDelegate delegate = _RecordingDelegate();
      final String before = <String>[
        for (int i = 0; i < 20; i++) 'Line $i',
      ].join('\n\n');
      final String source = '$before\n\n$_lowTide\n\nAfter';
      final int lineStart = source.indexOf(_lowTide);
      await tester.pumpWidget(
        _app(
          _noteView(
            harness,
            source,
            mediaResolver: _tideResolver(),
            scrollController: controller,
            delegate: delegate,
          ),
          width: 688,
          height: 400,
        ),
      );
      controller.jumpTo(900);
      await tester.pump();
      final Finder figure = find.byKey(notePhotoKey('a1b2c3d4e5f6', 0));
      final RenderObject child = figure.evaluate().single.renderObject!;
      final Offset centre = tester.getCenter(figure);
      final HitTestResult result = HitTestResult();
      tester.binding.hitTestInView(result, centre, tester.view.viewId);
      expect(
        result.path.any((HitTestEntry entry) => identical(entry.target, child)),
        isTrue,
      );
      expect(
        harness.view.photoLineAt(harness.view.globalToContent(centre)),
        TextRange(start: lineStart, end: lineStart + _lowTide.length),
      );
      tester.semantics.tap(find.semantics.byLabel('Photo, Low tide'));
      await tester.pump();
      expect(delegate.calls, <String>['selectPhoto $lineStart']);
      handle.dispose();
    });
  });

  group('wide tables', () {
    testWidgets('a table wider than the column scrolls inside itself', (
      WidgetTester tester,
    ) async {
      _pinSurface(tester);
      final _Harness harness = _Harness();
      final ScrollController controller = ScrollController();
      addTearDown(controller.dispose);
      final String table = _tableSource();
      Future<void> pump(String source) => tester.pumpWidget(
        _app(
          _noteView(
            harness,
            source,
            scrollController: controller,
            bottomInset: 600,
          ),
          width: 688,
          height: 400,
        ),
      );
      await pump('$table\n\nAfter.');
      final RenderNoteView view = harness.view;
      final LaidOutRow row = _tableRowOf(view);
      expect(row.contentWidth, closeTo(1301, 1));
      final double inside = row.top + 1;
      final Offset pointer = view.contentToGlobal(Offset(300, inside));
      final TestPointer mouse = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(mouse.hover(pointer));
      await tester.sendEventToBinding(mouse.scroll(const Offset(200, 0)));
      await tester.pump();
      expect(view.tableScrollOffsetAt(inside), 200);
      expect(controller.offset, 0);
      expect(
        view.globalToContent(pointer).dx,
        closeTo(view.globalToLocal(pointer).dx + 200, 0.001),
      );

      final List<LineFragment> cells = row.fragments
          .where((LineFragment f) => f.kind == FragmentKind.tableCell)
          .toList(growable: false);
      final Rect first = cells.first.rect;
      expect(view.placeContentRect(first), isNull);
      final Rect straddling = cells
          .firstWhere(
            (LineFragment f) =>
                f.rect.left - 200 < 688 && f.rect.right - 200 > 688,
          )
          .rect;
      expect(
        view.placeContentRect(straddling),
        Rect.fromLTRB(
          straddling.left - 200,
          straddling.top,
          688,
          straddling.bottom,
        ),
      );

      final LineFragment after = view.noteLayout.flow.rows.last.fragments.first;
      expect(view.tableScrollOffsetAt(after.rect.top + 1), 0);
      expect(view.placeContentRect(after.rect), after.rect);
      expect(view.contentToLocal(after.rect.topLeft).dx, after.rect.left);

      await pump('A\n\n$table\n\nAfter.');
      expect(view.tableScrollOffsetAt(_tableRowOf(view).top + 1), 200);

      final double y = _tableRowOf(view).top + 1;
      expect(view.scrollTableBy(y, 10000), isTrue);
      expect(view.tableScrollOffsetAt(y), closeTo(613, 1));
      expect(view.tableScrollOffsetAt(y), _tableRowOf(view).contentWidth - 688);
      expect(view.scrollTableBy(y, 10), isFalse);

      final Rect firstCell = _tableRowOf(view).fragments
          .firstWhere((LineFragment f) => f.kind == FragmentKind.tableCell)
          .rect;
      view.revealTableRect(firstCell);
      expect(view.tableScrollOffsetAt(y), firstCell.left);
      view.revealTableRect(
        Rect.fromLTRB(0, firstCell.top, 1, firstCell.bottom),
      );
      expect(view.tableScrollOffsetAt(y), 0);

      final Offset over = view.contentToGlobal(Offset(300, y));
      await tester.sendEventToBinding(mouse.hover(over));
      await tester.sendEventToBinding(mouse.scroll(const Offset(0, 100)));
      await tester.pump();
      expect(controller.offset, greaterThan(0));
      expect(view.tableScrollOffsetAt(y), 0);
    });
  });
}
