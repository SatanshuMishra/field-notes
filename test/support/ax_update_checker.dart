import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

class AxUpdateChecker {
  AxUpdateChecker._();

  static final AxUpdateChecker instance = AxUpdateChecker._();

  final Map<int, List<int>> _children = <int, List<int>>{};
  final List<String> rejections = <String>[];
  int updates = 0;

  void reset() {
    _children.clear();
    rejections.clear();
    updates = 0;
  }

  void apply(Map<int, List<int>> update) {
    updates++;
    final Map<int, List<int>> next = <int, List<int>>{..._children, ...update};
    final Set<int> reachable = <int>{};
    final List<int> queue = <int>[0];
    while (queue.isNotEmpty) {
      final int id = queue.removeLast();
      if (!reachable.add(id)) {
        continue;
      }
      queue.addAll(next[id] ?? const <int>[]);
    }
    final List<String> problems = <String>[
      for (final int id in update.keys)
        if (id != 0 && !reachable.contains(id))
          '$id will not be in the tree and is not the new root',
    ];
    final Map<int, int> parentOf = <int, int>{};
    for (final int parent in reachable) {
      for (final int child in next[parent] ?? const <int>[]) {
        final int? earlier = parentOf[child];
        if (earlier != null && earlier != parent) {
          problems.add('$child has two parents, $earlier and $parent');
        }
        parentOf[child] = parent;
      }
    }
    if (problems.isNotEmpty) {
      rejections.addAll(problems);
      return;
    }
    _children
      ..clear()
      ..addAll(<int, List<int>>{
        for (final int id in reachable) id: next[id] ?? const <int>[],
      });
  }
}

class _CheckingBuilder implements ui.SemanticsUpdateBuilder {
  final ui.SemanticsUpdateBuilder _real = ui.SemanticsUpdateBuilder();
  final Map<int, List<int>> _update = <int, List<int>>{};

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #updateNode) {
      final int id = invocation.namedArguments[#id] as int;
      final List<int> children =
          (invocation.namedArguments[#childrenInTraversalOrder] as List<int>)
              .toList();
      _update[id] = children;
    }
    if (invocation.memberName == #build) {
      AxUpdateChecker.instance.apply(_update);
    }
    return Function.apply(
      _forward(invocation.memberName),
      invocation.positionalArguments,
      invocation.namedArguments,
    );
  }

  Function _forward(Symbol name) => switch (name) {
    #updateNode => _real.updateNode,
    #updateCustomAction => _real.updateCustomAction,
    #build => _real.build,
    _ => throw UnsupportedError('$name'),
  };
}

class AxCheckingBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  ui.SemanticsUpdateBuilder createSemanticsUpdateBuilder() => _CheckingBuilder();

  static AxCheckingBinding ensureInitialized() {
    return AxCheckingBinding();
  }
}
