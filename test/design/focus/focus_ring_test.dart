import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/palette.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/tab_reach.dart';

const Key _controlKey = ValueKey<String>('control');

const Size _controlSize = Size(120, 48);

void _useKeyboardHighlight() {
  final FocusHighlightStrategy previous =
      FocusManager.instance.highlightStrategy;
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => FocusManager.instance.highlightStrategy = previous);
}

FocusNode _focusNode() {
  final FocusNode node = FocusNode(debugLabel: 'control');
  addTearDown(node.dispose);
  return node;
}

Widget _bare(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: Center(child: child),
);

Widget _stamp() => Semantics(
  button: true,
  label: 'Stamp',
  onTap: () {},
  child: GestureDetector(
    onTap: () {},
    child: const SizedBox(width: 48, height: 48),
  ),
);

Future<void> _pumpControl(
  WidgetTester tester,
  FocusNode focusNode, {
  FocusRingSurface surface = FocusRingSurface.light,
}) => tester.pumpWidget(
  _bare(
    FocusRing(
      key: _controlKey,
      focusNode: focusNode,
      surface: surface,
      onPressed: () {},
      child: SizedBox.fromSize(size: _controlSize),
    ),
  ),
);

void main() {
  testWidgets(
    'a focused control paints the focus ring token without changing its size',
    (WidgetTester tester) async {
      _useKeyboardHighlight();
      final FocusNode focusNode = _focusNode();
      await _pumpControl(tester, focusNode);
      final Rect unfocused = tester.getRect(find.byKey(_controlKey));
      expect(find.byKey(focusRingKey), findsNothing);

      focusNode.requestFocus();
      await tester.pumpAndSettle();

      expect(tester.getRect(find.byKey(_controlKey)), unfocused);
      expect(unfocused.size, _controlSize);
      expect(tester.getRect(find.byKey(focusRingKey)), unfocused);
      expect(
        tester.renderObject(find.byKey(focusRingKey)),
        paints..rect(
          rect: (Offset.zero & _controlSize).deflate(1.5),
          color: Palette.focusRing,
          strokeWidth: 3,
          style: PaintingStyle.stroke,
        ),
      );
    },
  );

  testWidgets('Enter and Space activate a focused control', (
    WidgetTester tester,
  ) async {
    final FocusNode focusNode = _focusNode();
    int presses = 0;
    await tester.pumpWidget(
      _bare(
        FocusRing(
          focusNode: focusNode,
          onPressed: () => presses++,
          child: const SizedBox(width: 48, height: 48),
        ),
      ),
    );
    focusNode.requestFocus();
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(presses, 1);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(presses, 2);
  });

  testWidgets(
    'the tab reach check fails for a tappable box with no focus and passes '
    'for the base control',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: Center(child: _stamp())),
        ),
      );

      final Object? unreached = await expectEveryTapTargetReachableByTab(
        tester,
      ).then<Object?>((void _) => null, onError: (Object error) => error);
      expect(
        unreached,
        isA<TestFailure>().having(
          (TestFailure failure) => failure.message,
          'message',
          contains("'Stamp'"),
        ),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: FocusRing(onPressed: () {}, child: _stamp()),
            ),
          ),
        ),
      );

      await expectEveryTapTargetReachableByTab(tester);
    },
  );

  testWidgets('a control on a dark surface paints the dark ring token', (
    WidgetTester tester,
  ) async {
    _useKeyboardHighlight();
    final FocusNode focusNode = _focusNode();
    await _pumpControl(tester, focusNode, surface: FocusRingSurface.dark);
    focusNode.requestFocus();
    await tester.pumpAndSettle();

    expect(
      tester.renderObject(find.byKey(focusRingKey)),
      paints..rect(
        rect: (Offset.zero & _controlSize).deflate(1),
        color: Palette.focusRingOnDark,
        strokeWidth: 2,
        style: PaintingStyle.stroke,
      ),
    );
  });
}
