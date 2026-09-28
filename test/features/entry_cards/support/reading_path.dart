import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

SemanticsNode _root(WidgetTester tester) => tester
    .binding
    .renderViews
    .single
    .owner!
    .semanticsOwner!
    .rootSemanticsNode!;

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

Rect globalSemanticsRect(WidgetTester tester, SemanticsNode node) {
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

List<SemanticsNode>? readingPathTo(WidgetTester tester, String label) {
  final SemanticsNode root = _root(tester);
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

bool frameCovers(Rect frame, Rect button) {
  final Rect reached = frame.intersect(button);
  return reached.width >= button.width - 0.01 &&
      reached.height >= button.height - 0.01;
}

void expectInsideEveryReadingFrame(WidgetTester tester, String label) {
  final List<SemanticsNode>? path = readingPathTo(tester, label);
  expect(path, isNotNull, reason: '$label is not in reading order');
  final Rect button = globalSemanticsRect(tester, path!.last);
  for (final SemanticsNode ancestor in path.sublist(0, path.length - 1)) {
    final Rect frame = globalSemanticsRect(tester, ancestor);
    expect(
      frameCovers(frame, button),
      isTrue,
      reason: 'node #${ancestor.id} $frame clips $label at $button',
    );
  }
}

List<int?> scrolledChildIndexes(WidgetTester tester) {
  final List<List<int?>> lists = <List<int?>>[];
  void walk(SemanticsNode node) {
    if (node.getSemanticsData().scrollExtentMax != null) {
      final List<int?> indexes = <int?>[];
      node.visitChildren((SemanticsNode child) {
        indexes.add(child.indexInParent);
        return true;
      });
      lists.add(indexes);
    }
    node.visitChildren((SemanticsNode child) {
      walk(child);
      return true;
    });
  }

  walk(_root(tester));
  expect(lists, hasLength(1), reason: 'expected one scrolling list');
  return lists.single;
}
