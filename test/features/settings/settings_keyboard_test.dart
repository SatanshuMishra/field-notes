import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/features/capture/video/video_recorder_sheet.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../accessibility/states/capture_states.dart';
import '../../accessibility/states/settings_states.dart';
import '../../accessibility/states/viewer_states.dart';
import '../../accessibility/support/a11y_state.dart';
import '../../support/tab_reach.dart';

const int _tabPresses = 24;

const List<String> _stateIds = <String>[
  'b1-settings',
  'b2-settings-spell-unavailable',
  'b3-settings-notice',
  'b5-delete-all-dialog',
  'b6-settings-reminders',
  'b7-settings-journal',
  'b8-settings-data',
  'c10-discard-dialog',
  'c18-discard-recording',
  'd13-change-mood-dialog',
  'd14-delete-entry-dialog',
];

final List<A11yState> _states = <A11yState>[
  ...settingsStates,
  ...captureStates,
  ...viewerStates,
];

Future<void> _pumpState(WidgetTester tester, String id) =>
    _states.singleWhere((A11yState state) => state.id == id).pump(tester);

Future<void> _pumpVideoDiscard(WidgetTester tester) async {
  await _pumpState(tester, 'c17-video-paused');
  await tester.tap(find.byKey(videoDiscardCircleKey));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

Iterable<RenderObject> _renderDepthFirst(RenderObject object) sync* {
  yield object;
  final List<RenderObject> children = <RenderObject>[];
  object.visitChildren(children.add);
  for (final RenderObject child in children) {
    yield* _renderDepthFirst(child);
  }
}

List<Rect> _paintedRects(WidgetTester tester) => List<Rect>.unmodifiable(<Rect>[
  for (final RenderView view in tester.binding.renderViews)
    for (final RenderObject object in _renderDepthFirst(view))
      if (object is RenderBox &&
          object.hasSize &&
          (object is RenderDecoratedBox || object is RenderParagraph))
        MatrixUtils.transformRect(
          object.getTransformTo(null),
          Offset.zero & object.size,
        ),
]);

void _useKeyboardHighlight() {
  final FocusHighlightStrategy previous =
      FocusManager.instance.highlightStrategy;
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => FocusManager.instance.highlightStrategy = previous);
}

class _SafeButton {
  const _SafeButton(this.name, this.pump, this.label);

  final String name;
  final Future<void> Function(WidgetTester tester) pump;
  final String label;
}

final List<_SafeButton> _safeButtons = <_SafeButton>[
  _SafeButton(
    'b5-delete-all-dialog',
    (WidgetTester tester) => _pumpState(tester, 'b5-delete-all-dialog'),
    'Keep my journal',
  ),
  _SafeButton(
    'c10-discard-dialog',
    (WidgetTester tester) => _pumpState(tester, 'c10-discard-dialog'),
    'Keep editing',
  ),
  _SafeButton(
    'c18-discard-recording',
    (WidgetTester tester) => _pumpState(tester, 'c18-discard-recording'),
    'Cancel',
  ),
  const _SafeButton('video discard', _pumpVideoDiscard, 'Cancel'),
  _SafeButton(
    'd13-change-mood-dialog',
    (WidgetTester tester) => _pumpState(tester, 'd13-change-mood-dialog'),
    'Cancel',
  ),
  _SafeButton(
    'd14-delete-entry-dialog',
    (WidgetTester tester) => _pumpState(tester, 'd14-delete-entry-dialog'),
    'Cancel',
  ),
];

void main() {
  group(
    'every tappable Settings and dialog control is reachable by Tab with a visible ring',
    () {
      for (final String id in _stateIds) {
        testWidgets(id, (WidgetTester tester) async {
          await _pumpState(tester, id);
          await expectEveryTapTargetReachableByTab(tester);
        });
      }
    },
  );

  group('keyboard focus moves nothing painted', () {
    for (final String id in _stateIds) {
      testWidgets(id, (WidgetTester tester) async {
        await _pumpState(tester, id);
        _useKeyboardHighlight();
        final List<Rect> unfocused = _paintedRects(tester);
        int ringed = 0;
        for (int press = 0; press < _tabPresses; press++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          ringed += find.byKey(focusRingKey).evaluate().length;
          expect(_paintedRects(tester), unfocused, reason: 'Tab $press');
        }
        expect(ringed, greaterThan(0));
      });
    }
  });

  group('a dialog opened by a tap focuses its safe button with no ring', () {
    for (final _SafeButton safe in _safeButtons) {
      testWidgets(safe.name, (WidgetTester tester) async {
        await safe.pump(tester);

        final FocusNode? focused = FocusManager.instance.primaryFocus;
        expect(focused, isNot(isA<FocusScopeNode>()));
        expect(
          find.descendant(
            of: find.ancestor(
              of: find.text(safe.label),
              matching: find.byType(FocusRing),
            ),
            matching: find.byElementPredicate(
              (Element element) => identical(element, focused?.context),
            ),
          ),
          findsOneWidget,
        );
        expect(find.byKey(focusRingKey), findsNothing);
      });
    }
  });
}
