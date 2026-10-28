import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/icons/chevron_glyph.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/domain/notes/note_photos.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart'
    show ResolvedMedia, logActionsDeleteKey, logActionsEditKey;
import 'package:field_notes/features/entry_cards/media/media_image.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart'
    show LogViewerExit;
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart'
    show logViewerBackKey, logViewerEarlierKey, logViewerLaterKey;
import 'package:field_notes/features/log_viewer/log_viewer_scene.dart';
import 'package:field_notes/features/log_viewer/note_panel_view.dart';
import 'package:field_notes/features/log_viewer/note_sheet_view.dart';
import 'package:field_notes/features/log_viewer/photo_viewer.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart';
import 'package:field_notes/features/log_viewer/viewer_waveform.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/reader/note_reader_view.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';
import 'package:field_notes/features/note_engine/toolbars/table_toolbar.dart';
import 'package:field_notes/features/notes/render/note_photo_block.dart'
    show NoteMediaScope;

import '../../support/photo_line_fixture.dart';
import '../notes/support/notes_harness.dart'
    show FakeNoteMediaResolver, availablePhoto, photoIdA, prefixOf;

const int _mousePointerId = 43;
const int _mouseDevice = 1;

const Color _ink = Color(0xFF4A3B2E);
const Color _white = Color(0xFFFFFFFF);
const Color _mediaGround = Color(0xFF1C1713);

final int _lightRow = _ink.withValues(alpha: 0.06).toARGB32();
final int _dark = _white.withValues(alpha: 0.12).toARGB32();

const Size _desktop = Size(1440, 900);
const Size _phone = Size(384, 832);
const String _date = '2026-07-19';
const String _dayTitle = 'Sunday, July 19';
const String _note = 'Watered the roses.\nTea under the elm.';
const String _openNoteLabel = 'open note';

const Key _playKey = ValueKey<String>('viewer-play');
const Key _glassKey = ValueKey<String>('viewer-glass');
const Key _exitKey = ValueKey<String>('viewer-exit');
const Key _deleteKey = ValueKey<String>('viewer-delete');
const Key _waveKey = ValueKey<String>('viewer-wave');

const String _intro = 'Low tide walk';
const String _todo = 'water the beans';
final String _readerNote = <String>[
  _intro,
  '- [ ] $_todo',
  mdPhotoLine(photoIdA, caption: 'The harbour wall', size: MdPhotoSize.small),
].join('\n\n');

const String _table = '| a | b |\n| --- | --- |\n| c | d |';

const List<NotePhoto> _photos = <NotePhoto>[
  NotePhoto(reference: 'a1b2c3d4e5f6', caption: 'The harbour wall'),
  NotePhoto(reference: 'b2c3d4e5f6a1', caption: 'Gulls on the pier'),
];

enum _Shape { circle, rounded }

enum _Role { button, slider }

class _Row {
  const _Row(
    this.label,
    this.control,
    this.fill,
    this.shape, {
    this.radius,
    this.role = _Role.button,
  });

  final String label;
  final Finder control;
  final int fill;
  final _Shape shape;
  final double? radius;
  final _Role role;
}

Finder _pressableAt(Finder inner) => find
    .ancestor(of: inner, matching: find.byType(Pressable), matchRoot: true)
    .first;

Finder _hoverFill(_Row row) => find.descendant(
  of: row.control,
  matching: find.byWidgetPredicate((Widget widget) {
    if (widget is! DecoratedBox) {
      return false;
    }
    final Decoration decoration = widget.decoration;
    if (decoration is! BoxDecoration ||
        decoration.color?.toARGB32() != row.fill) {
      return false;
    }
    return switch (row.shape) {
      _Shape.circle => decoration.shape == BoxShape.circle,
      _Shape.rounded =>
        decoration.borderRadius == BorderRadius.circular(row.radius!),
    };
  }),
);

MouseCursor? _cursor() =>
    RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(_mouseDevice);

void _view(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding.zero;
  tester.view.viewPadding = FakeViewPadding.zero;
  addTearDown(tester.view.reset);
}

Future<TestGesture> _mousePointer(WidgetTester tester) async {
  final TestGesture mouse = await tester.createGesture(
    kind: PointerDeviceKind.mouse,
    pointer: _mousePointerId,
  );
  await mouse.addPointer(location: Offset.zero);
  addTearDown(mouse.removePointer);
  await tester.pump();
  return mouse;
}

Future<void> _expectRows(
  WidgetTester tester,
  TestGesture mouse,
  List<_Row> rows,
) async {
  for (final _Row row in rows) {
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(row.control, findsOneWidget, reason: row.label);
    expect(_hoverFill(row), findsNothing, reason: row.label);

    await mouse.moveTo(tester.getCenter(row.control));
    await tester.pump();

    expect(_cursor(), SystemMouseCursors.click, reason: row.label);
    expect(_hoverFill(row), findsOneWidget, reason: row.label);
    final SemanticsNode node = tester.getSemantics(
      find
          .descendant(
            of: row.control,
            matching: find.byType(Pressable),
            matchRoot: true,
          )
          .first,
    );
    expect(node, switch (row.role) {
      _Role.button => isSemantics(isButton: true),
      _Role.slider => isSemantics(isSlider: true),
    }, reason: row.label);
    expect(node.label, row.label, reason: row.label);
  }
}

Entry _entry({required String id, required int hour, EntryType? type}) {
  final EntryType kind = type ?? EntryType.text;
  return Entry(
    id: id,
    dayId: 'day-1',
    type: kind,
    textContent: kind == EntryType.text ? _note : null,
    mediaId: kind == EntryType.text ? null : 'voice-blob',
    durationMs: kind == EntryType.text ? null : 65000,
    createdAt: DateTime(2026, 7, 19, hour, 12).millisecondsSinceEpoch,
    updatedAt: 0,
  );
}

LogViewerScene _scene() => LogViewerScene(
  entry: _entry(id: 'morning', hour: 8),
  date: _date,
  dayTitle: _dayTitle,
  mood: null,
  index: 1,
  count: 3,
  earlier: _entry(id: 'dawn', hour: 6, type: EntryType.voice),
  later: _entry(id: 'afternoon', hour: 14),
  exit: LogViewerExit.close,
  onBack: () {},
  onEarlier: () {},
  onLater: () {},
  onDelete: () {},
  onEdit: () {},
);

class _SheetHost extends StatefulWidget {
  const _SheetHost();

  @override
  State<_SheetHost> createState() => _SheetHostState();
}

class _SheetHostState extends State<_SheetHost> {
  final FakeNoteMediaResolver _resolver = FakeNoteMediaResolver();
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return NoteSheetView(
      scene: _scene(),
      resolver: _resolver,
      expanded: _expanded,
      onExpandedChanged: (bool expanded) =>
          setState(() => _expanded = expanded),
    );
  }
}

Future<void> _openFrom(
  WidgetTester tester,
  TargetPlatform platform,
  void Function(BuildContext context) open,
) async {
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform),
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => Center(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => open(context),
              child: const Text(_openNoteLabel),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text(_openNoteLabel));
  await tester.pumpAndSettle();
}

void _openPanel(BuildContext context) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: false,
  barrierLabel: 'Dismiss log viewer',
  barrierColor: Colors.transparent,
  pageBuilder:
      (
        BuildContext dialogContext,
        Animation<double> animation,
        Animation<double> secondaryAnimation,
      ) => DialogHost(
        child: NotePanelView(
          scene: _scene(),
          resolver: FakeNoteMediaResolver(),
        ),
      ),
);

void _openSheet(BuildContext context) => showPhoneSheet<void>(
  context,
  builder: (BuildContext sheetContext) => const _SheetHost(),
);

void _openPhotos(BuildContext context) => showPhotoViewer(
  context,
  photos: _photos,
  initialIndex: 0,
  dayTitle: _dayTitle,
  resolver: FakeNoteMediaResolver()..memoizeAll(),
);

Future<void> _pumpOnMedia(
  WidgetTester tester,
  TargetPlatform platform,
  Widget body,
) async {
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform),
      home: Scaffold(backgroundColor: _mediaGround, body: body),
    ),
  );
  await tester.pump();
}

Widget _viewerPieces() => Column(
  children: <Widget>[
    SizedBox(
      width: 800,
      height: 96,
      child: ViewerTopBar(
        exitLabel: 'Back to note',
        onExit: () {},
        centre: const SizedBox.shrink(),
        onDelete: () {},
        exitKey: _exitKey,
        deleteKey: _deleteKey,
      ),
    ),
    const SizedBox(height: 24),
    ViewerPrimaryButton(
      key: _playKey,
      playing: false,
      diameter: 64,
      onPressed: () {},
    ),
    const SizedBox(height: 24),
    ViewerGlassCircle(
      key: _glassKey,
      label: 'Next',
      glyph: const ChevronGlyph(pointsBack: false, color: _white, size: 15),
      onPressed: () {},
    ),
    const SizedBox(height: 24),
    SizedBox(
      width: 320,
      child: ViewerWaveform(
        key: _waveKey,
        peaks: const <double>[0.2, 0.6, 0.9, 0.4, 0.7, 0.3],
        progress: 0.3,
        active: true,
        height: 48,
        onSeek: (double fraction) {},
      ),
    ),
  ],
);

Future<RenderNoteView> _pumpReader(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: TargetPlatform.macOS),
      home: Material(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: NoteMediaScope(
            resolver: FakeNoteMediaResolver(<String, ResolvedMedia>{
              prefixOf(photoIdA): availablePhoto(
                photoIdA,
                width: 1600,
                height: 600,
              ),
            })..memoizeAll(),
            child: NoteReaderView(
              source: _readerNote,
              onToggleTask: (int box) {},
              onOpenPhoto: (int photo) {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
  return tester.renderObject<RenderNoteView>(
    find.descendant(
      of: find.byType(NoteReaderView),
      matching: find.byType(NoteViewBody),
    ),
  );
}

Offset _globalCentre(RenderNoteView render, Rect content) =>
    render.contentToGlobal(content.center);

Future<void> _pumpToolbar(WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      key: UniqueKey(),
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: TargetPlatform.macOS),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: TableToolbar(
            state: EditorState.create(
              _table,
              parse: (String source) => parseNoteTree(source, tables: true),
              selection: NoteSelection.collapsed(_table.indexOf('c')),
            ),
            enabled: true,
            onTransaction: (Transaction transaction) {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('every viewer and note control shows the click cursor and '
      'hover', (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    try {
      _view(tester, _desktop);
      final TestGesture mouse = await _mousePointer(tester);

      await _pumpOnMedia(tester, TargetPlatform.macOS, _viewerPieces());
      await _expectRows(tester, mouse, <_Row>[
        _Row(
          'Back to note',
          find.byKey(_exitKey),
          _dark,
          _Shape.rounded,
          radius: 17,
        ),
        _Row('Delete', find.byKey(_deleteKey), _dark, _Shape.circle),
        _Row('Play', find.byKey(_playKey), _dark, _Shape.rounded, radius: 32),
        _Row('Next', find.byKey(_glassKey), _dark, _Shape.circle),
        _Row(
          'Playback position',
          find.byKey(_waveKey),
          _dark,
          _Shape.rounded,
          radius: 2,
          role: _Role.slider,
        ),
      ]);

      await mouse.moveTo(Offset.zero);
      await _openFrom(tester, TargetPlatform.macOS, _openPanel);
      await _expectRows(tester, mouse, <_Row>[
        _Row(
          'Close',
          find.byKey(logViewerBackKey),
          _lightRow,
          _Shape.rounded,
          radius: 10,
        ),
        _Row(
          'Earlier log',
          find.byKey(logViewerEarlierKey),
          _lightRow,
          _Shape.rounded,
          radius: 12,
        ),
        _Row(
          'Later log',
          find.byKey(logViewerLaterKey),
          _lightRow,
          _Shape.rounded,
          radius: 12,
        ),
      ]);

      await mouse.moveTo(Offset.zero);
      _view(tester, _phone);
      await _openFrom(tester, TargetPlatform.android, _openSheet);
      await _expectRows(tester, mouse, <_Row>[
        _Row(
          'Close',
          find.byKey(logViewerBackKey),
          _lightRow,
          _Shape.rounded,
          radius: 14,
        ),
        _Row(
          'Edit note',
          find.byKey(logActionsEditKey),
          _dark,
          _Shape.rounded,
          radius: 14,
        ),
        _Row(
          'Delete',
          find.byKey(logActionsDeleteKey),
          _lightRow,
          _Shape.rounded,
          radius: Shapes.radiusSm,
        ),
      ]);

      await mouse.moveTo(Offset.zero);
      await _openFrom(tester, TargetPlatform.android, _openPhotos);
      final Finder photo = _pressableAt(find.byType(MediaImage));
      await mouse.moveTo(tester.getCenter(photo));
      await tester.pump();
      expect(_cursor(), SystemMouseCursors.click);
      expect(
        tester.getSemantics(photo),
        isSemantics(label: 'Show or hide photo controls', isButton: true),
      );

      await mouse.moveTo(Offset.zero);
      _view(tester, _desktop);
      final RenderNoteView reader = await _pumpReader(tester);
      final int introAt = _readerNote.indexOf(_intro);
      final int boxAt = _readerNote.indexOf('- [ ]');
      final Offset text = _globalCentre(
        reader,
        reader.noteLayout.rangeBounds(
          MdRange(introAt, introAt + _intro.length),
        ),
      );
      final Offset box = _globalCentre(
        reader,
        reader.noteLayout.rangeBounds(MdRange(boxAt + 2, boxAt + 5)),
      );
      final Offset picture = _globalCentre(
        reader,
        reader.noteLayout.photoRects.single.imageRect,
      );
      await mouse.moveTo(text);
      await tester.pump();
      expect(_cursor(), isNot(SystemMouseCursors.click));
      await mouse.moveTo(box);
      await tester.pump();
      expect(_cursor(), SystemMouseCursors.click);
      await mouse.moveTo(picture);
      await tester.pump();
      expect(_cursor(), SystemMouseCursors.click);
      await mouse.moveTo(text);
      await tester.pump();
      expect(_cursor(), isNot(SystemMouseCursors.click));
      expect(find.semantics.byLabel(RegExp(_todo)), findsOne);
      expect(find.semantics.byLabel(RegExp('The harbour wall')), findsOne);

      await mouse.moveTo(Offset.zero);
      await _pumpToolbar(tester);
      await _expectRows(tester, mouse, <_Row>[
        _Row(
          'Row above',
          _pressableAt(find.byKey(tableToolbarRowAboveKey)),
          _dark,
          _Shape.rounded,
          radius: 7,
        ),
        _Row(
          'Delete table',
          _pressableAt(find.byKey(tableToolbarDeleteTableKey)),
          _dark,
          _Shape.rounded,
          radius: 7,
        ),
      ]);
    } finally {
      semantics.dispose();
    }
  });
}
