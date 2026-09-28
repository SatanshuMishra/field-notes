import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/compact/compact_log_card.dart';
import 'package:field_notes/features/entry_cards/compact/log_actions_pill.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/entry_cards_harness.dart';

const Key _cardKey = ValueKey<String>('card');

const Duration _settle = Duration(milliseconds: 200);

Set<SemanticsNode> _sentNodes(SemanticsNode root) {
  final Set<SemanticsNode> sent = <SemanticsNode>{};
  void walk(SemanticsNode node) {
    if (node.isMergedIntoParent) {
      return;
    }
    sent.add(node);
    if (node.mergeAllDescendantsIntoThisNode) {
      return;
    }
    node.visitChildren((SemanticsNode child) {
      walk(child);
      return true;
    });
  }

  walk(root);
  return sent;
}

List<SemanticsNode> _readingChildren(
  SemanticsNode node,
  Set<SemanticsNode> sent,
) {
  if (node.hasChildren && !node.mergeAllDescendantsIntoThisNode) {
    return node.debugListChildrenInOrder(
      DebugSemanticsDumpOrder.traversalOrder,
    );
  }
  final Object? identifier = node.traversalParentIdentifier;
  if (identifier == null || kIsWeb) {
    return const <SemanticsNode>[];
  }
  return sent
      .where(
        (SemanticsNode candidate) =>
            candidate.attached &&
            candidate.traversalChildIdentifier == identifier,
      )
      .toList();
}

Rect _globalRect(WidgetTester tester, SemanticsNode node) {
  Rect rect = node.rect;
  for (
    SemanticsNode? current = node;
    current != null;
    current = current.parent
  ) {
    final Matrix4? transform = current.transform;
    if (transform != null) {
      rect = MatrixUtils.transformRect(transform, rect);
    }
  }
  final double ratio = tester.view.devicePixelRatio;
  return Rect.fromLTRB(
    rect.left / ratio,
    rect.top / ratio,
    rect.right / ratio,
    rect.bottom / ratio,
  );
}

List<SemanticsNode>? _readingPath(WidgetTester tester, String label) {
  final SemanticsNode root = tester
      .binding
      .renderViews
      .single
      .owner!
      .semanticsOwner!
      .rootSemanticsNode!;
  final Set<SemanticsNode> sent = _sentNodes(root);
  final Set<SemanticsNode> seen = <SemanticsNode>{};
  List<SemanticsNode>? walk(SemanticsNode node, List<SemanticsNode> path) {
    if (!seen.add(node)) {
      return null;
    }
    if (node.getSemanticsData().label == label) {
      return <SemanticsNode>[...path, node];
    }
    for (final SemanticsNode child in _readingChildren(node, sent)) {
      final List<SemanticsNode>? found = walk(child, <SemanticsNode>[
        ...path,
        node,
      ]);
      if (found != null) {
        return found;
      }
    }
    return null;
  }

  return walk(root, const <SemanticsNode>[]);
}

bool _covers(Rect frame, Rect button) {
  final Rect reached = frame.intersect(button);
  return reached.width >= button.width - 0.01 &&
      reached.height >= button.height - 0.01;
}

Future<void> _settleReveal(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(_settle);
}

double _pillOpacity(WidgetTester tester) => tester
    .widget<Opacity>(
      find
          .ancestor(
            of: find.byKey(logActionsPillKey),
            matching: find.byType(Opacity),
          )
          .first,
    )
    .opacity;

Widget _list(ScrollController scroll, List<Widget> children) {
  return MaterialApp(
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 400,
          height: 300,
          child: ListView(controller: scroll, children: children),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets("the revealed pill's buttons lie inside a reading-order "
      "ancestor's frame", (WidgetTester tester) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 371,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 139),
                  child: CompactLogCard(
                    entry: entryOf(
                      type: EntryType.text,
                      textContent: 'Harbour walk',
                    ),
                    resolver: FakeMediaResolver(),
                    density: CompactLogDensity.feed,
                    onOpen: () {},
                    onEdit: () {},
                    onDelete: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.getSize(find.byType(CompactLogCard)), const Size(371, 139));
    await tester.longPress(find.byType(CompactLogCard));
    await tester.pumpAndSettle();

    for (final String label in <String>[
      logActionsEditLabel,
      logActionsDeleteLabel,
    ]) {
      final List<SemanticsNode>? path = _readingPath(tester, label);
      expect(path, isNotNull, reason: '$label is not in reading order');
      final Rect button = _globalRect(tester, path!.last);
      expect(button.height, moreOrLessEquals(48, epsilon: 0.01));
      for (final SemanticsNode ancestor in path.sublist(0, path.length - 1)) {
        final Rect frame = _globalRect(tester, ancestor);
        expect(
          _covers(frame, button),
          isTrue,
          reason: 'node #${ancestor.id} $frame clips $label at $button',
        );
      }
    }
    semantics.dispose();
  });

  testWidgets('a pill whose card top is scrolled out of the list is hidden', (
    WidgetTester tester,
  ) async {
    final ScrollController scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      _list(scroll, <Widget>[
        LogActionsReveal(
          onEdit: () {},
          onDelete: () {},
          child: const SizedBox(key: _cardKey, height: 400),
        ),
        const SizedBox(height: 400),
      ]),
    );
    final Rect list = tester.getRect(find.byType(ListView));
    scroll.jumpTo(350);
    await tester.pump();
    expect(
      tester.getRect(find.byKey(_cardKey)).bottom,
      moreOrLessEquals(list.top + 50, epsilon: 0.01),
    );

    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: list.bottomRight + const Offset(40, 40));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(list.topCenter + const Offset(0, 25));
    await _settleReveal(tester);
    expect(_pillOpacity(tester), 0);

    scroll.jumpTo(0);
    await tester.pump();
    await _settleReveal(tester);
    expect(_pillOpacity(tester), 1);

    scroll.jumpTo(350);
    await tester.pump();
    await tester.pump();
    expect(_pillOpacity(tester), 0);
  });

  testWidgets('a hover caused by scrolling reveals no pill until the pointer '
      'moves', (WidgetTester tester) async {
    final ScrollController scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      _list(scroll, <Widget>[
        const SizedBox(height: 300),
        LogActionsReveal(
          onEdit: () {},
          onDelete: () {},
          child: const SizedBox(key: _cardKey, height: 100),
        ),
        const SizedBox(height: 800),
      ]),
    );
    final Rect list = tester.getRect(find.byType(ListView));
    final Offset parked = list.topCenter + const Offset(0, 150);
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: parked);
    addTearDown(mouse.removePointer);
    await tester.pump();
    expect(
      tester
          .getRect(find.byKey(_cardKey, skipOffstage: false))
          .contains(parked),
      isFalse,
    );

    scroll.jumpTo(200);
    await tester.pump();
    await _settleReveal(tester);
    expect(tester.getRect(find.byKey(_cardKey)).contains(parked), isTrue);
    expect(_pillOpacity(tester), 0);

    await mouse.moveBy(const Offset(2, 0));
    await _settleReveal(tester);
    expect(_pillOpacity(tester), 1);
  });

  testWidgets('a resize that brings the card top into view shows its pill', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final ScrollController scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: scroll,
            children: <Widget>[
              const SizedBox(height: 50),
              LogActionsReveal(
                onEdit: () {},
                onDelete: () {},
                child: const SizedBox(key: _cardKey, height: 300),
              ),
              const SizedBox(height: 600),
            ],
          ),
        ),
      ),
    );
    scroll.jumpTo(100);
    await tester.pump();
    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: const Offset(700, 590));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(const Offset(400, 100));
    await _settleReveal(tester);
    expect(tester.getRect(find.byKey(_cardKey)).top, -50);
    expect(_pillOpacity(tester), 0);

    tester.view.physicalSize = const Size(800, 1200);
    await tester.pump();
    await _settleReveal(tester);
    expect(tester.getRect(find.byKey(_cardKey)).top, 50);
    expect(_pillOpacity(tester), 1);
  });

  testWidgets('a revealed card in a list covers its pill with its own node', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
            children: <Widget>[
              for (final String id in <String>['a', 'b'])
                CompactLogCard(
                  entry: entryOf(
                    id: id,
                    type: EntryType.text,
                    textContent: 'Harbour walk',
                  ),
                  resolver: FakeMediaResolver(),
                  density: CompactLogDensity.feed,
                  onOpen: () {},
                  onEdit: () {},
                  onDelete: () {},
                ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.longPress(find.byType(CompactLogCard).first);
    await tester.pumpAndSettle();

    for (final String label in <String>[
      logActionsEditLabel,
      logActionsDeleteLabel,
    ]) {
      final List<SemanticsNode> path = _readingPath(tester, label)!;
      final Rect button = _globalRect(tester, path.last);
      final SemanticsNode card = path.lastWhere(
        (SemanticsNode node) =>
            node.getSemanticsData().hasAction(SemanticsAction.longPress),
      );
      expect(
        _covers(_globalRect(tester, card), button),
        isTrue,
        reason: 'the card node clips $label at $button',
      );
    }
    semantics.dispose();
  });
}
