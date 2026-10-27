import 'dart:math' as math;

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../tokens/tokens.dart';

import 'package:field_notes/design/interaction/min_target.dart';

const BorderRadius _sidebarFrameRadius = BorderRadius.all(Radius.circular(9));
const BorderRadius _sidebarSegmentRadius = BorderRadius.all(Radius.circular(7));
const double _sidebarFrameInset = Shapes.outlineWidth + 1.5;
const EdgeInsets _sidebarSegmentPadding = EdgeInsets.symmetric(
  horizontal: 10,
  vertical: 3,
);
const double _sidebarSegmentFontSize = 12;

class SettingsSegment<T> {
  const SettingsSegment({required this.value, required this.label});

  final T value;
  final String label;
}

class SettingsSegmented<T> extends StatelessWidget {
  const SettingsSegmented({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final List<SettingsSegment<T>> segments;
  final T value;
  final ValueChanged<T>? onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final bool sidebar =
        resolveShellLayout(Theme.of(context).platform) == ShellLayout.sidebar;
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: _SegmentBand(
        minHeight: minTargetOn(Theme.of(context).platform),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.colors.panelTop,
              border: context.shadows.outline,
              borderRadius: sidebar
                  ? _sidebarFrameRadius
                  : Shapes.buttonBorderRadius,
            ),
            child: Padding(
              padding: EdgeInsets.all(sidebar ? _sidebarFrameInset : 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final SettingsSegment<T> segment in segments)
                    sidebar
                        ? _sidebarTile(context, segment)
                        : _segmentTile(context, segment),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _choose(T choice) {
    if (choice != value) {
      onChanged?.call(choice);
    }
  }

  Widget _reachable({
    required String label,
    required bool selected,
    required VoidCallback? choose,
    required BorderRadius borderRadius,
    required Widget face,
  }) {
    return _SegmentReach(
      child: Pressable(
        inMutuallyExclusiveGroup: true,
        label: label,
        selected: selected,
        onPressed: choose,
        borderRadius: borderRadius,
        child: face,
      ),
    );
  }

  Widget _segmentTile(BuildContext context, SettingsSegment<T> segment) {
    final FieldNotesShadows shadows = context.shadows;
    final bool selected = segment.value == value;
    return _reachable(
      label: segment.label,
      selected: selected,
      choose: enabled ? () => _choose(segment.value) : null,
      borderRadius: Shapes.buttonBorderRadius,
      face: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? Palette.coral : const Color(0x00000000),
          border: selected ? shadows.outline : null,
          borderRadius: Shapes.buttonBorderRadius,
          boxShadow: selected ? shadows.button : const <BoxShadow>[],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Text(
            segment.label,
            style: context.textStyles.labelSans.copyWith(
              color: selected ? Palette.onAccent : context.colors.inkSoft,
            ),
          ),
        ),
      ),
    );
  }

  Widget _sidebarTile(BuildContext context, SettingsSegment<T> segment) {
    final bool selected = segment.value == value;
    return _reachable(
      label: segment.label,
      selected: selected,
      choose: enabled ? () => _choose(segment.value) : null,
      borderRadius: _sidebarSegmentRadius,
      face: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? Palette.coral : const Color(0x00000000),
          borderRadius: _sidebarSegmentRadius,
        ),
        child: Padding(
          padding: _sidebarSegmentPadding,
          child: Text(
            segment.label,
            style: context.textStyles.labelSans.copyWith(
              fontSize: _sidebarSegmentFontSize,
              fontWeight: FontWeight.w600,
              color: selected ? Palette.onAccent : context.colors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentBand extends SingleChildRenderObjectWidget {
  const _SegmentBand({required this.minHeight, required Widget super.child});

  final double minHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSegmentBand(minHeight);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderSegmentBand renderObject,
  ) {
    renderObject.minHeight = minHeight;
  }
}

class _RenderSegmentBand extends RenderShiftedBox {
  _RenderSegmentBand(this._minHeight) : super(null);

  double _minHeight;

  double get minHeight => _minHeight;

  set minHeight(double value) {
    if (value == _minHeight) {
      return;
    }
    _minHeight = value;
    markNeedsLayout();
  }

  static BoxConstraints _childConstraints(BoxConstraints constraints) =>
      constraints.copyWith(minHeight: 0);

  Size _bandAround(Size child) =>
      Size(child.width, math.max(child.height, _minHeight));

  @override
  double computeMinIntrinsicHeight(double width) =>
      math.max(super.computeMinIntrinsicHeight(width), _minHeight);

  @override
  double computeMaxIntrinsicHeight(double width) =>
      math.max(super.computeMaxIntrinsicHeight(width), _minHeight);

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final RenderBox? child = this.child;
    if (child == null) {
      return constraints.smallest;
    }
    return constraints.constrain(
      _bandAround(child.getDryLayout(_childConstraints(constraints))),
    );
  }

  @override
  void performLayout() {
    final RenderBox? child = this.child;
    if (child == null) {
      size = constraints.smallest;
      return;
    }
    child.layout(_childConstraints(constraints), parentUsesSize: true);
    size = constraints.constrain(_bandAround(child.size));
    (child.parentData! as BoxParentData).offset = Alignment.centerRight
        .alongOffset(
          Offset(
            size.width - child.size.width,
            size.height - child.size.height,
          ),
        );
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final RenderBox? child = this.child;
    if (child == null) {
      return false;
    }
    final Offset offset = (child.parentData! as BoxParentData).offset;
    return result.addWithPaintOffset(
      offset: offset,
      position: Offset(position.dx, offset.dy + child.size.height / 2),
      hitTest: (BoxHitTestResult result, Offset transformed) =>
          child.hitTest(result, position: transformed),
    );
  }
}

class _SegmentReach extends SingleChildRenderObjectWidget {
  const _SegmentReach({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSegmentReach();
}

class _RenderSegmentReach extends RenderProxyBox {
  _RenderSegmentBand? get _band {
    for (RenderObject? node = parent; node != null; node = node.parent) {
      if (node is _RenderSegmentBand) {
        return node;
      }
    }
    return null;
  }

  @override
  Rect get semanticBounds {
    final Rect own = Offset.zero & size;
    final _RenderSegmentBand? band = _band;
    if (band == null || !band.hasSize) {
      return own;
    }
    final Matrix4? fromBand = Matrix4.tryInvert(getTransformTo(band));
    if (fromBand == null) {
      return own;
    }
    final Rect bandHere = MatrixUtils.transformRect(
      fromBand,
      Offset.zero & band.size,
    );
    return Rect.fromLTRB(
      own.left,
      math.min(own.top, bandHere.top),
      own.right,
      math.max(own.bottom, bandHere.bottom),
    );
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config
      ..isSemanticBoundary = true
      ..isMergingSemanticsOfDescendants = true;
  }
}
