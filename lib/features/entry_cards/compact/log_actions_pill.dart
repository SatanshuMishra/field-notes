import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../design/widgets/icon_sticker_button.dart';

const Key logActionsPillKey = ValueKey<String>('log-actions-pill');
const Key logActionsEditKey = ValueKey<String>('log-actions-edit');
const Key logActionsDeleteKey = ValueKey<String>('log-actions-delete');

const String logActionsEditLabel = 'Edit note';
const String logActionsDeleteLabel = 'Delete entry';

const double _pillPadding = 4;
const double _pillGap = 2;
const double _pillRise = 15;
const double _pillInset = 12;
const double _hiddenDrop = 4;
const double _glyphExtent = 14;
const double _focusRingWidth = 2;
const double _defaultButtonExtent = 28;
const double _tapTarget = 48;
const Duration _revealDuration = Duration(milliseconds: 140);

const BorderRadius _pillRadius = BorderRadius.all(Radius.circular(10));
const BorderRadius _buttonRadius = BorderRadius.all(Radius.circular(7));

EdgeInsets logActionsPillTapInset({
  double buttonExtent = _defaultButtonExtent,
  required bool withEdit,
  bool growDown = false,
}) => _PillGeometry(
  buttonExtent: buttonExtent,
  paired: withEdit,
  growDown: growDown,
).pillInset;

const CustomSemanticsAction _editAction = CustomSemanticsAction(
  label: logActionsEditLabel,
);
const CustomSemanticsAction _deleteAction = CustomSemanticsAction(
  label: logActionsDeleteLabel,
);

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
                  hoverColor: Palette.onAccent.withValues(alpha: 0.14),
                  extent: buttonExtent,
                  margin: geometry.leadingMargin,
                  onPressed: edit,
                ),
              _LogActionButton(
                key: logActionsDeleteKey,
                glyph: IconStickerGlyph.trash,
                label: logActionsDeleteLabel,
                hoverColor: Palette.danger.withValues(alpha: 0.6),
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
    required this.hoverColor,
    required this.extent,
    required this.margin,
    required this.onPressed,
  });

  final IconStickerGlyph glyph;
  final String label;
  final Color hoverColor;
  final double extent;
  final EdgeInsetsGeometry margin;
  final VoidCallback onPressed;

  @override
  State<_LogActionButton> createState() => _LogActionButtonState();
}

class _LogActionButtonState extends State<_LogActionButton> {
  bool _hovered = false;
  bool _focused = false;

  void _onHoverHighlight(bool hovered) {
    if (mounted && hovered != _hovered) {
      setState(() => _hovered = hovered);
    }
  }

  void _onFocusHighlight(bool focused) {
    if (mounted && focused != _focused) {
      setState(() => _focused = focused);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FocusableActionDetector(
      mouseCursor: SystemMouseCursors.click,
      onShowHoverHighlight: _onHoverHighlight,
      onShowFocusHighlight: _onFocusHighlight,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (ActivateIntent intent) {
            widget.onPressed();
            return null;
          },
        ),
      },
      child: Semantics(
        button: true,
        label: widget.label,
        onTap: widget.onPressed,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: widget.onPressed,
          child: ExcludeSemantics(
            child: Padding(
              padding: widget.margin,
              child: SizedBox.square(
                dimension: widget.extent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: _hovered || _focused ? widget.hoverColor : null,
                    border: _focused
                        ? const Border.fromBorderSide(
                            BorderSide(
                              color: Palette.toolbarLabel,
                              width: _focusRingWidth,
                            ),
                          )
                        : null,
                    borderRadius: _buttonRadius,
                  ),
                  child: Center(
                    child: IconStickerGlyphIcon(
                      glyph: widget.glyph,
                      color: Palette.onAccent,
                      size: _glyphExtent,
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

class LogActionsReveal extends StatefulWidget {
  const LogActionsReveal({
    super.key,
    required this.child,
    this.onEdit,
    required this.onDelete,
  });

  final Widget child;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;

  @override
  State<LogActionsReveal> createState() => _LogActionsRevealState();
}

class _LogActionsRevealState extends State<LogActionsReveal>
    with SingleTickerProviderStateMixin {
  static final ValueNotifier<_LogActionsRevealState?> _shown =
      ValueNotifier<_LogActionsRevealState?>(null);

  final LayerLink _link = LayerLink();
  final OverlayPortalController _portal = OverlayPortalController();
  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: _revealDuration,
  );
  late final Animation<double> _progress = CurvedAnimation(
    parent: _reveal,
    curve: Curves.ease,
  );

  ScrollPosition? _scroll;
  bool _cardHovered = false;
  bool _pillHovered = false;
  bool _focusInside = false;
  bool _pinned = false;
  bool _suppressed = false;

  bool get _visible =>
      !_suppressed && (_cardHovered || _pillHovered || _focusInside || _pinned);

  @override
  void initState() {
    super.initState();
    _shown.addListener(_onShownChanged);
    _portal.show();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ScrollPosition? scroll = Scrollable.maybeOf(context)?.position;
    if (scroll != _scroll) {
      _scroll?.removeListener(_onScrolled);
      _scroll = scroll;
      _scroll?.addListener(_onScrolled);
    }
  }

  @override
  void dispose() {
    _scroll?.removeListener(_onScrolled);
    _shown.removeListener(_onShownChanged);
    if (_shown.value == this) {
      _shown.value = null;
    }
    _reveal.dispose();
    super.dispose();
  }

  void _update(VoidCallback change) {
    if (!mounted) {
      return;
    }
    setState(change);
    if (_visible) {
      _shown.value = this;
      _reveal.forward();
    } else {
      if (_shown.value == this) {
        _shown.value = null;
      }
      _reveal.reverse();
    }
  }

  void _onShownChanged() {
    final _LogActionsRevealState? shown = _shown.value;
    if (shown != null && shown != this && _visible) {
      _update(_hide);
    }
  }

  void _onScrolled() {
    if (_pinned) {
      _update(() => _pinned = false);
    }
  }

  void _hide() {
    _pinned = false;
    _suppressed = true;
  }

  void _choose(VoidCallback action) {
    _update(_hide);
    action();
  }

  void _onCardHover(bool hovered) {
    _update(() {
      _cardHovered = hovered;
      if (hovered) {
        _suppressed = false;
      }
    });
  }

  void _onPillHover(bool hovered) {
    _update(() => _pillHovered = hovered);
  }

  void _onFocusChange(bool focused) {
    _update(() {
      _focusInside = focused;
      if (focused) {
        _suppressed = false;
      }
    });
  }

  void _onLongPress() {
    _update(() {
      _pinned = true;
      _suppressed = false;
    });
  }

  void _onTapOutside(PointerDownEvent event) {
    if (_pinned) {
      _update(() => _pinned = false);
    }
  }

  Map<CustomSemanticsAction, VoidCallback> _semanticActions() {
    final VoidCallback? edit = widget.onEdit;
    return <CustomSemanticsAction, VoidCallback>{
      if (edit != null) _editAction: () => _choose(edit),
      _deleteAction: () => _choose(widget.onDelete),
    };
  }

  Widget _buildPill(BuildContext context) {
    final VoidCallback? edit = widget.onEdit;
    final bool visible = _visible;
    final EdgeInsets inset = logActionsPillTapInset(
      withEdit: edit != null,
      growDown: true,
    );
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: Alignment.topRight,
        followerAnchor: Alignment.topRight,
        offset: Offset(inset.right - _pillInset, -inset.top - _pillRise),
        child: IgnorePointer(
          ignoring: !visible,
          child: TapRegion(
            groupId: this,
            child: MouseRegion(
              onEnter: (PointerEnterEvent event) => _onPillHover(true),
              onExit: (PointerExitEvent event) => _onPillHover(false),
              child: ExcludeFocus(
                excluding: !visible,
                child: ExcludeSemantics(
                  excluding: !visible,
                  child: AnimatedBuilder(
                    animation: _progress,
                    builder: (BuildContext context, Widget? child) {
                      return Opacity(
                        opacity: _progress.value,
                        child: Transform.translate(
                          offset: Offset(
                            0,
                            _hiddenDrop * (1 - _progress.value),
                          ),
                          child: child,
                        ),
                      );
                    },
                    child: LogActionsPill(
                      key: logActionsPillKey,
                      onEdit: edit == null ? null : () => _choose(edit),
                      onDelete: () => _choose(widget.onDelete),
                      growDown: true,
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

  @override
  Widget build(BuildContext context) {
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _buildPill,
      child: CompositedTransformTarget(
        link: _link,
        child: TapRegion(
          groupId: this,
          onTapOutside: _onTapOutside,
          child: MouseRegion(
            onEnter: (PointerEnterEvent event) => _onCardHover(true),
            onExit: (PointerExitEvent event) => _onCardHover(false),
            child: Focus(
              canRequestFocus: true,
              onFocusChange: _onFocusChange,
              child: Semantics(
                onLongPress: _onLongPress,
                customSemanticsActions: _semanticActions(),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onLongPress: _onLongPress,
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
