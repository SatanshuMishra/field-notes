import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'a11y_state.dart' show A11yStateKind, A11yStatefulControl;
import 'a11y_variants.dart';

const String _unlabelledTap = 'unlabelled-tap';
const String _missingRole = 'missing-role';
const String _doubledTarget = 'doubled-target';
const String _repeatedText = 'repeated-text';
const String _missingState = 'missing-state';
const String _smallTarget = 'small-target';
const String _inertButton = 'inert-button';
const String _flutterTextContrast = 'flutter-text-contrast';
const String _textContrast = 'text-contrast';
const String _overflow = 'overflow';
const String _truncatedText = 'truncated-text';
const String _overlappingText = 'overlapping-text';
const String _focusVisible = 'focus-visible';
const String _liveRegion = 'live-region';
const String _keyboard = 'keyboard';

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
      'A tappable node is narrower or shorter than the platform minimum, 48 '
      'by 48 on Android, 28 by 28 on macOS and 40 by 40 on Windows, in the '
      'part a tap can reach, or in its whole size when a clip shows more than '
      "half of it on each axis, or Flutter's tap target guideline for the "
      'platform fails it.',
  _inertButton:
      'A node with the button flag that is not disabled has no tap and no '
      'long-press action.',
  _flutterTextContrast:
      "Flutter's textContrastGuideline fails a node's text, at 4.5:1, or 3:1 "
      'from 18 logical pixels or 14 bold.',
  _textContrast:
      'Painted text, including text under ExcludeSemantics, reaches less '
      'than 4.5:1 against the pixels around it, or 3:1 from 24 logical '
      'pixels or 18.66 bold.',
  _overflow: 'A RenderFlex or other box overflowed its space.',
  _truncatedText:
      'At 2x text a paragraph ellipsises, fades, clips or exceeds its max '
      'lines.',
  _overlappingText: "At 2x text two painted paragraphs' line boxes overlap.",
  _focusVisible:
      'A control focused with the keyboard paints its edge less than 3:1 '
      'apart from its unfocused paint.',
  _liveRegion:
      'A text changed while the state was pumped and no enclosing node is a '
      'live region.',
  _keyboard:
      'On macOS and Windows a node with a tap action is never focused while '
      'Tab moves through the state.',
};

const double _doubledTolerance = 2;

const double _clipTolerance = 0.001;

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
    required this.reachable,
    required this.whole,
    required this.anchor,
  });

  final int index;
  final SemanticsNode node;
  final SemanticsData data;
  final RenderView view;
  final Rect rect;
  final Rect reachable;
  final Rect? whole;
  final String anchor;

  String get label => data.label;

  bool get labelled => _oneLine(data.label).isNotEmpty;

  bool get tappable => _tappable(data);

  bool get clipped => switch (whole) {
    final Rect whole =>
      rect.width < whole.width - _clipTolerance ||
          rect.height < whole.height - _clipTolerance,
    null => false,
  };

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

Iterable<RenderObject> _renderDepthFirst(RenderObject object) sync* {
  yield object;
  final List<RenderObject> children = <RenderObject>[];
  object.visitChildren(children.add);
  for (final RenderObject child in children) {
    yield* _renderDepthFirst(child);
  }
}

Rect _logical(Rect physical, double devicePixelRatio) => Rect.fromLTRB(
  physical.left / devicePixelRatio,
  physical.top / devicePixelRatio,
  physical.right / devicePixelRatio,
  physical.bottom / devicePixelRatio,
);

Rect _logicalRect(SemanticsNode node, double devicePixelRatio) => _logical(
  _selfAndAncestors(node).fold(
    node.rect,
    (Rect rect, SemanticsNode current) => switch (current.transform) {
      final Matrix4 transform => MatrixUtils.transformRect(transform, rect),
      null => rect,
    },
  ),
  devicePixelRatio,
);

Rect _within(Rect rect, Rect bounds) =>
    rect.overlaps(bounds) ? rect.intersect(bounds) : Rect.zero;

Rect _reachableRect(SemanticsNode node, double devicePixelRatio) =>
    _selfAndAncestors(node)
        .skip(1)
        .fold(
          _logicalRect(node, devicePixelRatio),
          (Rect reachable, SemanticsNode ancestor) =>
              _within(reachable, _logicalRect(ancestor, devicePixelRatio)),
        );

Map<SemanticsNode, Rect> _wholeRects(Iterable<RenderView> views) {
  final Map<SemanticsNode, Rect> whole = <SemanticsNode, Rect>{};
  for (final RenderView view in views) {
    for (final RenderObject owner in _renderDepthFirst(view)) {
      if (owner.debugSemantics case final SemanticsNode node) {
        final Rect bounds = _logical(
          MatrixUtils.transformRect(
            owner.getTransformTo(view),
            owner.semanticBounds,
          ),
          view.flutterView.devicePixelRatio,
        );
        whole.update(
          node,
          (Rect other) => other.expandToInclude(bounds),
          ifAbsent: () => bounds,
        );
      }
    }
  }
  return Map<SemanticsNode, Rect>.unmodifiable(whole);
}

String _anchorOf(SemanticsNode node) =>
    _selfAndAncestors(node)
        .skip(1)
        .map((SemanticsNode ancestor) => ancestor.getSemanticsData().label)
        .where((String label) => _oneLine(label).isNotEmpty)
        .firstOrNull ??
    '';

List<_Visited> _judgedInWalkOrder(WidgetTester tester) {
  final Map<SemanticsNode, Rect> whole = _wholeRects(
    tester.binding.renderViews,
  );
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
          reachable: _reachableRect(node, view.flutterView.devicePixelRatio),
          whole: whole[node],
          anchor: _anchorOf(node),
        ),
  ];
}

bool _unlabelled(_Visited visited) =>
    visited.tappable &&
    !visited.data.flagsCollection.isTextField &&
    !visited.labelled &&
    _oneLine(visited.data.tooltip).isEmpty;

bool _roleless(_Visited visited) => visited.tappable && !visited.hasRole;

bool _inert(_Visited visited) =>
    visited.data.flagsCollection.isButton &&
    visited.data.flagsCollection.isEnabled != ui.Tristate.isFalse &&
    !visited.tappable;

bool _repeats(_Visited visited) {
  final List<String> segments = _segments(visited.label);
  return segments.toSet().length < segments.length;
}

TargetPlatform? _pumpedPlatform(WidgetTester tester) {
  final Widget? appTheme = find
      .descendant(
        of: find.byType(MaterialApp),
        matching: find.byWidgetPredicate(
          (Widget widget) => widget is AnimatedTheme || widget is Theme,
        ),
      )
      .evaluate()
      .firstOrNull
      ?.widget;
  return switch (appTheme) {
    AnimatedTheme(:final ThemeData data) ||
    Theme(:final ThemeData data) => data.platform,
    _ => null,
  };
}

Size a11yMinimumTarget(TargetPlatform platform) => switch (platform) {
  TargetPlatform.macOS => const Size(28, 28),
  TargetPlatform.windows => const Size(40, 40),
  _ => const Size(48, 48),
};

TargetPlatform _platformOf(WidgetTester tester) =>
    _pumpedPlatform(tester) ?? defaultTargetPlatform;

double _minimumTargetOf(WidgetTester tester) =>
    a11yMinimumTarget(_platformOf(tester)).shortestSide;

bool _small(_Visited visited, double minimumTarget) {
  if (!visited.tappable ||
      visited.data.flagsCollection.isHidden ||
      visited.data.flagsCollection.isLink) {
    return false;
  }
  final Size? size = _judgedSize(visited);
  return size != null &&
      (size.width < minimumTarget - precisionErrorTolerance ||
          size.height < minimumTarget - precisionErrorTolerance);
}

Size? _judgedSize(_Visited visited) => switch (visited.whole) {
  final Rect whole when visited.clipped =>
    _mostlyShown(visited.rect.width, whole.width) &&
            _mostlyShown(visited.rect.height, whole.height)
        ? whole.size
        : null,
  _ => visited.reachable.size,
};

bool _mostlyShown(double shown, double whole) =>
    shown >= whole - _clipTolerance || shown > whole / 2 + _clipTolerance;

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

List<_Visited> _labelledAs(List<_Visited> judged, String label) {
  final String wanted = _oneLine(label);
  return <_Visited>[
    for (final _Visited visited in judged)
      if (wanted.isNotEmpty && _oneLine(visited.label) == wanted) visited,
  ];
}

Iterable<(int, A11yStateKind)> _missingByLabel(
  List<_Visited> judged,
  String label,
  A11yStateKind kind,
) {
  final List<_Visited> candidates = _labelledAs(judged, label);
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

String? _statefulGap(List<_Visited> judged, A11yStatefulControl control) =>
    switch (control) {
      A11yStatefulControl(:final Finder finder?, :final int count)
          when finder.evaluate().length < count =>
        'stateful ${control.kind.name} control expected at least $count '
            '${finder.describeMatch(Plurality.many)}, '
            'found ${finder.evaluate().length}',
      A11yStatefulControl(:final String label?)
          when _labelledAs(judged, label).isEmpty =>
        'stateful ${control.kind.name} control matched no node labelled '
            '"${_oneLine(label)}"',
      _ => null,
    };

List<String> a11yStatefulGaps(
  WidgetTester tester,
  List<A11yStatefulControl> stateful,
) {
  if (stateful.isEmpty) {
    return const <String>[];
  }
  final List<_Visited> judged = _judgedInWalkOrder(tester);
  return <String>[
    for (final A11yStatefulControl control in stateful)
      if (_statefulGap(judged, control) case final String gap) gap,
  ];
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

List<A11yFinding> _semanticFindings(
  WidgetTester tester,
  List<_Visited> judged, {
  required String state,
  required List<A11yStatefulControl> stateful,
  Set<int> unlabelledByFlutter = const <int>{},
  Set<int> smallByFlutter = const <int>{},
}) {
  final double minimumTarget = _minimumTargetOf(tester);
  final List<int> doubled = _doubledHolders(judged);
  final Set<(int, A11yStateKind)> missingStates = _missingStates(
    tester,
    judged,
    stateful,
  );
  return <A11yFinding>[
    for (final _Visited visited in judged) ...<A11yFinding>[
      if (_unlabelled(visited) || unlabelledByFlutter.contains(visited.node.id))
        visited.finding(_unlabelledTap, state),
      if (_roleless(visited)) visited.finding(_missingRole, state),
      for (final int holder in doubled)
        if (holder == visited.index) visited.finding(_doubledTarget, state),
      if (_repeats(visited)) visited.finding(_repeatedText, state),
      for (final A11yStateKind kind in A11yStateKind.values)
        if (missingStates.contains((visited.index, kind)))
          visited.finding(_missingState, state),
      if (_small(visited, minimumTarget) ||
          smallByFlutter.contains(visited.node.id))
        visited.finding(_smallTarget, state),
      if (_inert(visited)) visited.finding(_inertButton, state),
    ],
  ];
}

List<A11yFinding> a11yFindings(
  WidgetTester tester, {
  required String state,
  List<A11yStatefulControl> stateful = const <A11yStatefulControl>[],
}) => _numbered(
  _semanticFindings(
    tester,
    _judgedInWalkOrder(tester),
    state: state,
    stateful: stateful,
  ),
);

const Map<TargetPlatform, String> _targetLinks = <TargetPlatform, String>{
  TargetPlatform.macOS: 'https://developer.apple.com/design/human-interface-guidelines/accessibility',
  TargetPlatform.windows: 'https://learn.microsoft.com/windows/apps/design/input/guidelines-for-targeting',
};

AccessibilityGuideline _targetGuideline(TargetPlatform platform) =>
    switch (_targetLinks[platform]) {
      final String link => MinimumTapTargetGuideline(
        size: a11yMinimumTarget(platform),
        link: link,
      ),
      null => androidTapTargetGuideline,
    };

final RegExp _failedNode = RegExp(r'^SemanticsNode#(\d+)', multiLine: true);

Future<Set<int>> _failedBy(
  WidgetTester tester,
  AccessibilityGuideline guideline,
) async {
  final String? failure = await meetsGuideline(guideline).matchAsync(tester);
  return <int>{
    if (failure != null)
      for (final RegExpMatch match in _failedNode.allMatches(failure))
        int.parse(match.group(1)!),
  };
}

const double _defaultFontSize = 14;
const double _largeText = 24;
const double _largeBoldText = 18.66;
const double _normalTextContrast = 4.5;
const double _largeTextContrast = 3;
const double _contrastTolerance = 0.01;
const double _groundGap = 2;
const double _clipSlack = 0.5;
const double _overlapSlack = 1;
const int _labelLength = 60;
const int _maxTabStops = 60;
const Duration _focusFade = Duration(milliseconds: 250);
const double _ringReach = 4;
const double _ringInset = 2;
const double _focusContrast = 3;
const Color _defaultInk = Color(0xFF000000);

bool _iconRune(int rune) =>
    (rune >= 0xE000 && rune <= 0xF8FF) || rune >= 0xF0000 || rune == 0xFFFC;

String _plainText(RenderParagraph paragraph) =>
    paragraph.text.toPlainText(includeSemanticsLabels: false);

String _readable(String text) => _oneLine(
  String.fromCharCodes(text.runes.where((int rune) => !_iconRune(rune))),
);

String _short(String text) {
  final String line = _readable(text);
  return line.length <= _labelLength
      ? line
      : '${line.substring(0, _labelLength - 3)}...';
}

double _contrast(Color a, Color b) {
  final double first = a.computeLuminance();
  final double second = b.computeLuminance();
  return first > second
      ? (first + 0.05) / (second + 0.05)
      : (second + 0.05) / (first + 0.05);
}

Color _over(Color ink, double alpha, Color ground) => Color.from(
  alpha: 1,
  red: ink.r * alpha + ground.r * (1 - alpha),
  green: ink.g * alpha + ground.g * (1 - alpha),
  blue: ink.b * alpha + ground.b * (1 - alpha),
);

final class _Capture {
  const _Capture({
    required this.origin,
    required this.scale,
    required this.width,
    required this.height,
    required this.bytes,
  });

  final Offset origin;
  final double scale;
  final int width;
  final int height;
  final ByteData bytes;

  int? pixelAt(Offset logical) {
    final int x = ((logical.dx - origin.dx) * scale).floor();
    final int y = ((logical.dy - origin.dy) * scale).floor();
    if (x < 0 || y < 0 || x >= width || y >= height) {
      return null;
    }
    return _pixel(x, y);
  }

  int _pixel(int x, int y) {
    final int at = (y * width + x) * 4;
    return 0xFF000000 |
        (bytes.getUint8(at) << 16) |
        (bytes.getUint8(at + 1) << 8) |
        bytes.getUint8(at + 2);
  }

  Offset _logicalOf(int x, int y) =>
      origin + Offset((x + 0.5) / scale, (y + 0.5) / scale);
}

RenderView _firstView(WidgetTester tester) => tester.binding.renderViews.first;

Rect _viewBounds(WidgetTester tester) => Offset.zero & _firstView(tester).size;

Future<_Capture> _capture(
  WidgetTester tester,
  Rect bounds, {
  required double scale,
}) async {
  final RenderView view = _firstView(tester);
  final double ratio = view.flutterView.devicePixelRatio;
  final OffsetLayer layer = view.debugLayer! as OffsetLayer;
  final (int, int, ByteData)? image = await tester.binding.runAsync(() async {
    final ui.Image image = await layer.toImage(
      Rect.fromLTRB(
        bounds.left * ratio,
        bounds.top * ratio,
        bounds.right * ratio,
        bounds.bottom * ratio,
      ),
      pixelRatio: scale / ratio,
    );
    try {
      final ByteData? bytes = await image.toByteData();
      return (image.width, image.height, bytes!);
    } finally {
      image.dispose();
    }
  });
  return switch (image) {
    (final int width, final int height, final ByteData bytes) => _Capture(
      origin: bounds.topLeft,
      scale: scale,
      width: width,
      height: height,
      bytes: bytes,
    ),
    null => throw StateError('the view could not be captured'),
  };
}

sealed class _PaintStep {
  const _PaintStep();
}

final class _Cover extends _PaintStep {
  const _Cover(this.rect);

  final Rect rect;
}

final class _Painted extends _PaintStep {
  const _Painted({
    required this.paragraph,
    required this.rect,
    required this.clip,
    required this.opacity,
    required this.layers,
  });

  final RenderParagraph paragraph;
  final Rect rect;
  final Rect clip;
  final double opacity;
  final List<RenderObject> layers;

  String get text => _plainText(paragraph);

  bool sharesLayersWith(_Painted other) =>
      layers.length == other.layers.length &&
      layers.indexed.every(
        ((int, RenderObject) entry) =>
            identical(entry.$2, other.layers[entry.$1]),
      );
}

double _opacityOf(RenderObject object) => switch (object) {
  final RenderOpacity box => box.opacity,
  final RenderAnimatedOpacity box => box.opacity.value,
  _ => 1,
};

bool _paints(RenderObject parent, RenderObject child) =>
    parent.paintsChild(child) &&
    switch (parent) {
      final RenderIndexedStack stack =>
        stack.getChildrenAsList().indexOf(child as RenderBox) == stack.index,
      _ => true,
    };

Matrix4 _childTransform(
  RenderObject parent,
  RenderObject child,
  Matrix4 transform,
) {
  final Matrix4 step = Matrix4.identity();
  parent.applyPaintTransform(child, step);
  return transform.multiplied(step);
}

_Painted? _paintedParagraph(
  RenderParagraph paragraph, {
  required Matrix4 transform,
  required Rect clip,
  required double opacity,
  required List<RenderObject> layers,
}) {
  final String text = _plainText(paragraph);
  if (!paragraph.hasSize || _readable(text).isEmpty) {
    return null;
  }
  final List<ui.TextBox> boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: text.length),
    boxHeightStyle: ui.BoxHeightStyle.max,
  );
  if (boxes.isEmpty) {
    return null;
  }
  final Rect local = boxes
      .map((ui.TextBox box) => box.toRect())
      .reduce((Rect a, Rect b) => a.expandToInclude(b));
  final Rect visible = _within(
    MatrixUtils.transformRect(transform, local),
    clip,
  );
  return visible.isEmpty
      ? null
      : _Painted(
          paragraph: paragraph,
          rect: visible,
          clip: clip,
          opacity: opacity,
          layers: layers,
        );
}

bool _opaque(Color color) => color.a >= 1;

bool _opaqueDecoration(Decoration decoration) => switch (decoration) {
  BoxDecoration(image: null, :final Color? color, :final Gradient? gradient) =>
    (color != null && _opaque(color)) ||
        (gradient != null && gradient.colors.every(_opaque)),
  _ => false,
};

bool _coversWhatIsBelow(RenderObject object) => switch (object) {
  final RenderDecoratedBox box =>
    box.position == DecorationPosition.background &&
        _opaqueDecoration(box.decoration),
  final RenderPhysicalModel model => _opaque(model.color),
  final RenderPhysicalShape shape => _opaque(shape.color),
  _ => switch (object.debugCreator) {
    DebugCreator(:final Element element) => switch (element.widget) {
      ColoredBox(:final Color color) => _opaque(color),
      _ => false,
    },
    _ => false,
  },
};

_Cover? _coverOf(
  RenderObject object, {
  required Matrix4 transform,
  required Rect clip,
  required double opacity,
}) {
  if (opacity < 1 || !_coversWhatIsBelow(object)) {
    return null;
  }
  final Rect covered = _within(
    MatrixUtils.transformRect(transform, object.paintBounds),
    clip,
  );
  return covered.isEmpty ? null : _Cover(covered);
}

Iterable<_PaintStep> _paintedFrom(
  RenderObject object, {
  required Matrix4 transform,
  required Rect clip,
  required double opacity,
  required List<RenderObject> layers,
  required Set<RenderObject> theaters,
}) sync* {
  if (_coverOf(object, transform: transform, clip: clip, opacity: opacity)
      case final _Cover cover) {
    yield cover;
  }
  if (object case final RenderParagraph paragraph) {
    if (_paintedParagraph(
          paragraph,
          transform: transform,
          clip: clip,
          opacity: opacity,
          layers: layers,
        )
        case final _Painted painted) {
      yield painted;
    }
  }
  final double childOpacity = opacity * _opacityOf(object);
  if (childOpacity <= 0) {
    return;
  }
  final List<RenderObject> children = <RenderObject>[];
  object.visitChildren(children.add);
  for (final RenderObject child in children) {
    if (!_paints(object, child)) {
      continue;
    }
    final Rect? childClip = object.describeApproximatePaintClip(child);
    final Rect clipped = childClip == null
        ? clip
        : _within(clip, MatrixUtils.transformRect(transform, childClip));
    if (clipped.isEmpty) {
      continue;
    }
    yield* _paintedFrom(
      child,
      transform: _childTransform(object, child, transform),
      clip: clipped,
      opacity: childOpacity,
      layers: theaters.contains(object)
          ? <RenderObject>[...layers, child]
          : layers,
      theaters: theaters,
    );
  }
}

List<_Painted> _paintedParagraphs(WidgetTester tester) {
  final Set<RenderObject> theaters = <RenderObject>{
    for (final Element element
        in find.byType(Overlay, skipOffstage: false).evaluate())
      if (element.renderObject case final RenderObject theater) theater,
  };
  final List<_PaintStep> steps = <_PaintStep>[
    for (final RenderView view in tester.binding.renderViews)
      if (view.child case final RenderObject child)
        ..._paintedFrom(
          child,
          transform: Matrix4.identity(),
          clip: Offset.zero & view.size,
          opacity: 1,
          layers: const <RenderObject>[],
          theaters: theaters,
        ),
  ];
  return <_Painted>[
    for (final (int at, _PaintStep step) in steps.indexed)
      if (step case final _Painted painted)
        if (!_coveredLater(painted, steps.skip(at + 1))) painted,
  ];
}

bool _coveredLater(_Painted painted, Iterable<_PaintStep> later) => later.any(
  (_PaintStep step) => switch (step) {
    _Cover(:final Rect rect) =>
      rect.inflate(_overlapSlack).contains(painted.rect.topLeft) &&
          rect.inflate(_overlapSlack).contains(painted.rect.bottomRight),
    _Painted() => false,
  },
);

SemanticsNode? _ownerNode(RenderObject object) {
  for (
    RenderObject? current = object;
    current != null;
    current = current.parent
  ) {
    if (current.debugSemantics case final SemanticsNode node) {
      return _selfAndAncestors(node)
          .firstWhere((SemanticsNode owner) => !owner.isMergedIntoParent);
    }
  }
  return null;
}

String _renderAnchor(RenderObject object, String label) {
  final String own = _oneLine(label);
  return switch (_ownerNode(object)) {
    final SemanticsNode node =>
      _selfAndAncestors(node)
          .map((SemanticsNode owner) => _oneLine(owner.label))
          .firstWhere(
            (String text) =>
                text.isNotEmpty && !text.contains(own) && !own.contains(text),
            orElse: () => '',
          ),
    null => '',
  };
}

bool _disabled(RenderObject object) => switch (_ownerNode(object)) {
  final SemanticsNode node => _selfAndAncestors(node).any(
    (SemanticsNode owner) =>
        owner.flagsCollection.isEnabled == ui.Tristate.isFalse,
  ),
  null => false,
};

bool _inLiveRegion(RenderObject object) => switch (_ownerNode(object)) {
  final SemanticsNode node => _selfAndAncestors(
    node,
  ).any((SemanticsNode owner) => owner.flagsCollection.isLiveRegion),
  null => false,
};

A11yFinding _renderFinding(
  String rule,
  String state,
  RenderObject object,
  String label,
  Rect rect,
) => A11yFinding(
  rule: rule,
  state: state,
  label: label,
  anchor: _renderAnchor(object, label),
  rect: rect,
);

Iterable<TextStyle> _leafStyles(InlineSpan span, TextStyle? inherited) sync* {
  final TextStyle? style = switch ((inherited, span.style)) {
    (null, final TextStyle? own) => own,
    (final TextStyle parent, null) => parent,
    (final TextStyle parent, final TextStyle own) => parent.merge(own),
  };
  if (span case TextSpan(
    :final String? text,
    :final List<InlineSpan>? children,
  )) {
    if (text != null && _readable(text).isNotEmpty) {
      yield style ?? const TextStyle();
    }
    for (final InlineSpan child in children ?? const <InlineSpan>[]) {
      yield* _leafStyles(child, style);
    }
  }
}

double _requiredContrast(TextStyle style, TextScaler scaler) {
  final double size = scaler.scale(style.fontSize ?? _defaultFontSize);
  final bool bold =
      (style.fontWeight ?? FontWeight.normal).value >= FontWeight.w700.value;
  return size >= _largeText || (bold && size >= _largeBoldText)
      ? _largeTextContrast
      : _normalTextContrast;
}

Color? _groundAround(_Capture capture, Rect rect, Rect clip) {
  final Rect ring = rect.inflate(_groundGap);
  final List<int> colours = <int>[
    for (double x = ring.left; x <= ring.right; x += 1)
      for (final double y in <double>[ring.top, ring.bottom])
        if (clip.contains(Offset(x, y)))
          if (capture.pixelAt(Offset(x, y)) case final int colour) colour,
    for (double y = ring.top; y <= ring.bottom; y += 1)
      for (final double x in <double>[ring.left, ring.right])
        if (clip.contains(Offset(x, y)))
          if (capture.pixelAt(Offset(x, y)) case final int colour) colour,
  ];
  if (colours.isEmpty) {
    return null;
  }
  final Map<int, int> counts = <int, int>{};
  for (final int colour in colours) {
    counts.update(colour, (int count) => count + 1, ifAbsent: () => 1);
  }
  return Color(
    counts.entries
        .reduce(
          (MapEntry<int, int> a, MapEntry<int, int> b) =>
              b.value > a.value ? b : a,
        )
        .key,
  );
}

Color _inkOf(TextStyle style) =>
    style.color ?? style.foreground?.color ?? _defaultInk;

Color _shownInk(TextStyle style, _Painted painted, Color ground) {
  final Color ink = _inkOf(style);
  return _over(ink, ink.a * painted.opacity, ground);
}

bool _lowContrast(_Painted painted, Color ground) =>
    _leafStyles(painted.paragraph.text, null).any(
      (TextStyle style) =>
          _contrast(_shownInk(style, painted, ground), ground) <
          _requiredContrast(style, painted.paragraph.textScaler) -
              _contrastTolerance,
    );

typedef _Seen = ({_Painted text, Color ground});

List<_Seen> _seenParagraphs(
  List<_Painted> painted,
  _Capture capture,
) => <_Seen>[
  for (final _Painted text in painted)
    if (_groundAround(capture, text.rect, text.clip) case final Color ground)
      (text: text, ground: ground),
];

List<A11yFinding> _contrastFindings(List<_Seen> seen, String state) =>
    <A11yFinding>[
      for (final _Seen shown in seen)
        if (!_disabled(shown.text.paragraph))
          if (_lowContrast(shown.text, shown.ground))
            _renderFinding(
              _textContrast,
              state,
              shown.text.paragraph,
              _short(shown.text.text),
              shown.text.rect,
            ),
    ];

bool _truncated(RenderParagraph paragraph) =>
    paragraph.didExceedMaxLines ||
    (!paragraph.softWrap &&
        paragraph.getMaxIntrinsicWidth(double.infinity) >
            paragraph.size.width + _clipSlack);

List<A11yFinding> _truncationFindings(List<_Painted> painted, String state) =>
    <A11yFinding>[
      for (final _Painted text in painted)
        if (_truncated(text.paragraph))
          _renderFinding(
            _truncatedText,
            state,
            text.paragraph,
            _short(text.text),
            text.rect,
          ),
    ];

bool _isAncestorOf(RenderObject ancestor, RenderObject object) {
  for (
    RenderObject? current = object.parent;
    current != null;
    current = current.parent
  ) {
    if (identical(current, ancestor)) {
      return true;
    }
  }
  return false;
}

Rect? _overlapOf(_Painted a, _Painted b) {
  if (!a.sharesLayersWith(b) ||
      _isAncestorOf(a.paragraph, b.paragraph) ||
      _isAncestorOf(b.paragraph, a.paragraph) ||
      !a.rect.overlaps(b.rect)) {
    return null;
  }
  final Rect shared = a.rect.intersect(b.rect);
  return shared.width > _overlapSlack && shared.height > _overlapSlack
      ? shared
      : null;
}

List<A11yFinding> _overlapFindings(List<_Painted> painted, String state) =>
    <A11yFinding>[
      for (int i = 0; i < painted.length; i++)
        for (int j = i + 1; j < painted.length; j++)
          if (_overlapOf(painted[i], painted[j]) case final Rect shared)
            _renderFinding(
              _overlappingText,
              state,
              painted[i].paragraph,
              '${_short(painted[i].text)} + ${_short(painted[j].text)}',
              shared,
            ),
    ];

List<A11yFinding> _liveRegionFindings(
  A11yWatch watch,
  List<_Painted> painted,
  String state,
) => <A11yFinding>[
  for (final _Painted text in painted)
    if (watch.changedText(text.paragraph) case final String latest)
      if (!_inLiveRegion(text.paragraph))
        _renderFinding(
          _liveRegion,
          state,
          text.paragraph,
          _short(latest),
          text.rect,
        ),
];

String _firstText(RenderObject object) => _renderDepthFirst(object)
    .whereType<RenderParagraph>()
    .map(_plainText)
    .firstWhere((String text) => _readable(text).isNotEmpty, orElse: () => '');

List<A11yFinding> _overflowFindings(A11yWatch watch, String state) =>
    <A11yFinding>[
      for (final RenderObject object in watch.overflows)
        if (object case final RenderBox box when box.attached && box.hasSize)
          _renderFinding(
            _overflow,
            state,
            box,
            _short(_firstText(box)),
            MatrixUtils.transformRect(
              box.getTransformTo(null),
              Offset.zero & box.size,
            ),
          ),
    ];

final class _Stop {
  const _Stop({required this.focus, required this.reached, this.finding});

  final FocusNode focus;
  final Set<int> reached;
  final A11yFinding? finding;
}

Future<void> _pumpFocus(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(_focusFade);
}

List<SemanticsNode> _allNodes(WidgetTester tester) => <SemanticsNode>[
  for (final RenderView view in tester.binding.renderViews)
    ..._depthFirst(_rootOf(view)),
];

List<SemanticsNode> _focusedNodes(List<SemanticsNode> nodes) => <SemanticsNode>[
  for (final SemanticsNode node in nodes)
    if (node.flagsCollection.isFocused == ui.Tristate.isTrue)
      _selfAndAncestors(node)
          .firstWhere((SemanticsNode owner) => !owner.isMergedIntoParent),
];

bool _tappable(SemanticsData data) =>
    data.hasAction(ui.SemanticsAction.tap) ||
    data.hasAction(ui.SemanticsAction.longPress);

bool _tappableNode(SemanticsNode node) => _tappable(node.getSemanticsData());

Set<int> _reachedBy(
  WidgetTester tester,
  List<SemanticsNode> nodes,
  List<SemanticsNode> focused,
  Rect rect,
) {
  final double ratio = _firstView(tester).flutterView.devicePixelRatio;
  return focused.isEmpty
      ? <int>{
          for (final SemanticsNode node in nodes)
            if (_tappableNode(node) &&
                _logicalRect(node, ratio).contains(rect.center))
              node.id,
        }
      : <int>{
          for (final SemanticsNode node in focused) ...<int>[
            for (final SemanticsNode near in _selfAndAncestors(node)) near.id,
            for (final SemanticsNode near in _depthFirst(node)) near.id,
          ],
        };
}

double _largestChange(_Capture focused, _Capture plain, Rect control) {
  final Rect outer = control.inflate(_ringReach);
  final Rect inner =
      control.width > _ringInset * 2 && control.height > _ringInset * 2
      ? control.deflate(_ringInset)
      : Rect.zero;
  return <double>[
    1,
    for (int y = 0; y < focused.height && y < plain.height; y++)
      for (int x = 0; x < focused.width && x < plain.width; x++)
        if (focused._pixel(x, y) != plain._pixel(x, y))
          if (focused._logicalOf(x, y) case final Offset at
              when outer.contains(at) && !inner.contains(at))
            _contrast(Color(focused._pixel(x, y)), Color(plain._pixel(x, y))),
  ].reduce((double a, double b) => a > b ? a : b);
}

Future<double> _focusChange(
  WidgetTester tester,
  FocusNode focus,
  Rect control,
) async {
  final Rect region = _within(
    control.inflate(_ringReach + 1),
    _viewBounds(tester),
  );
  if (region.isEmpty) {
    return 1;
  }
  final double scale = _firstView(tester).flutterView.devicePixelRatio;
  final _Capture focused = await _capture(tester, region, scale: scale);
  focus.unfocus();
  await _pumpFocus(tester);
  final _Capture plain = await _capture(tester, region, scale: scale);
  focus.requestFocus();
  await _pumpFocus(tester);
  return _largestChange(focused, plain, control);
}

Future<_Stop> _stopAt(
  WidgetTester tester,
  String state,
  FocusNode focus,
) async {
  final Rect control = focus.rect;
  final List<SemanticsNode> nodes = _allNodes(tester);
  final List<SemanticsNode> focused = _focusedNodes(nodes);
  final Set<int> reached = _reachedBy(tester, nodes, focused, control);
  final double change = await _focusChange(tester, focus, control);
  final SemanticsNode? named = focused.firstOrNull;
  return _Stop(
    focus: focus,
    reached: reached,
    finding: change < _focusContrast - _contrastTolerance
        ? A11yFinding(
            rule: _focusVisible,
            state: state,
            label: named?.getSemanticsData().label ?? focus.debugLabel ?? '',
            anchor: named == null ? '' : _anchorOf(named),
            rect: control,
          )
        : null,
  );
}

Future<List<_Stop>> _tabThrough(
  WidgetTester tester,
  String state,
  List<_Stop> stops,
) async {
  if (stops.length >= _maxTabStops) {
    return stops;
  }
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
  await _pumpFocus(tester);
  final FocusNode? focus = FocusManager.instance.primaryFocus;
  if (focus == null ||
      focus is FocusScopeNode ||
      focus.context == null ||
      stops.any((_Stop stop) => identical(stop.focus, focus))) {
    return stops;
  }
  return _tabThrough(tester, state, <_Stop>[
    ...stops,
    await _stopAt(tester, state, focus),
  ]);
}

List<A11yFinding> _keyboardFindings(
  List<_Visited> judged,
  List<_Stop> stops,
  String state,
) {
  final Set<int> reached = <int>{
    for (final _Stop stop in stops) ...stop.reached,
  };
  return <A11yFinding>[
    for (final _Visited visited in judged)
      if (visited.tappable &&
          visited.data.flagsCollection.isEnabled != ui.Tristate.isFalse &&
          !reached.contains(visited.node.id))
        visited.finding(_keyboard, state),
  ];
}

Future<List<A11yFinding>> a11yFullFindings(
  WidgetTester tester, {
  required String state,
  required A11yVariant variant,
  required A11yWatch watch,
  List<A11yStatefulControl> stateful = const <A11yStatefulControl>[],
}) async {
  final List<_Visited> judged = _judgedInWalkOrder(tester);
  final TargetPlatform platform = _platformOf(tester);
  final Set<int> unlabelled = await _failedBy(
    tester,
    labeledTapTargetGuideline,
  );
  final Set<int> small = await _failedBy(tester, _targetGuideline(platform));
  final Set<int> lowContrast = await _failedBy(tester, textContrastGuideline);
  final List<_Painted> painted = _paintedParagraphs(tester);
  final _Capture screen = await _capture(tester, _viewBounds(tester), scale: 1);
  final List<_Seen> seen = _seenParagraphs(painted, screen);
  final List<A11yFinding> found = <A11yFinding>[
    ..._semanticFindings(
      tester,
      judged,
      state: state,
      stateful: stateful,
      unlabelledByFlutter: unlabelled,
      smallByFlutter: small,
    ),
    for (final _Visited visited in judged)
      if (lowContrast.contains(visited.node.id))
        visited.finding(_flutterTextContrast, state),
    ..._contrastFindings(seen, state),
    if (variant.largeText) ...<A11yFinding>[
      ..._truncationFindings(painted, state),
      ..._overlapFindings(painted, state),
    ],
    ..._liveRegionFindings(watch, painted, state),
  ];
  final List<_Stop> stops = variant.largeText
      ? const <_Stop>[]
      : await _tabThrough(tester, state, const <_Stop>[]);
  return _numbered(<A11yFinding>[
    ...found,
    for (final _Stop stop in stops)
      if (stop.finding case final A11yFinding finding) finding,
    if (variant.desktop && !variant.largeText)
      ..._keyboardFindings(judged, stops, state),
    ..._overflowFindings(watch, state),
  ]);
}

RenderObject? _overflowingIn(FlutterErrorDetails details) {
  if (!details.exceptionAsString().contains('overflowed by')) {
    return null;
  }
  return (details.informationCollector?.call() ?? const <DiagnosticsNode>[])
      .map((DiagnosticsNode node) => node.value)
      .whereType<RenderObject>()
      .firstOrNull;
}

final class A11yWatch {
  A11yWatch._(this._binding, this._report);

  factory A11yWatch.start(WidgetTester tester) {
    final A11yWatch watch = A11yWatch._(tester.binding, FlutterError.onError);
    FlutterError.onError = watch._onError;
    tester.binding.addPostFrameCallback(watch._onFrame);
    return watch;
  }

  final WidgetsBinding _binding;
  final FlutterExceptionHandler? _report;
  final Map<RenderParagraph, List<String>> _texts =
      <RenderParagraph, List<String>>{};
  final List<RenderObject> _overflows = <RenderObject>[];
  bool _watching = true;
  bool _closed = false;

  List<RenderObject> get overflows =>
      List<RenderObject>.unmodifiable(_overflows);

  String? changedText(RenderParagraph paragraph) => switch (_texts[paragraph]) {
    final List<String> texts when texts.length > 1 => texts.last,
    _ => null,
  };

  void _onError(FlutterErrorDetails details) {
    final RenderObject? overflowing = _overflowingIn(details);
    if (overflowing == null) {
      _report?.call(details);
    } else if (!_overflows.contains(overflowing)) {
      _overflows.add(overflowing);
    }
  }

  void _onFrame(Duration stamp) {
    if (!_watching) {
      return;
    }
    _record();
    _binding.addPostFrameCallback(_onFrame);
  }

  void _record() {
    for (final RenderView view in _binding.renderViews) {
      for (final RenderParagraph paragraph in _renderDepthFirst(
        view,
      ).whereType<RenderParagraph>()) {
        final String text = _readable(_plainText(paragraph));
        final List<String> seen = _texts[paragraph] ?? const <String>[];
        if (text.isNotEmpty && (seen.isEmpty || seen.last != text)) {
          _texts[paragraph] = <String>[...seen, text];
        }
      }
    }
  }

  void watchTextFromHere() {
    _texts.clear();
    _record();
  }

  void stop() {
    if (_watching) {
      _record();
      _watching = false;
    }
  }

  void close() {
    stop();
    if (!_closed) {
      _closed = true;
      FlutterError.onError = _report;
    }
  }
}
