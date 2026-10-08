import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:field_notes/app/shell/bottom_bar_shell.dart'
    show phoneGestureBarInset;
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/app/shell/system_bars.dart';
import 'package:field_notes/app/shell/window_chrome.dart';
import 'package:field_notes/design/flowers/flower_bloom.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/icons/chevron_glyph.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/entry_cards/cards/voice_body.dart'
    show PlayPauseGlyph;
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart'
    show logViewerCloseLabel, logViewerDeleteLabel;
import 'package:field_notes/features/note_engine/note_engine.dart'
    show isTextInputFocused;

const double viewerDockLift = 18;

const String _playLabel = 'Play';
const String _pauseLabel = 'Pause';

const double _swipeReach = 56;
const double _swipeDrift = 60;

const double _glowAlpha = 0.18;
const double _glowRadius = 0.7;

const double _tapTarget = 48;
const double _disabledOpacity = 0.5;
const double _primaryGlyphShare = 0.32;

const double _quietFlowerSize = 16;
const double _quietFlowerGap = 8;

const double _dockSideInset = 16;
const double _dockLabelGap = 6;

const double _topBarTop = 16;
const double _topBarSide = 18;
const double _topBarCentreShare = 0.5;
const double _exitPillHeight = 34;
const double _exitGlyphSize = 14;
const double _exitGap = 7;
const EdgeInsets _exitPillPadding = EdgeInsets.fromLTRB(12, 0, 15, 0);
const BorderRadius _exitPillRadius = BorderRadius.all(
  Radius.circular(_exitPillHeight / 2),
);
const double _deleteFace = 40;
const double _deleteGlyphSize = 15;
const double _deleteHoverAlpha = 0.45;

const double _capsuleRound = 999;
const BorderRadius _capsuleRadius = BorderRadius.all(
  Radius.circular(_capsuleRound),
);
const EdgeInsets _capsulePadding = EdgeInsets.all(7);

const double _shadeHeight = 140;
const double _shadeAlpha = 0.7;

final BoxDecoration _voiceGlow = BoxDecoration(
  gradient: RadialGradient(
    radius: _glowRadius,
    colors: <Color>[
      Palette.coral.withValues(alpha: _glowAlpha),
      Palette.coral.withValues(alpha: 0),
    ],
  ),
);

enum ViewerGround { voice, media }

bool _isSidebar(BuildContext context) =>
    resolveShellLayout(Theme.of(context).platform) == ShellLayout.sidebar;

class ViewerStage extends StatelessWidget {
  const ViewerStage({
    super.key,
    required this.ground,
    required this.child,
    this.onSwipeNext,
    this.onSwipePrevious,
  });

  final ViewerGround ground;
  final Widget child;
  final VoidCallback? onSwipeNext;
  final VoidCallback? onSwipePrevious;

  @override
  Widget build(BuildContext context) {
    final Widget painted = _ViewerGroundPaint(ground: ground, child: child);
    if (_isSidebar(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const WindowDragBand(),
          Expanded(child: painted),
        ],
      );
    }
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: darkBackdropSystemBars,
      child: _ViewerSwipe(
        onNext: onSwipeNext,
        onPrevious: onSwipePrevious,
        child: painted,
      ),
    );
  }
}

class _ViewerGroundPaint extends StatelessWidget {
  const _ViewerGroundPaint({required this.ground, required this.child});

  final ViewerGround ground;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final Widget filled = SizedBox.expand(child: child);
    return switch (ground) {
      ViewerGround.voice => ColoredBox(
        color: Palette.mediaGround,
        child: DecoratedBox(decoration: _voiceGlow, child: filled),
      ),
      ViewerGround.media => ColoredBox(
        color: Palette.mediaBlack,
        child: filled,
      ),
    };
  }
}

@immutable
final class _Stroke {
  const _Stroke({
    required this.pointer,
    required this.start,
    required this.claimed,
  });

  final int pointer;
  final Offset start;
  final bool claimed;

  _Stroke claim() => _Stroke(pointer: pointer, start: start, claimed: true);
}

class _SwipeClaim extends InheritedWidget {
  const _SwipeClaim({required this.claim, required super.child});

  final ValueChanged<int> claim;

  @override
  bool updateShouldNotify(_SwipeClaim oldWidget) => claim != oldWidget.claim;
}

class _ViewerSwipe extends StatefulWidget {
  const _ViewerSwipe({
    required this.onNext,
    required this.onPrevious,
    required this.child,
  });

  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final Widget child;

  @override
  State<_ViewerSwipe> createState() => _ViewerSwipeState();
}

class _ViewerSwipeState extends State<_ViewerSwipe> {
  _Stroke? _stroke;
  int? _claimedPointer;

  void _claim(int pointer) {
    _claimedPointer = pointer;
  }

  void _onDown(PointerDownEvent event) {
    final bool claimed = _claimedPointer == event.pointer;
    _claimedPointer = null;
    final _Stroke? stroke = _stroke;
    if (stroke != null) {
      _stroke = stroke.claim();
      return;
    }
    _stroke = _Stroke(
      pointer: event.pointer,
      start: event.position,
      claimed: claimed,
    );
  }

  void _onUp(PointerUpEvent event) {
    final _Stroke? stroke = _stroke;
    if (stroke == null || stroke.pointer != event.pointer) {
      return;
    }
    _stroke = null;
    if (stroke.claimed) {
      return;
    }
    final Offset travel = event.position - stroke.start;
    if (travel.dy.abs() >= _swipeDrift) {
      return;
    }
    if (travel.dx < -_swipeReach) {
      widget.onNext?.call();
    } else if (travel.dx > _swipeReach) {
      widget.onPrevious?.call();
    }
  }

  void _onCancel(PointerCancelEvent event) {
    if (_stroke?.pointer == event.pointer) {
      _stroke = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SwipeClaim(
      claim: _claim,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onDown,
        onPointerUp: _onUp,
        onPointerCancel: _onCancel,
        child: widget.child,
      ),
    );
  }
}

class NoSwipe extends StatelessWidget {
  const NoSwipe({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ValueChanged<int>? claim = context
        .dependOnInheritedWidgetOfExactType<_SwipeClaim>()
        ?.claim;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: claim == null
          ? null
          : (PointerDownEvent event) => claim(event.pointer),
      child: child,
    );
  }
}

class ViewerKeys extends StatefulWidget {
  const ViewerKeys({
    super.key,
    required this.child,
    this.onSpace,
    this.onLeft,
    this.onRight,
    this.onEscape,
  });

  final Widget child;
  final VoidCallback? onSpace;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final VoidCallback? onEscape;

  @override
  State<ViewerKeys> createState() => _ViewerKeysState();
}

class _ViewerKeysState extends State<ViewerKeys> {
  final FocusNode _keys = FocusNode(debugLabel: 'viewer-keys');

  @override
  void dispose() {
    _keys.dispose();
    super.dispose();
  }

  VoidCallback? _actionFor(LogicalKeyboardKey key, {required bool repeat}) {
    if (key == LogicalKeyboardKey.arrowLeft) {
      return widget.onLeft;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      return widget.onRight;
    }
    if (repeat) {
      return null;
    }
    if (key == LogicalKeyboardKey.space) {
      return widget.onSpace;
    }
    if (key == LogicalKeyboardKey.escape) {
      return widget.onEscape;
    }
    return null;
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final bool topmost = ModalRoute.of(context)?.isCurrent ?? true;
    if (!topmost || isTextInputFocused()) {
      return KeyEventResult.ignored;
    }
    final VoidCallback? action = _actionFor(
      event.logicalKey,
      repeat: event is KeyRepeatEvent,
    );
    if (action == null) {
      return KeyEventResult.ignored;
    }
    action();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _keys,
      autofocus: true,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: widget.child,
    );
  }
}

class ViewerQuietLine extends StatelessWidget {
  const ViewerQuietLine({
    super.key,
    this.mood,
    required this.text,
    this.color = Palette.mediaInk,
  });

  final Mood? mood;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final Mood? mood = this.mood;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (mood != null) ...<Widget>[
          ExcludeSemantics(
            child: FlowerBloom.forMood(mood, size: _quietFlowerSize),
          ),
          const SizedBox(width: _quietFlowerGap),
        ],
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.captionSans.copyWith(color: color),
          ),
        ),
      ],
    );
  }
}

class ViewerPrimaryButton extends StatelessWidget {
  const ViewerPrimaryButton({
    super.key,
    required this.playing,
    required this.diameter,
    required this.onPressed,
  });

  final bool playing;
  final double diameter;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onPressed = this.onPressed;
    final bool enabled = onPressed != null;
    final BorderRadius round = BorderRadius.circular(diameter / 2);
    return Semantics(
      button: true,
      enabled: enabled,
      label: playing ? _pauseLabel : _playLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox.square(
          dimension: math.max(_tapTarget, diameter),
          child: Center(
            child: FocusRing(
              enabled: enabled,
              onPressed: onPressed,
              surface: FocusRingSurface.dark,
              borderRadius: round,
              child: Opacity(
                opacity: enabled ? 1 : _disabledOpacity,
                child: ExcludeSemantics(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Palette.coral,
                      shape: BoxShape.circle,
                      border: context.shadows.outline,
                    ),
                    child: SizedBox.square(
                      dimension: diameter,
                      child: Center(
                        child: PlayPauseGlyph(
                          playing: playing,
                          color: Palette.onAccent,
                          size: diameter * _primaryGlyphShare,
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

class ViewerGlassCircle extends StatelessWidget {
  const ViewerGlassCircle({
    super.key,
    required this.label,
    required this.glyph,
    required this.onPressed,
    this.face = _tapTarget,
    this.tint,
    this.grouped = false,
  });

  final String label;
  final Widget glyph;
  final VoidCallback? onPressed;
  final double face;
  final Color? tint;
  final bool grouped;

  @override
  Widget build(BuildContext context) {
    return GlassCircleButton(
      tone: GlassTone.media,
      face: face,
      label: label,
      glyph: glyph,
      onPressed: onPressed,
      tint: tint,
      grouped: grouped,
    );
  }
}

@immutable
final class ViewerDockSlot {
  const ViewerDockSlot({required this.label, required this.control, this.key});

  final String label;
  final Widget control;
  final Key? key;
}

class ViewerDock extends StatefulWidget {
  const ViewerDock({super.key, required this.slots});

  final List<ViewerDockSlot?> slots;

  @override
  State<ViewerDock> createState() => _ViewerDockState();
}

class _ViewerDockState extends State<ViewerDock> {
  final BackdropKey _glassGroup = BackdropKey();

  @override
  Widget build(BuildContext context) {
    final double gestureBar = phoneGestureBarInset(MediaQuery.of(context));
    return Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _dockSideInset,
          0,
          _dockSideInset,
          gestureBar + viewerDockLift,
        ),
        child: BackdropGroup(
          backdropKey: _glassGroup,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (final ViewerDockSlot? slot in widget.slots)
                Expanded(
                  child: slot == null
                      ? const SizedBox.shrink()
                      : _DockColumn(key: slot.key, slot: slot),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DockColumn extends StatelessWidget {
  const _DockColumn({super.key, required this.slot});

  final ViewerDockSlot slot;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        slot.control,
        const SizedBox(height: _dockLabelGap),
        ExcludeSemantics(
          child: Text(
            slot.label,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: context.textStyles.caption11Sans.copyWith(
              color: Palette.mediaInk,
            ),
          ),
        ),
      ],
    );
  }
}

class ViewerTopBar extends StatelessWidget {
  const ViewerTopBar({
    super.key,
    required this.exitLabel,
    required this.onExit,
    required this.centre,
    this.onDelete,
    this.exitKey,
    this.deleteKey,
  });

  final String exitLabel;
  final VoidCallback onExit;
  final Widget centre;
  final VoidCallback? onDelete;
  final Key? exitKey;
  final Key? deleteKey;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? onDelete = this.onDelete;
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _topBarSide,
          _topBarTop,
          _topBarSide,
          0,
        ),
        child: SizedBox(
          height: _tapTarget,
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return Row(
                children: <Widget>[
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _ExitPill(
                        key: exitKey,
                        label: exitLabel,
                        onPressed: onExit,
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: constraints.maxWidth * _topBarCentreShare,
                    ),
                    child: centre,
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: onDelete == null
                          ? null
                          : _HoverDelete(key: deleteKey, onPressed: onDelete),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ExitPill extends StatelessWidget {
  const _ExitPill({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final Widget glyph = label == logViewerCloseLabel
        ? const IconStickerGlyphIcon(
            glyph: IconStickerGlyph.close,
            color: Palette.mediaInk,
            size: _exitGlyphSize,
          )
        : const ChevronGlyph(
            pointsBack: true,
            color: Palette.mediaInk,
            size: _exitGlyphSize,
          );
    return Semantics(
      button: true,
      enabled: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: _tapTarget,
            minHeight: _tapTarget,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: FocusRing(
              onPressed: onPressed,
              surface: FocusRingSurface.dark,
              borderRadius: _exitPillRadius,
              child: ExcludeSemantics(
                child: GlassSurface(
                  tone: GlassTone.media,
                  borderRadius: _exitPillRadius,
                  padding: _exitPillPadding,
                  child: SizedBox(
                    height: _exitPillHeight,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        glyph,
                        const SizedBox(width: _exitGap),
                        Text(
                          label,
                          maxLines: 1,
                          style: context.textStyles.labelSans.copyWith(
                            color: Palette.mediaInk,
                          ),
                        ),
                      ],
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

class _HoverDelete extends StatefulWidget {
  const _HoverDelete({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  State<_HoverDelete> createState() => _HoverDeleteState();
}

class _HoverDeleteState extends State<_HoverDelete> {
  bool _hovered = false;

  void _hover(bool hovered) {
    if (hovered != _hovered) {
      setState(() => _hovered = hovered);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (PointerEnterEvent _) => _hover(true),
      onExit: (PointerExitEvent _) => _hover(false),
      child: ViewerGlassCircle(
        label: logViewerDeleteLabel,
        face: _deleteFace,
        tint: _hovered
            ? Palette.danger.withValues(alpha: _deleteHoverAlpha)
            : null,
        glyph: const IconStickerGlyphIcon(
          glyph: IconStickerGlyph.trash,
          color: Palette.mediaInk,
          size: _deleteGlyphSize,
        ),
        onPressed: widget.onPressed,
      ),
    );
  }
}

class ViewerCapsule extends StatelessWidget {
  const ViewerCapsule({super.key, required this.children, this.maxWidth});

  final List<Widget> children;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final double? maxWidth = this.maxWidth;
    final Widget capsule = GlassSurface(
      tone: GlassTone.media,
      borderRadius: _capsuleRadius,
      padding: _capsulePadding,
      child: Row(mainAxisSize: MainAxisSize.min, children: children),
    );
    if (maxWidth == null) {
      return capsule;
    }
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: capsule,
    );
  }
}

class ViewerOverlayShade extends StatelessWidget {
  const ViewerOverlayShade({super.key, required this.top});

  final bool top;

  @override
  Widget build(BuildContext context) {
    final Alignment edge = top ? Alignment.topCenter : Alignment.bottomCenter;
    final Alignment away = top ? Alignment.bottomCenter : Alignment.topCenter;
    return IgnorePointer(
      child: Align(
        alignment: edge,
        child: SizedBox(
          height: _shadeHeight,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: edge,
                end: away,
                colors: <Color>[
                  Palette.mediaBlack.withValues(alpha: _shadeAlpha),
                  Palette.mediaBlack.withValues(alpha: 0),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
