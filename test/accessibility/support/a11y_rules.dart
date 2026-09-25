import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'a11y_state.dart' show A11yStateKind, A11yStatefulControl;

const String _unlabelledTap = 'unlabelled-tap';
const String _missingRole = 'missing-role';
const String _doubledTarget = 'doubled-target';
const String _repeatedText = 'repeated-text';
const String _missingState = 'missing-state';
const String _smallTarget = 'small-target';

const Map<String, String> a11yRuleDescriptions = <String, String>{
  _unlabelledTap:
      'A tappable node that is not a text field has an empty label and an '
      'empty tooltip.',
  _missingRole:
      'A tappable node has no button, text-field or slider flag and no '
      'checked or toggled state.',
  _doubledTarget:
      'Two tappable nodes have global rects within 2 logical pixels on every '
      'edge.',
  _repeatedText: 'A label repeats a non-empty line.',
  _missingState:
      'A control listed as stateful has no state of its listed kind.',
  _smallTarget:
      'A tappable node is narrower or shorter than 48 logical pixels.',
};

const double _minimumTarget = 48;

const double _doubledTolerance = 2;

const double _minimumGapToBoundary = 0.001;

final RegExp _lineBreak = RegExp(r'\r\n|\r|\n');

List<String> _segments(String text) => <String>[
  for (final String segment in text.split(_lineBreak))
    if (segment.trim() case final String trimmed when trimmed.isNotEmpty)
      trimmed,
];

String _oneLine(String text) => _segments(text).join(' / ');

class A11yFinding {
  const A11yFinding({
    required this.rule,
    required this.state,
    required this.label,
    required this.anchor,
    required this.rect,
    this.occurrence = 1,
  });

  final String rule;
  final String state;
  final String label;
  final String anchor;
  final Rect rect;
  final int occurrence;

  String get id {
    final String labelText = _oneLine(label);
    final String anchorText = _oneLine(anchor);
    final String suffix = occurrence > 1 ? ' #$occurrence' : '';
    return '$rule | $state | '
        '${labelText.isEmpty ? '<unlabelled>' : labelText} | '
        '${anchorText.isEmpty ? '<root>' : anchorText}$suffix';
  }

  A11yFinding numbered(int occurrence) => A11yFinding(
    rule: rule,
    state: state,
    label: label,
    anchor: anchor,
    rect: rect,
    occurrence: occurrence,
  );

  @override
  String toString() => '$id at $rect';
}

class _Visited {
  const _Visited({
    required this.index,
    required this.node,
    required this.data,
    required this.view,
    required this.rect,
    required this.anchor,
  });

  final int index;
  final SemanticsNode node;
  final SemanticsData data;
  final RenderView view;
  final Rect rect;
  final String anchor;

  String get label => data.label;

  bool get labelled => _oneLine(data.label).isNotEmpty;

  bool get tappable =>
      data.hasAction(ui.SemanticsAction.tap) ||
      data.hasAction(ui.SemanticsAction.longPress);

  bool get hasRole {
    final ui.SemanticsFlags flags = data.flagsCollection;
    return flags.isButton ||
        flags.isTextField ||
        flags.isSlider ||
        flags.isChecked != ui.CheckedState.none ||
        flags.isToggled != ui.Tristate.none;
  }

  bool hasState(A11yStateKind kind) {
    final ui.SemanticsFlags flags = data.flagsCollection;
    return switch (kind) {
      A11yStateKind.toggled => flags.isToggled != ui.Tristate.none,
      A11yStateKind.checked => flags.isChecked != ui.CheckedState.none,
      A11yStateKind.selected => flags.isSelected != ui.Tristate.none,
    };
  }

  A11yFinding finding(String rule, String state) => A11yFinding(
    rule: rule,
    state: state,
    label: label,
    anchor: anchor,
    rect: rect,
  );
}

Iterable<SemanticsNode> _selfAndAncestors(SemanticsNode node) sync* {
  for (
    SemanticsNode? current = node;
    current != null;
    current = current.parent
  ) {
    yield current;
  }
}

Iterable<SemanticsNode> _depthFirst(SemanticsNode node) sync* {
  yield node;
  final List<SemanticsNode> children = <SemanticsNode>[];
  node.visitChildren((SemanticsNode child) {
    children.add(child);
    return true;
  });
  for (final SemanticsNode child in children) {
    yield* _depthFirst(child);
  }
}

SemanticsNode _rootOf(RenderView view) {
  final SemanticsNode? root = view.owner?.semanticsOwner?.rootSemanticsNode;
  if (root == null) {
    throw StateError(
      'a11yFindings needs a semantics tree: call tester.ensureSemantics() '
      'and pump a frame first',
    );
  }
  return root;
}

bool _judged(SemanticsNode node) =>
    !node.isMergedIntoParent &&
    !node.isInvisible &&
    !node.flagsCollection.isHidden;

Rect _logicalRect(SemanticsNode node, double devicePixelRatio) {
  final Rect physical = _selfAndAncestors(node).fold(
    node.rect,
    (Rect rect, SemanticsNode current) => switch (current.transform) {
      final Matrix4 transform => MatrixUtils.transformRect(transform, rect),
      null => rect,
    },
  );
  return Rect.fromLTRB(
    physical.left / devicePixelRatio,
    physical.top / devicePixelRatio,
    physical.right / devicePixelRatio,
    physical.bottom / devicePixelRatio,
  );
}

String _anchorOf(SemanticsNode node) =>
    _selfAndAncestors(node)
        .skip(1)
        .map((SemanticsNode ancestor) => ancestor.getSemanticsData().label)
        .where((String label) => _oneLine(label).isNotEmpty)
        .firstOrNull ??
    '';

List<_Visited> _judgedInWalkOrder(WidgetTester tester) {
  final List<(RenderView, SemanticsNode)> walk = <(RenderView, SemanticsNode)>[
    for (final RenderView view in tester.binding.renderViews)
      for (final SemanticsNode node in _depthFirst(_rootOf(view))) (view, node),
  ];
  return <_Visited>[
    for (final (int index, (RenderView view, SemanticsNode node))
        in walk.indexed)
      if (_judged(node))
        _Visited(
          index: index,
          node: node,
          data: node.getSemanticsData(),
          view: view,
          rect: _logicalRect(node, view.flutterView.devicePixelRatio),
          anchor: _anchorOf(node),
        ),
  ];
}

bool _isAtBoundary(Rect child, Rect parent) =>
    !(child.left - parent.left > _minimumGapToBoundary &&
        parent.right - child.right > _minimumGapToBoundary &&
        child.top - parent.top > _minimumGapToBoundary &&
        parent.bottom - child.bottom > _minimumGapToBoundary);

bool _partlyOutside(_Visited visited) {
  Rect paintBounds = visited.node.rect;
  for (final SemanticsNode current in _selfAndAncestors(visited.node)) {
    final Matrix4? transform = current.transform;
    if (transform != null) {
      paintBounds = MatrixUtils.transformRect(transform, paintBounds);
    }
    if (current.flagsCollection.hasImplicitScrolling &&
        _isAtBoundary(paintBounds, current.rect)) {
      return true;
    }
  }
  return _isAtBoundary(
    paintBounds,
    Offset.zero & visited.view.flutterView.physicalSize,
  );
}

bool _unlabelled(_Visited visited) =>
    visited.tappable &&
    !visited.data.flagsCollection.isTextField &&
    !visited.labelled &&
    _oneLine(visited.data.tooltip).isEmpty;

bool _roleless(_Visited visited) => visited.tappable && !visited.hasRole;

bool _repeats(_Visited visited) {
  final List<String> segments = _segments(visited.label);
  return segments.toSet().length < segments.length;
}

bool _small(_Visited visited) =>
    visited.tappable &&
    !visited.data.flagsCollection.isHidden &&
    !visited.data.flagsCollection.isLink &&
    !_partlyOutside(visited) &&
    (visited.rect.width < _minimumTarget - precisionErrorTolerance ||
        visited.rect.height < _minimumTarget - precisionErrorTolerance);

bool _sameTarget(_Visited a, _Visited b) =>
    identical(a.view, b.view) &&
    (a.rect.left - b.rect.left).abs() <= _doubledTolerance &&
    (a.rect.top - b.rect.top).abs() <= _doubledTolerance &&
    (a.rect.right - b.rect.right).abs() <= _doubledTolerance &&
    (a.rect.bottom - b.rect.bottom).abs() <= _doubledTolerance;

_Visited _doubledHolder(_Visited earlier, _Visited later) =>
    earlier.labelled && !later.labelled ? earlier : later;

List<int> _doubledHolders(List<_Visited> judged) {
  final List<_Visited> tappable = <_Visited>[
    for (final _Visited visited in judged)
      if (visited.tappable) visited,
  ];
  return <int>[
    for (int i = 0; i < tappable.length; i++)
      for (int j = i + 1; j < tappable.length; j++)
        if (_sameTarget(tappable[i], tappable[j]))
          _doubledHolder(tappable[i], tappable[j]).index,
  ];
}

Iterable<SemanticsNode> _nodesFound(WidgetTester tester, Finder finder) sync* {
  final int count = finder.evaluate().length;
  for (int i = 0; i < count; i++) {
    final SemanticsNode? node = _semanticsOf(tester, finder.at(i));
    if (node != null) {
      yield node;
    }
  }
}

SemanticsNode? _semanticsOf(WidgetTester tester, Finder finder) {
  try {
    return tester.getSemantics(finder);
  } on StateError {
    return null;
  }
}

Iterable<(int, A11yStateKind)> _missingByFinder(
  WidgetTester tester,
  Map<SemanticsNode, _Visited> byNode,
  Finder finder,
  A11yStateKind kind,
) => <(int, A11yStateKind)>[
  for (final SemanticsNode node in _nodesFound(tester, finder))
    if (byNode[node] case final _Visited visited when !visited.hasState(kind))
      (visited.index, kind),
];

Iterable<(int, A11yStateKind)> _missingByLabel(
  List<_Visited> judged,
  String label,
  A11yStateKind kind,
) {
  final String wanted = _oneLine(label);
  final List<_Visited> candidates = <_Visited>[
    for (final _Visited visited in judged)
      if (wanted.isNotEmpty && _oneLine(visited.label) == wanted) visited,
  ];
  return candidates.isEmpty ||
          candidates.any((_Visited visited) => visited.hasState(kind))
      ? const <(int, A11yStateKind)>[]
      : <(int, A11yStateKind)>[(candidates.first.index, kind)];
}

Set<(int, A11yStateKind)> _missingStates(
  WidgetTester tester,
  List<_Visited> judged,
  List<A11yStatefulControl> stateful,
) {
  final Map<SemanticsNode, _Visited> byNode = <SemanticsNode, _Visited>{
    for (final _Visited visited in judged) visited.node: visited,
  };
  return <(int, A11yStateKind)>{
    for (final A11yStatefulControl control in stateful)
      ...switch (control) {
        A11yStatefulControl(:final Finder finder?) => _missingByFinder(
          tester,
          byNode,
          finder,
          control.kind,
        ),
        A11yStatefulControl(:final String label?) => _missingByLabel(
          judged,
          label,
          control.kind,
        ),
        _ => const <(int, A11yStateKind)>[],
      },
  };
}

List<A11yFinding> _numbered(List<A11yFinding> findings) {
  final List<String> ids = <String>[
    for (final A11yFinding finding in findings) finding.id,
  ];
  return <A11yFinding>[
    for (final (int i, A11yFinding finding) in findings.indexed)
      finding.numbered(
        ids.take(i + 1).where((String id) => id == ids[i]).length,
      ),
  ];
}

List<A11yFinding> a11yFindings(
  WidgetTester tester, {
  required String state,
  List<A11yStatefulControl> stateful = const <A11yStatefulControl>[],
}) {
  final List<_Visited> judged = _judgedInWalkOrder(tester);
  final List<int> doubled = _doubledHolders(judged);
  final Set<(int, A11yStateKind)> missingStates = _missingStates(
    tester,
    judged,
    stateful,
  );
  return _numbered(<A11yFinding>[
    for (final _Visited visited in judged) ...<A11yFinding>[
      if (_unlabelled(visited)) visited.finding(_unlabelledTap, state),
      if (_roleless(visited)) visited.finding(_missingRole, state),
      for (final int holder in doubled)
        if (holder == visited.index) visited.finding(_doubledTarget, state),
      if (_repeats(visited)) visited.finding(_repeatedText, state),
      for (final A11yStateKind kind in A11yStateKind.values)
        if (missingStates.contains((visited.index, kind)))
          visited.finding(_missingState, state),
      if (_small(visited)) visited.finding(_smallTarget, state),
    ],
  ]);
}
