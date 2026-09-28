import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

Iterable<SemanticsNode> _roots(WidgetTester tester) sync* {
  for (final RenderView view in tester.binding.renderViews) {
    final SemanticsNode? root = view.owner?.semanticsOwner?.rootSemanticsNode;
    if (root != null) {
      yield root;
    }
  }
}

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

List<SemanticsNode> _traversalChildren(
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

List<String> readingOrderOrphans(WidgetTester tester) {
  final List<String> orphans = <String>[];
  for (final SemanticsNode root in _roots(tester)) {
    final Set<SemanticsNode> sent = _sentNodes(root);
    final Set<SemanticsNode> reached = <SemanticsNode>{};
    void walk(SemanticsNode node) {
      if (!reached.add(node)) {
        return;
      }
      for (final SemanticsNode child in _traversalChildren(node, sent)) {
        walk(child);
      }
    }

    walk(root);
    for (final SemanticsNode node in sent.difference(reached)) {
      final String label = node.getSemanticsData().label;
      orphans.add('#${node.id} "${label.replaceAll('\n', ' ')}"');
    }
  }
  return orphans;
}

List<String> labelsInReadingOrder(WidgetTester tester) {
  final List<String> labels = <String>[];
  for (final SemanticsNode root in _roots(tester)) {
    final Set<SemanticsNode> sent = _sentNodes(root);
    final Set<SemanticsNode> seen = <SemanticsNode>{};
    void walk(SemanticsNode node) {
      if (!seen.add(node)) {
        return;
      }
      final String label = node.getSemanticsData().label;
      if (label.isNotEmpty) {
        labels.add(label);
      }
      for (final SemanticsNode child in _traversalChildren(node, sent)) {
        walk(child);
      }
    }

    walk(root);
  }
  return labels;
}
