import 'dart:math' as math;

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
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

  Size get size => Size(
    rowPadding.horizontal +
        (paired ? leadingMargin.horizontal + buttonExtent : 0) +
        trailingMargin.horizontal +
        buttonExtent,
    rowPadding.vertical + _top + buttonExtent + _bottom,
  );
}

class _PillReach extends SingleChildRenderObjectWidget {
  const _PillReach({
    required this.reach,
    required this.semanticIndex,
    required super.child,
  });

  final Rect? reach;
  final int? semanticIndex;

  @override
  _RenderPillReach createRenderObject(BuildContext context) =>
      _RenderPillReach(reach, semanticIndex);

  @override
  void updateRenderObject(BuildContext context, _RenderPillReach renderObject) {
    renderObject
      ..reach = reach
      ..semanticIndex = semanticIndex;
  }
}

class _RenderPillReach extends RenderProxyBox {
  _RenderPillReach(this._reach, this._semanticIndex);

  Rect? _reach;
  int? _semanticIndex;

  set semanticIndex(int? value) {
    if (value == _semanticIndex) {
      return;
    }
    _semanticIndex = value;
    markNeedsSemanticsUpdate();
  }

  set reach(Rect? value) {
    if (value == _reach) {
      return;
    }
    _reach = value;
    markNeedsSemanticsUpdate();
    parent?.markNeedsSemanticsUpdate();
  }

  @override
  Rect get semanticBounds {
    final Rect card = Offset.zero & size;
    final Rect? reach = _reach;
    if (reach == null) {
      return card;
    }
    return card.expandToInclude(reach.shift(Offset(size.width, 0)));
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
    final int? index = _semanticIndex;
    if (index != null) {
      config.indexInParent = index;
    }
  }
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
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: _hovered || _focused ? widget.hoverColor : null,
                        borderRadius: _buttonRadius,
                      ),
                    ),
                    if (_focused) const _LogActionFocusRing(key: focusRingKey),
                    Center(
                      child: IconStickerGlyphIcon(
                        glyph: widget.glyph,
                        color: Palette.onAccent,
                        size: _glyphExtent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LogActionFocusRing extends StatelessWidget {
  const _LogActionFocusRing({super.key});

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        border: Border.fromBorderSide(
          BorderSide(color: Palette.toolbarLabel, width: _focusRingWidth),
        ),
        borderRadius: _buttonRadius,
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
    this.semanticIndex,
  });

  final Widget child;
  final VoidCallback? onEdit;
  final VoidCallback onDelete;
  final int? semanticIndex;

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
  Size? _window;
  bool _cardHovered = false;
  bool _awaitingMove = false;
  bool _pillHovered = false;
  bool _focusInside = false;
  bool _focusInPill = false;
  bool _pinned = false;
  bool _suppressed = false;
  bool _topInView = true;
  bool _viewCheckScheduled = false;

  bool get _wanted =>
      (_cardHovered && !_awaitingMove) ||
      _pillHovered ||
      _focusInside ||
      _focusInPill ||
      _pinned;

  bool get _visible => !_suppressed && _topInView && _wanted;

  bool get _pointerIsStill =>
      SchedulerBinding.instance.schedulerPhase ==
      SchedulerPhase.postFrameCallbacks;

  @override
  void initState() {
    super.initState();
    _shown.addListener(_onShownChanged);
    _reveal.addStatusListener(_onRevealStatus);
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
    final Size? window = MediaQuery.maybeSizeOf(context);
    if (window != _window) {
      _window = window;
      _scheduleViewCheck();
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
      if (!_portal.isShowing) {
        _portal.show();
      }
      _reveal.forward();
    } else {
      if (_shown.value == this) {
        _shown.value = null;
      }
      _reveal.reverse();
    }
  }

  void _onRevealStatus(AnimationStatus status) {
    if (status.isDismissed && !_visible && _portal.isShowing) {
      _pillHovered = false;
      _focusInPill = false;
      _portal.hide();
    }
  }

  void _onShownChanged() {
    final _LogActionsRevealState? shown = _shown.value;
    if (shown != null && shown != this && _visible) {
      _update(_hide);
    }
  }

  void _onScrolled() {
    _scheduleViewCheck();
    if (_pinned) {
      _update(() => _pinned = false);
    }
  }

  bool _cardTopInView() {
    final RenderObject? card = context.findRenderObject();
    final RenderObject? viewport = RenderAbstractViewport.maybeOf(card);
    if (card is! RenderBox ||
        viewport is! RenderBox ||
        !card.hasSize ||
        !viewport.hasSize) {
      return true;
    }
    final double top = card.localToGlobal(Offset.zero, ancestor: viewport).dy;
    return top >= -precisionErrorTolerance &&
        top <= viewport.size.height + precisionErrorTolerance;
  }

  void _scheduleViewCheck() {
    if (_viewCheckScheduled || !_wanted) {
      return;
    }
    _viewCheckScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      _viewCheckScheduled = false;
      _recheckView();
    });
  }

  void _recheckView() {
    if (!mounted) {
      return;
    }
    final bool inView = _cardTopInView();
    if (inView == _topInView) {
      return;
    }
    _update(() => _topInView = inView);
    if (!inView) {
      _reveal.value = 0;
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

  void _onCardEnter(PointerEnterEvent event) {
    final bool still = _pointerIsStill;
    _update(() {
      _cardHovered = true;
      _awaitingMove = still;
      _suppressed = false;
      _topInView = _cardTopInView();
    });
  }

  void _onCardMove(PointerHoverEvent event) {
    if (_awaitingMove) {
      _update(() {
        _awaitingMove = false;
        _topInView = _cardTopInView();
      });
    }
  }

  void _onCardExit(PointerExitEvent event) {
    _update(() {
      _cardHovered = false;
      _awaitingMove = false;
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
        _topInView = _cardTopInView();
      }
    });
  }

  void _onPillFocusChange(bool focused) {
    _update(() => _focusInPill = focused);
  }

  void _onLongPress() {
    _update(() {
      _pinned = true;
      _suppressed = false;
      _topInView = _cardTopInView();
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

  _PillGeometry get _geometry => _PillGeometry(
    buttonExtent: _defaultButtonExtent,
    paired: widget.onEdit != null,
    growDown: true,
  );

  Offset _pillCorner(_PillGeometry geometry) => Offset(
    geometry.pillInset.right - _pillInset,
    -geometry.pillInset.top - _pillRise,
  );

  Rect _pillReach() {
    final _PillGeometry geometry = _geometry;
    final Offset corner = _pillCorner(geometry);
    final Size size = geometry.size;
    return Rect.fromLTRB(
      corner.dx - size.width,
      corner.dy,
      corner.dx,
      corner.dy + size.height,
    );
  }

  Widget _buildPill(BuildContext context) {
    final VoidCallback? edit = widget.onEdit;
    final bool visible = _visible;
    return Align(
      alignment: AlignmentDirectional.topStart,
      child: CompositedTransformFollower(
        link: _link,
        showWhenUnlinked: false,
        targetAnchor: Alignment.topRight,
        followerAnchor: Alignment.topRight,
        offset: _pillCorner(_geometry),
        child: IgnorePointer(
          ignoring: !visible,
          child: TapRegion(
            groupId: this,
            child: MouseRegion(
              onEnter: (PointerEnterEvent event) => _onPillHover(true),
              onExit: (PointerExitEvent event) => _onPillHover(false),
              child: Focus(
                canRequestFocus: false,
                skipTraversal: true,
                includeSemantics: false,
                onFocusChange: _onPillFocusChange,
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PillReach(
      reach: _visible ? _pillReach() : null,
      semanticIndex: widget.semanticIndex,
      child: OverlayPortal(
        controller: _portal,
        overlayChildBuilder: _buildPill,
        child: CompositedTransformTarget(
          link: _link,
          child: TapRegion(
            groupId: this,
            onTapOutside: _onTapOutside,
            child: MouseRegion(
              onEnter: _onCardEnter,
              onHover: _onCardMove,
              onExit: _onCardExit,
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
      ),
    );
  }
}
