import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/notes/markdown/markdown.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/capture/text/editor/note_editor.dart';
import 'package:field_notes/features/capture/text/text_composer_sheet.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/note_engine/commands/inline_format.dart';
import 'package:field_notes/features/note_engine/commands/line_format.dart';
import 'package:field_notes/features/note_engine/document/editor_state.dart';
import 'package:field_notes/features/note_engine/document/selection.dart';
import 'package:field_notes/features/note_engine/document/transaction.dart';
import 'package:field_notes/features/note_engine/layout/note_layout.dart';
import 'package:field_notes/features/note_engine/layout/note_layout_engine.dart';
import 'package:field_notes/features/note_engine/layout/note_typography.dart';
import 'package:field_notes/features/note_engine/note_engine.dart';
import 'package:field_notes/features/note_engine/photos/photo_commands.dart';
import 'package:field_notes/features/note_engine/projection/atomic_objects.dart';
import 'package:field_notes/features/note_engine/projection/visible_text.dart';
import 'package:field_notes/features/note_engine/render/photo_figure.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';

import '../../../support/note_editor_driver.dart';
import '../../../support/photo_line_fixture.dart';
import '../../../support/text_input_messages.dart';
import '../../capture/core/capture_test_support.dart' show captureHarness;
import '../../notes/support/notes_harness.dart'
    show FakeNoteMediaResolver, availablePhoto, photoIdA, prefixOf;

const List<String> _corpus = <String>[
  '',
  'plain text with no markers at all',
  '**bold** and _italic_ and ~~struck~~',
  '# one\n## two\n### three',
  '- first\n- second\n1. third',
  '> quoted line\n> and another',
  'a [link](https://example.com) inside a sentence',
  'inline `code` and a fence:\n```dart\nfinal x = 1;\n```',
  '![alt](photo/7f3ac91b2d4e "right medium")',
  '---',
  'unclosed **bold and _italic',
  '***triple*** and ****quad****',
  'trailing markers **\n_ \n> \n# ',
  'emoji 🌲 with **bold 🌲** inside',
  'windows\r\nline\r\nendings',
  '\n\n\n',
  '   leading spaces and a # not-a-heading',
  '[unclosed](link\nand [another](https://a.b)',
];

const String _markerAlphabet = '*_~`[]()#>- \n.abc';

const String _styleFile = 'markdown_style_controller_test.dart';
const String _keysFile = 'photo_line_keys_test.dart';
const String _formatFile = 'format_actions_test.dart';
const String _editorFile = 'in_place_photo_editor_test.dart';
const String _wrapFile = 'in_place_photo_wrap_test.dart';
const String _singleFile = 'single_field_note_editor_test.dart';
const String _recognizerFile = 'no_recognizer_test.dart';

const String _engineTests = 'test/features/note_engine';
const String _visibleTextObjects =
    '$_engineTests/projection/visible_text_objects_test.dart';
const String _deltaMapping = '$_engineTests/input/delta_mapping_test.dart';
const String _visibleTextBuilder =
    '$_engineTests/projection/visible_text_builder_test.dart';
const String _caretSelection = '$_engineTests/render/caret_selection_test.dart';
const String _controllerTest =
    '$_engineTests/editor/note_editor_controller_test.dart';
const String _photoCommands = '$_engineTests/photos/photo_commands_test.dart';
const String _sideEdit = '$_engineTests/commands/side_edit_property_test.dart';
const String _inlineFormat = '$_engineTests/commands/inline_format_test.dart';
const String _noteView = '$_engineTests/render/note_view_test.dart';
const String _clipboardActions =
    '$_engineTests/gestures/clipboard_actions_test.dart';
const String _editorViewTest = '$_engineTests/editor/note_editor_view_test.dart';
const String _historyTest = '$_engineTests/document/history_test.dart';
const String _floatFlow = '$_engineTests/layout/float_flow_test.dart';
const String _caretGeometry = '$_engineTests/layout/caret_geometry_test.dart';
const String _touchSelection =
    '$_engineTests/gestures/touch_selection_test.dart';
const String _spellChecker = '$_engineTests/spell/spell_checker_test.dart';
const String _composerSeam =
    'test/features/capture/text/composer_editor_seam_test.dart';

const Duration _hold = Duration(milliseconds: 110);
const Duration _longHold = Duration(milliseconds: 600);
const double _tolerance = 0.5;

final String _a = mdPhotoLine(photoIdA);
final String _note = 'one\n$_a\ntwo';
final String _large = mdPhotoLine(photoIdA, size: MdPhotoSize.large);
final String _leftLarge = mdPhotoLine(
  photoIdA,
  side: MdPhotoSide.left,
  size: MdPhotoSize.large,
);
final String _full = mdPhotoLine(photoIdA, size: MdPhotoSize.full);
final String _stacked = 'one\n$_a\n# two';

String _prose(int n) =>
    List<String>.generate(n, (int i) => 'word${i % 7}').join(' ');

String _fuzz(Random random) {
  final int length = random.nextInt(120);
  return String.fromCharCodes(<int>[
    for (int i = 0; i < length; i++)
      _markerAlphabet.codeUnitAt(random.nextInt(_markerAlphabet.length)),
  ]);
}

void _pointer(String path, String name, String why) {
  final String joined = File(
    path,
  ).readAsStringSync().replaceAll(RegExp(r"'\s+'"), '');
  expect(joined, contains("'$name'"), reason: '$why: pointer to $path');
}

MdTree _parse(String source) => parseNoteTree(source, tables: tablesEnabled);

EditorState _state(String source, NoteSelection selection) =>
    EditorState.create(source, parse: _parse, selection: selection);

VisibleText _project(String source, int? activeLine) =>
    const NoteVisibleProjector().project(source, _parse(source), activeLine);

LaidOutNote _layout(String source, {double width = 560, double scale = 1}) =>
    NoteLayoutEngine(projector: const NoteVisibleProjector()).layout(
      LayoutInputs(
        source: source,
        tree: _parse(source),
        visibleText: _project(source, null),
        activeLine: null,
        columnWidth: width,
        textScaler: TextScaler.linear(scale),
        boldText: false,
        locale: const Locale('en'),
        readerMode: false,
        mediaDimensions: <String, Size>{
          prefixOf(photoIdA): const Size(1200, 900),
        },
      ),
    );

double _runWidth(String text, TextStyle style) {
  final TextPainter painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout();
  final double width = painter.width;
  painter.dispose();
  return width;
}

int _lineOf(String source, int offset) =>
    '\n'.allMatches(source.substring(0, offset)).length;

EditorState _applied(
  EditorState state,
  Transaction? transaction,
  String why,
) {
  expect(transaction, isNotNull, reason: why);
  return state.apply(transaction!);
}

int _blockIndex(NoteLayout layout, MdBlockKind kind) =>
    layout.inputs.tree.blocks.indexWhere((MdBlock block) => block.kind == kind);

int _lastBlockIndex(NoteLayout layout, MdBlockKind kind) => layout
    .inputs
    .tree
    .blocks
    .lastIndexWhere((MdBlock block) => block.kind == kind);

List<FragmentInfo> _fragmentsOf(NoteLayout layout, int blockIndex) =>
    <FragmentInfo>[
      for (final FragmentInfo fragment in layout.fragments)
        if (fragment.blockIndex == blockIndex) fragment,
    ];

void _expectRoundTrip(VisibleText visible, int length, String why) {
  final OffsetMap map = visible.map;
  expect(map.sourceLength, length, reason: why);
  for (int o = 0; o <= length; o++) {
    final SourceOffsets back = map.visibleToSource(map.sourceToVisible(o));
    final VisibleSpan? unit = map.spans
        .where(
          (VisibleSpan span) =>
              span.mapsAsUnit &&
              span.sourceRange.start < o &&
              o < span.sourceRange.end,
        )
        .firstOrNull;
    if (unit != null) {
      final List<int> edges = <int>[
        unit.sourceRange.start,
        unit.sourceRange.end,
      ];
      expect(
        edges,
        contains(back.upstream),
        reason: '$why $o inside the unit ${unit.sourceRange}',
      );
      expect(
        edges,
        contains(back.downstream),
        reason: '$why $o inside the unit ${unit.sourceRange}',
      );
      continue;
    }
    expect(back.upstream, lessThanOrEqualTo(o), reason: '$why $o');
    expect(back.downstream, greaterThanOrEqualTo(o), reason: '$why $o');
  }
}

VisibleSpan? _spanOver(VisibleText visible, int start, int end) {
  for (final VisibleSpan span in visible.map.spans) {
    if (span.sourceRange.start == start && span.sourceRange.end == end) {
      return span;
    }
  }
  return null;
}

FakeNoteMediaResolver _resolver() => FakeNoteMediaResolver(
  <String, ResolvedMedia>{
    prefixOf(photoIdA): availablePhoto(photoIdA, width: 1200, height: 900),
  },
)..memoizeAll();

void _pinSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 2000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

class _Harness {
  _Harness(String text) : controller = NoteEditorController(text: text);

  final NoteEditorController controller;
  final FocusNode focusNode = FocusNode();
  final UndoHistoryController undo = UndoHistoryController();
  final ScrollController scroll = ScrollController();
  final FakeNoteMediaResolver resolver = _resolver();

  Widget app({double width = 560, double height = 700, double scale = 1}) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: ComposerMediaScope(
              resolver: resolver,
              child: Align(
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: noteEditorFor(
                    NoteEditorConfig(
                      controller: controller,
                      focusNode: focusNode,
                      undoController: undo,
                      scrollController: scroll,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void dispose() {
    controller.dispose();
    focusNode.dispose();
    undo.dispose();
    scroll.dispose();
  }
}

Future<_Harness> _pump(
  WidgetTester tester,
  String text, {
  double width = 560,
  double height = 700,
  double scale = 1,
}) async {
  _pinSurface(tester);
  final _Harness harness = _Harness(text);
  addTearDown(harness.dispose);
  await tester.pumpWidget(
    harness.app(width: width, height: height, scale: scale),
  );
  await tester.pump();
  await tester.pump();
  return harness;
}

Future<void> _focus(WidgetTester tester, _Harness harness) async {
  harness.focusNode.requestFocus();
  await tester.pump();
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) =>
    tester.pump(const Duration(seconds: 1));

RenderNoteView _view(WidgetTester tester) =>
    tester.renderObject<RenderNoteView>(
      find.descendant(
        of: find.byType(NoteEditorView),
        matching: find.byType(NoteViewBody),
      ),
    );

Rect _editorRect(WidgetTester tester) =>
    tester.getRect(find.byType(NoteEditorView));

Rect _figure(WidgetTester tester) =>
    tester.getRect(NoteEditorDriver(tester).photoFinder(0));

Offset _global(WidgetTester tester, Offset content) =>
    _view(tester).contentToGlobal(content);

Future<void> _pumpComposer(
  WidgetTester tester, {
  TextEditingController? controller,
}) async {
  _pinSurface(tester);
  await tester.pumpWidget(
    captureHarness(
      DialogHost(
        child: ComposerShell(
          child: TextComposerSheet(
            controller: controller,
            onSave: (String _) {},
            onCancel: () {},
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

List<MethodCall> _mockPlatform(WidgetTester tester) {
  final List<MethodCall> log = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (MethodCall call) async {
      log.add(call);
      if (call.method == 'Clipboard.hasStrings') {
        return <String, Object?>{'value': true};
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  return log;
}

int _handleCount(WidgetTester tester) {
  final RenderNoteView view = _view(tester);
  final List<LayerLink?> links = <LayerLink?>[
    view.startHandleLayerLink,
    view.endHandleLayerLink,
  ];
  return tester
      .widgetList<CompositedTransformFollower>(
        find.byType(CompositedTransformFollower),
      )
      .where(
        (CompositedTransformFollower follower) =>
            links.any((LayerLink? link) => identical(link, follower.link)),
      )
      .length;
}

List<String> _toolbarLabels(WidgetTester tester) => <String>[
  for (final Text text in tester.widgetList<Text>(
    find.descendant(
      of: find.byType(AdaptiveTextSelectionToolbar),
      matching: find.byType(Text),
    ),
  ))
    text.data ?? '',
];

void _expectInside(Rect inner, Rect outer, String why) {
  expect(inner.left, greaterThanOrEqualTo(outer.left - _tolerance), reason: why);
  expect(inner.top, greaterThanOrEqualTo(outer.top - _tolerance), reason: why);
  expect(inner.right, lessThanOrEqualTo(outer.right + _tolerance), reason: why);
  expect(
    inner.bottom,
    lessThanOrEqualTo(outer.bottom + _tolerance),
    reason: why,
  );
}

Future<void> _overlayOn(
  WidgetTester tester,
  TargetPlatform platform,
  String why,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await _pump(tester, 'the harbour at dawn', width: 400, height: 300);
  final NoteEditorDriver driver = NoteEditorDriver(tester);
  await driver.setSelection(const TextSelection.collapsed(offset: 6));
  final Offset point = driver.caretRect.center;
  final bool android = platform == TargetPlatform.android;
  final TestGesture gesture = await tester.startGesture(
    point,
    kind: android ? PointerDeviceKind.touch : PointerDeviceKind.mouse,
  );
  await tester.pump(_longHold);
  if (android) {
    expect(find.byType(TextMagnifier), findsOneWidget, reason: why);
  }
  await gesture.up();
  await tester.pump();
  await tester.pump();
  if (android) {
    expect(driver.selection.start, 4, reason: why);
    expect(driver.selection.end, 11, reason: why);
    expect(_handleCount(tester), 2, reason: why);
    expect(
      _toolbarLabels(tester),
      <String>['Cut', 'Copy', 'Paste', 'Select all'],
      reason: why,
    );
  } else {
    expect(_handleCount(tester), 0, reason: why);
    expect(
      find.byType(AdaptiveTextSelectionToolbar),
      findsNothing,
      reason: why,
    );
  }
  await _settle(tester);
  await tester.pumpWidget(const SizedBox.shrink());
  await _settle(tester);
}

typedef _FormatCase = ({
  String name,
  String requirement,
  Transaction? Function(EditorState state) command,
  String text,
  int base,
  int extent,
  String expectedText,
  int? expectedBase,
  int? expectedExtent,
});

Transaction? _bold(EditorState state) =>
    toggleInlineFormat(state, InlineFormat.bold);

Transaction? _italic(EditorState state) =>
    toggleInlineFormat(state, InlineFormat.italic);

Transaction? _link(EditorState state) =>
    toggleInlineFormat(state, InlineFormat.link);

Transaction? _bullet(EditorState state) =>
    toggleList(state, NoteListKind.bullet);

const List<Transaction? Function(EditorState state)> _sixCommands =
    <Transaction? Function(EditorState state)>[
      _bold,
      _italic,
      cycleHeading,
      _bullet,
      toggleQuote,
      _link,
    ];

const List<_FormatCase> _formatCases = <_FormatCase>[
  (
    name: 'bold wraps a single word',
    requirement: 'unchanged',
    command: _bold,
    text: 'hello world',
    base: 0,
    extent: 5,
    expectedText: '**hello** world',
    expectedBase: 2,
    expectedExtent: 7,
  ),
  (
    name: 'bold unwraps markers outside the selection',
    requirement: 'unchanged',
    command: _bold,
    text: '**hello** world',
    base: 2,
    extent: 7,
    expectedText: 'hello world',
    expectedBase: 0,
    expectedExtent: 5,
  ),
  (
    name: 'bold unwraps markers inside the selection',
    requirement: 'unchanged',
    command: _bold,
    text: '**hello** world',
    base: 0,
    extent: 9,
    expectedText: 'hello world',
    expectedBase: 0,
    expectedExtent: 5,
  ),
  (
    name: 'bold on a collapsed caret leaves it between the markers',
    requirement: 'C1',
    command: _bold,
    text: 'ab',
    base: 1,
    extent: 1,
    expectedText: '**ab**',
    expectedBase: 3,
    expectedExtent: 3,
  ),
  (
    name: 'bold wraps a multi word selection',
    requirement: 'unchanged',
    command: _bold,
    text: 'one two three',
    base: 4,
    extent: 13,
    expectedText: 'one **two three**',
    expectedBase: 6,
    expectedExtent: 15,
  ),
  (
    name: 'italic wraps with a single underscore',
    requirement: 'C1: italic writes *',
    command: _italic,
    text: 'hello world',
    base: 6,
    extent: 11,
    expectedText: 'hello *world*',
    expectedBase: null,
    expectedExtent: null,
  ),
  (
    name: 'italic unwraps its own markers',
    requirement: 'unchanged',
    command: _italic,
    text: 'hello _world_',
    base: 7,
    extent: 12,
    expectedText: 'hello world',
    expectedBase: 6,
    expectedExtent: 11,
  ),
  (
    name: 'italic inside bold leaves the bold markers alone',
    requirement: 'C1',
    command: _italic,
    text: '**hello**',
    base: 2,
    extent: 7,
    expectedText: '***hello***',
    expectedBase: null,
    expectedExtent: null,
  ),
  (
    name: 'heading prefixes the caret line',
    requirement: 'C2',
    command: cycleHeading,
    text: 'a title',
    base: 3,
    extent: 3,
    expectedText: '# a title',
    expectedBase: null,
    expectedExtent: null,
  ),
  (
    name: 'heading removes an existing prefix of any level',
    requirement: 'C2: H1 to H2',
    command: cycleHeading,
    text: '# a title',
    base: 4,
    extent: 4,
    expectedText: '## a title',
    expectedBase: null,
    expectedExtent: null,
  ),
  (
    name: 'heading prefixes every line the selection touches',
    requirement: 'C2',
    command: cycleHeading,
    text: 'one\ntwo\nthree',
    base: 1,
    extent: 9,
    expectedText: '# one\n# two\n# three',
    expectedBase: null,
    expectedExtent: null,
  ),
  (
    name: 'heading removes the prefix from every selected line',
    requirement: 'C2: H2 to H3',
    command: cycleHeading,
    text: '## one\n## two',
    base: 4,
    extent: 11,
    expectedText: '### one\n### two',
    expectedBase: null,
    expectedExtent: null,
  ),
  (
    name: 'the list prefix applies to the caret line',
    requirement: 'unchanged',
    command: _bullet,
    text: 'milk',
    base: 4,
    extent: 4,
    expectedText: '- milk',
    expectedBase: 6,
    expectedExtent: 6,
  ),
  (
    name: 'the list prefix toggles off again',
    requirement: 'unchanged',
    command: _bullet,
    text: '- milk',
    base: 6,
    extent: 6,
    expectedText: 'milk',
    expectedBase: 4,
    expectedExtent: 4,
  ),
  (
    name: 'the list prefix applies to a multi line selection',
    requirement: 'unchanged',
    command: _bullet,
    text: 'milk\neggs',
    base: 0,
    extent: 9,
    expectedText: '- milk\n- eggs',
    expectedBase: 2,
    expectedExtent: 13,
  ),
  (
    name: 'quote prefixes the caret line',
    requirement: 'unchanged',
    command: toggleQuote,
    text: 'she said',
    base: 0,
    extent: 0,
    expectedText: '> she said',
    expectedBase: 2,
    expectedExtent: 2,
  ),
  (
    name: 'quote toggles off again',
    requirement: 'unchanged',
    command: toggleQuote,
    text: '> she said',
    base: 2,
    extent: 10,
    expectedText: 'she said',
    expectedBase: 0,
    expectedExtent: 8,
  ),
  (
    name: 'a link wraps the selection and parks the caret in the target',
    requirement: 'unchanged',
    command: _link,
    text: 'see the docs',
    base: 4,
    extent: 12,
    expectedText: 'see [the docs]()',
    expectedBase: 15,
    expectedExtent: 15,
  ),
  (
    name: 'a link on a collapsed caret parks it in the label',
    requirement: 'unchanged',
    command: _link,
    text: 'see ',
    base: 4,
    extent: 4,
    expectedText: 'see []()',
    expectedBase: 5,
    expectedExtent: 5,
  ),
  (
    name: 'a link unwraps back to its label',
    requirement: 'unchanged',
    command: _link,
    text: 'see [the docs](https://a.b)',
    base: 5,
    extent: 13,
    expectedText: 'see the docs',
    expectedBase: 4,
    expectedExtent: 12,
  ),
];

const Map<String, (String, String)> _formatPointers =
    <String, (String, String)>{
      'bold on a collapsed caret leaves it between the markers': (
        _inlineFormat,
        'bold wraps the word around a collapsed caret',
      ),
      'italic wraps with a single underscore': (
        _inlineFormat,
        'italic writes single stars',
      ),
    };

void main() {
  group(_styleFile, () {
    test('the built span is length preserving over the marker corpus', () {
      const String why =
          '$_styleFile: length preserving over the marker corpus; V1';
      _pointer(
        _visibleTextObjects,
        'offsets map both ways and a crlf maps as one unit',
        why,
      );
      for (final String source in _corpus) {
        for (final int? line in <int?>[
          null,
          _lineOf(source, source.length),
        ]) {
          final String at = '$why [${source.replaceAll('\n', r'\n')}] $line';
          late final VisibleText visible;
          expect(
            () => visible = _project(source, line),
            returnsNormally,
            reason: at,
          );
          _expectRoundTrip(visible, source.length, at);
        }
      }
    });

    test('the built span is length preserving over a fuzz corpus', () {
      const String why =
          '$_styleFile: length preserving over a fuzz corpus; V1';
      _pointer(
        _deltaMapping,
        'random deltas re-project to the platform text without a resync',
        why,
      );
      final Random random = Random(20260920);
      for (int i = 0; i < 400; i++) {
        final String source = _fuzz(random);
        expect(source.length, lessThan(120), reason: why);
        final String at = '$why [${source.replaceAll('\n', r'\n')}]';
        for (final int? line in <int?>[
          null,
          _lineOf(source, source.length),
        ]) {
          late final VisibleText visible;
          expect(
            () => visible = _project(source, line),
            returnsNormally,
            reason: '$at $line',
          );
          _expectRoundTrip(visible, source.length, '$at $line');
        }
      }
    });

    test('markers stay visible and dimmed instead of being hidden', () {
      const String why =
          '$_styleFile: markers stay visible and dimmed; V1, V5 change it';
      _pointer(
        _visibleTextBuilder,
        'markers are hidden off the active line and shown on it',
        why,
      );
      final VisibleText active = _project('**bold**', 0);
      expect(active.text, '**bold**', reason: why);
      expect(_spanOver(active, 0, 2)?.dimmed, isTrue, reason: why);
      expect(_spanOver(active, 6, 8)?.dimmed, isTrue, reason: why);
      expect(_project('**bold**', null).text, 'bold', reason: why);
    });

    test('a heading keeps its hashes and emphasises the text', () {
      const String why =
          '$_styleFile: a heading keeps its hashes; V1, V5, L2';
      final VisibleText active = _project('## Title', 0);
      expect(active.text, '## Title', reason: why);
      expect(_spanOver(active, 0, 3)?.dimmed, isTrue, reason: why);
      expect(_project('## Title', null).text, 'Title', reason: why);
      final TextStyle heading = NoteTypography.heading(2);
      expect(heading, TypographyTokens.headlineSerif, reason: why);
      expect(heading.fontSize, 21, reason: why);
      expect(heading.fontWeight, FontWeight.w500, reason: why);
    });

    test('a value past the live style limit falls back to one plain span', () {
      const String why =
          '$_styleFile: past the live style limit; V1: no style limit';
      final String source = '**bold** ' * 800;
      final VisibleText visible = _project(source, null);
      expect(visible.text, ('bold ' * 800).trimRight(), reason: why);
      expect(visible.map.sourceLength, source.length, reason: why);
    });

    test('a value at the live style limit is still styled', () {
      const String why = '$_styleFile: at the live style limit; unchanged';
      final String source = '**b** '.padRight(6000, 'x');
      expect(source.length, 6000, reason: why);
      expect(
        _project(source, null).text,
        'b ${'x' * 5994}',
        reason: why,
      );
    });

    test('a raised styleLimit live-styles a buffer past liveStyleLimit', () {
      const String why = '$_styleFile: a raised style limit; V1';
      final String source = '**bold** and *italic* ' * 273;
      expect(source.length, 6006, reason: why);
      final VisibleText visible = _project(source, null);
      expect(
        visible.text,
        ('bold and italic ' * 273).trimRight(),
        reason: why,
      );
      expect(visible.map.sourceLength, source.length, reason: why);
    });

    test('nothing is ever truncated, however long the note', () {
      const String why = '$_styleFile: nothing is truncated; unchanged';
      final String source = 'a very long note. ' * 4000;
      final VisibleText visible = _project(source, null);
      expect(source.length, 72000, reason: why);
      expect(visible.text, source.trimRight(), reason: why);
      expect(visible.map.sourceLength, 72000, reason: why);
      expect(
        visible.map.visibleToSource(visible.text.length).downstream,
        72000,
        reason: why,
      );
    });

    test('the composing range carries the IME underline', () {
      const String why =
          '$_styleFile: the composing range is underlined; I9, unchanged';
      _pointer(_caretSelection, 'the composing range is underlined', why);
    });

    testWidgets(
      'the composing underline is dropped when withComposing is false',
      (WidgetTester tester) async {
        const String why = '$_styleFile: no composing underline; I9';
        await _pump(tester, '');
        await NoteEditorDriver(tester).enterText('hello there');
        expect(_view(tester).composing, TextRange.empty, reason: why);
      },
    );

    test('a controller attached to another controller shares its value', () {
      const String why =
          '$_styleFile: an attached controller shares its value; M2, '
          'unchanged';
      _pointer(
        _controllerTest,
        'the controller reads and writes through an attached source',
        why,
      );
      final TextEditingController source = TextEditingController(text: 'seed');
      addTearDown(source.dispose);
      final NoteEditorController attached = NoteEditorController.attachedTo(
        source,
      );
      addTearDown(attached.dispose);
      expect(attached.text, 'seed', reason: why);
      source.text = 'from the source';
      expect(attached.text, 'from the source', reason: why);
      attached.value = const TextEditingValue(
        text: 'from the editor',
        selection: TextSelection.collapsed(offset: 15),
      );
      expect(source.text, 'from the editor', reason: why);
    });
  });

  group(_keysFile, () {
    test('removes the whole photo line when the photo is selected', () {
      const String why = '$_keysFile: removes the photo line; P3, 11.3';
      final EditorState state = _state(_note, const NoteSelection.collapsed(9));
      for (final PhotoKeyResult? result in <PhotoKeyResult?>[
        photoBackspace(state),
        photoDelete(state),
      ]) {
        expect(result, isA<PhotoKeyEdit>(), reason: why);
        final EditorState next = state.apply(
          (result! as PhotoKeyEdit).transaction,
        );
        expect(next.source, 'one\n\ntwo', reason: why);
        expect(next.selection, const NoteSelection.collapsed(5), reason: why);
      }
    });

    test('Backspace at the start of the line after a photo selects it', () {
      const String why =
          '$_keysFile: Backspace after a photo selects it; P2, unchanged';
      _pointer(
        _photoCommands,
        'the first backspace selects the photo and the second removes it',
        why,
      );
      final PhotoKeyResult? result = photoBackspace(
        _state(_note, const NoteSelection.collapsed(43)),
      );
      expect(result, isA<PhotoKeySelect>(), reason: why);
      final NoteSelection selection = (result! as PhotoKeySelect).selection;
      expect(selection.anchor, 4, reason: why);
      expect(selection.head, 42, reason: why);
    });

    test('Delete at the end of the line before a photo selects it', () {
      const String why =
          '$_keysFile: Delete before a photo selects it; P2, unchanged';
      final PhotoKeyResult? result = photoDelete(
        _state(_note, const NoteSelection.collapsed(3)),
      );
      expect(result, isA<PhotoKeySelect>(), reason: why);
      final NoteSelection selection = (result! as PhotoKeySelect).selection;
      expect(selection.anchor, 4, reason: why);
      expect(selection.head, 42, reason: why);
    });

    test('leaves plain text and range deletions to the default', () {
      const String why = '$_keysFile: plain text is left alone; unchanged';
      for (final NoteSelection selection in <NoteSelection>[
        const NoteSelection.collapsed(2),
        const NoteSelection.collapsed(44),
        const NoteSelection(anchor: 0, head: 2),
      ]) {
        expect(
          photoBackspace(_state(_note, selection)),
          isNull,
          reason: '$why $selection',
        );
      }
    });

    testWidgets('crosses a selected photo in one step each way', (
      WidgetTester tester,
    ) async {
      const String why = '$_keysFile: crosses a photo in one step; P2, '
          'unchanged';
      final _Harness harness = await _pump(tester, _note);
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _focus(tester, harness);
      await driver.setSelection(const TextSelection.collapsed(offset: 9));
      await driver.pressKey(LogicalKeyboardKey.arrowRight);
      expect(
        driver.selection,
        const TextSelection.collapsed(offset: 43),
        reason: why,
      );
      await driver.setSelection(const TextSelection.collapsed(offset: 9));
      await driver.pressKey(LogicalKeyboardKey.arrowLeft);
      expect(
        driver.selection,
        const TextSelection.collapsed(offset: 3),
        reason: why,
      );
    });

    testWidgets('extends a selection across a photo in one step', (
      WidgetTester tester,
    ) async {
      const String why = '$_keysFile: extends across a photo; S1, V2';
      final _Harness harness = await _pump(tester, _note);
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _focus(tester, harness);
      await driver.setSelection(
        const TextSelection(baseOffset: 1, extentOffset: 9),
      );
      await driver.pressKey(LogicalKeyboardKey.arrowRight, shift: true);
      expect(driver.selection.baseOffset, 1, reason: why);
      expect(
        driver.selection.extentOffset,
        greaterThanOrEqualTo(42),
        reason: why,
      );
    });

    testWidgets('leaves a caret outside a photo to the default', (
      WidgetTester tester,
    ) async {
      const String why = '$_keysFile: a caret outside a photo; unchanged';
      final _Harness harness = await _pump(tester, _note);
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _focus(tester, harness);
      await driver.setSelection(const TextSelection.collapsed(offset: 1));
      await driver.pressKey(LogicalKeyboardKey.arrowRight);
      expect(
        driver.selection,
        const TextSelection.collapsed(offset: 2),
        reason: why,
      );
    });

    testWidgets('moves the caret to the line after the photo', (
      WidgetTester tester,
    ) async {
      const String why = '$_keysFile: Escape moves after the photo; C7 step '
          '3, unchanged';
      final _Harness harness = await _pump(tester, _note);
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _focus(tester, harness);
      await driver.setSelection(const TextSelection.collapsed(offset: 9));
      await driver.pressKey(LogicalKeyboardKey.escape);
      expect(
        driver.selection,
        const TextSelection.collapsed(offset: 43),
        reason: why,
      );
    });

    testWidgets('a photo on the last line deselects to the line before it', (
      WidgetTester tester,
    ) async {
      const String why = '$_keysFile: a last-line photo deselects before; '
          'C7 step 3';
      final _Harness harness = await _pump(tester, 'one\n$_a');
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _focus(tester, harness);
      await driver.setSelection(const TextSelection.collapsed(offset: 9));
      await driver.pressKey(LogicalKeyboardKey.escape);
      expect(
        driver.selection,
        const TextSelection.collapsed(offset: 3),
        reason: why,
      );
    });

    testWidgets('does nothing without a selected photo', (
      WidgetTester tester,
    ) async {
      const String why = '$_keysFile: Escape without a photo; C7 step 4';
      final _Harness harness = await _pump(tester, _note);
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _focus(tester, harness);
      await driver.setSelection(const TextSelection.collapsed(offset: 1));
      await driver.pressKey(LogicalKeyboardKey.escape);
      expect(
        driver.selection,
        const TextSelection.collapsed(offset: 1),
        reason: why,
      );
      expect(driver.source, _note, reason: why);
    });

    test('typing on a selected photo starts a new line after it', () {
      const String why =
          '$_keysFile: typing on a selected photo; P2, unchanged';
      _pointer(
        _photoCommands,
        'typing with a photo selected starts a new line after it',
        why,
      );
      final EditorState selected = _state(
        _note,
        const NoteSelection.collapsed(9),
      );
      final EditorState next = _applied(
        selected,
        typeOverSelectedPhoto(selected, 'x'),
        why,
      );
      expect(next.source, 'one\n$_a\nx\ntwo', reason: why);
      expect(next.selection, const NoteSelection.collapsed(44), reason: why);
    });

    testWidgets('Enter on a selected photo opens an empty line after it', (
      WidgetTester tester,
    ) async {
      const String why = '$_keysFile: Enter on a selected photo; P2 with 11.3';
      final _Harness harness = await _pump(tester, _note);
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _focus(tester, harness);
      await driver.setSelection(const TextSelection.collapsed(offset: 9));
      await driver.typeText('\n');
      expect(driver.source, 'one\n$_a\n\ntwo', reason: why);
      expect(
        driver.selection,
        const TextSelection.collapsed(offset: 43),
        reason: why,
      );
    });

    testWidgets('an IME composition on a selected photo moves with the text', (
      WidgetTester tester,
    ) async {
      const String why = '$_keysFile: an IME composition on a photo; P2';
      final _Harness harness = await _pump(tester, _note);
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _focus(tester, harness);
      await driver.setSelection(const TextSelection.collapsed(offset: 9));
      await sendRequestExistingInputState(tester);
      await tester.pump();
      final TextEditingValue platform = TextEditingValue.fromJSON(
        tester.testTextInput.editingState!,
      );
      final int at = platform.selection.start;
      await sendDeltas(tester, <Map<String, Object?>>[
        insertionDelta(
          oldText: platform.text,
          at: at,
          text: 'か',
          composing: TextRange(start: at, end: at + 1),
        ),
      ]);
      await tester.pump();
      expect(driver.source, 'one\n$_a\nか\ntwo', reason: why);
      expect(
        harness.controller.value.composing,
        const TextRange(start: 43, end: 44),
        reason: why,
      );
    });

    testWidgets('replacing part of a photo line takes the whole line', (
      WidgetTester tester,
    ) async {
      const String why = '$_keysFile: replacing part of a photo line; V2, I4';
      final _Harness harness = await _pump(tester, _note);
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _focus(tester, harness);
      await driver.setSelection(
        const TextSelection(baseOffset: 1, extentOffset: 9),
      );
      await driver.typeText('y');
      expect(driver.source, isNot(contains('photo/')), reason: why);
      expect(driver.source, startsWith('oy'), reason: why);
      expect(driver.source, endsWith('two'), reason: why);
    });

    testWidgets(
      'deleting the break after a photo keeps the photo on its own line',
      (WidgetTester tester) async {
        const String why =
            '$_keysFile: deleting the break after a photo; V2, P2';
        final _Harness harness = await _pump(tester, _note);
        final NoteEditorDriver driver = NoteEditorDriver(tester);
        await _focus(tester, harness);
        await driver.setSelection(
          const TextSelection(baseOffset: 42, extentOffset: 44),
        );
        await driver.pressKey(LogicalKeyboardKey.backspace);
        expect(driver.source, 'one\n${_a}wo', reason: why);
        expect(_a.allMatches(driver.source).length, 1, reason: why);
        expect(driver.source, endsWith('wo'), reason: why);
      },
    );

    testWidgets(
      'deleting the break before a photo keeps the photo on its own line',
      (WidgetTester tester) async {
        const String why =
            '$_keysFile: deleting the break before a photo; V2, P2';
        final _Harness harness = await _pump(tester, _note);
        final NoteEditorDriver driver = NoteEditorDriver(tester);
        await _focus(tester, harness);
        await driver.setSelection(
          const TextSelection(baseOffset: 2, extentOffset: 4),
        );
        await driver.pressKey(LogicalKeyboardKey.backspace);
        expect(driver.source, 'on$_a\ntwo', reason: why);
        expect(_a.allMatches(driver.source).length, 1, reason: why);
        expect(driver.source, startsWith('on'), reason: why);
      },
    );

    testWidgets('typing away from photos passes through untouched', (
      WidgetTester tester,
    ) async {
      const String why = '$_keysFile: typing away from photos; E5, unchanged';
      _pointer(
        _sideEdit,
        'no command changes bytes outside its replacement range',
        why,
      );
      final _Harness harness = await _pump(tester, _note);
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _focus(tester, harness);
      await driver.setSelection(const TextSelection.collapsed(offset: 1));
      await driver.typeText('z');
      expect(driver.source, 'ozne\n$_a\ntwo', reason: why);
    });
  });

  group(_formatFile, () {
    for (final _FormatCase row in _formatCases) {
      test(row.name, () {
        final String why = '$_formatFile: ${row.name}; ${row.requirement}';
        final (String, String)? pointer = _formatPointers[row.name];
        if (pointer != null) {
          _pointer(pointer.$1, pointer.$2, why);
        }
        final EditorState state = _state(
          row.text,
          NoteSelection(anchor: row.base, head: row.extent),
        );
        final EditorState next = _applied(state, row.command(state), why);
        expect(next.source, row.expectedText, reason: why);
        final int? base = row.expectedBase;
        final int? extent = row.expectedExtent;
        if (base != null && extent != null) {
          expect(next.selection.anchor, base, reason: why);
          expect(next.selection.head, extent, reason: why);
        }
        expect(state.source, row.text, reason: why);
      });
    }

    test('every action tolerates a value that was never focused', () {
      const String why = '$_formatFile: a value never focused; E4, C8';
      for (final Transaction? Function(EditorState state) command
          in _sixCommands) {
        final NoteEditorController controller = NoteEditorController(
          text: 'orphan',
        );
        addTearDown(controller.dispose);
        expect(
          controller.selection,
          const TextSelection.collapsed(offset: 6),
          reason: why,
        );
        controller.applyCommand(command);
        expect(controller.text, contains('orphan'), reason: why);
        expect(controller.selection.isValid, isTrue, reason: why);
        expect(
          controller.selection.end,
          lessThanOrEqualTo(controller.text.length),
          reason: why,
        );
      }
    });

    test('no action ever shortens the text it was given', () {
      const String why = '$_formatFile: no action shortens; E5, C1, C2';
      _pointer(
        _sideEdit,
        'no command changes bytes outside its replacement range',
        why,
      );
      const String text = 'keep every character';
      for (final Transaction? Function(EditorState state) command
          in _sixCommands) {
        final EditorState state = _state(
          text,
          const NoteSelection(anchor: 0, head: 4),
        );
        final EditorState next = _applied(state, command(state), why);
        expect(next.source.length, greaterThan(text.length), reason: why);
        expect(
          next.source.replaceAll(RegExp(r'[*_#>\-\[\]() ]'), ''),
          'keepeverycharacter',
          reason: '$why ${next.source}',
        );
      }
    });
  });

  group(_editorFile, () {
    test('lays out at the figure height, with the figure on it', () {
      const String why = '$_editorFile: the figure band; L2, L5';
      final LaidOutNote layout = _layout(_stacked);
      final PhotoRect photo = layout.photoRects.single;
      expect(photo.rect.left, closeTo(280, 0.01), reason: why);
      expect(photo.rect.top, closeTo(38.4, 0.01), reason: why);
      expect(photo.rect.width, closeTo(280, 0.01), reason: why);
      expect(photo.rect.height, closeTo(210, 0.01), reason: why);
      expect(photo.flow, PhotoFlow.floatRight, reason: why);
      final FragmentInfo heading = _fragmentsOf(
        layout,
        _blockIndex(layout, MdBlockKind.heading),
      ).first;
      expect(heading.lineBox.rect.top, closeTo(38.4, 0.01), reason: why);
      expect(heading.besideFloat, isTrue, reason: why);
      expect(heading.lineBox.rect.right, lessThanOrEqualTo(264.01), reason: why);
    });

    testWidgets('draws its Markdown invisibly and hides the caret on it', (
      WidgetTester tester,
    ) async {
      const String why = '$_editorFile: the Markdown is drawn invisibly; V1, '
          'R3, S1';
      _pointer(
        _caretSelection,
        'the caret is hidden with a range, a selected photo or no focus',
        why,
      );
      final _Harness harness = await _pump(tester, _note);
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      expect(driver.visibleText, 'one\n\u{FFFC}\ntwo', reason: why);
      await _focus(tester, harness);
      await driver.setSelection(const TextSelection.collapsed(offset: 8));
      expect(find.byKey(photoFigureRingKey), findsOneWidget, reason: why);
      await driver.setSelection(const TextSelection.collapsed(offset: 44));
      expect(find.byKey(photoFigureRingKey), findsNothing, reason: why);
    });

    testWidgets('a right photo sits against the right edge of the column', (
      WidgetTester tester,
    ) async {
      const String why = '$_editorFile: a right photo at the right edge; L5, '
          'unchanged';
      await _pump(tester, _note);
      expect(
        _figure(tester).right,
        closeTo(_editorRect(tester).right, _tolerance),
        reason: why,
      );
    });

    testWidgets('while the editor scrolls', (WidgetTester tester) async {
      const String why = '$_editorFile: the figure tracks a scroll; R2, R5';
      final String before = List<String>.filled(
        30,
        'a line of text',
      ).join('\n');
      final String after = List<String>.filled(30, 'more text').join('\n');
      final _Harness harness = await _pump(
        tester,
        '$before\n$_a\n$after',
        height: 400,
      );
      final Finder figure = NoteEditorDriver(tester).photoFinder(0);
      int seen = 0;
      for (final double offset in <double>[0, 200, 420, 700]) {
        harness.scroll.jumpTo(
          min(offset, harness.scroll.position.maxScrollExtent),
        );
        await tester.pump();
        if (figure.evaluate().isEmpty) {
          continue;
        }
        seen += 1;
        final Rect content = _view(tester).noteLayout.photoRects.single.rect;
        expect(
          tester.getRect(figure).top,
          closeTo(_global(tester, content.topLeft).dy, _tolerance),
          reason: '$why $offset',
        );
      }
      expect(seen, greaterThan(0), reason: why);
    });

    testWidgets('while the window resizes', (WidgetTester tester) async {
      const String why = '$_editorFile: the figure tracks a resize; L1, L6';
      final _Harness harness = await _pump(tester, _note);
      for (final double width in <double>[560, 700, 480, 720]) {
        await tester.pumpWidget(harness.app(width: width));
        await tester.pump();
        final Rect figure = _figure(tester);
        final Rect content = _view(tester).noteLayout.photoRects.single.rect;
        expect(
          figure.right,
          closeTo(_editorRect(tester).right, _tolerance),
          reason: '$why $width',
        );
        expect(
          figure.top,
          closeTo(_global(tester, content.topLeft).dy, _tolerance),
          reason: '$why $width',
        );
      }
    });

    test('at 1.0x text', () {
      const String why = '$_editorFile: at 1.0x text; L4, L5';
      final LaidOutNote layout = _layout(_stacked, width: 720);
      expect(layout.photoRects.single.flow, PhotoFlow.floatRight, reason: why);
      expect(
        _fragmentsOf(
          layout,
          _blockIndex(layout, MdBlockKind.heading),
        ).first.besideFloat,
        isTrue,
        reason: why,
      );
    });

    test('at 1.5x text', () {
      const String why = '$_editorFile: at 1.5x text; L4';
      final LaidOutNote layout = _layout(_stacked, width: 900, scale: 1.5);
      final PhotoRect photo = layout.photoRects.single;
      expect(photo.flow, PhotoFlow.floatRight, reason: why);
      expect(photo.rect.width, closeTo(450, 0.01), reason: why);
      expect(
        _fragmentsOf(
          layout,
          _blockIndex(layout, MdBlockKind.heading),
        ).first.besideFloat,
        isTrue,
        reason: why,
      );
    });

    test('at 2.0x text', () {
      const String why = '$_editorFile: at 2.0x text; L4';
      final LaidOutNote layout = _layout(_stacked, width: 900, scale: 2);
      final PhotoRect photo = layout.photoRects.single;
      expect(photo.flow, PhotoFlow.block, reason: why);
      expect(photo.rect.width, closeTo(900, 0.01), reason: why);
      expect(
        _fragmentsOf(
          layout,
          _blockIndex(layout, MdBlockKind.heading),
        ).first.lineBox.rect.top,
        closeTo(photo.rect.bottom + 38.4, 0.01),
        reason: why,
      );
    });

    testWidgets('while text is typed above it', (WidgetTester tester) async {
      const String why = '$_editorFile: the figure tracks typing above; R2';
      _pointer(
        _noteView,
        'pressing enter above a photo keeps its element mounted',
        why,
      );
      final _Harness harness = await _pump(tester, _note);
      harness.controller.value = TextEditingValue(
        text: 'one\nand another line\n$_a\ntwo',
        selection: const TextSelection.collapsed(offset: 20),
      );
      await tester.pump();
      final Rect content = _view(tester).noteLayout.photoRects.single.rect;
      expect(
        _figure(tester).top,
        closeTo(_global(tester, content.topLeft).dy, _tolerance),
        reason: why,
      );
    });

    testWidgets('past the live-style limit the photo still shows in place', (
      WidgetTester tester,
    ) async {
      const String why = '$_editorFile: past the live-style limit; V1';
      final _Harness harness = await _pump(
        tester,
        '${'word ' * 1300}\n$_a\ntwo',
      );
      final Rect content = _view(tester).noteLayout.photoRects.single.rect;
      harness.scroll.jumpTo(
        min(content.top, harness.scroll.position.maxScrollExtent),
      );
      await tester.pump();
      expect(
        NoteEditorDriver(tester).photoFinder(0),
        findsOneWidget,
        reason: why,
      );
      expect(
        '\u{FFFC}'.allMatches(NoteEditorDriver(tester).visibleText).length,
        1,
        reason: why,
      );
    });

    testWidgets('select-all covers the exact source, photo lines included', (
      WidgetTester tester,
    ) async {
      const String why = '$_editorFile: select-all copies the source; S1, S5';
      _pointer(
        _clipboardActions,
        'copy writes the source markdown of the selection',
        why,
      );
      final List<MethodCall> log = _mockPlatform(tester);
      final _Harness harness = await _pump(tester, _note);
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _focus(tester, harness);
      await driver.setSelection(
        TextSelection(baseOffset: 0, extentOffset: _note.length),
      );
      await driver.pressKey(LogicalKeyboardKey.keyC, control: true);
      await tester.pump();
      final MethodCall copy = log.lastWhere(
        (MethodCall call) => call.method == 'Clipboard.setData',
      );
      expect(
        (copy.arguments as Map<Object?, Object?>)['text'],
        _note,
        reason: why,
      );
    });

    testWidgets('a click on the picture selects its photo', (
      WidgetTester tester,
    ) async {
      const String why = '$_editorFile: a click selects the photo; S1, S2';
      _pointer(_editorViewTest, 'clicking a photo selects its line', why);
      final _Harness harness = await _pump(tester, _note);
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await driver.press(
        driver.photoFinder(0),
        _hold,
        kind: PointerDeviceKind.mouse,
      );
      await tester.pump();
      expect(harness.focusNode.hasFocus, isTrue, reason: why);
      expect(driver.selection.start, 4, reason: why);
      expect(driver.selection.end, 42, reason: why);
      expect(find.byKey(photoFigureRingKey), findsOneWidget, reason: why);
      await _settle(tester);
    });

    testWidgets('Backspace after a photo selects it, then removes it', (
      WidgetTester tester,
    ) async {
      const String why = '$_editorFile: Backspace selects then removes; P2, '
          'P3';
      final _Harness harness = await _pump(tester, _note);
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _focus(tester, harness);
      await driver.setSelection(const TextSelection.collapsed(offset: 43));
      await driver.pressKey(LogicalKeyboardKey.backspace);
      expect(driver.source, _note, reason: why);
      expect(driver.selection.start, 4, reason: why);
      expect(driver.selection.end, 42, reason: why);
      await driver.pressKey(LogicalKeyboardKey.backspace);
      expect(driver.source, 'one\n\ntwo', reason: why);
      expect(driver.photoFinder(0), findsNothing, reason: why);
    });

    testWidgets('the arrows cross a photo in one step each way', (
      WidgetTester tester,
    ) async {
      const String why = '$_editorFile: the arrows cross a photo; P2';
      final _Harness harness = await _pump(tester, _note);
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _focus(tester, harness);
      await driver.setSelection(const TextSelection.collapsed(offset: 8));
      await driver.pressKey(LogicalKeyboardKey.arrowRight);
      expect(
        driver.selection,
        const TextSelection.collapsed(offset: 43),
        reason: why,
      );
      await driver.pressKey(LogicalKeyboardKey.arrowLeft);
      final TextSelection onPhoto = driver.selection;
      expect(
        (onPhoto.start == 4 && onPhoto.end == 42) ||
            (onPhoto.isCollapsed &&
                onPhoto.start >= 4 &&
                onPhoto.start <= 42),
        isTrue,
        reason: '$why S1 $onPhoto',
      );
      await driver.pressKey(LogicalKeyboardKey.arrowLeft);
      expect(
        driver.selection,
        const TextSelection.collapsed(offset: 3),
        reason: why,
      );
    });

    testWidgets('Esc deselects a photo', (WidgetTester tester) async {
      const String why = '$_editorFile: Esc deselects a photo; C7 step 3';
      final _Harness harness = await _pump(tester, _note);
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _focus(tester, harness);
      await driver.setSelection(const TextSelection.collapsed(offset: 8));
      await driver.pressKey(LogicalKeyboardKey.escape);
      expect(
        driver.selection,
        const TextSelection.collapsed(offset: 43),
        reason: why,
      );
      expect(find.byKey(photoFigureRingKey), findsNothing, reason: why);
    });

    testWidgets('typing on a selected photo writes on a new line after it', (
      WidgetTester tester,
    ) async {
      const String why = '$_editorFile: typing on a selected photo; P2';
      _pointer(
        _deltaMapping,
        'typing over a selected photo goes on a new line after it',
        why,
      );
      final _Harness harness = await _pump(tester, _note);
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _focus(tester, harness);
      await driver.setSelection(const TextSelection.collapsed(offset: 8));
      await driver.typeText('x');
      expect(driver.source, 'one\n$_a\nx\ntwo', reason: why);
      expect(driver.photoFinder(0), findsOneWidget, reason: why);
    });

    testWidgets('undo restores the note after an edit beside a photo', (
      WidgetTester tester,
    ) async {
      const String why = '$_editorFile: undo restores the note; U1, U2';
      _pointer(
        _historyTest,
        'undo and redo restore the selection before and after',
        why,
      );
      final _Harness harness = await _pump(tester, _note);
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _focus(tester, harness);
      await driver.setSelection(const TextSelection.collapsed(offset: 8));
      await driver.typeText('x');
      expect(driver.source, 'one\n$_a\nx\ntwo', reason: why);
      harness.undo.undo();
      await tester.pump();
      expect(driver.source, _note, reason: why);
    });
  });

  group(_wrapFile, () {
    testWidgets('keeps the paragraph beside it and the rest below it', (
      WidgetTester tester,
    ) async {
      const String why = '$_wrapFile: the paragraph beside and below; L4, L5';
      _pointer(
        _floatFlow,
        'lines whose top is above the float bottom lie in the band',
        why,
      );
      final String text = 'one\n$_large\n${_prose(120)}';
      await _pump(tester, text, width: 720);
      expect(_figure(tester).right, closeTo(720, _tolerance), reason: why);
      final LaidOutNote layout = _view(tester).noteLayout;
      final Rect photo = layout.photoRects.single.rect;
      final List<FragmentInfo> paragraph = _fragmentsOf(
        layout,
        _lastBlockIndex(layout, MdBlockKind.paragraph),
      );
      expect(
        paragraph.first.lineBox.rect.top,
        closeTo(photo.top, 0.01),
        reason: why,
      );
      final int start = text.indexOf(_large) + _large.length + 1;
      for (final Rect box in layout.selectionBoxes(
        NoteSelection(anchor: start, head: text.length),
      )) {
        expect(
          box.overlaps(photo.deflate(_tolerance)),
          isFalse,
          reason: '$why $box',
        );
      }
      expect(
        paragraph.where((FragmentInfo f) => f.besideFloat).length,
        greaterThanOrEqualTo(2),
        reason: why,
      );
      expect(
        paragraph.any(
          (FragmentInfo f) =>
              f.lineBox.rect.top >= photo.bottom - _tolerance &&
              f.lineBox.rect.right > photo.left,
        ),
        isTrue,
        reason: why,
      );
    });

    testWidgets('on the left it indents the text beside it', (
      WidgetTester tester,
    ) async {
      const String why = '$_wrapFile: a left photo indents; L5';
      final String text = 'one\n$_leftLarge\n${_prose(120)}';
      await _pump(tester, text, width: 720);
      expect(
        _figure(tester).left,
        closeTo(_editorRect(tester).left, _tolerance),
        reason: why,
      );
      final LaidOutNote layout = _view(tester).noteLayout;
      final Rect photo = layout.photoRects.single.rect;
      expect(photo.left, closeTo(0, 0.01), reason: why);
      final int start = text.indexOf(_leftLarge) + _leftLarge.length + 1;
      for (final Rect box in layout.selectionBoxes(
        NoteSelection(anchor: start, head: text.length),
      )) {
        expect(
          box.overlaps(photo.deflate(_tolerance)),
          isFalse,
          reason: '$why $box',
        );
      }
      final List<FragmentInfo> beside = <FragmentInfo>[
        for (final FragmentInfo f in _fragmentsOf(
          layout,
          _lastBlockIndex(layout, MdBlockKind.paragraph),
        ))
          if (f.besideFloat) f,
      ];
      expect(beside, isNotEmpty, reason: why);
      for (final FragmentInfo f in beside) {
        expect(
          f.lineBox.rect.left,
          greaterThanOrEqualTo(496 - 0.01),
          reason: '$why ${f.lineBox.rect}',
        );
      }
    });

    testWidgets('a paragraph with line breaks still clears a left photo', (
      WidgetTester tester,
    ) async {
      const String why = '$_wrapFile: a paragraph with line breaks; L5, G7';
      final String body = List<String>.filled(8, _prose(6)).join('\n');
      final String text = 'one\n$_leftLarge\n$body';
      await _pump(tester, text, width: 720);
      final LaidOutNote layout = _view(tester).noteLayout;
      final Rect photo = layout.photoRects.single.rect;
      expect(
        layout.inputs.tree.blocks
            .where((MdBlock b) => b.kind == MdBlockKind.paragraph)
            .length,
        2,
        reason: '$why one paragraph after the photo, one before it',
      );
      final int start = text.indexOf(_leftLarge) + _leftLarge.length + 1;
      for (final Rect box in layout.selectionBoxes(
        NoteSelection(anchor: start, head: text.length),
      )) {
        expect(
          box.overlaps(photo.deflate(_tolerance)),
          isFalse,
          reason: '$why $box',
        );
      }
      expect(
        layout.fragments.where((FragmentInfo f) => f.besideFloat).length,
        greaterThanOrEqualTo(2),
        reason: why,
      );
    });

    testWidgets('a short paragraph pushes the next block below the photo', (
      WidgetTester tester,
    ) async {
      const String why = '$_wrapFile: a short paragraph; L5 changes it';
      await _pump(tester, 'one\n$_large\nshort note\n\n# after', width: 720);
      final LaidOutNote layout = _view(tester).noteLayout;
      final Rect photo = layout.photoRects.single.rect;
      final FragmentInfo heading = _fragmentsOf(
        layout,
        _blockIndex(layout, MdBlockKind.heading),
      ).first;
      expect(heading.besideFloat, isTrue, reason: why);
      expect(
        heading.lineBox.rect.top,
        lessThan(photo.bottom - _tolerance),
        reason: why,
      );
      expect(heading.lineBox.rect.right, lessThanOrEqualTo(224.01), reason: why);
    });

    testWidgets('a short paragraph at the end keeps the photo scrollable', (
      WidgetTester tester,
    ) async {
      const String why = '$_wrapFile: the photo stays scrollable; L5';
      final _Harness harness = await _pump(
        tester,
        'one\n$_large\nshort note',
        width: 720,
        height: 120,
      );
      await tester.pump();
      final Rect photo = _view(tester).noteLayout.photoRects.single.rect;
      expect(
        harness.scroll.position.maxScrollExtent + 120,
        greaterThanOrEqualTo(photo.bottom - _tolerance),
        reason: why,
      );
    });

    testWidgets('the source is untouched by the wrap', (
      WidgetTester tester,
    ) async {
      const String why = '$_wrapFile: the source is untouched; E5, V1';
      final String text = 'one\n$_large\n${_prose(60)}';
      final _Harness harness = await _pump(tester, text, width: 720);
      expect(harness.controller.text, text, reason: why);
      expect(
        NoteEditorDriver(tester).visibleText,
        'one\n\u{FFFC}\n${_prose(60)}',
        reason: why,
      );
    });

    testWidgets('stays inside the writing column, selected or not', (
      WidgetTester tester,
    ) async {
      const String why = '$_wrapFile: a Full photo stays in the column; L3, '
          'P12';
      await _pump(tester, 'one\n$_full\n${_prose(20)}', width: 720);
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      final Rect column = _editorRect(tester);
      _expectInside(_figure(tester), column, why);
      await driver.press(driver.photoFinder(0), _hold);
      await tester.pump();
      expect(find.byKey(photoFigureRingKey), findsOneWidget, reason: why);
      _expectInside(
        tester.getRect(find.byKey(photoFigureRingKey)),
        column,
        why,
      );
      await _settle(tester);
    });

    testWidgets(
      'the editor adds no scrollbar of its own',
      (WidgetTester tester) async {
        const String why = '$_wrapFile: no scrollbar of its own; R7';
        _pointer(
          _noteView,
          'the view attaches one scroll position and reserves the bottom '
              'inset',
          why,
        );
        await _pump(
          tester,
          'one\n$_large\n${_prose(400)}',
          width: 720,
          height: 300,
        );
        for (final Type type in <Type>[Scrollbar, RawScrollbar]) {
          expect(
            find.descendant(
              of: find.byType(NoteEditorView),
              matching: find.byType(type),
            ),
            findsNothing,
            reason: '$why $type',
          );
        }
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );

    testWidgets('the wheel scrolls with the pointer over a photo', (
      WidgetTester tester,
    ) async {
      const String why = '$_wrapFile: the wheel over a photo; unchanged';
      final _Harness harness = await _pump(
        tester,
        'one\n$_large\n${_prose(400)}',
        width: 720,
        height: 300,
      );
      final Offset onPhoto = _figure(tester).center;
      final TestPointer pointer = TestPointer(1, PointerDeviceKind.mouse);
      await tester.sendEventToBinding(pointer.hover(onPhoto));
      await tester.sendEventToBinding(pointer.scroll(const Offset(0, 120)));
      await tester.pump();
      expect(harness.scroll.offset, closeTo(120, 1), reason: why);
    });

    testWidgets('the trackpad scrolls with the pointer over a photo', (
      WidgetTester tester,
    ) async {
      const String why = '$_wrapFile: the trackpad over a photo; unchanged';
      final _Harness harness = await _pump(
        tester,
        'one\n$_large\n${_prose(400)}',
        width: 720,
        height: 300,
      );
      final Offset onPhoto = _figure(tester).center;
      final TestPointer pointer = TestPointer(2, PointerDeviceKind.trackpad);
      await tester.sendEventToBinding(pointer.panZoomStart(onPhoto));
      await tester.sendEventToBinding(
        pointer.panZoomUpdate(onPhoto, pan: const Offset(0, -90)),
      );
      await tester.sendEventToBinding(pointer.panZoomEnd());
      await tester.pump();
      expect(harness.scroll.offset, greaterThan(50), reason: why);
    });

    testWidgets('never hides under the picture', (WidgetTester tester) async {
      const String why = '$_wrapFile: the caret beside a left photo; L8';
      _pointer(
        _caretGeometry,
        'the caret left edge sits on the glyph box edge beside a left float',
        why,
      );
      final String text = 'one\n$_leftLarge\n${_prose(120)}';
      final _Harness harness = await _pump(tester, text, width: 720);
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await _focus(tester, harness);
      final Rect figure = _figure(tester);
      final int start = text.indexOf(_leftLarge) + _leftLarge.length + 1;
      int beside = 0;
      for (int offset = start; offset <= text.length; offset++) {
        await driver.setSelection(TextSelection.collapsed(offset: offset));
        final Rect caret = driver.caretRect;
        if (caret.top >= figure.bottom - _tolerance) {
          continue;
        }
        beside += 1;
        expect(
          caret.left,
          greaterThanOrEqualTo(figure.right - _tolerance),
          reason: '$why caret at $offset',
        );
      }
      expect(beside, greaterThan(0), reason: why);
    });
  });

  group(_singleFile, () {
    testWidgets('the writing surface is a TextField, not a raw EditableText', (
      WidgetTester tester,
    ) async {
      const String why = '$_singleFile: the writing surface; M1, M2';
      _pointer(_composerSeam, 'the composer writes with the new note editor', why);
      await _pumpComposer(tester);
      expect(find.byType(NoteEditorView), findsOneWidget, reason: why);
      expect(find.byType(TextField), findsNothing, reason: why);
      expect(find.byType(EditableText), findsNothing, reason: why);
    });

    testWidgets(
      'the selection overlay survives: handles and a context menu',
      (WidgetTester tester) async {
        const String why = '$_singleFile: handles and a context menu; S3, S4, '
            'S2';
        _pointer(
          _touchSelection,
          'a long press selects a word and shows the magnifier',
          why,
        );
        _pointer(
          _touchSelection,
          'the context menu shows cut, copy, paste and select all',
          why,
        );
        _mockPlatform(tester);
        for (final TargetPlatform platform in <TargetPlatform>[
          TargetPlatform.android,
          TargetPlatform.macOS,
        ]) {
          debugDefaultTargetPlatformOverride = platform;
          try {
            await _overlayOn(tester, platform, '$why ${platform.name}');
          } finally {
            debugDefaultTargetPlatformOverride = null;
          }
        }
      },
    );

    testWidgets(
      'a long press paints a real selection',
      (WidgetTester tester) async {
        const String why = '$_singleFile: a long press paints a selection; '
            'S3, R1';
        await _pump(tester, '');
        final NoteEditorDriver driver = NoteEditorDriver(tester);
        await driver.enterText('hello there world');
        final TestGesture gesture = await tester.startGesture(
          _editorRect(tester).topLeft + const Offset(12, 10),
        );
        await tester.pump(_longHold);
        await gesture.up();
        await tester.pump();
        await tester.pump();
        final TextSelection selection = driver.selection;
        expect(selection.isCollapsed, isFalse, reason: why);
        final RenderNoteView view = _view(tester);
        expect(
          view.selection,
          NoteSelection(
            anchor: selection.baseOffset,
            head: selection.extentOffset,
            affinity: selection.affinity,
          ),
          reason: why,
        );
        expect(
          view.noteLayout.selectionBoxes(view.selection!),
          isNotEmpty,
          reason: why,
        );
        await _settle(tester);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.android),
    );

    testWidgets('spell check and stylus handwriting stay off', (
      WidgetTester tester,
    ) async {
      const String why = '$_singleFile: spell check and stylus stay off; SP1, '
          'section 4';
      _pointer(_spellChecker, 'nothing is checked when the setting is off', why);
      final List<MethodCall> scribe = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.scribe,
        (MethodCall call) async {
          scribe.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.scribe,
          null,
        ),
      );
      final _Harness harness = await _pump(tester, 'the harbour at dawn');
      await _focus(tester, harness);
      final Offset start = _editorRect(tester).topLeft + const Offset(20, 10);
      final TestGesture gesture = await tester.startGesture(
        start,
        kind: PointerDeviceKind.stylus,
      );
      await tester.pump();
      await gesture.moveTo(start + const Offset(60, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(scribe, isEmpty, reason: why);
      expect(
        scribe.map((MethodCall call) => call.method),
        isNot(contains('Scribe.startStylusHandwriting')),
        reason: why,
      );
      await _settle(tester);
    });

    testWidgets('the editor writes in the note body type, not the theme type', (
      WidgetTester tester,
    ) async {
      const String why = '$_singleFile: the note body type; L2';
      const TextStyle body = NoteTypography.body;
      expect(
        body.fontFamily,
        TypographyTokens.noteBody.fontFamily,
        reason: why,
      );
      expect(body.fontSize, 16, reason: why);
      expect(body.height, 1.6, reason: why);
      expect(body.color, TypographyTokens.noteBody.color, reason: why);
      expect(body.letterSpacing, isNull, reason: why);
      await _pumpComposer(tester);
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      const String sample = 'a quiet morning';
      await driver.enterText(sample);
      final Size line = driver.firstLineSize;
      final TextStyle theme = Theme.of(
        tester.element(driver.find),
      ).textTheme.bodyLarge!;
      expect(line.width, closeTo(_runWidth(sample, body), 0.01), reason: why);
      expect(
        line.height,
        closeTo(body.fontSize! * body.height!, 0.01),
        reason: why,
      );
      expect(
        line.width,
        isNot(closeTo(_runWidth(sample, theme), 0.5)),
        reason: why,
      );
    });

    testWidgets('the mounted editor paints the styled span from the controller', (
      WidgetTester tester,
    ) async {
      const String why = '$_singleFile: the mounted editor paints styled '
          'text; V1, V5';
      await _pumpComposer(tester);
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await driver.enterText('**bold** plain');
      final VisibleText active = _view(tester).visibleText;
      expect(active.text, '**bold** plain', reason: why);
      final VisibleSpan first = active.map.spans.first;
      expect(first.sourceRange.start, 0, reason: why);
      expect(first.sourceRange.end, 2, reason: why);
      expect(first.dimmed, isTrue, reason: why);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      expect(driver.visibleText, 'bold plain', reason: why);
    });

    testWidgets('the editor never truncates and enforces no length limit', (
      WidgetTester tester,
    ) async {
      const String why = '$_singleFile: no length limit; unchanged';
      await _pump(tester, '');
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      await driver.enterText('a long note line.\n' * 500);
      expect(driver.source.length, 9000, reason: why);
    });

    testWidgets('a plain controller handed to the composer is still styled live', (
      WidgetTester tester,
    ) async {
      const String why = '$_singleFile: a plain controller is styled live; '
          'M2, V5';
      final TextEditingController plain = TextEditingController();
      addTearDown(plain.dispose);
      await _pumpComposer(tester, controller: plain);
      await NoteEditorDriver(tester).enterText('## a heading');
      expect(plain.text, '## a heading', reason: why);
      final VisibleText visible = _view(tester).visibleText;
      final VisibleLine line = visible.lines.firstWhere(
        (VisibleLine line) => line.sourceLine == visible.activeLine,
      );
      final VisibleSpan first = line.spans.first;
      expect(first.sourceRange.start, 0, reason: why);
      expect(first.sourceRange.end, 3, reason: why);
      expect(first.dimmed, isTrue, reason: why);
    });

    testWidgets('the hint shows only while the note is empty', (
      WidgetTester tester,
    ) async {
      const String why = '$_singleFile: the hint while empty; R7';
      await _pumpComposer(tester);
      final NoteEditorDriver driver = NoteEditorDriver(tester);
      expect(driver.visibleHintStyle, isNotNull, reason: why);
      await driver.enterText('a word');
      expect(driver.visibleHintStyle, isNull, reason: why);
    });
  });

  group(_recognizerFile, () {
    List<File> engineSources() => Directory('lib/features/note_engine')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File file) => file.path.endsWith('.dart'))
        .toList();

    test('the editor directory exists and holds sources to inspect', () {
      const String why = '$_recognizerFile: the directory exists; M5';
      expect(
        Directory('lib/features/note_engine').existsSync(),
        isTrue,
        reason: why,
      );
      expect(engineSources(), isNotEmpty, reason: why);
    });

    test('no editor source mentions a banned span construct', () {
      const String why = '$_recognizerFile: no banned span construct; M5';
      for (final File source in engineSources()) {
        expect(
          source.readAsStringSync().contains('recognizer:'),
          isFalse,
          reason: '$why ${source.path}',
        );
      }
    });

    testWidgets('each one is an empty box of the width the wrap asked for', (
      WidgetTester tester,
    ) async {
      const String why = '$_recognizerFile: one atomic photo object; V2, R1';
      await _pump(tester, 'one\n$_large\n${_prose(120)}');
      final VisibleText visible = _view(tester).visibleText;
      expect('\u{FFFC}'.allMatches(visible.text).length, 1, reason: why);
      final AtomicObject atomic = visible.atomics.single;
      expect(atomic.kind, AtomicKind.photo, reason: why);
      expect(atomic.visibleLength, 1, reason: why);
      expect(find.byType(PhotoFigure), findsOneWidget, reason: why);
    });
  });
}
