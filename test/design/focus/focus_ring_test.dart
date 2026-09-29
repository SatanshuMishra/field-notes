import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
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
  BorderRadius borderRadius = BorderRadius.zero,
}) => tester.pumpWidget(
  _bare(
    FocusRing(
      key: _controlKey,
      focusNode: focusNode,
      surface: surface,
      borderRadius: borderRadius,
      onPressed: () {},
      child: SizedBox.fromSize(size: _controlSize),
    ),
  ),
);

void main() {
  testWidgets(
    'a focused control paints its ring 2 px outside its edge without changing its size',
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
          rect: (Offset.zero & _controlSize).inflate(3.5),
          color: FieldNotesColors.light.ink,
          strokeWidth: 3,
          style: PaintingStyle.stroke,
        ),
      );
    },
  );

  testWidgets(
    'a focused rounded control paints its ring 2 px outside its rounded edge',
    (WidgetTester tester) async {
      _useKeyboardHighlight();
      final FocusNode focusNode = _focusNode();
      await _pumpControl(
        tester,
        focusNode,
        borderRadius: const BorderRadius.all(Radius.circular(15)),
      );
      focusNode.requestFocus();
      await tester.pumpAndSettle();

      final Rect control = Offset.zero & _controlSize;
      expect(
        tester.renderObject(find.byKey(focusRingKey)),
        paints..drrect(
          outer: RRect.fromRectAndRadius(
            control.inflate(5),
            const Radius.circular(20),
          ),
          inner: RRect.fromRectAndRadius(
            control.inflate(2),
            const Radius.circular(17),
          ),
          color: FieldNotesColors.light.ink,
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

  testWidgets(
    'a control on a dark surface paints the dark ring 2 px outside its edge',
    (WidgetTester tester) async {
      _useKeyboardHighlight();
      final FocusNode focusNode = _focusNode();
      await _pumpControl(tester, focusNode, surface: FocusRingSurface.dark);
      focusNode.requestFocus();
      await tester.pumpAndSettle();

      expect(
        tester.renderObject(find.byKey(focusRingKey)),
        paints..rect(
          rect: (Offset.zero & _controlSize).inflate(3),
          color: Palette.focusRingOnDark,
          strokeWidth: 2,
          style: PaintingStyle.stroke,
        ),
      );
    },
  );

  testWidgets(
    'a focused control at the end of a list scrolls its whole ring into view',
    (WidgetTester tester) async {
      _useKeyboardHighlight();
      final List<FocusNode> nodes = <FocusNode>[
        for (int index = 0; index < 6; index++) _focusNode(),
      ];
      final ScrollController scroll = ScrollController();
      addTearDown(scroll.dispose);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              height: 200,
              child: ListView(
                key: const ValueKey<String>('list'),
                controller: scroll,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: <Widget>[
                  for (int index = 0; index < nodes.length; index++)
                    FocusRing(
                      key: ValueKey<int>(index),
                      focusNode: nodes[index],
                      onPressed: () {},
                      child: const SizedBox(height: 50),
                    ),
                ],
              ),
            ),
          ),
        ),
      );

      nodes[3].requestFocus();
      await tester.pumpAndSettle();

      final Rect list = tester.getRect(
        find.byKey(const ValueKey<String>('list')),
      );
      final Rect ring = tester
          .getRect(find.byKey(const ValueKey<int>(3)))
          .inflate(5);
      expect(scroll.offset, 5);
      expect(list.top, lessThanOrEqualTo(ring.top));
      expect(list.bottom, greaterThanOrEqualTo(ring.bottom));
    },
  );

  testWidgets('a ring that is already fully visible scrolls nothing', (
    WidgetTester tester,
  ) async {
    _useKeyboardHighlight();
    final FocusNode focusNode = _focusNode();
    final ScrollController scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 200,
            height: 200,
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.all(8),
              children: <Widget>[
                FocusRing(
                  focusNode: focusNode,
                  onPressed: () {},
                  child: const SizedBox(height: 48),
                ),
                const SizedBox(height: 400),
              ],
            ),
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pumpAndSettle();

    expect(scroll.offset, 0);
  });
}
