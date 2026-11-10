import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show kTouchSlop;
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
import 'package:field_notes/design/interaction/hover_fill.dart';
import 'package:field_notes/design/interaction/min_target.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/design/widgets/phone_sheet.dart';
import 'package:field_notes/design/widgets/sticker_button.dart';
import 'package:field_notes/domain/mood/mood.dart';
import 'package:field_notes/features/entry_cards/cards/video_body.dart'
    show VideoDownloadRing;
import 'package:field_notes/features/entry_cards/cards/video_controls_overlay.dart'
    show canAutoHideVideoControls;
import 'package:field_notes/features/entry_cards/cards/voice_body.dart'
    show PlayPauseGlyph;
import 'package:field_notes/features/entry_cards/compact/log_actions_pill.dart'
    show logActionsDeleteKey;
import 'package:field_notes/features/entry_cards/transport/transport.dart'
    show TransportActivityNotification;
import 'package:field_notes/features/log_viewer/log_viewer.dart'
    show LogViewerExit;
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart'
    show
        logViewerBackKey,
        logViewerCloseLabel,
        logViewerDeleteLabel,
        logViewerEarlierKey,
        logViewerEarlierLabel,
        logViewerLaterKey,
        logViewerLaterLabel;
import 'package:field_notes/features/log_viewer/log_viewer_scene.dart';
import 'package:field_notes/features/note_engine/note_engine.dart'
    show isTextInputFocused;

const double viewerDockLift = 18;

const Duration viewerControlsIdle = Duration(seconds: 3);

const String viewerTitleLabel = 'Title';
const String viewerTitleHint = 'Add a title';
const String viewerRenameLabel = 'Rename';
const String viewerSaveTitleLabel = 'Save';
const String viewerDeleteLogLabel = 'Delete log';

const Key viewerTitleFieldKey = ValueKey<String>('viewer-title-field');
const Key viewerRenameRowKey = ValueKey<String>('viewer-rename-row');
const Key viewerSaveTitleKey = ValueKey<String>('viewer-save-title');

const String _playLabel = 'Play';
const String _pauseLabel = 'Pause';

const double _swipeReach = 56;
const double _swipeDrift = 60;

const double _glowAlpha = 0.18;
const double _glowRadius = 0.7;

const double _tapTarget = 48;
const double _disabledOpacity = 0.5;
const double _primaryGlyphShare = 0.32;
const double _primaryRingShare = 0.6;

const double _quietFlowerSize = 16;
const double _quietFlowerGap = 8;

const double _dockSideInset = 16;
const double _dockLabelGap = 6;
const double _dockAboveGap = 8;

const double _topBarTop = 16;
const double _topBarSide = 18;
const double _topBarCentreShare = 0.5;
const double _topBarGap = 12;
const double _exitPillHeight = 34;
const double _exitPillLabelPadding = 4;
const double _exitGlyphSize = 14;
const double _exitGap = 7;
const EdgeInsets _exitPillPadding = EdgeInsets.fromLTRB(12, 0, 15, 0);
const BorderRadius _exitPillRadius = BorderRadius.all(
  Radius.circular(_exitPillHeight / 2),
);
const double _deleteFace = 40;
const double _deleteGlyphSize = 15;
const double _deleteHoverAlpha = 0.45;
const EdgeInsets _deletePlatePadding = EdgeInsets.symmetric(horizontal: 4);
const BorderRadius _deletePlateRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusMd),
);

const double _capsuleRound = 999;
const BorderRadius _capsuleRadius = BorderRadius.all(
  Radius.circular(_capsuleRound),
);
const EdgeInsets _capsulePadding = EdgeInsets.all(7);
const EdgeInsets _labelScrimPadding = EdgeInsets.symmetric(
  horizontal: 8,
  vertical: 4,
);

const double _shadeHeight = 140;
const double _shadeAlpha = 0.7;

const Alignment _stageCentre = Alignment(0, -0.2);
const double _stageRadius = 1.2;
const double _stageEdgeShare = 0.4;

const Duration _doubleTapWindow = Duration(milliseconds: 300);

const String _escapeShortcut = 'Esc';
const String _earlierShortcut = 'Page Up';
const String _laterShortcut = 'Page Down';

const double _edgeArrowSize = 48;
const double _edgeArrowGlyph = 24;
const double _edgeArrowInset = 16;
const double _edgeArrowCompactInset = 4;
const double _edgeArrowBorder = 1.5;
const double _edgeRestDark = 0.66;
const double _edgeHoverDark = 0.92;
const double _edgeRestLight = 0.9;
const double _edgeLineDark = 0.32;
const double _edgeLineLight = 0.55;
const BorderRadius _edgeArrowRadius = BorderRadius.all(
  Radius.circular(_edgeArrowSize / 2),
);

const double _logBarTop = 12;
const double _logBarSide = 16;
const double _logBarFadeBelow = 40;
const double _logBarGap = 8;
const double _dockBackingHeight = 200;
const double _dockBackingFadeStop = 0.35;
const double _logBarGlyph = 18;
const double _logBarTitleSize = 19;
const double _logBarTitleLine = 1.3;
const double _logBarTitleMaxWidth = 520;
const double _logBarTitleRule = 1.5;
const double _logBarTitleGap = 1;
const double _logBarStampSize = 15;
const double _logBarStampLine = 1.1;
const double _logBarFlower = 14;
const double _logBarFlowerGap = 6;
const EdgeInsets _logBarCountPadding = EdgeInsets.symmetric(horizontal: 8);
const EdgeInsets _logBarTitlePadding = EdgeInsets.symmetric(vertical: 2);
const BorderRadius _logBarButtonRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusMd),
);

const double _sheetRowHeight = 52;
const double _sheetGlyph = 18;
const double _sheetRowGap = 12;
const double _sheetRowSeam = 1;
const double _sheetTitleSize = 19;
const EdgeInsets _sheetRowPadding = EdgeInsets.symmetric(horizontal: 18);
const EdgeInsets _sheetFieldPadding = EdgeInsets.fromLTRB(18, 4, 18, 12);
const EdgeInsets _sheetBottomPadding = EdgeInsets.only(bottom: 8);

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
    final SystemUiOverlayStyle bars = switch (ground) {
      ViewerGround.voice => systemBarsOverColor(context.colors.viewerStage),
      ViewerGround.media => darkBackdropSystemBars,
    };
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
      value: bars,
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
      ViewerGround.voice => DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: _stageCentre,
            radius: _stageRadius,
            colors: <Color>[
              context.colors.viewerStage,
              Color.lerp(
                context.colors.viewerStage,
                context.colors.viewerStageEdge,
                _stageEdgeShare,
              )!,
            ],
          ),
        ),
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
  const NoSwipe({
    super.key,
    required this.child,
    this.behavior = HitTestBehavior.translucent,
    this.onPointerDown,
  });

  final Widget child;
  final HitTestBehavior behavior;
  final ValueChanged<int>? onPointerDown;

  @override
  Widget build(BuildContext context) {
    final ValueChanged<int>? claim = context
        .dependOnInheritedWidgetOfExactType<_SwipeClaim>()
        ?.claim;
    return Listener(
      behavior: behavior,
      onPointerDown: (PointerDownEvent event) {
        claim?.call(event.pointer);
        onPointerDown?.call(event.pointer);
      },
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
    this.onPageUp,
    this.onPageDown,
    this.autofocus = true,
  });

  final Widget child;
  final VoidCallback? onSpace;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final VoidCallback? onEscape;
  final VoidCallback? onPageUp;
  final VoidCallback? onPageDown;
  final bool autofocus;

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
    if (key == LogicalKeyboardKey.pageUp) {
      return widget.onPageUp;
    }
    if (key == LogicalKeyboardKey.pageDown) {
      return widget.onPageDown;
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
      autofocus: widget.autofocus,
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
    return ViewerLabelScrim(
      child: Row(
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
              textAlign: TextAlign.center,
              style: context.textStyles.captionSans.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class ViewerLabelScrim extends StatelessWidget {
  const ViewerLabelScrim({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Palette.mediaScrim,
        borderRadius: _capsuleRadius,
      ),
      child: Padding(padding: _labelScrimPadding, child: child),
    );
  }
}

class ViewerPrimaryButton extends StatelessWidget {
  const ViewerPrimaryButton({
    super.key,
    required this.playing,
    required this.diameter,
    required this.onPressed,
    this.download,
  });

  final bool playing;
  final double diameter;
  final VoidCallback? onPressed;
  final double? download;

  @override
  Widget build(BuildContext context) {
    final double? download = this.download;
    final VoidCallback? onPressed = download == null ? this.onPressed : null;
    final bool enabled = onPressed != null;
    final BorderRadius round = BorderRadius.circular(diameter / 2);
    return Pressable(
      label: playing ? _pauseLabel : _playLabel,
      onPressed: onPressed,
      surface: FocusRingSurface.dark,
      borderRadius: round,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => SizedBox.square(
        dimension: math.max(_tapTarget, diameter),
        child: Center(
          child: download == null
              ? _face(context, hovered: hovered, enabled: enabled, round: round)
              : _downloadFace(download),
        ),
      ),
    );
  }

  Widget _downloadFace(double download) {
    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        color: Palette.mediaVeil,
        shape: BoxShape.circle,
      ),
      child: VideoDownloadRing(
        fraction: download,
        size: diameter * _primaryRingShare,
      ),
    );
  }

  Widget _face(
    BuildContext context, {
    required bool hovered,
    required bool enabled,
    required BorderRadius round,
  }) {
    return Opacity(
      opacity: enabled ? 1 : _disabledOpacity,
      child: HoverFill(
        hovered: hovered,
        surface: FocusRingSurface.dark,
        borderRadius: round,
        child: Container(
          width: diameter,
          height: diameter,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Palette.coral,
            shape: BoxShape.circle,
            border: context.shadows.outline,
          ),
          child: PlayPauseGlyph(
            playing: playing,
            color: Palette.onAccent,
            size: diameter * _primaryGlyphShare,
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
  const ViewerDock({super.key, required this.slots, this.above});

  final List<ViewerDockSlot?> slots;
  final Widget? above;

  @override
  State<ViewerDock> createState() => _ViewerDockState();
}

class _ViewerDockState extends State<ViewerDock> {
  final BackdropKey _glassGroup = BackdropKey();

  @override
  Widget build(BuildContext context) {
    final double gestureBar = phoneGestureBarInset(MediaQuery.of(context));
    final Widget? above = widget.above;
    final Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        for (final ViewerDockSlot? slot in widget.slots)
          Expanded(
            child: slot == null
                ? const SizedBox.shrink()
                : _DockColumn(key: slot.key, slot: slot),
          ),
      ],
    );
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
          child: above == null
              ? row
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    above,
                    const SizedBox(height: _dockAboveGap),
                    row,
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
          child: ViewerLabelScrim(
            child: Text(
              slot.label,
              textAlign: TextAlign.center,
              style: context.textStyles.caption11Sans.copyWith(
                color: Palette.mediaInk,
              ),
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
    required this.centre,
    this.exitLabel,
    this.onExit,
    this.onDelete,
    this.exitKey,
    this.deleteKey,
  });

  final String? exitLabel;
  final VoidCallback? onExit;
  final Widget centre;
  final VoidCallback? onDelete;
  final Key? exitKey;
  final Key? deleteKey;

  @override
  Widget build(BuildContext context) {
    final String? exitLabel = this.exitLabel;
    final VoidCallback? onExit = this.onExit;
    final VoidCallback? onDelete = this.onDelete;
    final bool sidebar = _isSidebar(context);
    final double statusBar = sidebar ? 0 : MediaQuery.paddingOf(context).top;
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          _topBarSide,
          statusBar + _topBarTop,
          _topBarSide,
          0,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: _tapTarget),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final Widget? delete = onDelete == null
                  ? null
                  : sidebar
                  ? _HoverDelete(key: deleteKey, onPressed: onDelete)
                  : ViewerDangerDelete(key: deleteKey, onPressed: onDelete);
              if (exitLabel == null || onExit == null) {
                return Row(
                  children: <Widget>[
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        heightFactor: 1,
                        child: centre,
                      ),
                    ),
                    if (delete != null) ...<Widget>[
                      const SizedBox(width: _topBarGap),
                      delete,
                    ],
                  ],
                );
              }
              return Row(
                children: <Widget>[
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      heightFactor: 1,
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
                      heightFactor: 1,
                      child: delete,
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

class ViewerDangerDelete extends StatelessWidget {
  const ViewerDangerDelete({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const StickerButtonVariant variant = StickerButtonVariant.danger;
    const StickerGround ground = StickerGround.media;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Palette.mediaScrim,
        borderRadius: _deletePlateRadius,
      ),
      child: Padding(
        padding: _deletePlatePadding,
        child: StickerButton(
          label: logViewerDeleteLabel,
          onPressed: onPressed,
          variant: variant,
          ground: ground,
          focusSurface: FocusRingSurface.dark,
          padTapTarget: true,
          icon: IconStickerGlyphIcon(
            glyph: IconStickerGlyph.trash,
            color: variant.inkOn(ground, context.colors),
            size: _deleteGlyphSize,
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
    return Pressable(
      label: label,
      onPressed: onPressed,
      surface: FocusRingSurface.dark,
      borderRadius: _exitPillRadius,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => ConstrainedBox(
        constraints: const BoxConstraints(
          minWidth: _tapTarget,
          minHeight: _tapTarget,
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: HoverFill(
            hovered: hovered,
            surface: FocusRingSurface.dark,
            borderRadius: _exitPillRadius,
            child: GlassSurface(
              tone: GlassTone.media,
              tint: Palette.mediaScrim,
              borderRadius: _exitPillRadius,
              padding: _exitPillPadding,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: _exitPillHeight),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    glyph,
                    const SizedBox(width: _exitGap),
                    Flexible(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: _exitPillLabelPadding,
                        ),
                        child: Text(
                          label,
                          style: context.textStyles.labelSans.copyWith(
                            color: Palette.mediaInk,
                          ),
                        ),
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
      cursor: SystemMouseCursors.click,
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
      tint: Palette.mediaScrim,
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

class ViewerControlsFade extends StatefulWidget {
  const ViewerControlsFade({
    super.key,
    required this.ready,
    required this.playing,
    required this.child,
  });

  final bool ready;
  final bool playing;
  final Widget child;

  @override
  State<ViewerControlsFade> createState() => _ViewerControlsFadeState();
}

class _ViewerControlsFadeState extends State<ViewerControlsFade> {
  final FocusNode _within = FocusNode(
    debugLabel: 'viewer controls',
    canRequestFocus: false,
    skipTraversal: true,
  );
  Timer? _idle;
  Timer? _pictureTap;
  bool _hidden = false;
  bool _accessibleNavigation = false;
  bool _shownAtDown = true;
  Set<int> _pressed = const <int>{};
  int? _controlPointer;
  _Stroke? _stroke;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_onFocusMoved);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _accessibleNavigation =
        MediaQuery.maybeAccessibleNavigationOf(context) ?? false;
    _hidden = false;
    _restartIdle();
  }

  @override
  void didUpdateWidget(ViewerControlsFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.ready != widget.ready ||
        oldWidget.playing != widget.playing) {
      _hidden = false;
      _restartIdle();
    }
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_onFocusMoved);
    _within.dispose();
    _idle?.cancel();
    _pictureTap?.cancel();
    super.dispose();
  }

  void _onFocusMoved() {
    if (mounted && _within.hasFocus) {
      _wake();
    }
  }

  bool get _canHide => canAutoHideVideoControls(
    controlsEnabled: widget.ready,
    isPlaying: widget.playing,
    focusWithin: false,
    accessibleNavigation: _accessibleNavigation,
  );

  bool get _focusOnControl {
    final FocusNode? focus = FocusManager.instance.primaryFocus;
    return focus != null && focus is! FocusScopeNode && !focus.skipTraversal;
  }

  bool get _touch => !_isSidebar(context);

  void _restartIdle() {
    _idle?.cancel();
    _idle = _canHide ? Timer(viewerControlsIdle, _onIdle) : null;
  }

  void _onIdle() {
    _idle = null;
    if (!mounted || !_canHide) {
      return;
    }
    if (_pressed.isNotEmpty || _focusOnControl) {
      _restartIdle();
      return;
    }
    setState(() => _hidden = true);
  }

  void _wake() {
    if (_hidden) {
      setState(() => _hidden = false);
    }
    _restartIdle();
  }

  bool _onTransportActivity(TransportActivityNotification notification) {
    _wake();
    return false;
  }

  void _onDown(PointerDownEvent event) {
    _shownAtDown = !_hidden;
    _pressed = <int>{..._pressed, event.pointer};
    _stroke = _Stroke(
      pointer: event.pointer,
      start: event.position,
      claimed: event.pointer == _controlPointer,
    );
    _controlPointer = null;
    _wake();
  }

  void _onUp(PointerUpEvent event) {
    _pressed = _pressed.difference(<int>{event.pointer});
    final _Stroke? stroke = _stroke;
    _stroke = null;
    final bool tapped =
        stroke != null &&
        stroke.pointer == event.pointer &&
        !stroke.claimed &&
        (event.position - stroke.start).distance < kTouchSlop;
    if (tapped && _touch) {
      _onPictureTap();
    }
  }

  void _onCancel(PointerCancelEvent event) {
    _pressed = _pressed.difference(<int>{event.pointer});
    if (_stroke?.pointer == event.pointer) {
      _stroke = null;
    }
  }

  void _onPictureTap() {
    final Timer? pending = _pictureTap;
    if (pending != null) {
      pending.cancel();
      _pictureTap = null;
      return;
    }
    final bool hide = _shownAtDown;
    _pictureTap = Timer(_doubleTapWindow, () {
      _pictureTap = null;
      if (mounted && hide && _canHide) {
        _idle?.cancel();
        _idle = null;
        setState(() => _hidden = true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool visible = !_canHide || !_hidden;
    final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return MouseRegion(
      opaque: false,
      onEnter: (PointerEnterEvent _) => _wake(),
      onHover: (PointerHoverEvent _) => _wake(),
      onExit: (PointerExitEvent _) => _wake(),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onDown,
        onPointerMove: (PointerMoveEvent _) => _wake(),
        onPointerUp: _onUp,
        onPointerCancel: _onCancel,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: still ? Duration.zero : Motion.fade,
          curve: Motion.fadeCurve,
          child: IgnorePointer(
            ignoring: !visible,
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: systemBarsOverColor(context.colors.viewerStage),
              child: NotificationListener<TransportActivityNotification>(
                onNotification: _onTransportActivity,
                child: NoSwipe(
                  behavior: HitTestBehavior.deferToChild,
                  onPointerDown: (int pointer) => _controlPointer = pointer,
                  child: Focus(
                    focusNode: _within,
                    includeSemantics: false,
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

class ViewerDockBacking extends StatelessWidget {
  const ViewerDockBacking({super.key});

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: _dockBackingHeight,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[colors.viewerFadeStart, colors.viewerFadeEnd],
                stops: const <double>[0, _dockBackingFadeStop],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ViewerEdgeArrows extends StatelessWidget {
  const ViewerEdgeArrows({
    super.key,
    required this.onPrevious,
    required this.onNext,
  });

  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final double inset = _isSidebar(context)
        ? _edgeArrowInset
        : _edgeArrowCompactInset;
    final VoidCallback? previous = onPrevious;
    final VoidCallback? next = onNext;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        if (previous != null)
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: inset),
              child: NoSwipe(
                child: _EdgeArrow(
                  key: logViewerEarlierKey,
                  pointsBack: true,
                  label: logViewerEarlierLabel,
                  shortcut: _earlierShortcut,
                  onPressed: previous,
                ),
              ),
            ),
          ),
        if (next != null)
          Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: EdgeInsets.only(right: inset),
              child: NoSwipe(
                child: _EdgeArrow(
                  key: logViewerLaterKey,
                  pointsBack: false,
                  label: logViewerLaterLabel,
                  shortcut: _laterShortcut,
                  onPressed: next,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

@immutable
final class _EdgeArrowColors {
  const _EdgeArrowColors({
    required this.rest,
    required this.hover,
    required this.line,
  });

  factory _EdgeArrowColors.of(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return switch (Theme.of(context).brightness) {
      Brightness.dark => _EdgeArrowColors(
        rest: colors.viewerFadeEnd.withValues(alpha: _edgeRestDark),
        hover: colors.viewerFadeEnd.withValues(alpha: _edgeHoverDark),
        line: colors.ink.withValues(alpha: _edgeLineDark),
      ),
      Brightness.light => _EdgeArrowColors(
        rest: colors.cardBright.withValues(alpha: _edgeRestLight),
        hover: colors.cardLight,
        line: colors.ink.withValues(alpha: _edgeLineLight),
      ),
    };
  }

  final Color rest;
  final Color hover;
  final Color line;
}

class _EdgeArrow extends StatelessWidget {
  const _EdgeArrow({
    super.key,
    required this.pointsBack,
    required this.label,
    required this.shortcut,
    required this.onPressed,
  });

  final bool pointsBack;
  final String label;
  final String shortcut;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final _EdgeArrowColors edge = _EdgeArrowColors.of(context);
    return Pressable(
      label: label,
      tooltip: '$label ($shortcut)',
      iconOnly: true,
      onPressed: onPressed,
      borderRadius: _edgeArrowRadius,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => Container(
        width: _edgeArrowSize,
        height: _edgeArrowSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: hovered ? edge.hover : edge.rest,
          shape: BoxShape.circle,
          border: Border.all(color: edge.line, width: _edgeArrowBorder),
        ),
        child: ChevronGlyph(
          pointsBack: pointsBack,
          color: context.colors.ink,
          size: _edgeArrowGlyph,
        ),
      ),
    );
  }
}

String? _titleOrNull(String? raw) {
  final String title = raw?.trim() ?? '';
  return title.isEmpty ? null : title;
}

TextStyle _titleStyle(BuildContext context) => context.textStyles.headlineSerif
    .copyWith(fontSize: _logBarTitleSize, height: _logBarTitleLine);

class ViewerLogBar extends StatelessWidget {
  const ViewerLogBar({super.key, required this.scene, this.fades = false});

  final LogViewerScene scene;
  final bool fades;

  BoxDecoration _fade(FieldNotesColors colors) {
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: <Color>[colors.viewerFadeEnd, colors.viewerFadeStart],
      ),
    );
  }

  Widget _exitGlyph(Color color) {
    return switch (scene.exit) {
      LogViewerExit.back => ChevronGlyph(
        pointsBack: true,
        color: color,
        size: _logBarGlyph,
      ),
      LogViewerExit.close => IconStickerGlyphIcon(
        glyph: IconStickerGlyph.close,
        color: color,
        size: _logBarGlyph,
      ),
    };
  }

  Widget _trashGlyph(Color color) => IconStickerGlyphIcon(
    glyph: IconStickerGlyph.trash,
    color: color,
    size: _logBarGlyph,
  );

  Widget _count(BuildContext context, String position, Color ink) {
    return Padding(
      padding: _logBarCountPadding,
      child: Text(
        position,
        maxLines: 1,
        softWrap: false,
        style: context.textStyles.captionSans.copyWith(
          color: ink,
          fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool sidebar = _isSidebar(context);
    final String? position = scene.position;
    final FieldNotesColors colors = context.colors;
    final Color softInk = fades ? colors.inkSoft : colors.ink;
    final double statusBar = sidebar ? 0 : MediaQuery.paddingOf(context).top;
    final Widget row = Padding(
      padding: EdgeInsets.fromLTRB(
        _logBarSide,
        statusBar + _logBarTop,
        _logBarSide,
        fades ? 0 : _logBarTop,
      ),
      child: Row(
        children: <Widget>[
          if (sidebar) ...<Widget>[
            _LogBarButton(
              key: logViewerBackKey,
              label: scene.exitLabel,
              tooltip: '${scene.exitLabel} ($_escapeShortcut)',
              glyph: _exitGlyph,
              onPressed: scene.onBack,
            ),
            const SizedBox(width: _logBarGap),
          ],
          Expanded(
            child: _LogBarHeading(
              scene: scene,
              editable: sidebar,
              softInk: softInk,
            ),
          ),
          if (position != null) _count(context, position, softInk),
          if (sidebar)
            _LogBarButton(
              key: logActionsDeleteKey,
              label: logViewerDeleteLabel,
              tooltip: logViewerDeleteLabel,
              glyph: _trashGlyph,
              hoverColor: colors.dangerInk,
              onPressed: scene.onDelete,
            ),
        ],
      ),
    );
    return Align(
      alignment: Alignment.topCenter,
      child: fades
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                ColoredBox(color: colors.viewerFadeEnd, child: row),
                IgnorePointer(
                  child: SizedBox(
                    height: _logBarFadeBelow,
                    child: DecoratedBox(decoration: _fade(colors)),
                  ),
                ),
              ],
            )
          : row,
    );
  }
}

class _LogBarButton extends StatelessWidget {
  const _LogBarButton({
    super.key,
    required this.label,
    required this.tooltip,
    required this.glyph,
    required this.onPressed,
    this.hoverColor,
  });

  final String label;
  final String tooltip;
  final Widget Function(Color color) glyph;
  final VoidCallback onPressed;
  final Color? hoverColor;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Pressable(
      label: label,
      tooltip: tooltip,
      iconOnly: true,
      onPressed: onPressed,
      borderRadius: _logBarButtonRadius,
      builder: (BuildContext context, bool hovered) => SizedBox.square(
        dimension: minIconTargetOn(Theme.of(context).platform),
        child: Center(
          child: glyph(hovered ? hoverColor ?? colors.ink : colors.inkSoft),
        ),
      ),
    );
  }
}

class _LogBarHeading extends StatelessWidget {
  const _LogBarHeading({
    required this.scene,
    required this.editable,
    required this.softInk,
  });

  final LogViewerScene scene;
  final bool editable;
  final Color softInk;

  Widget? _title(BuildContext context) {
    final String? title = _titleOrNull(scene.entry.title);
    final LogViewerRename? rename = scene.onRename;
    if (editable && rename != null) {
      return _ViewerTitleField(
        key: ValueKey<String>(scene.entry.id),
        title: title,
        onRename: rename,
        hintInk: softInk,
      );
    }
    if (title == null) {
      return null;
    }
    return Semantics(
      header: true,
      child: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: _titleStyle(context),
      ),
    );
  }

  Widget _stamp(BuildContext context) {
    final Mood? mood = scene.mood;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (mood != null) ...<Widget>[
          ExcludeSemantics(
            child: FlowerBloom.forMood(mood, size: _logBarFlower),
          ),
          const SizedBox(width: _logBarFlowerGap),
        ],
        Flexible(
          child: Text(
            scene.stamp(context),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.textStyles.stampAccent.copyWith(
              fontSize: _logBarStampSize,
              height: _logBarStampLine,
              color: softInk,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final Widget? title = _title(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (title != null) ...<Widget>[
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _logBarTitleMaxWidth),
            child: title,
          ),
          const SizedBox(height: _logBarTitleGap),
        ],
        _stamp(context),
      ],
    );
  }
}

class _ViewerTitleField extends StatefulWidget {
  const _ViewerTitleField({
    super.key,
    required this.title,
    required this.onRename,
    required this.hintInk,
  });

  final String? title;
  final LogViewerRename onRename;
  final Color hintInk;

  @override
  State<_ViewerTitleField> createState() => _ViewerTitleFieldState();
}

class _ViewerTitleFieldState extends State<_ViewerTitleField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.title ?? '',
  );
  late final FocusNode _focus = FocusNode(
    debugLabel: 'viewer title',
    onKeyEvent: _onKey,
  );
  late String? _saved = widget.title;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(_ViewerTitleField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title && !_focus.hasFocus) {
      _saved = widget.title;
      _controller.text = widget.title ?? '';
    }
  }

  @override
  void dispose() {
    _commit();
    _focus.removeListener(_onFocus);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _commit() {
    final String? typed = _titleOrNull(_controller.text);
    if (typed != _saved) {
      _saved = typed;
      unawaited(_save(typed));
    }
  }

  Future<void> _save(String? typed) async {
    final bool saved = await widget.onRename(typed);
    if (saved || !mounted || _saved != typed) {
      return;
    }
    _saved = widget.title;
    if (!_focus.hasFocus) {
      _controller.text = widget.title ?? '';
    }
  }

  void _onFocus() {
    if (!_focus.hasFocus) {
      _commit();
    }
  }

  void _finish() {
    _focus.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    _controller.text = _saved ?? '';
    _finish();
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final TextStyle style = _titleStyle(context);
    final double target = minTargetOn(Theme.of(context).platform);
    return Semantics(
      container: true,
      label: viewerTitleLabel,
      child: Material(
        type: MaterialType.transparency,
        child: TextField(
          key: viewerTitleFieldKey,
          controller: _controller,
          focusNode: _focus,
          maxLines: 1,
          style: style,
          cursorColor: colors.ink,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.sentences,
          onEditingComplete: _finish,
          onTapOutside: (PointerDownEvent _) {
            if (_focus.hasFocus) {
              _finish();
            }
          },
          decoration: InputDecoration(
            isDense: true,
            filled: false,
            hintText: viewerTitleHint,
            hintStyle: style.copyWith(color: widget.hintInk),
            contentPadding: _logBarTitlePadding,
            constraints: BoxConstraints(minHeight: target),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: colors.ink,
                width: _logBarTitleRule,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showViewerLogSheet(BuildContext context, LogViewerScene scene) {
  return showPhoneSheet<void>(
    context,
    builder: (BuildContext sheetContext) => _ViewerLogSheet(scene: scene),
  );
}

class _ViewerLogSheet extends StatefulWidget {
  const _ViewerLogSheet({required this.scene});

  final LogViewerScene scene;

  @override
  State<_ViewerLogSheet> createState() => _ViewerLogSheetState();
}

class _ViewerLogSheetState extends State<_ViewerLogSheet> {
  late final TextEditingController _title = TextEditingController(
    text: widget.scene.entry.title ?? '',
  );
  bool _renaming = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();

  void _save() {
    final String? typed = _titleOrNull(_title.text);
    final LogViewerRename? rename = widget.scene.onRename;
    if (rename != null && typed != _titleOrNull(widget.scene.entry.title)) {
      unawaited(rename(typed));
    }
    _close();
  }

  void _delete() {
    _close();
    widget.scene.onDelete();
  }

  Widget _field(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final TextStyle style = _titleStyle(context)
        .copyWith(fontSize: _sheetTitleSize);
    return Padding(
      padding: _sheetFieldPadding,
      child: Semantics(
        label: viewerTitleLabel,
        child: TextField(
          key: viewerTitleFieldKey,
          controller: _title,
          autofocus: true,
          maxLines: 1,
          style: style,
          cursorColor: colors.ink,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (String _) => _save(),
          decoration: InputDecoration(
            filled: false,
            hintText: viewerTitleHint,
            hintStyle: style.copyWith(color: colors.inkSoft),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: colors.inkSoft),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(
                color: colors.ink,
                width: _logBarTitleRule,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_renaming) {
      return PhoneSheet(
        title: viewerTitleLabel,
        actions: <Widget>[
          Expanded(
            child: StickerButton(
              key: viewerSaveTitleKey,
              label: viewerSaveTitleLabel,
              onPressed: _save,
            ),
          ),
        ],
        child: _field(context),
      );
    }
    final bool canRename = widget.scene.onRename != null;
    final bool titled = _titleOrNull(widget.scene.entry.title) != null;
    return PhoneSheet(
      child: Padding(
        padding: _sheetBottomPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (canRename) ...<Widget>[
              _SheetRow(
                key: viewerRenameRowKey,
                glyph: IconStickerGlyph.edit,
                label: titled ? viewerRenameLabel : viewerTitleHint,
                onPressed: () => setState(() => _renaming = true),
              ),
              Divider(
                height: _sheetRowSeam,
                thickness: _sheetRowSeam,
                color: context.colors.dashMuted,
              ),
            ],
            _SheetRow(
              key: logActionsDeleteKey,
              glyph: IconStickerGlyph.trash,
              label: viewerDeleteLogLabel,
              color: context.colors.dangerInk,
              onPressed: _delete,
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    super.key,
    required this.glyph,
    required this.label,
    required this.onPressed,
    this.color,
  });

  final IconStickerGlyph glyph;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final Color ink = color ?? context.colors.ink;
    return Pressable(
      label: label,
      onPressed: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _sheetRowHeight),
        child: Padding(
          padding: _sheetRowPadding,
          child: Row(
            children: <Widget>[
              IconStickerGlyphIcon(glyph: glyph, color: ink, size: _sheetGlyph),
              const SizedBox(width: _sheetRowGap),
              Expanded(
                child: Text(
                  label,
                  style: context.textStyles.labelSans.copyWith(color: ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
