import 'dart:math' as math;

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/focus/keyboard_focus_builder.dart';
import 'package:field_notes/design/interaction/hover_fill.dart';
import 'package:field_notes/design/interaction/hover_style.dart';
import 'package:field_notes/design/interaction/min_target.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show CustomSemanticsAction;

import '../../../design/feedback/dialog_host.dart';
import '../../../design/motion/motion_tokens.dart';
import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/icon_sticker_button.dart';
import '../../../design/widgets/phone_sheet.dart';
import '../../../design/widgets/sticker_button.dart';
import '../../../domain/platform/desktop_platform.dart';
import '../transport/transport_bar.dart'
    show TransportGlyph, TransportGlyphIcon;

const Key logActionsPillKey = ValueKey<String>('log-actions-pill');
const Key logActionsEditKey = ValueKey<String>('log-actions-edit');
const Key logActionsDeleteKey = ValueKey<String>('log-actions-delete');
const Key logActionsOpenKey = ValueKey<String>('log-actions-open');
const Key logActionsMoreKey = ValueKey<String>('log-actions-more');
const Key logActionsRenameKey = ValueKey<String>('log-actions-rename');
const Key logActionsMenuKey = ValueKey<String>('log-actions-menu');

const String logActionsEditLabel = 'Edit note';
const String logActionsDeleteLabel = 'Delete entry';
const String logActionsOpenLabel = 'Open';
const String logActionsOpenTooltip = 'Open full view';
const String logActionsMoreLabel = 'More';
const String logActionsRenameLabel = 'Rename';
const String logActionsAddTitleLabel = 'Add a title';
const String logMenuDeleteLabel = 'Delete log';

const double _pillPadding = 4;
const double _pillGap = 2;
const double _glyphExtent = 14;
const double _defaultButtonExtent = 28;
const double _tapTarget = 48;

const double _cardActionGap = 2;
const double _cardGlyphExtent = 20;
const double _strokeWidth = 1.7;
const double _glyphViewBox = 24;

const double _menuWidth = 216;
const double _menuGap = 4;
const double _menuScreenMargin = 8;
const double _menuRowInset = 10;
const double _menuRowGlyphGap = 10;
const double _menuRowGlyph = 18;
const double _menuPhoneRowHeight = 52;
const double _menuLabelSize = 14;
const EdgeInsets _menuPadding = EdgeInsets.all(4);
const EdgeInsets _menuSheetPadding = EdgeInsets.fromLTRB(12, 2, 12, 12);

final Color _actionHoverFill = Palette.onAccent.withValues(alpha: 0.14);

final FocusTraversalPolicy _cardTabOrder = _TreeOrderTraversalPolicy();

const BorderRadius _pillRadius = BorderRadius.all(Radius.circular(10));
const BorderRadius _buttonRadius = BorderRadius.all(Radius.circular(7));
const BorderRadius _cardActionRadius = BorderRadius.all(
  Radius.circular(Shapes.radius8),
);
const BorderRadius _menuRadius = BorderRadius.all(
  Radius.circular(Shapes.radius12),
);
const BorderRadius _menuRowRadius = BorderRadius.all(
  Radius.circular(Shapes.radius8),
);

EdgeInsets logActionsPillTapInset({
  double buttonExtent = _defaultButtonExtent,
  required bool withEdit,
  bool growDown = false,
}) => _PillGeometry(
  buttonExtent: buttonExtent,
  paired: withEdit,
  growDown: growDown,
).pillInset;

class LogActionsPill extends StatelessWidget {
  const LogActionsPill({
    super.key,
    this.onEdit,
    required this.onDelete,
    this.buttonExtent = _defaultButtonExtent,
    this.growDown = false,
  });

  final VoidCallback? onEdit;
  final VoidCallback onDelete;
  final double buttonExtent;
  final bool growDown;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? edit = onEdit;
    final Color dangerInk = StickerButtonVariant.danger.inkOn(
      StickerGround.media,
      context.colors,
    );
    final _PillGeometry geometry = _PillGeometry(
      buttonExtent: buttonExtent,
      paired: edit != null,
      growDown: growDown,
    );
    return Stack(
      children: <Widget>[
        Positioned.fill(
          child: Padding(
            padding: geometry.pillInset,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                color: Palette.toolbarInk,
                borderRadius: _pillRadius,
                boxShadow: Shadows.toastLift,
              ),
            ),
          ),
        ),
        Padding(
          padding: geometry.rowPadding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (edit != null)
                _LogActionButton(
                  key: logActionsEditKey,
                  glyph: IconStickerGlyph.edit,
                  label: logActionsEditLabel,
                  glyphColor: Palette.onAccent,
                  extent: buttonExtent,
                  margin: geometry.leadingMargin,
                  onPressed: edit,
                ),
              _LogActionButton(
                key: logActionsDeleteKey,
                glyph: IconStickerGlyph.trash,
                label: logActionsDeleteLabel,
                glyphColor: dangerInk,
                extent: buttonExtent,
                margin: geometry.trailingMargin,
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

final class _PillGeometry {
  const _PillGeometry({
    required this.buttonExtent,
    required this.paired,
    required this.growDown,
  });

  final double buttonExtent;
  final bool paired;
  final bool growDown;

  double get _slack => math.max<double>(0, _tapTarget - buttonExtent);

  double get _outer =>
      paired ? math.max<double>(0, _slack - _pillGap / 2) : _slack / 2;

  double get _top =>
      growDown ? math.min<double>(_pillPadding, _slack) : _slack / 2;

  double get _bottom => _slack - _top;

  EdgeInsets get pillInset => EdgeInsets.fromLTRB(
    math.max<double>(0, _outer - _pillPadding),
    math.max<double>(0, _top - _pillPadding),
    math.max<double>(0, _outer - _pillPadding),
    math.max<double>(0, _bottom - _pillPadding),
  );

  EdgeInsets get rowPadding => EdgeInsets.fromLTRB(
    math.max<double>(0, _pillPadding - _outer),
    math.max<double>(0, _pillPadding - _top),
    math.max<double>(0, _pillPadding - _outer),
    math.max<double>(0, _pillPadding - _bottom),
  );

  EdgeInsetsDirectional get leadingMargin =>
      EdgeInsetsDirectional.fromSTEB(_outer, _top, _pillGap / 2, _bottom);

  EdgeInsetsDirectional get trailingMargin => EdgeInsetsDirectional.fromSTEB(
    paired ? _pillGap / 2 : _outer,
    _top,
    _outer,
    _bottom,
  );
}

class _LogActionButton extends StatefulWidget {
  const _LogActionButton({
    super.key,
    required this.glyph,
    required this.label,
    required this.glyphColor,
    required this.extent,
    required this.margin,
    required this.onPressed,
  });

  final IconStickerGlyph glyph;
  final String label;
  final Color glyphColor;
  final double extent;
  final EdgeInsetsGeometry margin;
  final VoidCallback onPressed;

  @override
  State<_LogActionButton> createState() => _LogActionButtonState();
}

class _LogActionButtonState extends State<_LogActionButton> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'log action');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Pressable(
      label: widget.label,
      onPressed: widget.onPressed,
      focusNode: _focusNode,
      surface: FocusRingSurface.dark,
      placement: FocusRingPlacement.edge,
      borderRadius: _buttonRadius,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => Padding(
        padding: widget.margin,
        child: SizedBox.square(
          dimension: widget.extent,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              KeyboardFocusBuilder(
                focusNode: _focusNode,
                builder: (BuildContext context, bool keyboardFocused) =>
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: hovered || keyboardFocused
                            ? _actionHoverFill
                            : null,
                        borderRadius: _buttonRadius,
                      ),
                    ),
              ),
              Center(
                child: IconStickerGlyphIcon(
                  glyph: widget.glyph,
                  color: widget.glyphColor,
                  size: _glyphExtent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LogCardHighlight extends InheritedWidget {
  const LogCardHighlight({
    super.key,
    required this.active,
    required super.child,
  });

  final bool active;

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LogCardHighlight>()?.active ??
      false;

  @override
  bool updateShouldNotify(LogCardHighlight oldWidget) =>
      active != oldWidget.active;
}

class LogCardFrame extends StatelessWidget {
  const LogCardFrame({
    super.key,
    required this.builder,
    required this.onOpen,
    required this.onLongPress,
    this.semanticActions = const <CustomSemanticsAction, VoidCallback>{},
    this.semanticIndex,
    this.borderRadius = BorderRadius.zero,
  });

  final PressableBuilder builder;
  final VoidCallback onOpen;
  final VoidCallback onLongPress;
  final Map<CustomSemanticsAction, VoidCallback> semanticActions;
  final int? semanticIndex;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final Widget card = Pressable(
      label: '',
      onPressed: onOpen,
      paintsHover: false,
      excludeSemantics: false,
      borderRadius: borderRadius,
      builder: (BuildContext context, bool hovered) => Semantics(
        onLongPress: onLongPress,
        customSemanticsActions: semanticActions,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onLongPress: onLongPress,
          child: builder(context, hovered),
        ),
      ),
    );
    final Widget ordered = FocusTraversalGroup(
      policy: _cardTabOrder,
      child: card,
    );
    final int? index = semanticIndex;
    return index == null
        ? ordered
        : IndexedSemantics(index: index, child: ordered);
  }
}

final class _TreeOrderTraversalPolicy extends FocusTraversalPolicy
    with DirectionalFocusTraversalPolicyMixin {
  @override
  Iterable<FocusNode> sortDescendants(
    Iterable<FocusNode> descendants,
    FocusNode currentNode,
  ) {
    final Map<FocusNode, List<Element>> lineages = <FocusNode, List<Element>>{
      for (final FocusNode node in descendants) node: _lineageOf(node.context),
    };
    return <FocusNode>[...descendants]..sort(
      (FocusNode a, FocusNode b) =>
          _compareLineages(lineages[a]!, lineages[b]!),
    );
  }
}

List<Element> _lineageOf(BuildContext? context) {
  if (context is! Element) {
    return const <Element>[];
  }
  final List<Element> upward = <Element>[context];
  context.visitAncestorElements((Element ancestor) {
    upward.add(ancestor);
    return true;
  });
  return upward.reversed.toList(growable: false);
}

int _compareLineages(List<Element> first, List<Element> second) {
  final int shared = math.min(first.length, second.length);
  int depth = 0;
  while (depth < shared && identical(first[depth], second[depth])) {
    depth += 1;
  }
  if (depth == shared || depth == 0) {
    return first.length.compareTo(second.length);
  }
  int order = 0;
  first[depth - 1].visitChildren((Element child) {
    if (order == 0 && identical(child, first[depth])) {
      order = -1;
    } else if (order == 0 && identical(child, second[depth])) {
      order = 1;
    }
  });
  return order;
}

class LogCardActions extends StatelessWidget {
  const LogCardActions({
    super.key,
    this.onOpen,
    required this.onMore,
    this.moreAnchorKey,
  });

  final VoidCallback? onOpen;
  final VoidCallback onMore;
  final GlobalKey? moreAnchorKey;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? open = onOpen;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (open != null) ...<Widget>[
          _CardActionButton(
            key: logActionsOpenKey,
            label: logActionsOpenLabel,
            tooltip: logActionsOpenTooltip,
            highlighted: LogCardHighlight.of(context),
            onPressed: open,
            glyph: (Color color) => TransportGlyphIcon(
              glyph: TransportGlyph.fullScreen,
              color: color,
              size: _cardGlyphExtent,
            ),
          ),
          const SizedBox(width: _cardActionGap),
        ],
        KeyedSubtree(
          key: moreAnchorKey,
          child: _CardActionButton(
            key: logActionsMoreKey,
            label: logActionsMoreLabel,
            tooltip: logActionsMoreLabel,
            onPressed: onMore,
            glyph: (Color color) => TransportGlyphIcon(
              glyph: TransportGlyph.more,
              color: color,
              size: _cardGlyphExtent,
            ),
          ),
        ),
      ],
    );
  }
}

class _CardActionButton extends StatelessWidget {
  const _CardActionButton({
    super.key,
    required this.label,
    required this.tooltip,
    required this.onPressed,
    required this.glyph,
    this.highlighted = false,
  });

  final String label;
  final String tooltip;
  final VoidCallback onPressed;
  final Widget Function(Color color) glyph;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Pressable(
      label: label,
      tooltip: tooltip,
      iconOnly: true,
      onPressed: onPressed,
      borderRadius: _cardActionRadius,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) {
        final bool lit = hovered || highlighted;
        return HoverFill(
          hovered: lit,
          borderRadius: _cardActionRadius,
          position: DecorationPosition.background,
          child: SizedBox.square(
            dimension: minIconTargetOn(Theme.of(context).platform),
            child: Center(child: glyph(lit ? colors.ink : colors.inkSoft)),
          ),
        );
      },
    );
  }
}

enum _StrokeGlyph { title }

class _StrokeGlyphIcon extends StatelessWidget {
  const _StrokeGlyphIcon({
    required this.glyph,
    required this.color,
    required this.size,
  });

  final _StrokeGlyph glyph;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _StrokeGlyphPainter(glyph: glyph, color: color),
  );
}

class _StrokeGlyphPainter extends CustomPainter {
  const _StrokeGlyphPainter({required this.glyph, required this.color});

  final _StrokeGlyph glyph;
  final Color color;

  Path get _path => switch (glyph) {
    _StrokeGlyph.title =>
      Path()
        ..moveTo(5, 6.5)
        ..lineTo(19, 6.5)
        ..moveTo(12, 6.5)
        ..lineTo(12, 18.5)
        ..moveTo(9, 18.5)
        ..lineTo(15, 18.5),
  };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.shortestSide / _glyphViewBox);
    canvas.drawPath(
      _path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_StrokeGlyphPainter oldDelegate) =>
      glyph != oldDelegate.glyph || color != oldDelegate.color;
}

enum LogMenuGlyph { title, edit, trash }

@immutable
final class LogMenuItem {
  const LogMenuItem({
    required this.key,
    required this.label,
    required this.glyph,
    required this.onSelected,
    this.danger = false,
  });

  final Key key;
  final String label;
  final LogMenuGlyph glyph;
  final VoidCallback onSelected;
  final bool danger;
}

Future<void> showLogActionsMenu(
  BuildContext anchor, {
  required List<LogMenuItem> items,
}) async {
  final LogMenuItem? chosen = isDesktopPlatform(Theme.of(anchor).platform)
      ? await _showAnchoredMenu(anchor, items)
      : await _showMenuSheet(anchor, items);
  chosen?.onSelected();
}

Future<LogMenuItem?> _showAnchoredMenu(
  BuildContext anchor,
  List<LogMenuItem> items,
) {
  final RenderBox box = anchor.findRenderObject()! as RenderBox;
  final Rect from = MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
  final bool still = MediaQuery.maybeDisableAnimationsOf(anchor) ?? false;
  return showGeneralDialog<LogMenuItem>(
    context: anchor,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: const Color(0x00000000),
    transitionDuration: still ? Duration.zero : Motion.press,
    pageBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) => DialogHost(
          child: CustomSingleChildLayout(
            delegate: _AnchoredMenuLayout(anchor: from),
            child: _AnchoredMenu(items: items),
          ),
        ),
    transitionBuilder:
        (
          BuildContext context,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) => FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Motion.fadeCurve),
          child: child,
        ),
  );
}

Future<LogMenuItem?> _showMenuSheet(
  BuildContext anchor,
  List<LogMenuItem> items,
) => showPhoneSheet<LogMenuItem>(
  anchor,
  builder: (BuildContext context) => PhoneSheet(
    key: logActionsMenuKey,
    color: context.colors.panelTop,
    child: Padding(
      padding: _menuSheetPadding,
      child: _MenuRows(items: items, rowHeight: _menuPhoneRowHeight),
    ),
  ),
);

class _AnchoredMenuLayout extends SingleChildLayoutDelegate {
  const _AnchoredMenuLayout({required this.anchor});

  final Rect anchor;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      const BoxConstraints.tightFor(width: _menuWidth).copyWith(
        maxHeight: math.max(0, constraints.maxHeight - 2 * _menuScreenMargin),
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final double furthestLeft = math.max(
      _menuScreenMargin,
      size.width - childSize.width - _menuScreenMargin,
    );
    final double furthestTop = math.max(
      _menuScreenMargin,
      size.height - childSize.height - _menuScreenMargin,
    );
    final double below = anchor.bottom + _menuGap;
    final double top = below <= furthestTop
        ? below
        : anchor.top - _menuGap - childSize.height;
    return Offset(
      (anchor.right - childSize.width).clamp(_menuScreenMargin, furthestLeft),
      top.clamp(_menuScreenMargin, furthestTop),
    );
  }

  @override
  bool shouldRelayout(_AnchoredMenuLayout oldDelegate) =>
      anchor != oldDelegate.anchor;
}

class _AnchoredMenu extends StatelessWidget {
  const _AnchoredMenu({required this.items});

  final List<LogMenuItem> items;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: logActionsMenuKey,
      decoration: BoxDecoration(
        color: context.colors.cardBright,
        border: context.shadows.outline,
        borderRadius: _menuRadius,
        boxShadow: context.shadows.hero,
      ),
      child: Padding(
        padding: _menuPadding,
        child: _MenuRows(
          items: items,
          rowHeight: minButtonTargetOn(Theme.of(context).platform),
        ),
      ),
    );
  }
}

class _MenuRows extends StatelessWidget {
  const _MenuRows({required this.items, required this.rowHeight});

  final List<LogMenuItem> items;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (final LogMenuItem item in items)
          _MenuRow(item: item, height: rowHeight),
      ],
    );
  }
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.height});

  final LogMenuItem item;
  final double height;

  Widget _glyph(Color color) => switch (item.glyph) {
    LogMenuGlyph.title => _StrokeGlyphIcon(
      glyph: _StrokeGlyph.title,
      color: color,
      size: _menuRowGlyph,
    ),
    LogMenuGlyph.edit => IconStickerGlyphIcon(
      glyph: IconStickerGlyph.edit,
      color: color,
      size: _menuRowGlyph,
    ),
    LogMenuGlyph.trash => IconStickerGlyphIcon(
      glyph: IconStickerGlyph.trash,
      color: color,
      size: _menuRowGlyph,
    ),
  };

  Color? _hoverFill(BuildContext context, bool hovered) {
    if (!hovered) {
      return null;
    }
    return item.danger
        ? context.colors.dangerSurface
        : HoverStyle.of(context, FocusRingSurface.light, HoverShape.rounded);
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Pressable(
      key: item.key,
      label: item.label,
      onPressed: () => Navigator.of(context).pop(item),
      borderRadius: _menuRowRadius,
      placement: FocusRingPlacement.edge,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => DecoratedBox(
        decoration: HoverStyle.decoration(
          color: _hoverFill(context, hovered),
          shape: HoverShape.rounded,
          borderRadius: _menuRowRadius,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: height),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: _menuRowInset),
            child: Row(
              children: <Widget>[
                _glyph(item.danger ? colors.dangerInk : colors.inkSoft),
                const SizedBox(width: _menuRowGlyphGap),
                Expanded(
                  child: Text(
                    item.label,
                    style: TextStyle(
                      fontFamily: TypographyTokens.sans,
                      fontSize: _menuLabelSize,
                      fontWeight: FontWeight.w600,
                      color: item.danger ? colors.dangerInk : colors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
