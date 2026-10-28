import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/icons/nav_icons.dart';
import 'package:field_notes/design/interaction/hover_fill.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/material.dart';

const double phoneBottomBarCaptureRise = 4.25;

const double phoneBottomBarHeight = 64;
const double phoneBottomBarSideInset = 12;
const double phoneBottomBarGap = 8;

const double _barRadius = phoneBottomBarHeight / 2;
const double _barPadding = 6;
const double _cellHeight = 52;
const double _iconSize = 22;
const double _labelGap = 2;
const double _labelSize = 11;

const double _captureExtent = 46;
const double _plusSize = 22;
const double _plusStroke = 2.6;

const BorderRadius _barBorderRadius = BorderRadius.all(
  Radius.circular(_barRadius),
);
const BorderRadius _cellRadius = BorderRadius.all(
  Radius.circular(_cellHeight / 2),
);
const BorderRadius _captureRadius = BorderRadius.all(
  Radius.circular(_captureExtent / 2),
);

const Color phoneBottomBarSceneInk = Color.fromRGBO(251, 243, 228, 0.82);
const Color phoneBottomBarSceneTint = Color.fromRGBO(28, 22, 16, 0.72);
const Color phoneBottomBarScenePill = Palette.coral30;
const Color _captureGlow = Color.fromRGBO(120, 50, 30, 0.55);
const Color _captureHighlight = Color.fromRGBO(255, 255, 255, 0.25);

const List<BoxShadow> _captureShadow = <BoxShadow>[
  BoxShadow(
    color: _captureGlow,
    offset: Offset(0, 4),
    blurRadius: 12,
    spreadRadius: -4,
  ),
];

class PhoneBottomBar extends StatelessWidget {
  const PhoneBottomBar({
    super.key,
    required this.destinations,
    required this.selected,
    this.onSelect,
    this.onCapture,
    this.overScene = false,
    this.grouped = false,
  }) : assert(
         destinations.length == 4,
         'PhoneBottomBar requires four destinations',
       );

  final List<ShellDestination> destinations;
  final ShellDestination? selected;
  final ValueChanged<ShellDestination>? onSelect;
  final VoidCallback? onCapture;
  final bool overScene;
  final bool grouped;

  GlassTone get tone => overScene ? GlassTone.scene : GlassTone.paper;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: phoneBottomBarHeight,
      child: GlassSurface(
        tone: tone,
        borderRadius: _barBorderRadius,
        grouped: grouped,
        tint: overScene ? phoneBottomBarSceneTint : null,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Expanded(child: _tab(context, destinations[0])),
            Expanded(child: _tab(context, destinations[1])),
            Expanded(child: _capture(context)),
            Expanded(child: _tab(context, destinations[2])),
            Expanded(child: _tab(context, destinations[3])),
          ],
        ),
      ),
    );
  }

  Color _inkFor(BuildContext context, {required bool isSelected}) {
    final FieldNotesColors colors = context.colors;
    return switch ((overScene, isSelected)) {
      (true, true) => colors.accentTint,
      (true, false) => phoneBottomBarSceneInk,
      (false, true) => colors.accentInkStrong,
      (false, false) => colors.mutedInkStrong,
    };
  }

  Color _pillFor(BuildContext context) => overScene
      ? phoneBottomBarScenePill
      : tone.pillFor(Theme.of(context).brightness);

  FocusRingSurface get _surface =>
      overScene ? FocusRingSurface.dark : FocusRingSurface.light;

  Widget _tab(BuildContext context, ShellDestination destination) {
    final bool isSelected = destination == selected;
    final Color ink = _inkFor(context, isSelected: isSelected);
    final NavGlyph? glyph = destination.glyph;
    Widget art(bool hovered) => SizedBox(
      height: _cellHeight,
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isSelected ? _pillFor(context) : null,
          borderRadius: _cellRadius,
        ),
        child: HoverFill(
          hovered: hovered,
          surface: _surface,
          borderRadius: _cellRadius,
          position: DecorationPosition.background,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              if (glyph == null)
                Icon(destination.icon, size: _iconSize, color: ink)
              else
                NavIcon(glyph: glyph, color: ink, size: _iconSize),
              const SizedBox(height: _labelGap),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    destination.label,
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.visible,
                    style: context.textStyles.caption11Sans.copyWith(
                      inherit: false,
                      fontSize: _labelSize,
                      fontWeight: FontWeight.w600,
                      color: ink,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    final ValueChanged<ShellDestination>? onSelect = this.onSelect;
    if (onSelect == null) {
      return ExcludeSemantics(child: _slot(art(false)));
    }
    return Pressable(
      key: ValueKey<String>('tab-${destination.name}'),
      label: destination.label,
      selected: isSelected,
      onPressed: () => onSelect(destination),
      borderRadius: _cellRadius,
      surface: _surface,
      placement: FocusRingPlacement.edge,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => _slot(art(hovered)),
    );
  }

  Widget _slot(Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _barPadding),
      child: Center(child: child),
    );
  }

  Widget _capture(BuildContext context) {
    Widget circle(bool hovered) => SizedBox.square(
      dimension: _captureExtent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Palette.coral,
          shape: BoxShape.circle,
          border: context.shadows.outline,
          boxShadow: _captureShadow,
        ),
        child: HoverFill(
          hovered: hovered,
          surface: FocusRingSurface.dark,
          borderRadius: _captureRadius,
          position: DecorationPosition.background,
          child: const CustomPaint(
            painter: GlassHighlightPainter(
              color: _captureHighlight,
              borderRadius: _captureRadius,
              insets: EdgeInsets.all(Shapes.outlineWidth),
            ),
            child: Center(
              child: NavIcon(
                glyph: NavGlyph.plus,
                color: Palette.onAccent,
                size: _plusSize,
                strokeWidth: _plusStroke,
              ),
            ),
          ),
        ),
      ),
    );
    final VoidCallback? onCapture = this.onCapture;
    if (onCapture == null) {
      return ExcludeSemantics(child: Center(child: circle(false)));
    }
    return Pressable(
      key: const ValueKey<String>('capture-button'),
      label: 'New entry',
      onPressed: onCapture,
      borderRadius: _captureRadius,
      surface: _surface,
      placement: FocusRingPlacement.edge,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) =>
          Center(child: circle(hovered)),
    );
  }
}
