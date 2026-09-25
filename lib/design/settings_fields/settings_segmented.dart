import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

const double _minTapTarget = 48;

class SettingsSegment<T> {
  const SettingsSegment({
    required this.value,
    required this.label,
  });

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
    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: _SegmentBand(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Palette.panelTop,
              border: Shapes.outline,
              borderRadius: Shapes.buttonBorderRadius,
            ),
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final SettingsSegment<T> segment in segments)
                    _segmentTile(segment),
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

  Widget _segmentTile(SettingsSegment<T> segment) {
    final bool selected = segment.value == value;
    return _SegmentReach(
      child: Semantics(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        enabled: enabled,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => _choose(segment.value) : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? Palette.cardBright : const Color(0x00000000),
              border: selected ? Shapes.outline : null,
              borderRadius: Shapes.buttonBorderRadius,
              boxShadow: selected ? Shadows.button : const <BoxShadow>[],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              child: Text(segment.label, style: TypographyTokens.labelSans),
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentBand extends SingleChildRenderObjectWidget {
  const _SegmentBand({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSegmentBand();
}

class _RenderSegmentBand extends RenderShiftedBox {
  _RenderSegmentBand() : super(null);

  static BoxConstraints _childConstraints(BoxConstraints constraints) =>
      constraints.copyWith(minHeight: 0);

  static Size _bandAround(Size child) =>
      Size(child.width, math.max(child.height, _minTapTarget));

  @override
  double computeMinIntrinsicHeight(double width) => math.max(
    super.computeMinIntrinsicHeight(width),
    _minTapTarget,
  );

  @override
  double computeMaxIntrinsicHeight(double width) => math.max(
    super.computeMaxIntrinsicHeight(width),
    _minTapTarget,
  );

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
    config.isSemanticBoundary = true;
  }
}
