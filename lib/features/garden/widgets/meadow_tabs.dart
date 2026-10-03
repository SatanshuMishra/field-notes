import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/garden/model/meadow_year.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/widgets/meadow_header.dart';
import 'package:field_notes/features/garden/widgets/meadow_landmarks.dart';
import 'package:field_notes/features/garden/widgets/meadow_ribbon.dart';

const String meadowDetailsCloseLabel = 'Close';
const String meadowDetailsCloseTooltip = 'Close (Esc)';
const ValueKey<String> meadowDetailsCloseKey = ValueKey<String>(
  'meadow-details-close',
);

const double _minTapTarget = 48;
const int _panelColumns = 4;
const Color _clear = Color(0x00000000);
const BorderRadius _trackRadius = BorderRadius.all(Radius.circular(12));
const BorderRadius _tabRadius = BorderRadius.all(Radius.circular(9));

enum MeadowDetailsTab { days, landmarks }

String meadowTabNote(MeadowDetailsTab tab, {required bool compact}) =>
    switch ((tab, compact)) {
      (MeadowDetailsTab.days, false) => 'Hover a month to find its flowers',
      (MeadowDetailsTab.days, true) => 'Tap a month to find its flowers',
      (MeadowDetailsTab.landmarks, false) =>
        'Hover one to find those days in the meadow',
      (MeadowDetailsTab.landmarks, true) => 'Tap one to find those days',
    };

class MeadowTabs extends StatefulWidget {
  const MeadowTabs({
    super.key,
    required this.year,
    required this.isCurrentYear,
    required this.compact,
    required this.growthPoint,
    required this.highlight,
    required this.onHighlight,
    this.tab,
    this.onTab,
    this.onClose,
    this.onFocusMonth,
    this.onFocusLandmark,
  });

  final MeadowYear year;
  final bool isCurrentYear;
  final bool compact;
  final int growthPoint;
  final MeadowRange? highlight;
  final ValueChanged<MeadowRange?> onHighlight;
  final MeadowDetailsTab? tab;
  final ValueChanged<MeadowDetailsTab>? onTab;
  final VoidCallback? onClose;
  final ValueChanged<int>? onFocusMonth;
  final ValueChanged<int>? onFocusLandmark;

  @override
  State<MeadowTabs> createState() => _MeadowTabsState();
}

class _MeadowTabsState extends State<MeadowTabs> {
  MeadowDetailsTab _own = MeadowDetailsTab.days;

  MeadowDetailsTab get _tab => widget.tab ?? _own;

  void _choose(MeadowDetailsTab tab) {
    if (tab == _tab) {
      return;
    }
    setState(() => _own = tab);
    widget.onTab?.call(tab);
    widget.onHighlight(null);
  }

  @override
  Widget build(BuildContext context) {
    final bool compact = widget.compact;
    final MeadowDetailsTab tab = _tab;
    final bool days = tab == MeadowDetailsTab.days;
    final VoidCallback? close = widget.onClose;
    final Widget header = Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(14, 12, 12, 8)
          : const EdgeInsets.fromLTRB(16, 14, 12, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _TabHeader(
              child: _TabSwitch(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: context.colors.ink.withAlpha(0x0F),
                    borderRadius: _trackRadius,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: _TabButton(
                            label: compact ? 'Day by day' : meadowDetailsLabel,
                            selected: days,
                            onPressed: () => _choose(MeadowDetailsTab.days),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: _TabButton(
                            label: widget.isCurrentYear
                                ? 'This year so far'
                                : 'Landmarks',
                            selected: !days,
                            onPressed: () =>
                                _choose(MeadowDetailsTab.landmarks),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (close != null) ...<Widget>[
            const SizedBox(width: 8),
            _CloseButton(compact: compact, onPressed: close),
          ],
        ],
      ),
    );
    final Widget note = Padding(
      padding: compact
          ? const EdgeInsets.fromLTRB(16, 0, 16, 8)
          : const EdgeInsets.fromLTRB(18, 0, 18, 10),
      child: Text(
        meadowTabNote(tab, compact: compact),
        style: context.textStyles.captionSans.copyWith(fontSize: 11),
      ),
    );
    final Widget body = days
        ? MeadowRibbon(
            year: widget.year,
            compact: compact,
            growthPoint: widget.growthPoint,
            highlight: widget.highlight,
            onHighlight: widget.onHighlight,
            columns: _panelColumns,
            onFocus: widget.onFocusMonth,
          )
        : MeadowLandmarks(
            year: widget.year,
            isCurrentYear: widget.isCurrentYear,
            compact: compact,
            highlight: widget.highlight,
            onHighlight: widget.onHighlight,
            onFocus: widget.onFocusLandmark,
          );
    final EdgeInsets bodyPadding = compact
        ? const EdgeInsets.fromLTRB(14, 0, 14, 14)
        : const EdgeInsets.fromLTRB(16, 0, 16, 16);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool bounded = constraints.hasBoundedHeight;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            header,
            note,
            if (bounded)
              Flexible(
                child: SingleChildScrollView(padding: bodyPadding, child: body),
              )
            else
              Padding(padding: bodyPadding, child: body),
          ],
        );
      },
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
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
              borderRadius: _tabRadius,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? Palette.coral : _clear,
                  borderRadius: _tabRadius,
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 10,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: context.textStyles.captureLabelSans.copyWith(
                      color: selected ? Palette.onAccent : colors.inkSoft,
                      fontSize: 12,
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

class _CloseButton extends StatefulWidget {
  const _CloseButton({required this.compact, required this.onPressed});

  final bool compact;
  final VoidCallback onPressed;

  @override
  State<_CloseButton> createState() => _CloseButtonState();
}

class _CloseButtonState extends State<_CloseButton> {
  bool _hovered = false;

  void _hover(bool hovered) {
    if (hovered != _hovered) {
      setState(() => _hovered = hovered);
    }
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final bool compact = widget.compact;
    final double extent = compact ? 44 : 34;
    final BorderRadius radius = BorderRadius.all(
      Radius.circular(compact ? 12 : 10),
    );
    final Widget face = DecoratedBox(
      decoration: BoxDecoration(
        color: _hovered ? colors.ink08 : _clear,
        borderRadius: radius,
      ),
      child: SizedBox.square(
        dimension: extent,
        child: Center(
          child: MeadowGlyph(
            path: meadowCross,
            size: compact ? 16 : 14,
            color: colors.ink,
            stroke: 2.4,
          ),
        ),
      ),
    );
    return Semantics(
      key: meadowDetailsCloseKey,
      button: true,
      label: meadowDetailsCloseLabel,
      onTap: widget.onPressed,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (PointerEnterEvent event) => _hover(true),
        onExit: (PointerExitEvent event) => _hover(false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: widget.onPressed,
          child: FocusRing(
            onPressed: widget.onPressed,
            borderRadius: radius,
            child: ExcludeSemantics(
              child: compact
                  ? face
                  : Tooltip(
                      message: meadowDetailsCloseTooltip,
                      excludeFromSemantics: true,
                      child: face,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabHeader extends SingleChildRenderObjectWidget {
  const _TabHeader({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTabHeader();
}

class _RenderTabHeader extends RenderShiftedBox {
  _RenderTabHeader() : super(null);

  Rect _reach = Rect.zero;

  Rect get reach => _reach;

  static BoxConstraints _childConstraints(BoxConstraints constraints) =>
      constraints.copyWith(minHeight: 0, maxHeight: double.infinity);

  double _around(double child) => math.max(child, _minTapTarget);

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
    final double height = _around(child.size.height);
    final double top = (height - child.size.height) / 2;
    (child.parentData! as BoxParentData).offset = Offset(0, top);
    size = constraints.constrain(Size(child.size.width, height));
    final Rect target = _switchIn(child).shift(Offset(0, top));
    final double half = math.max(_minTapTarget / 2, target.height / 2);
    final double centre = target.isEmpty ? height / 2 : target.center.dy;
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
    final Offset probe = _reach.contains(position)
        ? Offset(position.dx, _reach.center.dy)
        : position;
    return result.addWithPaintOffset(
      offset: offset,
      position: probe,
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
