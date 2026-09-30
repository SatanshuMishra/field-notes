import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/widgets/meadow_landmarks.dart';
import 'package:field_notes/features/garden/widgets/meadow_ribbon.dart';

const double _minTapTarget = 48;
const Color _clear = Color(0x00000000);
const BorderRadius _panelRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusMd),
);
const BorderRadius _switchRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusSm),
);

enum _MeadowTab { days, landmarks }

class MeadowTabs extends StatefulWidget {
  const MeadowTabs({
    super.key,
    required this.year,
    required this.isCurrentYear,
    required this.compact,
    required this.growthPoint,
    required this.highlight,
    required this.onHighlight,
  });

  final MeadowYear year;
  final bool isCurrentYear;
  final bool compact;
  final int growthPoint;
  final MeadowRange? highlight;
  final ValueChanged<MeadowRange?> onHighlight;

  @override
  State<MeadowTabs> createState() => _MeadowTabsState();
}

class _MeadowTabsState extends State<MeadowTabs> {
  _MeadowTab _tab = _MeadowTab.days;

  void _choose(_MeadowTab tab) {
    if (tab == _tab) {
      return;
    }
    setState(() => _tab = tab);
    widget.onHighlight(null);
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final bool compact = widget.compact;
    final bool days = _tab == _MeadowTab.days;
    final String note = switch ((days, compact)) {
      (true, false) => 'Hover a month to find its flowers',
      (true, true) => 'Tap a month to find its flowers',
      (false, false) => 'Hover one to find those days in the meadow',
      (false, true) => 'Tap one to find those days',
    };
    const double edge = Shapes.outlineWidth;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.cardWarm,
        border: context.shadows.outline,
        borderRadius: _panelRadius,
        boxShadow: context.shadows.cardDefault,
      ),
      child: Padding(
        padding: compact
            ? const EdgeInsets.fromLTRB(10 + edge, edge, 10 + edge, 11 + edge)
            : const EdgeInsets.fromLTRB(14 + edge, edge, 14 + edge, 14 + edge),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _TabHeader(
              before: compact ? 8 : 10,
              after: compact ? 9 : 12,
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  _TabSwitch(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.ink.withAlpha(0x0F),
                        borderRadius: _switchRadius,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(3),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            _TabButton(
                              label: compact
                                  ? 'Day by day'
                                  : 'The year, day by day',
                              selected: days,
                              compact: compact,
                              onPressed: () => _choose(_MeadowTab.days),
                            ),
                            const SizedBox(width: 4),
                            _TabButton(
                              label: widget.isCurrentYear
                                  ? 'This year so far'
                                  : 'Landmarks',
                              selected: !days,
                              compact: compact,
                              onPressed: () => _choose(_MeadowTab.landmarks),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Text(
                    note,
                    style: compact
                        ? context.textStyles.caption9Sans
                        : context.textStyles.captionSans.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
            if (days)
              MeadowRibbon(
                year: widget.year,
                compact: compact,
                growthPoint: widget.growthPoint,
                highlight: widget.highlight,
                onHighlight: widget.onHighlight,
              )
            else
              MeadowLandmarks(
                year: widget.year,
                isCurrentYear: widget.isCurrentYear,
                compact: compact,
                highlight: widget.highlight,
                onHighlight: widget.onHighlight,
              ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.compact,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final BorderRadius radius = BorderRadius.all(
      Radius.circular(compact ? Shapes.radiusIconButton : Shapes.radiusThumb),
    );
    return _TabReach(
      child: Semantics(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onPressed,
            child: FocusRing(
              onPressed: onPressed,
              borderRadius: radius,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? Palette.coral : _clear,
                  borderRadius: radius,
                  boxShadow: selected
                      ? <BoxShadow>[
                          BoxShadow(
                            color: colors.shadow,
                            offset: const Offset(1, 1),
                          ),
                        ]
                      : const <BoxShadow>[],
                ),
                child: Padding(
                  padding: compact
                      ? const EdgeInsets.symmetric(horizontal: 8, vertical: 5)
                      : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: context.textStyles.captureLabelSans.copyWith(
                      color: selected ? Palette.onAccent : colors.inkSoft,
                      fontSize: compact ? 10 : 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabHeader extends SingleChildRenderObjectWidget {
  const _TabHeader({
    required this.before,
    required this.after,
    required Widget super.child,
  });

  final double before;
  final double after;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTabHeader(before, after);

  @override
  void updateRenderObject(BuildContext context, _RenderTabHeader renderObject) {
    renderObject
      ..before = before
      ..after = after;
  }
}

class _RenderTabHeader extends RenderShiftedBox {
  _RenderTabHeader(this._before, this._after) : super(null);

  double _before;
  double _after;
  Rect _reach = Rect.zero;

  Rect get reach => _reach;

  set before(double value) {
    if (value != _before) {
      _before = value;
      markNeedsLayout();
    }
  }

  set after(double value) {
    if (value != _after) {
      _after = value;
      markNeedsLayout();
    }
  }

  static BoxConstraints _childConstraints(BoxConstraints constraints) =>
      constraints.copyWith(minHeight: 0, maxHeight: double.infinity);

  double _around(double child) =>
      math.max(_before + child + _after, _minTapTarget);

  @override
  double computeMinIntrinsicHeight(double width) =>
      _around(super.computeMinIntrinsicHeight(width));

  @override
  double computeMaxIntrinsicHeight(double width) =>
      _around(super.computeMaxIntrinsicHeight(width));

  @override
  Size computeDryLayout(covariant BoxConstraints constraints) {
    final RenderBox? child = this.child;
    if (child == null) {
      return constraints.constrain(Size(0, _around(0)));
    }
    final Size inner = child.getDryLayout(_childConstraints(constraints));
    return constraints.constrain(Size(inner.width, _around(inner.height)));
  }

  @override
  void performLayout() {
    final RenderBox? child = this.child;
    if (child == null) {
      size = constraints.constrain(Size(0, _around(0)));
      _reach = Rect.zero;
      return;
    }
    child.layout(_childConstraints(constraints), parentUsesSize: true);
    final Rect target = _switchIn(child);
    final double half = math.max(_minTapTarget / 2, target.height / 2);
    final double shift = math.max(0, half - (_before + target.center.dy));
    final double centre = _before + shift + target.center.dy;
    (child.parentData! as BoxParentData).offset = Offset(0, _before + shift);
    size = constraints.constrain(
      Size(
        child.size.width,
        math.max(_before + shift + child.size.height + _after, centre + half),
      ),
    );
    _reach = Rect.fromLTRB(
      target.left,
      centre - half,
      target.right,
      centre + half,
    );
  }

  static Rect _switchIn(RenderBox child) {
    final _RenderTabSwitch? found = _findSwitch(child);
    if (found == null) {
      return Rect.zero;
    }
    return MatrixUtils.transformRect(
      found.getTransformTo(child),
      Offset.zero & found.laidOut,
    );
  }

  static _RenderTabSwitch? _findSwitch(RenderObject node) {
    if (node is _RenderTabSwitch) {
      return node;
    }
    _RenderTabSwitch? found;
    node.visitChildren((RenderObject child) {
      found ??= _findSwitch(child);
    });
    return found;
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
      position: _reach.contains(position)
          ? Offset(position.dx, _reach.center.dy)
          : position,
      hitTest: (BoxHitTestResult result, Offset transformed) =>
          child.hitTest(result, position: transformed),
    );
  }
}

class _TabSwitch extends SingleChildRenderObjectWidget {
  const _TabSwitch({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTabSwitch();
}

class _RenderTabSwitch extends RenderProxyBox {
  Size _laidOut = Size.zero;

  Size get laidOut => _laidOut;

  @override
  void performLayout() {
    super.performLayout();
    _laidOut = size;
  }
}

class _TabReach extends SingleChildRenderObjectWidget {
  const _TabReach({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTabReach();
}

class _RenderTabReach extends RenderProxyBox {
  _RenderTabHeader? get _header {
    for (RenderObject? node = parent; node != null; node = node.parent) {
      if (node is _RenderTabHeader) {
        return node;
      }
    }
    return null;
  }

  @override
  Rect get semanticBounds {
    final Rect own = Offset.zero & size;
    final _RenderTabHeader? header = _header;
    if (header == null || !header.hasSize) {
      return own;
    }
    final Matrix4? fromHeader = Matrix4.tryInvert(getTransformTo(header));
    if (fromHeader == null) {
      return own;
    }
    final Rect bandHere = MatrixUtils.transformRect(fromHeader, header.reach);
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
