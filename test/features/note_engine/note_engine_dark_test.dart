import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/editor/note_editor_controller.dart';
import 'package:field_notes/features/note_engine/editor/note_editor_view.dart';
import 'package:field_notes/features/note_engine/layout/line_fragments.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/note_layout_engine.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/render/note_view.dart';
import 'package:field_notes/features/note_engine/render/photo_figure.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';
import 'package:field_notes/features/note_engine/toolbars/table_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/theme_harness.dart';

const Size _surface = Size(1200, 2000);
const Color _darkInk = Color(0xFFEDE1E1);
const String _headed =
    '# Harbour\n\n## Tide table\n\n### Low water\n\nThe fog lifted slowly.';

typedef _Raster = ({ByteData pixels, int width, int height});

Widget _column(Widget child) => Align(
  alignment: Alignment.topLeft,
  child: SizedBox(width: 688, height: 800, child: child),
);

Future<RenderNoteView> _pumpNote(
  WidgetTester tester,
  String source, {
  int? activeLine,
}) async {
  final MdTree tree = parseNoteTree(source);
  final NoteLayoutEngine engine = NoteLayoutEngine();
  final bool readOnly = activeLine == null;
  await pumpThemed(
    tester,
    _column(
      NoteView(
        source: source,
        tree: tree,
        visibleText: const NoteVisibleProjector().project(
          source,
          tree,
          activeLine,
        ),
        runLayout: engine.layout,
        activeLine: activeLine,
        readOnly: readOnly,
        focused: !readOnly,
        selection: readOnly ? null : const NoteSelection.collapsed(0),
      ),
    ),
    brightness: Brightness.dark,
    size: _surface,
  );
  return tester.renderObject<RenderNoteView>(find.byType(NoteViewBody));
}

Future<RenderNoteView> _pumpEditor(
  WidgetTester tester,
  String source, {
  bool focused = false,
  bool fromLight = false,
}) async {
  final NoteEditorController controller = NoteEditorController(text: source);
  final FocusNode focusNode = FocusNode();
  final UndoHistoryController undo = UndoHistoryController();
  final ScrollController scroll = ScrollController();
  addTearDown(() {
    scroll.dispose();
    undo.dispose();
    focusNode.dispose();
    controller.dispose();
  });
  final Widget editor = _column(
    NoteEditorView(
      controller: controller,
      focusNode: focusNode,
      undoController: undo,
      scrollController: scroll,
    ),
  );
  for (final Brightness brightness in <Brightness>[
    if (fromLight) Brightness.light,
    Brightness.dark,
  ]) {
    await pumpThemed(tester, editor, brightness: brightness, size: _surface);
    await tester.pump(kThemeAnimationDuration);
  }
  if (focused) {
    focusNode.requestFocus();
    await tester.pump();
    await tester.pump();
  }
  return tester.renderObject<RenderNoteView>(find.byType(NoteViewBody));
}

Future<_Raster> _rasterOf(WidgetTester tester, LaidOutNote note) async {
  final _Raster? raster = await tester.runAsync(() async {
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);
    for (final LineFragment fragment in note.flow.fragments) {
      fragment.paint(canvas, Offset.zero);
    }
    final ui.Picture picture = recorder.endRecording();
    final int width = note.size.width.ceil();
    final int height = note.size.height.ceil();
    final ui.Image image = picture.toImageSync(width, height);
    final ByteData? pixels = await image.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    image.dispose();
    picture.dispose();
    return (pixels: pixels!, width: width, height: height);
  });
  return raster!;
}

Rect _boxOf(LaidOutNote note, String source, String run) {
  final int start = source.indexOf(run);
  expect(start, greaterThanOrEqualTo(0), reason: run);
  return note
      .selectionBoxes(NoteSelection(anchor: start, head: start + run.length))
      .reduce((Rect a, Rect b) => a.expandToInclude(b));
}

List<Color> _pixelsIn(_Raster raster, Rect region) => <Color>[
  for (
    int y = math.max(0, region.top.floor());
    y < math.min(raster.height, region.bottom.ceil());
    y++
  )
    for (
      int x = math.max(0, region.left.floor());
      x < math.min(raster.width, region.right.ceil());
      x++
    )
      if (_pixelAt(raster, x, y) case final Color pixel when pixel.a > 0) pixel,
];

Color _pixelAt(_Raster raster, int x, int y) {
  final int at = (y * raster.width + x) * 4;
  return Color.fromARGB(
    raster.pixels.getUint8(at + 3),
    raster.pixels.getUint8(at),
    raster.pixels.getUint8(at + 1),
    raster.pixels.getUint8(at + 2),
  );
}

List<Color> _opaque(List<Color> pixels) => <Color>[
  for (final Color pixel in pixels)
    if (pixel.a == 1) pixel,
];

Color _peak(List<Color> pixels) =>
    pixels.reduce((Color a, Color b) => b.a > a.a ? b : a);

Color _wash(List<Color> pixels) {
  final Map<int, int> counts = <int, int>{};
  for (final Color pixel in pixels) {
    if (pixel.a < 0.25) {
      counts.update(
        pixel.toARGB32(),
        (int count) => count + 1,
        ifAbsent: () => 1,
      );
    }
  }
  final MapEntry<int, int> most = counts.entries.reduce(
    (MapEntry<int, int> a, MapEntry<int, int> b) => b.value > a.value ? b : a,
  );
  return Color(most.key);
}

Matcher _drawnIn(Color expected, {int rgb = 3, int alpha = 3}) =>
    predicate<Color>(
      (Color actual) =>
          ((actual.r - expected.r) * 255).abs() <= rgb &&
          ((actual.g - expected.g) * 255).abs() <= rgb &&
          ((actual.b - expected.b) * 255).abs() <= rgb &&
          ((actual.a - expected.a) * 255).abs() <= alpha,
      'drawn in $expected',
    );

void _expectInk(List<Color> pixels, Color expected, String reason) {
  final List<Color> opaque = _opaque(pixels);
  expect(opaque, isNotEmpty, reason: reason);
  expect(opaque, everyElement(_drawnIn(expected)), reason: reason);
}

Set<int> _paintedColours(RenderNoteView view) {
  final Set<int> colours = <int>{};
  expect(
    view,
    paints..everything((Symbol method, List<dynamic> arguments) {
      if (method == #drawRect || method == #drawRRect) {
        colours.add((arguments[1] as Paint).color.toARGB32());
      }
      return true;
    }),
  );
  return colours;
}

void main() {
  test('note engine names no light-only colour', () {
    expect(
      lightOnlyTokenUses(<String>[
        'lib/features/note_engine',
        'lib/features/notes',
      ]),
      isEmpty,
    );
  });

  testWidgets('note body and headings paint their dark ink', (
    WidgetTester tester,
  ) async {
    for (final bool editor in <bool>[false, true]) {
      final RenderNoteView view = editor
          ? await _pumpEditor(tester, _headed)
          : await _pumpNote(tester, _headed);
      final LaidOutNote note = view.noteLayout;
      final _Raster raster = await _rasterOf(tester, note);
      for (final String run in <String>[
        'Harbour',
        'Tide table',
        'Low water',
        'The fog lifted slowly.',
      ]) {
        _expectInk(
          _pixelsIn(raster, _boxOf(note, _headed, run)),
          _darkInk,
          '${editor ? 'editor' : 'reader'}: $run',
        );
      }
    }
  });

  testWidgets('a live switch to the dark theme repaints the note in dark ink', (
    WidgetTester tester,
  ) async {
    final RenderNoteView view = await _pumpEditor(
      tester,
      _headed,
      fromLight: true,
    );
    final LaidOutNote note = view.noteLayout;
    final _Raster raster = await _rasterOf(tester, note);
    for (final String run in <String>['Harbour', 'The fog lifted slowly.']) {
      _expectInk(
        _pixelsIn(raster, _boxOf(note, _headed, run)),
        _darkInk,
        'switched: $run',
      );
    }
  });

  testWidgets('links, code, quotes and markers paint their dark colours', (
    WidgetTester tester,
  ) async {
    const String source =
        'See [the chart](https://tides.example) today.\n\n'
        'Use `mooring` here.\n\n'
        '> A quiet line.\n\n'
        '- [x] packed the stove';
    final RenderNoteView view = await _pumpNote(tester, source);
    final LaidOutNote note = view.noteLayout;
    final _Raster raster = await _rasterOf(tester, note);
    _expectInk(
      _pixelsIn(raster, _boxOf(note, source, 'the chart')),
      const Color(0xFFE38F9D),
      'link',
    );
    expect(
      _wash(_pixelsIn(raster, _boxOf(note, source, 'mooring'))),
      _drawnIn(const Color(0x14EDE1E1), rgb: 8),
      reason: 'inline code background',
    );
    expect(_paintedColours(view), contains(0xFF574F4F), reason: 'quote rule');
    _expectInk(
      _pixelsIn(raster, _boxOf(note, source, 'packed the stove')),
      const Color(0xFF9F9191),
      'checked item',
    );

    const String active = '# Harbour\n\nThe fog lifted.';
    final RenderNoteView marked = await _pumpNote(
      tester,
      active,
      activeLine: 0,
    );
    final LaidOutNote markedNote = marked.noteLayout;
    final _Raster markedRaster = await _rasterOf(tester, markedNote);
    expect(
      _peak(_pixelsIn(markedRaster, _boxOf(markedNote, active, '#'))),
      _drawnIn(const Color(0x57EDE1E1), rgb: 8, alpha: 4),
      reason: 'caret-line markdown symbol',
    );
  });

  testWidgets('caret and photo shadow use their dark colours', (
    WidgetTester tester,
  ) async {
    final RenderNoteView editor = await _pumpEditor(
      tester,
      'The fog lifted.',
      focused: true,
    );
    expect(editor.cursorColor, const Color(0xFFE692A0));
    expect(_paintedColours(editor), contains(0xFFE692A0));

    const String photo = '![Low tide](photo/a1b2c3d4e5f6 "right medium")';
    final MdTree tree = parseNoteTree(photo);
    final MdPhotoLine line = MdPhotoLine.ofBlock(tree.blocks.single, photo);
    await pumpThemed(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: PhotoFigure(
          line: line,
          rect: PhotoRect(
            sourceRange: MdRange(0, photo.length),
            reference: line.reference,
            occurrence: 0,
            rect: const Rect.fromLTWH(0, 0, 344, 344 / 1.5 + 28),
            imageRect: const Rect.fromLTWH(0, 0, 344, 344 / 1.5),
            flow: PhotoFlow.floatRight,
          ),
          media: null,
        ),
      ),
      brightness: Brightness.dark,
      size: _surface,
    );
    final List<BoxShadow> shadows = <BoxShadow>[
      for (final DecoratedBox box in tester.widgetList<DecoratedBox>(
        find.descendant(
          of: find.byKey(photoFigureFrameKey),
          matching: find.byType(DecoratedBox),
        ),
      ))
        if (box.decoration case BoxDecoration(:final List<BoxShadow> boxShadow))
          ...boxShadow,
    ];
    expect(shadows, hasLength(1));
    expect(shadows.single.color, const Color(0x29000000));

    const String table = '| a | b |\n| --- | --- |\n| c | d |';
    await pumpThemed(
      tester,
      Align(
        alignment: Alignment.topLeft,
        child: TableToolbar(
          state: EditorState.create(
            table,
            parse: (String text) => parseNoteTree(text, tables: true),
            selection: const NoteSelection.collapsed(2),
          ),
          enabled: true,
          onTransaction: (Transaction transaction) {},
        ),
      ),
      brightness: Brightness.dark,
      size: _surface,
    );
    final DecoratedBox bar = tester.widget<DecoratedBox>(
      find.byKey(tableToolbarKey),
    );
    expect((bar.decoration as BoxDecoration).color, const Color(0xFF2A241D));
  });
}
