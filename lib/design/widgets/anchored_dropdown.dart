import 'dart:math' as math;

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/glass/glass_surface.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

const double anchoredDropdownGap = 4;

const double _menuRadius = 14;
const EdgeInsets _menuPadding = EdgeInsets.symmetric(vertical: 6);
const EdgeInsets _choicePadding = EdgeInsets.symmetric(
  horizontal: 12,
  vertical: 8,
);
const double _choiceMinHeight = 44;
const double _checkSize = 18;
const double _checkGap = 8;
const double _descriptionGap = 2;
const double _mutedAlpha = 0.68;
const double _highlightAlpha = 0.12;
const double _choiceRadius = 10;
const EdgeInsets _choiceInset = EdgeInsets.symmetric(horizontal: 6);
const double _screenMargin = 16;
const double _minimumMenuHeight = _choiceMinHeight * 2;

@immutable
class AnchoredDropdownChoice<T> {
  const AnchoredDropdownChoice({
    required this.value,
    required this.label,
    this.description,
    this.key,
  });

  final T value;
  final String label;
  final String? description;
  final Key? key;
}

typedef AnchoredDropdownAnchorBuilder = Widget Function(
  BuildContext context,
  bool open,
  VoidCallback toggle,
);

class AnchoredDropdown<T> extends StatefulWidget {
  const AnchoredDropdown({
    super.key,
    required this.choices,
    required this.current,
    required this.onSelected,
    required this.builder,
    this.tapRegionGroupId,
    this.onOpen,
    this.menuKey,
    this.tone = GlassTone.paper,
    this.ink,
    this.widensToFitChoices = false,
  });

  final List<AnchoredDropdownChoice<T>> choices;
  final T? current;
  final ValueChanged<T> onSelected;
  final AnchoredDropdownAnchorBuilder builder;
  final Object? tapRegionGroupId;
  final VoidCallback? onOpen;
  final Key? menuKey;
  final GlassTone tone;
  final Color? ink;
  final bool widensToFitChoices;

  @override
  State<AnchoredDropdown<T>> createState() => _AnchoredDropdownState<T>();
}

class _AnchoredDropdownState<T> extends State<AnchoredDropdown<T>> {
  final OverlayPortalController _portal = OverlayPortalController();
  final LayerLink _link = LayerLink();
  final Object _ownGroup = Object();
  final FocusNode _menuFocus = FocusNode(debugLabel: 'anchored dropdown');
  FocusNode? _returnFocus;
  int _highlighted = 0;
  bool _shown = false;

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKeyOutsideMenu);
    _menuFocus.dispose();
    super.dispose();
  }

  int _currentIndex() {
    final int index = widget.choices.indexWhere(
      (AnchoredDropdownChoice<T> choice) => choice.value == widget.current,
    );
    return math.max(0, index);
  }

  void _toggle() {
    if (_shown) {
      _close();
      return;
    }
    _open();
  }

  void _open() {
    _returnFocus = FocusManager.instance.primaryFocus;
    setState(() {
      _highlighted = _currentIndex();
      _shown = true;
      _portal.show();
    });
    HardwareKeyboard.instance.addHandler(_onKeyOutsideMenu);
    widget.onOpen?.call();
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (mounted && _shown) {
        _menuFocus.requestFocus();
      }
    });
  }

  void _close() {
    if (!_shown) {
      return;
    }
    HardwareKeyboard.instance.removeHandler(_onKeyOutsideMenu);
    setState(() {
      _shown = false;
      _portal.hide();
    });
    final FocusNode? previous = _returnFocus;
    _returnFocus = null;
    if (previous != null &&
        previous.context != null &&
        previous.canRequestFocus) {
      previous.requestFocus();
    }
  }

  void _pick(AnchoredDropdownChoice<T> choice) {
    _close();
    widget.onSelected(choice.value);
  }

  void _move(int step) {
    final int count = widget.choices.length;
    if (count == 0) {
      return;
    }
    setState(() => _highlighted = (_highlighted + step) % count);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      return KeyEventResult.ignored;
    }
    final LogicalKeyboardKey key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _close();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _move(1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _move(-1);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter ||
        key == LogicalKeyboardKey.space) {
      if (event is KeyDownEvent &&
          _highlighted >= 0 &&
          _highlighted < widget.choices.length) {
        _pick(widget.choices[_highlighted]);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      _close();
      return KeyEventResult.ignored;
    }
    return KeyEventResult.ignored;
  }

  bool _onKeyOutsideMenu(KeyEvent event) {
    if (!_shown || _menuFocus.hasFocus || event is KeyUpEvent) {
      return false;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _close();
      return true;
    }
    _menuFocus.requestFocus();
    return false;
  }

  Rect? _anchorRect() {
    final RenderObject? anchor = context.findRenderObject();
    if (anchor is! RenderBox || !anchor.hasSize || !anchor.attached) {
      return null;
    }
    return anchor.localToGlobal(Offset.zero) & anchor.size;
  }

  Widget _menu(BuildContext context) {
    final List<AnchoredDropdownChoice<T>> choices = widget.choices;
    if (choices.isEmpty) {
      return const SizedBox.shrink();
    }
    final Rect? anchor = _anchorRect();
    final double screen = MediaQuery.sizeOf(context).height;
    final double below = anchor == null
        ? screen
        : screen -
              anchor.bottom -
              anchoredDropdownGap -
              _screenMargin -
              MediaQuery.paddingOf(context).bottom;
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double roomAfterStartEdge = anchor == null
        ? screenWidth
        : screenWidth - anchor.left - _screenMargin;
    final double roomBeforeEndEdge = anchor == null
        ? screenWidth
        : anchor.right - _screenMargin;
    final bool growsRightward = widget.widensToFitChoices
        ? roomAfterStartEdge >= roomBeforeEndEdge
        : !rtl;
    final double widestMenu = math.max(
      0,
      growsRightward ? roomAfterStartEdge : roomBeforeEndEdge,
    );
    final Color ink = widget.ink ?? context.colors.ink;
    final FocusRingSurface surface = widget.tone == GlassTone.media
        ? FocusRingSurface.dark
        : FocusRingSurface.light;
    final Widget list = Material(
      type: MaterialType.transparency,
      child: ExcludeFocus(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int index = 0; index < choices.length; index++)
                _DropdownChoiceTile(
                  key: choices[index].key,
                  label: choices[index].label,
                  description: choices[index].description,
                  chosen: choices[index].value == widget.current,
                  highlighted: index == _highlighted,
                  ink: ink,
                  surface: surface,
                  onHover: () {
                    if (_highlighted != index) {
                      setState(() => _highlighted = index);
                    }
                  },
                  onTap: () => _pick(choices[index]),
                ),
            ],
          ),
        ),
      ),
    );
    final Widget menu = TapRegion(
      groupId: _ownGroup,
      onTapOutside: (PointerDownEvent event) => _close(),
      child: Focus(
        focusNode: _menuFocus,
        onKeyEvent: _onKey,
        child: SizedBox(
          key: widget.menuKey,
          width: widget.widensToFitChoices ? null : anchor?.width,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: widget.widensToFitChoices
                  ? math.min(anchor?.width ?? 0, widestMenu)
                  : 0,
              maxWidth: widget.widensToFitChoices
                  ? widestMenu
                  : double.infinity,
              maxHeight: math.max(_minimumMenuHeight, below),
            ),
            child: _fittedToChoices(
              GlassSurface(
                tone: widget.tone,
                borderRadius: BorderRadius.circular(_menuRadius),
                padding: _menuPadding,
                child: list,
              ),
            ),
          ),
        ),
      ),
    );
    final Object? outerGroup = widget.tapRegionGroupId;
    return Align(
      alignment: Alignment.topLeft,
      child: CompositedTransformFollower(
        link: _link,
        targetAnchor: growsRightward
            ? Alignment.bottomLeft
            : Alignment.bottomRight,
        followerAnchor: growsRightward ? Alignment.topLeft : Alignment.topRight,
        offset: const Offset(0, anchoredDropdownGap),
        child: outerGroup == null
            ? menu
            : TapRegion(groupId: outerGroup, child: menu),
      ),
    );
  }

  Widget _fittedToChoices(Widget menu) =>
      widget.widensToFitChoices ? IntrinsicWidth(child: menu) : menu;

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: _ownGroup,
      child: CompositedTransformTarget(
        link: _link,
        child: OverlayPortal(
          controller: _portal,
          overlayChildBuilder: _menu,
          child: widget.builder(context, _shown, _toggle),
        ),
      ),
    );
  }
}

class _DropdownChoiceTile extends StatelessWidget {
  const _DropdownChoiceTile({
    super.key,
    required this.label,
    required this.description,
    required this.chosen,
    required this.highlighted,
    required this.ink,
    required this.surface,
    required this.onHover,
    required this.onTap,
  });

  final String label;
  final String? description;
  final bool chosen;
  final bool highlighted;
  final Color ink;
  final FocusRingSurface surface;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String? description = this.description;
    final BorderRadius radius = BorderRadius.circular(_choiceRadius);
    return Padding(
      padding: _choiceInset,
      child: MouseRegion(
        onEnter: (PointerEnterEvent _) => onHover(),
        child: Pressable(
          inMutuallyExclusiveGroup: true,
          label: description == null ? label : '$label\n$description',
          selected: chosen,
          onPressed: onTap,
          borderRadius: radius,
          surface: surface,
          paintsHover: false,
          builder: (BuildContext context, bool _) => DecoratedBox(
            decoration: BoxDecoration(
              color: highlighted
                  ? ink.withValues(alpha: _highlightAlpha)
                  : Colors.transparent,
              borderRadius: radius,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _choiceMinHeight),
              child: Padding(
                padding: _choicePadding,
                child: Row(
                  children: <Widget>[
                    SizedBox.square(
                      dimension: _checkSize,
                      child: chosen
                          ? Icon(Icons.check, size: _checkSize, color: ink)
                          : null,
                    ),
                    const SizedBox(width: _checkGap),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            label,
                            style: context.textStyles.bodySans.copyWith(
                              color: ink,
                            ),
                          ),
                          if (description != null) ...<Widget>[
                            const SizedBox(height: _descriptionGap),
                            Text(
                              description,
                              style: context.textStyles.captionSans.copyWith(
                                color: ink.withValues(alpha: _mutedAlpha),
                              ),
                            ),
                          ],
                        ],
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
