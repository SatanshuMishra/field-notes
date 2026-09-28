import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/features/capture/text/composer_footer.dart';
import 'package:field_notes/features/capture/text/editor/format_bar.dart';
import 'package:field_notes/features/note_engine/editor/note_editor_view.dart';
import 'package:field_notes/features/note_engine/toolbars/table_toolbar.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../accessibility/states/capture_states.dart';
import '../../../accessibility/states/viewer_states.dart';
import '../../../accessibility/support/a11y_state.dart';
import '../../../support/note_editor_driver.dart';
import '../../../support/tab_reach.dart';

const List<String> _stateIds = <String>[
  'c2-composer-new',
  'c3-composer-keyboard',
  'c4-more-formats',
  'c5-edit-note',
  'c6-photo-selected',
  'c7-photo-caption',
  'c8-table-toolbar',
  'c11-draft-chip',
  'c12-voice-idle',
  'c13-voice-recording',
  'c14-voice-paused',
  'c15-video-idle',
  'c16-video-recording',
  'c17-video-paused',
  'c19-photo-removed-toast',
  'd3-viewer-voice',
  'd4-viewer-video',
];

const int _guardTabPresses = 24;

const String _listNote = '- a\n- b';
const String _indentedListNote = '- a\n  - b';

final TargetPlatformVariant _bothPlatforms = TargetPlatformVariant(
  const <TargetPlatform>{TargetPlatform.android, TargetPlatform.macOS},
);

final List<A11yState> _states = <A11yState>[...captureStates, ...viewerStates];

Future<void> _pumpState(WidgetTester tester, String id) =>
    _states.singleWhere((A11yState state) => state.id == id).pump(tester);

FocusNode _editorFocus(WidgetTester tester) =>
    tester.widget<NoteEditorView>(find.byType(NoteEditorView)).focusNode;

Future<void> _press(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool control = false,
  bool shift = false,
}) async {
  if (control) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  }
  if (shift) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.sendKeyEvent(key);
  if (shift) {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  }
  if (control) {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  }
  await tester.pump();
}

Future<void> _focusEditor(WidgetTester tester, FocusNode editor) async {
  editor.requestFocus();
  await tester.pump();
  expect(editor.hasPrimaryFocus, isTrue);
}

Finder _primaryFocusIn(Finder container) {
  final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
  return find.descendant(
    of: container,
    matching: find.byElementPredicate(
      (Element element) => identical(element, focused),
    ),
  );
}

Future<void> _expectLeavesBothWays(
  WidgetTester tester, {
  Finder? forwardTo,
  Finder? backwardTo,
}) async {
  final FocusNode editor = _editorFocus(tester);
  final String source = NoteEditorDriver(tester).source;

  await _focusEditor(tester, editor);
  await _press(tester, LogicalKeyboardKey.tab, control: true);
  final FocusNode? next = FocusManager.instance.primaryFocus;
  expect(next, isNot(same(editor)));
  expect(next, isNot(isA<FocusScopeNode>()));
  if (forwardTo != null) {
    expect(_primaryFocusIn(forwardTo), findsOneWidget);
  }
  await _press(tester, LogicalKeyboardKey.tab, shift: true);
  expect(editor.hasPrimaryFocus, isTrue);

  await _focusEditor(tester, editor);
  await _press(tester, LogicalKeyboardKey.tab, control: true, shift: true);
  final FocusNode? previous = FocusManager.instance.primaryFocus;
  expect(previous, isNot(same(editor)));
  expect(previous, isNot(isA<FocusScopeNode>()));
  if (backwardTo != null) {
    expect(_primaryFocusIn(backwardTo), findsOneWidget);
  }
  await _press(tester, LogicalKeyboardKey.tab);
  expect(editor.hasPrimaryFocus, isTrue);

  expect(NoteEditorDriver(tester).source, source);
}

bool get _android => defaultTargetPlatform == TargetPlatform.android;

Iterable<RenderObject> _renderDepthFirst(RenderObject object) sync* {
  yield object;
  final List<RenderObject> children = <RenderObject>[];
  object.visitChildren(children.add);
  for (final RenderObject child in children) {
    yield* _renderDepthFirst(child);
  }
}

Set<Rect> _paintedRects(WidgetTester tester) => <Rect>{
  for (final RenderView view in tester.binding.renderViews)
    for (final RenderObject object in _renderDepthFirst(view))
      if (object is RenderBox &&
          object.hasSize &&
          (object is RenderDecoratedBox || object is RenderParagraph))
        MatrixUtils.transformRect(
          object.getTransformTo(null),
          Offset.zero & object.size,
        ),
};

Future<void> _useHighlight(
  WidgetTester tester,
  FocusHighlightStrategy strategy,
) async {
  FocusManager.instance.highlightStrategy = strategy;
  await tester.pump();
}

Future<void> _tabOn(WidgetTester tester) async {
  final Finder editors = find.byType(NoteEditorView);
  final bool inEditor =
      editors.evaluate().isNotEmpty && _editorFocus(tester).hasPrimaryFocus;
  await _press(tester, LogicalKeyboardKey.tab, control: inEditor);
}

void main() {
  group(
    'every tappable composer, recorder and media control is reachable by Tab with a visible ring',
    () {
      for (final String id in _stateIds) {
        testWidgets(id, (WidgetTester tester) async {
          await _pumpState(tester, id);
          await expectEveryTapTargetReachableByTab(tester);
        });
      }
    },
  );

  group('a focus ring moves nothing painted', () {
    for (final String id in _stateIds) {
      testWidgets(id, (WidgetTester tester) async {
        await _pumpState(tester, id);
        final FocusHighlightStrategy previous =
            FocusManager.instance.highlightStrategy;
        addTearDown(() => FocusManager.instance.highlightStrategy = previous);
        int ringed = 0;
        for (int press = 0; press < _guardTabPresses; press++) {
          await _useHighlight(tester, FocusHighlightStrategy.alwaysTraditional);
          await _tabOn(tester);
          ringed += find.byKey(focusRingKey).evaluate().length;
          final Set<Rect> withRing = _paintedRects(tester);
          await _useHighlight(tester, FocusHighlightStrategy.alwaysTouch);
          expect(find.byKey(focusRingKey), findsNothing);
          expect(
            _paintedRects(tester).difference(withRing),
            isEmpty,
            reason: 'Tab $press',
          );
        }
        expect(ringed, greaterThan(0));
      });
    }
  });

  group(
    'Control+Tab leaves the note editor forward and Control+Shift+Tab backward',
    () {
      testWidgets('from a paragraph', (WidgetTester tester) async {
        await _pumpState(tester, 'c2-composer-new');
        await _expectLeavesBothWays(
          tester,
          forwardTo: _android ? find.byKey(formatBoldKey) : null,
          backwardTo: _android ? find.byType(ComposerFooter) : null,
        );
      }, variant: _bothPlatforms);

      testWidgets('from a table cell', (WidgetTester tester) async {
        await _pumpState(tester, 'c8-table-toolbar');
        final FocusNode editor = _editorFocus(tester);
        final TextSelection cell = NoteEditorDriver(tester).selection;
        await _focusEditor(tester, editor);
        await _press(tester, LogicalKeyboardKey.tab);
        expect(editor.hasPrimaryFocus, isTrue);
        expect(NoteEditorDriver(tester).selection, isNot(cell));

        await NoteEditorDriver(tester).setSelection(cell);
        await _expectLeavesBothWays(
          tester,
          forwardTo: _android ? find.byType(TableToolbar) : null,
          backwardTo: _android ? find.byType(ComposerFooter) : null,
        );
      }, variant: _bothPlatforms);

      testWidgets('from a list item, where Tab still indents', (
        WidgetTester tester,
      ) async {
        await _pumpState(tester, 'c2-composer-new');
        final NoteEditorDriver driver = NoteEditorDriver(tester);
        await driver.enterText(_listNote);
        await driver.setSelection(
          const TextSelection.collapsed(offset: _listNote.length),
        );
        await _expectLeavesBothWays(tester);

        final FocusNode editor = _editorFocus(tester);
        await _focusEditor(tester, editor);
        await _press(tester, LogicalKeyboardKey.tab);
        expect(driver.source, _indentedListNote);
        expect(editor.hasPrimaryFocus, isTrue);
      }, variant: _bothPlatforms);
    },
  );
}
