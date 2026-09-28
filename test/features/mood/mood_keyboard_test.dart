import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/mood/mood_picker_grid.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../accessibility/states/viewer_states.dart';
import '../../accessibility/support/a11y_state.dart';
import '../../support/tab_reach.dart';
import 'support/mood_harness.dart';

const int _tabPresses = 12;

const int _guardTabPresses = 16;

const List<String> _stateIds = <String>[
  'd9-mood-prompt-today',
  'd10-mood-prompt-past',
  'd11-mood-picker',
  'd12-mood-set',
  'd16-day-past-mood',
];

Future<void> _pumpState(WidgetTester tester, String id) =>
    viewerStates.singleWhere((A11yState state) => state.id == id).pump(tester);

void _useKeyboardHighlight() {
  final FocusHighlightStrategy previous =
      FocusManager.instance.highlightStrategy;
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => FocusManager.instance.highlightStrategy = previous);
}

bool _focusIsWithin(Finder finder) {
  final BuildContext? focused = FocusManager.instance.primaryFocus?.context;
  if (focused is! Element) {
    return false;
  }
  final Element target = finder.evaluate().single;
  bool within = identical(focused, target);
  focused.visitAncestorElements((Element ancestor) {
    within = within || identical(ancestor, target);
    return !within;
  });
  return within;
}

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

void main() {
  group(
    'every tappable mood control is reachable by Tab with a visible ring',
    () {
      for (final String id in _stateIds) {
        testWidgets(id, (WidgetTester tester) async {
          await _pumpState(tester, id);
          await expectEveryTapTargetReachableByTab(tester);
        });
      }
    },
  );

  testWidgets('Enter and Space pick a focused mood tile', (
    WidgetTester tester,
  ) async {
    final List<Mood> picked = <Mood>[];
    await tester.pumpWidget(
      moodHarness(MoodPickerGrid(selected: null, onMoodSelected: picked.add)),
    );
    _useKeyboardHighlight();
    final Finder calm = find.ancestor(
      of: find.text(Mood.calm.label),
      matching: find.byType(FocusRing),
    );

    for (int press = 0; press < _tabPresses && !_focusIsWithin(calm); press++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(_focusIsWithin(calm), isTrue);
    expect(
      find.descendant(of: calm, matching: find.byKey(focusRingKey)),
      findsOneWidget,
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();

    expect(picked, <Mood>[Mood.calm, Mood.calm]);
  });

  group('keyboard focus moves nothing painted on the mood controls', () {
    for (final String id in _stateIds) {
      testWidgets(id, (WidgetTester tester) async {
        await _pumpState(tester, id);
        _useKeyboardHighlight();
        final Set<Rect> unfocused = _paintedRects(tester);
        int ringed = 0;
        for (int press = 0; press < _guardTabPresses; press++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          ringed += find.byKey(focusRingKey).evaluate().length;
          expect(
            unfocused.difference(_paintedRects(tester)),
            isEmpty,
            reason: 'Tab $press',
          );
        }
        expect(ringed, greaterThan(0));
      });
    }
  });
}
