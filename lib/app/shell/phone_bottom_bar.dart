import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/icons/nav_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

const double phoneBottomBarCaptureRise = 4.25;

const double _barHeight = 64;

const double _iconSize = 22;
const double _iconTop = 13;
const double _labelGap = 3;
const EdgeInsets _tabInset = EdgeInsets.symmetric(vertical: 6, horizontal: 4);

const double _captureExtent = 52;
const double _plusSize = 22;
const double _plusStroke = 2.6;

const BorderRadius _captureRadius = BorderRadius.all(
  Radius.circular(_captureExtent / 2),
);

const BorderRadius _tabRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusControl),
);

class PhoneBottomBar extends StatelessWidget {
  const PhoneBottomBar({
    super.key,
    required this.destinations,
    required this.selected,
    this.onSelect,
    this.onCapture,
  }) : assert(
         destinations.length == 4,
         'PhoneBottomBar requires four destinations',
       );

  final List<ShellDestination> destinations;
  final ShellDestination? selected;
  final ValueChanged<ShellDestination>? onSelect;
  final VoidCallback? onCapture;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return _RaisedStack(
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: colors.panelTop,
            border: Border(
              top: BorderSide(color: colors.line, width: Shapes.outlineWidth),
            ),
          ),
          child: SafeArea(
            top: false,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _barHeight),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Expanded(child: _tab(context, destinations[0])),
                    Expanded(child: _tab(context, destinations[1])),
                    const Spacer(),
                    Expanded(child: _tab(context, destinations[2])),
                    Expanded(child: _tab(context, destinations[3])),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: -phoneBottomBarCaptureRise,
          left: 0,
          right: 0,
          child: SafeArea(
            top: false,
            bottom: false,
            child: Center(child: _capture(context)),
          ),
        ),
      ],
    );
  }

  Widget _tab(BuildContext context, ShellDestination destination) {
    final FieldNotesColors colors = context.colors;
    final bool isSelected = destination == selected;
    final Color color = isSelected ? colors.accentInk : colors.mutedDeep;
    final NavGlyph? glyph = destination.glyph;
    final Widget art = Padding(
      padding: _tabInset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (glyph == null)
            Icon(destination.icon, size: _iconSize, color: color)
          else
            NavIcon(glyph: glyph, color: color, size: _iconSize),
          const SizedBox(height: _labelGap),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              destination.label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              style: context.textStyles.captionSans.copyWith(
                inherit: false,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
    final ValueChanged<ShellDestination>? onSelect = this.onSelect;
    final Widget placed = Padding(
      padding: EdgeInsets.only(top: _iconTop - _tabInset.top),
      child: Align(
        alignment: Alignment.topCenter,
        child: onSelect == null
            ? art
            : FocusRing(
                onPressed: () => onSelect(destination),
                borderRadius: _tabRadius,
                child: ExcludeSemantics(child: art),
              ),
      ),
    );
    if (onSelect == null) {
      return ExcludeSemantics(child: placed);
    }
    return Semantics(
      button: true,
      selected: isSelected,
      label: destination.label,
      child: GestureDetector(
        key: ValueKey<String>('tab-${destination.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(destination),
        child: placed,
      ),
    );
  }

  Widget _capture(BuildContext context) {
    final Widget circle = Container(
      width: _captureExtent,
      height: _captureExtent,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Palette.coral,
        shape: BoxShape.circle,
        border: Border.all(
          color: context.colors.line,
          width: Shapes.outlineWidth,
        ),
        boxShadow: context.shadows.emphasis,
      ),
      child: const NavIcon(
        glyph: NavGlyph.plus,
        color: Palette.onAccent,
        size: _plusSize,
        strokeWidth: _plusStroke,
      ),
    );
    final VoidCallback? onCapture = this.onCapture;
    if (onCapture == null) {
      return circle;
    }
    return Semantics(
      button: true,
      label: 'New entry',
      child: ClipOval(
        clipBehavior: Clip.none,
        child: GestureDetector(
          key: const ValueKey<String>('capture-button'),
          behavior: HitTestBehavior.opaque,
          onTap: onCapture,
          child: FocusRing(
            onPressed: onCapture,
            borderRadius: _captureRadius,
            child: circle,
          ),
        ),
      ),
    );
  }
}

class _RaisedStack extends Stack {
  const _RaisedStack({required super.children})
    : super(clipBehavior: Clip.none);

  @override
  RenderStack createRenderObject(BuildContext context) => _RenderRaisedStack(
    alignment: alignment,
    textDirection: textDirection ?? Directionality.maybeOf(context),
    fit: fit,
  );
}

class _RenderRaisedStack extends RenderStack {
  _RenderRaisedStack({super.alignment, super.textDirection, super.fit})
    : super(clipBehavior: Clip.none);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!hitTestChildren(result, position: position)) {
      return false;
    }
    result.add(BoxHitTestEntry(this, position));
    return true;
  }
}
