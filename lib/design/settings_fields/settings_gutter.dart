import 'dart:math' as math;

import 'package:field_notes/design/interaction/hover_style.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

const double settingsGutter = HoverStyle.fillInset;

class SettingsGutter extends InheritedWidget {
  const SettingsGutter({
    super.key,
    required this.padding,
    this.minHeight = 0,
    required super.child,
  }) : _slotted = false;

  const SettingsGutter._slotted({
    required this.padding,
    required this.minHeight,
    required super.child,
  }) : _slotted = true;

  const SettingsGutter.none({super.key, required super.child})
    : padding = EdgeInsets.zero,
      minHeight = 0,
      _slotted = false;

  final EdgeInsets padding;
  final double minHeight;
  final bool _slotted;

  bool get framesRows => padding != EdgeInsets.zero || minHeight > 0;

  @override
  bool updateShouldNotify(SettingsGutter oldWidget) =>
      oldWidget.padding != padding ||
      oldWidget.minHeight != minHeight ||
      oldWidget._slotted != _slotted;
}

class SettingsGutterRow extends StatelessWidget {
  const SettingsGutterRow({
    super.key,
    required this.padding,
    required this.minHeight,
    required this.child,
  });

  final EdgeInsets padding;
  final double minHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) => SettingsGutter._slotted(
    padding: padding,
    minHeight: minHeight,
    child: _GutterSlot(padding: padding, minHeight: minHeight, child: child),
  );
}

class SettingsRowFrame extends StatelessWidget {
  const SettingsRowFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final SettingsGutter? gutter = context
        .dependOnInheritedWidgetOfExactType<SettingsGutter>();
    if (gutter == null || !gutter.framesRows) {
      return child;
    }
    final Widget framed = ConstrainedBox(
      constraints: BoxConstraints(minHeight: gutter.minHeight),
      child: Padding(
        padding: gutter.padding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[SettingsGutter.none(child: child)],
        ),
      ),
    );
    return gutter._slotted ? _GutterClaim(child: framed) : framed;
  }
}

class _GutterSlot extends SingleChildRenderObjectWidget {
  const _GutterSlot({
    required this.padding,
    required this.minHeight,
    required super.child,
  });

  final EdgeInsets padding;
  final double minHeight;

  @override
  _RenderGutterSlot createRenderObject(BuildContext context) =>
      _RenderGutterSlot(padding: padding, minHeight: minHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderGutterSlot renderObject,
  ) {
    renderObject
      ..padding = padding
      ..minHeight = minHeight;
  }
}

class _RenderGutterSlot extends RenderShiftedBox {
  _RenderGutterSlot({required this._padding, required this._minHeight})
    : super(null);

  EdgeInsets _padding;
  double _minHeight;
  final Set<_RenderGutterClaim> _claims = <_RenderGutterClaim>{};
  bool _layingOut = false;

  set padding(EdgeInsets value) {
    if (value == _padding) {
      return;
    }
    _padding = value;
    markNeedsLayout();
  }

  set minHeight(double value) {
    if (value == _minHeight) {
      return;
    }
    _minHeight = value;
    markNeedsLayout();
  }

  bool get _framesChild => _claims.isEmpty;

  void _claim(_RenderGutterClaim claim) {
    if (_claims.add(claim) && _claims.length == 1) {
      _relayoutUnlessLayingOut();
    }
  }

  void _release(_RenderGutterClaim claim) {
    if (_claims.remove(claim) && _claims.isEmpty) {
      _relayoutUnlessLayingOut();
    }
  }

  void _relayoutUnlessLayingOut() {
    if (attached && !_layingOut) {
      markNeedsLayout();
    }
  }

  @override
  void performLayout() {
    _layingOut = true;
    try {
      final bool framed = _framesChild;
      size = _layout(constraints, framed: framed, dry: false);
      if (_framesChild != framed) {
        size = _layout(constraints, framed: _framesChild, dry: false);
      }
    } finally {
      _layingOut = false;
    }
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) =>
      _layout(constraints, framed: _framesChild, dry: true);

  Size _layout(
    BoxConstraints constraints, {
    required bool framed,
    required bool dry,
  }) {
    final RenderBox? child = this.child;
    final EdgeInsets padding = framed ? _padding : EdgeInsets.zero;
    final double floor = framed ? _minHeight : 0;
    if (child == null) {
      return constraints.constrain(
        Size(padding.horizontal, math.max(floor, padding.vertical)),
      );
    }
    final BoxConstraints inner = !framed
        ? constraints
        : constraints.hasBoundedWidth
        ? BoxConstraints.tightFor(
            width: math.max(0, constraints.maxWidth - padding.horizontal),
          )
        : const BoxConstraints();
    final Size childSize = dry
        ? child.getDryLayout(inner)
        : (child..layout(inner, parentUsesSize: true)).size;
    final Size size = constraints.constrain(
      Size(
        childSize.width + padding.horizontal,
        math.max(floor, childSize.height + padding.vertical),
      ),
    );
    if (!dry) {
      final double free = size.height - padding.vertical - childSize.height;
      (child.parentData! as BoxParentData).offset = Offset(
        padding.left,
        padding.top + math.max(0, free) / 2,
      );
    }
    return size;
  }

  @override
  double computeMinIntrinsicWidth(double height) =>
      _intrinsicWidth(height, (RenderBox child, double extent) {
        return child.getMinIntrinsicWidth(extent);
      });

  @override
  double computeMaxIntrinsicWidth(double height) =>
      _intrinsicWidth(height, (RenderBox child, double extent) {
        return child.getMaxIntrinsicWidth(extent);
      });

  @override
  double computeMinIntrinsicHeight(double width) =>
      _intrinsicHeight(width, (RenderBox child, double extent) {
        return child.getMinIntrinsicHeight(extent);
      });

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _intrinsicHeight(width, (RenderBox child, double extent) {
        return child.getMaxIntrinsicHeight(extent);
      });

  double _intrinsicWidth(
    double height,
    double Function(RenderBox child, double extent) measure,
  ) {
    final EdgeInsets padding = _framesChild ? _padding : EdgeInsets.zero;
    final RenderBox? child = this.child;
    final double inner = child == null
        ? 0
        : measure(child, math.max(0, height - padding.vertical));
    return inner + padding.horizontal;
  }

  double _intrinsicHeight(
    double width,
    double Function(RenderBox child, double extent) measure,
  ) {
    final EdgeInsets padding = _framesChild ? _padding : EdgeInsets.zero;
    final double floor = _framesChild ? _minHeight : 0;
    final RenderBox? child = this.child;
    final double inner = child == null
        ? 0
        : measure(child, math.max(0, width - padding.horizontal));
    return math.max(floor, inner + padding.vertical);
  }
}

class _GutterClaim extends SingleChildRenderObjectWidget {
  const _GutterClaim({required super.child});

  @override
  _RenderGutterClaim createRenderObject(BuildContext context) =>
      _RenderGutterClaim();
}

class _RenderGutterClaim extends RenderProxyBox {
  _RenderGutterSlot? _slot;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    final _RenderGutterSlot? slot = _nearestSlot();
    _slot = slot;
    slot?._claim(this);
  }

  @override
  void detach() {
    _slot?._release(this);
    _slot = null;
    super.detach();
  }

  _RenderGutterSlot? _nearestSlot() {
    RenderObject? node = parent;
    while (node != null) {
      if (node is _RenderGutterSlot) {
        return node;
      }
      node = node.parent;
    }
    return null;
  }
}
