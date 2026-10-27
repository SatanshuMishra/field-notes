import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

class ComposerHeaderLayout extends MultiChildRenderObjectWidget {
  ComposerHeaderLayout({
    super.key,
    required Widget leading,
    required Widget title,
    required Widget trailing,
  }) : super(children: <Widget>[leading, title, trailing]);

  @override
  RenderComposerHeaderLayout createRenderObject(BuildContext context) =>
      RenderComposerHeaderLayout(Directionality.of(context));

  @override
  void updateRenderObject(
    BuildContext context,
    RenderComposerHeaderLayout renderObject,
  ) {
    renderObject.textDirection = Directionality.of(context);
  }
}

final class _HeaderParentData extends ContainerBoxParentData<RenderBox> {}

class RenderComposerHeaderLayout extends RenderBox
    with
        ContainerRenderObjectMixin<RenderBox, _HeaderParentData>,
        RenderBoxContainerDefaultsMixin<RenderBox, _HeaderParentData> {
  RenderComposerHeaderLayout(this._textDirection);

  TextDirection _textDirection;

  TextDirection get textDirection => _textDirection;

  set textDirection(TextDirection value) {
    if (_textDirection != value) {
      _textDirection = value;
      markNeedsLayout();
    }
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _HeaderParentData) {
      child.parentData = _HeaderParentData();
    }
  }

  ({RenderBox leading, RenderBox title, RenderBox trailing}) get _parts {
    final RenderBox leading = firstChild!;
    final RenderBox title = childAfter(leading)!;
    return (leading: leading, title: title, trailing: childAfter(title)!);
  }

  Size _layoutAll(
    BoxConstraints constraints,
    ChildLayouter layoutChild, {
    void Function(RenderBox child, Offset offset)? place,
  }) {
    final (:RenderBox leading, :RenderBox title, :RenderBox trailing) = _parts;
    final double width = constraints.maxWidth;
    final BoxConstraints loose = BoxConstraints(maxWidth: width);
    final Size leadingSize = layoutChild(leading, loose);
    final Size trailingSize = layoutChild(
      trailing,
      BoxConstraints(maxWidth: math.max(0, width - leadingSize.width)),
    );
    final double middle = math.max(
      0,
      width - leadingSize.width - trailingSize.width,
    );
    final bool stacked = title.getMinIntrinsicWidth(double.infinity) > middle;
    final double titleWidth = stacked ? width : middle;
    final Size titleSize = layoutChild(
      title,
      BoxConstraints.tightFor(width: titleWidth),
    );
    final bool rtl = textDirection == TextDirection.rtl;
    double startOf(double x, double childWidth) =>
        rtl ? width - x - childWidth : x;
    final double actionsHeight = math.max(
      leadingSize.height,
      trailingSize.height,
    );
    final double rowHeight = stacked
        ? actionsHeight
        : math.max(actionsHeight, titleSize.height);
    if (place != null) {
      place(
        leading,
        Offset(
          startOf(0, leadingSize.width),
          (rowHeight - leadingSize.height) / 2,
        ),
      );
      place(
        trailing,
        Offset(
          startOf(width - trailingSize.width, trailingSize.width),
          (rowHeight - trailingSize.height) / 2,
        ),
      );
      place(
        title,
        stacked
            ? Offset(startOf(0, titleSize.width), rowHeight)
            : Offset(
                startOf(leadingSize.width, titleSize.width),
                (rowHeight - titleSize.height) / 2,
              ),
      );
    }
    return constraints.constrain(
      Size(width, stacked ? rowHeight + titleSize.height : rowHeight),
    );
  }

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) =>
      _layoutAll(constraints, ChildLayoutHelper.dryLayoutChild);

  @override
  void performLayout() {
    size = _layoutAll(
      constraints,
      ChildLayoutHelper.layoutChild,
      place: (RenderBox child, Offset offset) =>
          (child.parentData! as _HeaderParentData).offset = offset,
    );
  }

  @override
  void paint(PaintingContext context, Offset offset) =>
      defaultPaint(context, offset);

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      defaultHitTestChildren(result, position: position);
}
