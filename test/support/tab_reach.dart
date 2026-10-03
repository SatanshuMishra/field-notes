import 'dart:ui' as ui;

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/features/note_engine/editor/note_editor_view.dart';
import 'package:field_notes/features/note_engine/render/render_note_view.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const int _maxTabPresses = 120;

const double _screenTolerance = 0.5;

const String _dismissPrefix = 'Dismiss';

class _Target {
  const _Target({required this.name, required this.rect, required this.view});

  final String name;
  final Rect rect;
  final RenderView view;
}

class _Stop {
  const _Stop({
    required this.node,
    required this.rect,
    required this.view,
    required this.editable,
    required this.ringed,
  });

  final FocusNode node;
  final Rect? rect;
  final RenderView? view;
  final bool editable;
  final bool ringed;

  bool get control => node is! FocusScopeNode;

  bool get needsRing => control && !editable;

  bool reaches(_Target target) => switch (rect) {
    final Rect rect when control && identical(view, target.view) =>
      target.rect.contains(rect.center) ||
          (!editable && rect.contains(target.rect.center)),
    _ => false,
  };
}

Future<void> expectEveryTapTargetReachableByTab(WidgetTester tester) async {
  final SemanticsHandle semantics = tester.ensureSemantics();
  final FocusHighlightStrategy strategy =
      FocusManager.instance.highlightStrategy;
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  try {
    await _settle(tester);
    final List<_Target> targets = _tapTargets(tester);
    final List<_Stop> stops = await _tabStops(tester);
    final List<String> problems = <String>[
      for (final _Target target in targets)
        if (!stops.any((_Stop stop) => stop.reaches(target)))
          '${target.name} is never reached by Tab',
      for (final _Stop stop in stops)
        if (stop.needsRing && !stop.ringed)
          '${_stopName(stop, targets)} takes Tab focus with no focus ring',
    ];
    if (problems.isNotEmpty) {
      fail(problems.join('\n'));
    }
  } finally {
    FocusManager.instance.highlightStrategy = strategy;
    semantics.dispose();
  }
}

Future<List<_Stop>> _tabStops(WidgetTester tester) async {
  await _pressTab(tester);
  final FocusNode? first = FocusManager.instance.primaryFocus;
  if (first == null) {
    return const <_Stop>[];
  }
  final List<_Stop> stops = <_Stop>[_stopAt(first)];
  for (int press = 1; press < _maxTabPresses; press++) {
    final _Stop from = stops.last;
    final FocusNode? next = await _advance(tester, from);
    if (next == null || identical(next, first) || identical(next, from.node)) {
      break;
    }
    stops.add(_stopAt(next));
  }
  return List<_Stop>.unmodifiable(stops);
}

Future<FocusNode?> _advance(WidgetTester tester, _Stop from) async {
  await _pressTab(tester);
  final FocusNode? next = FocusManager.instance.primaryFocus;
  if (!identical(next, from.node) || !from.editable) {
    return next;
  }
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await _settle(tester);
  return FocusManager.instance.primaryFocus;
}

Future<void> _pressTab(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await _settle(tester);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
}

_Stop _stopAt(FocusNode node) {
  final BuildContext? context = node.context;
  final RenderObject? object = context?.findRenderObject();
  final RenderView? view = object == null || !object.attached
      ? null
      : _viewOf(object);
  final Rect? rect = view == null ? null : _renderRect(object!, view);
  return _Stop(
    node: node,
    rect: rect,
    view: view,
    editable: context != null && _isEditable(node, context),
    ringed:
        context is Element &&
        rect != null &&
        view != null &&
        _hasRing(context, rect, view),
  );
}

bool _isEditable(FocusNode node, BuildContext context) =>
    identical(
      context.findAncestorWidgetOfExactType<EditableText>()?.focusNode,
      node,
    ) ||
    identical(
      context.findAncestorWidgetOfExactType<NoteEditorView>()?.focusNode,
      node,
    );

bool _hasRing(Element focus, Rect rect, RenderView view) => find
    .byKey(focusRingKey)
    .evaluate()
    .any(
      (Element ring) =>
          _isWithin(ring, focus) || _ringCentredIn(ring, rect, view),
    );

bool _isWithin(Element element, Element ancestor) {
  final List<Element> ancestors = <Element>[];
  element.visitAncestorElements((Element parent) {
    ancestors.add(parent);
    return true;
  });
  return ancestors.any((Element parent) => identical(parent, ancestor));
}

bool _ringCentredIn(Element ring, Rect rect, RenderView view) =>
    switch (ring.renderObject) {
      final RenderObject object when object.attached =>
        identical(_viewOf(object), view) &&
            rect.contains(_renderRect(object, view).center),
      _ => false,
    };

String _stopName(_Stop stop, List<_Target> targets) {
  final String at = switch (stop.rect) {
    final Rect rect => ' at $rect',
    null => '',
  };
  final List<String> names = <String>[
    for (final _Target target in targets)
      if (stop.reaches(target)) target.name,
  ];
  return names.isEmpty
      ? 'focus node ${stop.node.debugLabel ?? stop.node.toStringShort()}$at'
      : names.join(', ');
}

RenderObject _rootOf(RenderObject object) => switch (object.parent) {
  final RenderObject parent => _rootOf(parent),
  null => object,
};

RenderView? _viewOf(RenderObject object) => switch (_rootOf(object)) {
  final RenderView view => view,
  _ => null,
};

Rect _logical(Rect physical, RenderView view) {
  final double ratio = view.flutterView.devicePixelRatio;
  return Rect.fromLTRB(
    physical.left / ratio,
    physical.top / ratio,
    physical.right / ratio,
    physical.bottom / ratio,
  );
}

Rect _renderRect(RenderObject object, RenderView view) => _logical(
  MatrixUtils.transformRect(object.getTransformTo(view), object.paintBounds),
  view,
);

Iterable<SemanticsNode> _selfAndAncestors(SemanticsNode node) sync* {
  for (
    SemanticsNode? current = node;
    current != null;
    current = current.parent
  ) {
    yield current;
  }
}

Rect _semanticsRect(SemanticsNode node, RenderView view) => _logical(
  _selfAndAncestors(node).fold(
    node.rect,
    (Rect rect, SemanticsNode current) => switch (current.transform) {
      final Matrix4 transform => MatrixUtils.transformRect(transform, rect),
      null => rect,
    },
  ),
  view,
);

Iterable<SemanticsNode> _semanticsDepthFirst(SemanticsNode node) sync* {
  yield node;
  final List<SemanticsNode> children = <SemanticsNode>[];
  node.visitChildren((SemanticsNode child) {
    children.add(child);
    return true;
  });
  for (final SemanticsNode child in children) {
    yield* _semanticsDepthFirst(child);
  }
}

Iterable<RenderObject> _renderDepthFirst(RenderObject object) sync* {
  yield object;
  final List<RenderObject> children = <RenderObject>[];
  object.visitChildren(children.add);
  for (final RenderObject child in children) {
    yield* _renderDepthFirst(child);
  }
}

Iterable<SemanticsNode> _nodesProducedIn(RenderObject root) sync* {
  for (final RenderObject object in _renderDepthFirst(root)) {
    if (object.debugSemantics case final SemanticsNode node) {
      yield* _semanticsDepthFirst(node);
    }
  }
}

bool _isSelectionToolbar(Widget widget) =>
    widget is AdaptiveTextSelectionToolbar ||
    widget is TextSelectionToolbar ||
    widget is DesktopTextSelectionToolbar ||
    widget is CupertinoTextSelectionToolbar ||
    widget is CupertinoDesktopTextSelectionToolbar;

Set<SemanticsNode> _excludedNodes(WidgetTester tester) => <SemanticsNode>{
  for (final RenderView view in tester.binding.renderViews)
    for (final RenderObject object in _renderDepthFirst(view))
      if (object is RenderNoteView) ..._nodesProducedIn(object),
  for (final Element toolbar
      in find.byWidgetPredicate(_isSelectionToolbar).evaluate())
    if (toolbar.renderObject case final RenderObject object)
      ..._nodesProducedIn(object),
};

bool _isTapTarget(SemanticsNode node, SemanticsData data) =>
    data.hasAction(ui.SemanticsAction.tap) &&
    data.flagsCollection.isEnabled != ui.Tristate.isFalse &&
    !data.flagsCollection.isTextField &&
    !data.flagsCollection.isHidden &&
    !node.isMergedIntoParent &&
    !node.isInvisible;

bool _covers(Rect rect, Rect screen) =>
    rect.left <= screen.left + _screenTolerance &&
    rect.top <= screen.top + _screenTolerance &&
    rect.right >= screen.right - _screenTolerance &&
    rect.bottom >= screen.bottom - _screenTolerance;

String _nameOf(SemanticsData data, Rect rect) {
  final String label = data.label.trim().isNotEmpty
      ? data.label.trim()
      : data.tooltip.trim();
  return label.isEmpty ? '<unlabelled> at $rect' : "'$label' at $rect";
}

List<_Target> _tapTargets(WidgetTester tester) {
  final Set<SemanticsNode> excluded = _excludedNodes(tester);
  return List<_Target>.unmodifiable(<_Target>[
    for (final RenderView view in tester.binding.renderViews)
      if (view.owner?.semanticsOwner?.rootSemanticsNode
          case final SemanticsNode root)
        for (final SemanticsNode node in _semanticsDepthFirst(root))
          if (!excluded.contains(node))
            if (node.getSemanticsData() case final SemanticsData data
                when _isTapTarget(node, data))
              if (_semanticsRect(node, view) case final Rect rect
                  when !(data.label.startsWith(_dismissPrefix) &&
                      _covers(rect, _semanticsRect(root, view))))
                _Target(name: _nameOf(data, rect), rect: rect, view: view),
  ]);
}
