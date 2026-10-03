import 'dart:async';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/features/streak/streak.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/flowers/flowers.dart';
import '../../design/icons/nav_icons.dart';
import '../../design/tokens/tokens.dart';
import '../../design/widgets/icon_sticker_button.dart';
import '../../design/widgets/widgets.dart';
import '../../domain/mood/flower_kind.dart';
import 'keep_focus_in_view.dart';
import 'shell_destination.dart';
import 'window_chrome.dart';

const double shellSidebarOpenWidth = 176;
const double shellSidebarCollapsedWidth = 68;
const Duration shellSidebarResize = Duration(milliseconds: 250);
const Cubic shellSidebarCurve = Cubic(0.2, 0.8, 0.2, 1);

const String sidebarCollapseLabel = 'Collapse sidebar (⌘\\)';
const String sidebarExpandLabel = 'Expand sidebar (⌘\\)';

const Key sidebarRailKey = ValueKey<String>('sidebar-rail');
const Key sidebarToggleKey = ValueKey<String>('sidebar-toggle');

const double _railPaddingVertical = 18;
const double _railPaddingHorizontal = 12;
const double _headHeight = 34;
const double _headGap = 20;
const double _headFlower = 30;
const double _headWordmarkGap = 8;
const double _headWordmarkInset = 4;
const double _headWordmarkSize = 22;
const double _navItemHeight = 40;
const double _navItemGap = 6;
const double _navIconSize = 18;
const double _navLabelGap = 10;
const double _streakGap = 12;
const double _footerGap = 8;

const double _toggleExtent = 26;
const double _toggleTop = 22;
const double _toggleOpenInset = 10;
const double _toggleOverhang = 13;
const double _toggleIconExtent = 16;
const double _toggleIconStroke = 2.2;
const double _toggleEdgeWidth = 1;

const BorderRadius _navItemRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusControl),
);
const BorderRadius _toggleRadius = BorderRadius.all(
  Radius.circular(_toggleExtent / 2),
);

const String _soundOnLabel = 'Sound effects on';
const String _soundOffLabel = 'Sound effects off';

double _toggleLeft({required bool collapsed}) => collapsed
    ? shellSidebarCollapsedWidth + _toggleOverhang - _toggleExtent
    : shellSidebarOpenWidth - _toggleOpenInset - _toggleExtent;

class SidebarShell extends StatefulWidget {
  const SidebarShell({
    super.key,
    required this.destinations,
    required this.selected,
    required this.onSelect,
    required this.onSound,
    required this.body,
    this.streak,
    this.soundOn = true,
    this.obscured = false,
    this.collapsed = false,
    this.onCollapsedChanged,
  });

  final List<ShellDestination> destinations;
  final ShellDestination selected;
  final ValueChanged<ShellDestination> onSelect;
  final VoidCallback onSound;
  final Widget body;
  final Widget? streak;
  final bool soundOn;
  final bool obscured;
  final bool collapsed;
  final ValueChanged<bool>? onCollapsedChanged;

  @override
  State<SidebarShell> createState() => _SidebarShellState();
}

class _SidebarShellState extends State<SidebarShell> {
  final FocusNode _keys = FocusNode(
    debugLabel: 'sidebar-shortcuts',
    skipTraversal: true,
  );

  late final Map<Type, Action<Intent>> _actions = <Type, Action<Intent>>{
    _ToggleSidebarIntent: CallbackAction<_ToggleSidebarIntent>(
      onInvoke: (_ToggleSidebarIntent _) {
        _toggle();
        return null;
      },
    ),
  };

  bool get _toggles => widget.onCollapsedChanged != null;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((Duration _) => _reclaim());
  }

  @override
  void didUpdateWidget(SidebarShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.obscured && !widget.obscured) {
      WidgetsBinding.instance.addPostFrameCallback((Duration _) => _reclaim());
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusChanged);
    _keys.dispose();
    super.dispose();
  }

  bool get _focusFellToScope {
    final FocusNode? focused = FocusManager.instance.primaryFocus;
    return focused == null || identical(focused, _keys.enclosingScope);
  }

  bool get _mayReclaim =>
      mounted && _toggles && !widget.obscured && _focusFellToScope;

  void _reclaim() {
    if (_mayReclaim) {
      _keys.requestFocus();
    }
  }

  void _onFocusChanged() {
    if (_mayReclaim) {
      scheduleMicrotask(_reclaim);
    }
  }

  void _toggle() {
    widget.onCollapsedChanged?.call(!widget.collapsed);
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final bool obscured = widget.obscured;
    final Widget shell = KeepFocusInView(
      child: Scaffold(
        backgroundColor: colors.panelTop,
        body: Column(
          children: <Widget>[
            _dragBar(context),
            Expanded(
              child: ExcludeSemantics(
                excluding: obscured,
                child: ExcludeFocus(
                  excluding: obscured,
                  child: AbsorbPointer(
                    absorbing: obscured,
                    child: DecoratedBox(
                      decoration: _panelWash(colors),
                      child: DecoratedBox(
                        decoration: _panelGlow,
                        child: _panel(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (!_toggles) {
      return shell;
    }
    return Shortcuts(
      includeSemantics: false,
      shortcuts: <ShortcutActivator, Intent>{
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.backslash):
            const _ToggleSidebarIntent(),
      },
      child: Actions(
        actions: _actions,
        child: Focus(focusNode: _keys, includeSemantics: false, child: shell),
      ),
    );
  }

  Widget _panel(BuildContext context) {
    final bool collapsed = widget.collapsed;
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: Stack(
        clipBehavior: Clip.none,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              FocusTraversalOrder(
                order: const NumericFocusOrder(0),
                child: FocusTraversalGroup(child: _rail(context)),
              ),
              DashedDivider(
                axis: Axis.vertical,
                thickness: 1.0,
                color: context.colors.ink22,
              ),
              Expanded(
                child: FocusTraversalOrder(
                  order: const NumericFocusOrder(2),
                  child: FocusTraversalGroup(child: widget.body),
                ),
              ),
            ],
          ),
          if (_toggles)
            AnimatedPositioned(
              duration: shellSidebarResize,
              curve: shellSidebarCurve,
              top: _toggleTop,
              left: _toggleLeft(collapsed: collapsed),
              width: _toggleExtent,
              height: _toggleExtent,
              child: FocusTraversalOrder(
                order: const NumericFocusOrder(1),
                child: _SidebarToggle(collapsed: collapsed, onPressed: _toggle),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dragBar(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return GestureDetector(
      key: windowTitleBarKey,
      behavior: HitTestBehavior.opaque,
      onPanStart: (DragStartDetails _) => unawaited(startWindowDrag()),
      onDoubleTap: () => unawaited(runTitlebarDoubleClick()),
      child: Container(
        height: shellTitleBarHeight,
        padding: const EdgeInsets.symmetric(horizontal: shellTitleBarPadding),
        decoration: BoxDecoration(
          color: colors.titleBar,
          border: Border(bottom: BorderSide(color: colors.ink16, width: 1)),
        ),
        child: Row(
          children: <Widget>[
            const SizedBox(
              key: ValueKey<String>('traffic-lights'),
              width: windowButtonsSlotWidth,
            ),
            Expanded(
              child: Text(
                'field notes — a journal of days',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.windowTitleAccent,
              ),
            ),
            const SizedBox(width: windowButtonsSlotWidth),
          ],
        ),
      ),
    );
  }

  Widget _rail(BuildContext context) {
    final bool collapsed = widget.collapsed;
    final double width = collapsed
        ? shellSidebarCollapsedWidth
        : shellSidebarOpenWidth;
    return AnimatedContainer(
      key: sidebarRailKey,
      duration: shellSidebarResize,
      curve: shellSidebarCurve,
      width: width,
      child: ClipRect(
        child: OverflowBox(
          alignment: AlignmentDirectional.topStart,
          minWidth: width,
          maxWidth: width,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: _railPaddingVertical,
              horizontal: _railPaddingHorizontal,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _head(context),
                const SizedBox(height: _headGap),
                for (final (int index, ShellDestination d)
                    in widget.destinations.indexed) ...<Widget>[
                  if (index > 0) const SizedBox(height: _navItemGap),
                  _railItem(context, d),
                ],
                const Spacer(),
                widget.streak ??
                    StreakPill(
                      form: collapsed
                          ? StreakPillForm.rail
                          : StreakPillForm.sidebar,
                    ),
                const SizedBox(height: _streakGap),
                _footer(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _head(BuildContext context) {
    final bool collapsed = widget.collapsed;
    return SizedBox(
      height: _headHeight,
      child: Padding(
        padding: EdgeInsets.only(left: collapsed ? 0 : _headWordmarkInset),
        child: Row(
          mainAxisAlignment: collapsed
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: <Widget>[
            const FlowerBloom(kind: FlowerKind.peony, size: _headFlower),
            if (!collapsed) ...<Widget>[
              const SizedBox(width: _headWordmarkGap),
              Expanded(
                child: Text(
                  'field\nnotes',
                  overflow: TextOverflow.visible,
                  style: context.textStyles.wordmarkAccent.copyWith(
                    fontSize: _headWordmarkSize,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final bool settingsSelected = widget.selected == ShellDestination.settings;
    final bool soundOn = widget.soundOn;
    final List<Widget> buttons = <Widget>[
      IconStickerButton(
        key: const ValueKey<String>('settings-button'),
        glyph: IconStickerGlyph.gear,
        glyphColor: settingsSelected ? Palette.onAccent : colors.ink,
        background: settingsSelected ? Palette.coral : colors.cardLight,
        semanticLabel: ShellDestination.settings.label,
        selected: settingsSelected,
        onPressed: () => widget.onSelect(ShellDestination.settings),
      ),
      IconStickerButton(
        key: const ValueKey<String>('sound-button'),
        glyph: soundOn ? IconStickerGlyph.soundOn : IconStickerGlyph.soundOff,
        glyphColor: colors.ink,
        background: soundOn ? colors.cardLight : colors.cardWarm,
        semanticLabel: soundOn ? _soundOnLabel : _soundOffLabel,
        onPressed: widget.onSound,
      ),
    ];
    if (widget.collapsed) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          buttons.first,
          const SizedBox(height: _footerGap),
          buttons.last,
        ],
      );
    }
    return Row(
      children: <Widget>[
        buttons.first,
        const SizedBox(width: _footerGap),
        buttons.last,
      ],
    );
  }

  Widget _railItem(BuildContext context, ShellDestination d) {
    final FieldNotesShadows shadows = context.shadows;
    final bool collapsed = widget.collapsed;
    final bool isSelected = d == widget.selected;
    final Color foreground = isSelected
        ? Palette.onAccent
        : context.colors.inkSoft;
    final NavGlyph? glyph = d.glyph;
    void select() => widget.onSelect(d);
    final Widget item = Semantics(
      button: true,
      selected: isSelected,
      label: d.label,
      child: GestureDetector(
        key: ValueKey<String>('rail-${d.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: select,
        child: FocusRing(
          onPressed: select,
          borderRadius: _navItemRadius,
          child: ExcludeSemantics(
            child: SizedBox(
              height: _navItemHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isSelected ? Palette.coral : null,
                  border: isSelected ? shadows.outline : null,
                  borderRadius: _navItemRadius,
                  boxShadow: isSelected ? shadows.emphasis : null,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: collapsed ? 0 : _railPaddingHorizontal,
                  ),
                  child: Row(
                    mainAxisAlignment: collapsed
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.start,
                    children: <Widget>[
                      if (glyph == null)
                        Icon(d.icon, size: _navIconSize, color: foreground)
                      else
                        NavIcon(
                          glyph: glyph,
                          color: foreground,
                          size: _navIconSize,
                        ),
                      if (!collapsed) ...<Widget>[
                        const SizedBox(width: _navLabelGap),
                        Flexible(
                          child: Text(
                            d.label,
                            maxLines: 1,
                            softWrap: false,
                            overflow: TextOverflow.ellipsis,
                            style: context.textStyles.navLabelSans.copyWith(
                              color: foreground,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (!collapsed) {
      return item;
    }
    return Tooltip(message: d.label, excludeFromSemantics: true, child: item);
  }
}

class _ToggleSidebarIntent extends Intent {
  const _ToggleSidebarIntent();
}

class _SidebarToggle extends StatefulWidget {
  const _SidebarToggle({required this.collapsed, required this.onPressed});

  final bool collapsed;
  final VoidCallback onPressed;

  @override
  State<_SidebarToggle> createState() => _SidebarToggleState();
}

class _SidebarToggleState extends State<_SidebarToggle> {
  bool _hovered = false;

  void _hover(bool hovered) {
    if (hovered != _hovered) {
      setState(() => _hovered = hovered);
    }
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final bool collapsed = widget.collapsed;
    final String label = collapsed ? sidebarExpandLabel : sidebarCollapseLabel;
    final Color fill = _hovered
        ? colors.ink08
        : collapsed
        ? colors.cardWarm
        : Colors.transparent;
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: label,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (PointerEnterEvent _) => _hover(true),
          onExit: (PointerExitEvent _) => _hover(false),
          child: GestureDetector(
            key: sidebarToggleKey,
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            child: FocusRing(
              onPressed: widget.onPressed,
              borderRadius: _toggleRadius,
              child: ExcludeSemantics(
                child: SizedBox.square(
                  dimension: _toggleExtent,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: fill,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: collapsed ? colors.ink25 : Colors.transparent,
                        width: _toggleEdgeWidth,
                      ),
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size.square(_toggleIconExtent),
                        painter: SidebarChevronPainter(
                          pointsBack: !collapsed,
                          color: colors.mutedDeep,
                        ),
                      ),
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

class SidebarChevronPainter extends CustomPainter {
  const SidebarChevronPainter({required this.pointsBack, required this.color});

  final bool pointsBack;
  final Color color;

  static const double viewBox = 24;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.shortestSide / viewBox);
    final Path chevron = pointsBack
        ? (Path()
            ..moveTo(15, 5)
            ..lineTo(8, 12)
            ..lineTo(15, 19))
        : (Path()
            ..moveTo(9, 5)
            ..lineTo(16, 12)
            ..lineTo(9, 19));
    canvas.drawPath(
      chevron,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _toggleIconStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(SidebarChevronPainter oldDelegate) =>
      oldDelegate.pointsBack != pointsBack || oldDelegate.color != color;
}

const double _panelGlowBaseRadius = 0.5;
const double _panelGlowExtentX = 1.2;
const double _panelGlowExtentY = 0.6;
const double _panelGlowCentreX = 0.15;
const double _panelGlowFadeStop = 0.55;

const Color _panelCoralTintFade = Color(0x00C76A54);

BoxDecoration _panelWash(FieldNotesColors colors) => BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[colors.panelTop, colors.panelBottom],
  ),
);

const BoxDecoration _panelGlow = BoxDecoration(
  gradient: RadialGradient(
    center: Alignment(2 * _panelGlowCentreX - 1, -1),
    radius: _panelGlowBaseRadius,
    colors: <Color>[Palette.panelCoralTint, _panelCoralTintFade],
    stops: <double>[0, _panelGlowFadeStop],
    transform: _PanelGlowScale(),
  ),
);

class _PanelGlowScale extends GradientTransform {
  const _PanelGlowScale();

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final double base = _panelGlowBaseRadius * bounds.shortestSide;
    if (base <= 0) {
      return Matrix4.identity();
    }
    final double scaleX = _panelGlowExtentX * bounds.width / base;
    final double scaleY = _panelGlowExtentY * bounds.height / base;
    final double centreX = bounds.left + _panelGlowCentreX * bounds.width;
    final double centreY = bounds.top;
    return Matrix4.identity()
      ..setEntry(0, 0, scaleX)
      ..setEntry(1, 1, scaleY)
      ..setEntry(0, 3, centreX * (1 - scaleX))
      ..setEntry(1, 3, centreY * (1 - scaleY));
  }
}
