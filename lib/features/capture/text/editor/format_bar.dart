import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, KeyRepeatEvent, KeyUpEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/icons/format_icons.dart';
import 'package:field_notes/design/interaction/min_target.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart'
    show ComposerStageInks;
import 'package:field_notes/features/note_engine/capabilities.dart'
    show tablesEnabled;
import 'package:field_notes/features/note_engine/commands/inline_format.dart'
    show InlineFormat, toggleInlineFormat;
import 'package:field_notes/features/note_engine/commands/line_format.dart'
    show NoteListKind, cycleHeading, toggleList, toggleQuote;
import 'package:field_notes/features/note_engine/commands/table_commands.dart'
    show insertTable;
import 'package:field_notes/features/note_engine/document/editor_state.dart'
    show EditorState;
import 'package:field_notes/features/note_engine/document/transaction.dart'
    show Transaction;
import 'package:field_notes/features/note_engine/note_engine.dart'
    show NoteEditorController;

import '../composer_footer.dart'
    show composerAddPhotoKey, composerAddPhotoLabel;

const Key formatBoldKey = ValueKey<String>('format-bold');
const Key formatItalicKey = ValueKey<String>('format-italic');
const Key formatHeadingKey = ValueKey<String>('format-heading');
const Key formatListKey = ValueKey<String>('format-list');
const Key formatQuoteKey = ValueKey<String>('format-quote');
const Key formatLinkKey = ValueKey<String>('format-link');
const Key formatUndoKey = ValueKey<String>('format-undo');
const Key formatRedoKey = ValueKey<String>('format-redo');
const Key formatNumberedKey = ValueKey<String>('format-numbered');
const Key formatTaskKey = ValueKey<String>('format-task');
const Key formatTableKey = ValueKey<String>('format-table');
const Key formatMoreKey = ValueKey<String>('format-more');
const Key formatStrikethroughKey = ValueKey<String>('format-strikethrough');
const Key formatHighlightKey = ValueKey<String>('format-highlight');
const Key formatCodeKey = ValueKey<String>('format-code');
const Key formatBarSeparatorKey = ValueKey<String>('format-bar-separator');

double formatBarHeightOn(TargetPlatform platform) => minIconTargetOn(platform);

const double _glyphExtent = 18;
const double _disabledOpacity = 0.35;
const double _separatorWidth = 1;
const double _separatorHeight = 18;
const double _separatorMargin = 6;
const double _separatorReach = _separatorWidth + 2 * _separatorMargin;
const int _fewestShownWhenCrowded = 3;
const double _menuGap = 6;
const double _menuPadding = 4;
const double _menuWidth = 190;
const double _menuItemMinHeight = 40;
const double _menuItemPadding = 10;
const double _menuItemGap = 10;
const double _menuLabelSize = 13;
const BorderRadius _focusRadius = BorderRadius.all(
  Radius.circular(Shapes.radius8),
);
const BorderRadius _menuRadius = BorderRadius.all(
  Radius.circular(Shapes.radius12),
);

typedef _Command = Transaction? Function(EditorState state);
typedef _IconBuilder = Widget Function(Color ink);

enum _BarGlyph {
  strike,
  highlight,
  code,
  numbered,
  task,
  table,
  photo,
  more,
  redo,
}

final class _BarItem {
  const _BarItem({
    required this.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.startsGroup = false,
  });

  final Key key;
  final String label;
  final _IconBuilder icon;
  final VoidCallback? onTap;
  final bool startsGroup;
}

final class _BarFit {
  const _BarFit({
    required this.shown,
    required this.tucked,
    required this.separated,
  });

  factory _BarFit.of(List<_BarItem> items, double extent, double width) {
    final double bare = items.length * extent;
    final int groups = items.where((_BarItem item) => item.startsGroup).length;
    if (bare + groups * _separatorReach <= width) {
      return _BarFit(shown: items, tucked: const <_BarItem>[], separated: true);
    }
    if (bare <= width) {
      return _BarFit(
        shown: items,
        tucked: const <_BarItem>[],
        separated: false,
      );
    }
    final int fits = ((width - extent) / extent).floor();
    final int count = math.min(
      math.max(_fewestShownWhenCrowded, fits),
      items.length - 1,
    );
    return _BarFit(
      shown: items.sublist(0, count),
      tucked: items.sublist(count),
      separated: false,
    );
  }

  final List<_BarItem> shown;
  final List<_BarItem> tucked;
  final bool separated;
}

class FormatBar extends StatelessWidget {
  const FormatBar({
    super.key,
    required this.controller,
    required this.undoController,
    this.tablesAvailable = tablesEnabled,
    this.editorFocusNode,
    this.onAddPhoto,
    this.addingPhoto,
  });

  final TextEditingController controller;
  final UndoHistoryController undoController;
  final bool tablesAvailable;
  final FocusNode? editorFocusNode;
  final VoidCallback? onAddPhoto;
  final ValueListenable<bool>? addingPhoto;

  @override
  Widget build(BuildContext context) {
    final double extent = formatBarHeightOn(Theme.of(context).platform);
    final ValueListenable<bool>? adding = addingPhoto;
    return TextFieldTapRegion(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return ListenableBuilder(
            listenable: Listenable.merge(<Listenable?>[undoController, adding]),
            builder: (BuildContext context, Widget? _) {
              return _row(
                context,
                extent,
                _BarFit.of(_items(), extent, constraints.maxWidth),
              );
            },
          );
        },
      ),
    );
  }

  Widget _row(BuildContext context, double extent, _BarFit fit) {
    final ComposerStageInks inks = ComposerStageInks.of(context);
    return SizedBox(
      height: extent,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          for (final _BarItem item in fit.shown) ...<Widget>[
            if (fit.separated && item.startsGroup) _separator(inks.line),
            _FormatButton(
              key: item.key,
              extent: extent,
              icon: item.icon(inks.chrome),
              label: item.label,
              onTap: item.onTap,
            ),
          ],
          if (fit.tucked.isNotEmpty)
            _MoreFormats(
              key: formatMoreKey,
              controller: controller,
              extent: extent,
              items: fit.tucked,
            ),
        ],
      ),
    );
  }

  Widget _separator(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: _separatorMargin),
      child: SizedBox(
        key: formatBarSeparatorKey,
        width: _separatorWidth,
        height: _separatorHeight,
        child: ColoredBox(color: color),
      ),
    );
  }

  List<_BarItem> _items() {
    final bool canUndo = undoController.value.canUndo;
    final bool canRedo = undoController.value.canRedo;
    final bool adding = addingPhoto?.value ?? false;
    final VoidCallback? addPhoto = onAddPhoto;
    return <_BarItem>[
      _format(
        formatBoldKey,
        'Bold',
        _formatGlyph(FormatGlyph.bold),
        _inline(InlineFormat.bold),
      ),
      _format(
        formatItalicKey,
        'Italic',
        _formatGlyph(FormatGlyph.italic),
        _inline(InlineFormat.italic),
      ),
      _format(
        formatHeadingKey,
        'Heading',
        _formatGlyph(FormatGlyph.heading),
        cycleHeading,
      ),
      _format(
        formatStrikethroughKey,
        'Strikethrough',
        _barGlyph(_BarGlyph.strike),
        _inline(InlineFormat.strikethrough),
      ),
      _format(
        formatHighlightKey,
        'Highlight',
        _barGlyph(_BarGlyph.highlight),
        _inline(InlineFormat.highlight),
      ),
      _format(
        formatCodeKey,
        'Inline code',
        _barGlyph(_BarGlyph.code),
        _inline(InlineFormat.code),
      ),
      _format(
        formatListKey,
        'Bullet list',
        _formatGlyph(FormatGlyph.list),
        (EditorState s) => toggleList(s, NoteListKind.bullet),
        startsGroup: true,
      ),
      _format(
        formatNumberedKey,
        'Numbered list',
        _barGlyph(_BarGlyph.numbered),
        (EditorState s) => toggleList(s, NoteListKind.numbered),
      ),
      _format(
        formatTaskKey,
        'Task list',
        _barGlyph(_BarGlyph.task),
        (EditorState s) => toggleList(s, NoteListKind.task),
      ),
      _format(
        formatQuoteKey,
        'Quote',
        _formatGlyph(FormatGlyph.quote),
        toggleQuote,
      ),
      _format(
        formatLinkKey,
        'Link',
        _formatGlyph(FormatGlyph.link),
        _inline(InlineFormat.link),
        startsGroup: true,
      ),
      if (tablesAvailable)
        _format(
          formatTableKey,
          'Table',
          _barGlyph(_BarGlyph.table),
          insertTable,
        ),
      if (addPhoto != null)
        _BarItem(
          key: composerAddPhotoKey,
          label: composerAddPhotoLabel,
          icon: _barGlyph(_BarGlyph.photo),
          onTap: adding ? null : addPhoto,
        ),
      _BarItem(
        key: formatUndoKey,
        label: 'Undo',
        icon: _formatGlyph(FormatGlyph.undo),
        onTap: canUndo ? undoController.undo : null,
        startsGroup: true,
      ),
      _BarItem(
        key: formatRedoKey,
        label: 'Redo',
        icon: _barGlyph(_BarGlyph.redo),
        onTap: canRedo ? undoController.redo : null,
      ),
    ];
  }

  _Command _inline(InlineFormat format) =>
      (EditorState s) => toggleInlineFormat(s, format);

  _IconBuilder _formatGlyph(FormatGlyph glyph) =>
      (Color ink) => FormatIcon(glyph: glyph, color: ink, size: _glyphExtent);

  _IconBuilder _barGlyph(_BarGlyph glyph) =>
      (Color ink) => _BarIcon(glyph: glyph, color: ink);

  _BarItem _format(
    Key key,
    String label,
    _IconBuilder icon,
    _Command command, {
    bool startsGroup = false,
  }) {
    final TextEditingController current = controller;
    return _BarItem(
      key: key,
      label: label,
      icon: icon,
      startsGroup: startsGroup,
      onTap: current is NoteEditorController
          ? () {
              current.applyCommand(command);
              editorFocusNode?.requestFocus();
            }
          : null,
    );
  }
}

class _FormatButton extends StatelessWidget {
  const _FormatButton({
    super.key,
    required this.extent,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final double extent;
  final Widget icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      label: label,
      onPressed: onTap,
      borderRadius: _focusRadius,
      placement: FocusRingPlacement.edge,
      iconOnly: true,
      child: SizedBox.square(
        dimension: extent,
        child: Center(
          child: Opacity(
            opacity: onTap != null ? 1 : _disabledOpacity,
            child: icon,
          ),
        ),
      ),
    );
  }
}

class _MoreFormats extends StatefulWidget {
  const _MoreFormats({
    super.key,
    required this.controller,
    required this.extent,
    required this.items,
  });

  final TextEditingController controller;
  final double extent;
  final List<_BarItem> items;

  bool get hasAction => items.any((_BarItem item) => item.onTap != null);

  @override
  State<_MoreFormats> createState() => _MoreFormatsState();
}

class _MoreFormatsState extends State<_MoreFormats> {
  late final AnchoredMenu _menu = AnchoredMenu(
    anchor: () => mounted ? context : null,
    composing: () => widget.controller.value.composing.isValid,
    builder: _panel,
  );
  final Object _group = Object();

  @override
  void didUpdateWidget(_MoreFormats oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.hasAction) {
      _menu.close();
    }
  }

  @override
  void dispose() {
    _menu.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_menu.isOpen) {
      _menu.close();
    } else {
      _menu.open();
    }
  }

  void _choose(_BarItem item) {
    _menu.close();
    item.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    _menu.refresh();
    return TapRegion(
      groupId: _group,
      child: _FormatButton(
        extent: widget.extent,
        icon: _BarIcon(
          glyph: _BarGlyph.more,
          color: ComposerStageInks.of(context).chrome,
        ),
        label: 'More formats',
        onTap: widget.hasAction ? _toggle : null,
      ),
    );
  }

  Widget _panel(BuildContext overlayContext) {
    final RenderBox? button = context.findRenderObject() as RenderBox?;
    final RenderBox? overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (button == null || overlay == null || !button.hasSize) {
      return const SizedBox.shrink();
    }
    final Rect anchor = MatrixUtils.transformRect(
      button.getTransformTo(overlay),
      Offset.zero & button.size,
    );
    final FieldNotesColors colors = overlayContext.colors;
    final FieldNotesShadows shadows = overlayContext.shadows;
    return CustomSingleChildLayout(
      delegate: _MenuLayout(
        anchor: anchor,
        keyboardInset: MediaQuery.viewInsetsOf(overlayContext).bottom,
      ),
      child: TextFieldTapRegion(
        child: TapRegion(
          groupId: _group,
          onTapOutside: (PointerDownEvent _) => _menu.close(),
          child: Container(
            width: _menuWidth,
            padding: const EdgeInsets.all(_menuPadding),
            decoration: BoxDecoration(
              color: colors.cardBright,
              border: shadows.outline,
              borderRadius: _menuRadius,
              boxShadow: shadows.emphasis,
            ),
            child: FocusTraversalGroup(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (final _BarItem item in widget.items)
                      _menuItem(overlayContext, item),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _menuItem(BuildContext overlayContext, _BarItem item) {
    return Pressable(
      key: item.key,
      label: item.label,
      onPressed: item.onTap == null ? null : () => _choose(item),
      borderRadius: _focusRadius,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: math.max(_menuItemMinHeight, widget.extent),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: _menuItemPadding),
          child: Opacity(
            opacity: item.onTap != null ? 1 : _disabledOpacity,
            child: Row(
              children: <Widget>[
                item.icon(overlayContext.colors.ink),
                const SizedBox(width: _menuItemGap),
                Expanded(
                  child: Text(
                    item.label,
                    style: overlayContext.textStyles.ui.copyWith(
                      fontSize: _menuLabelSize,
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

typedef _AnchorScene = ({
  CapturedThemes themes,
  MediaQueryData? media,
  FocusNode? focus,
});

final class AnchoredMenu {
  AnchoredMenu({
    required this.anchor,
    required this.composing,
    required this.builder,
    this.escapeOwner,
  });

  final ValueGetter<BuildContext?> anchor;
  final ValueGetter<bool> composing;
  final WidgetBuilder builder;
  final FocusNode? escapeOwner;

  OverlayEntry? _entry;
  _AnchorScene? _scene;
  bool _refreshing = false;
  bool _escapeHeld = false;
  bool _listening = false;

  bool get isOpen => _entry != null;

  void open() {
    final BuildContext? at = anchor();
    if (_entry != null || at == null) {
      return;
    }
    final OverlayState overlay = Overlay.of(at);
    _scene = _sceneOf(at, overlay);
    final OverlayEntry entry = OverlayEntry(builder: _build);
    _entry = entry;
    overlay.insert(entry);
    _syncEscape();
  }

  void close() {
    final OverlayEntry? entry = _entry;
    if (entry == null) {
      return;
    }
    _entry = null;
    _scene = null;
    entry.remove();
    entry.dispose();
    _syncEscape();
  }

  void refresh() {
    if (_entry == null || _refreshing) {
      return;
    }
    _refreshing = true;
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      _refreshing = false;
      final OverlayEntry? entry = _entry;
      if (entry == null) {
        return;
      }
      final BuildContext? at = anchor();
      if (at == null || !at.mounted) {
        close();
        return;
      }
      _scene = _sceneOf(at, Overlay.of(at));
      entry.markNeedsBuild();
    });
  }

  void dispose() {
    close();
    _escapeHeld = false;
    _syncEscape();
  }

  _AnchorScene _sceneOf(BuildContext at, OverlayState overlay) => (
    themes: InheritedTheme.capture(from: at, to: overlay.context),
    media: at.getInheritedWidgetOfExactType<MediaQuery>()?.data,
    focus: Focus.maybeOf(at, createDependency: false),
  );

  Widget _build(BuildContext overlayContext) {
    final _AnchorScene? scene = _scene;
    if (scene == null) {
      return const SizedBox.shrink();
    }
    final MediaQueryData overlayMedia = MediaQuery.of(overlayContext);
    final MediaQueryData media = scene.media ?? overlayMedia;
    return Semantics(
      container: true,
      child: MediaQuery(
        data: media.copyWith(
          padding: overlayMedia.padding,
          viewInsets: overlayMedia.viewInsets,
          viewPadding: overlayMedia.viewPadding,
        ),
        child: scene.themes.wrap(
          Focus(
            parentNode: scene.focus,
            canRequestFocus: false,
            skipTraversal: true,
            includeSemantics: false,
            child: Builder(builder: builder),
          ),
        ),
      ),
    );
  }

  KeyEventResult _onKey(KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.escape) {
      return KeyEventResult.ignored;
    }
    switch (event) {
      case KeyDownEvent()
          when _entry != null &&
              !composing() &&
              !(escapeOwner?.hasFocus ?? false):
        _escapeHeld = true;
        close();
        return KeyEventResult.handled;
      case KeyDownEvent():
        _escapeHeld = false;
        _syncEscape();
        return KeyEventResult.ignored;
      case KeyRepeatEvent() when _escapeHeld:
        return KeyEventResult.handled;
      case KeyUpEvent() when _escapeHeld:
        _escapeHeld = false;
        _syncEscape();
        return KeyEventResult.handled;
      case _:
        return KeyEventResult.ignored;
    }
  }

  void _syncEscape() {
    final bool wanted = _entry != null || _escapeHeld;
    if (wanted == _listening) {
      return;
    }
    _listening = wanted;
    if (wanted) {
      FocusManager.instance.addEarlyKeyEventHandler(_onKey);
    } else {
      FocusManager.instance.removeEarlyKeyEventHandler(_onKey);
    }
  }
}

class _MenuLayout extends SingleChildLayoutDelegate {
  const _MenuLayout({required this.anchor, required this.keyboardInset});

  final Rect anchor;
  final double keyboardInset;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) {
    final double roomBelow =
        constraints.maxHeight - keyboardInset - anchor.bottom - _menuGap;
    final double roomAbove = anchor.top - _menuGap;
    return constraints.loosen().copyWith(
      maxHeight: math.max(0, math.max(roomBelow, roomAbove)),
    );
  }

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final double below = anchor.bottom + _menuGap;
    final double above = anchor.top - _menuGap - childSize.height;
    final double room = size.height - keyboardInset;
    final double top = below + childSize.height <= room || above < 0
        ? below
        : above;
    final double left = anchor.right - childSize.width;
    return Offset(
      left.clamp(0, math.max(0, size.width - childSize.width)).toDouble(),
      top,
    );
  }

  @override
  bool shouldRelayout(_MenuLayout oldDelegate) =>
      oldDelegate.anchor != anchor ||
      oldDelegate.keyboardInset != keyboardInset;
}

class _BarIcon extends StatelessWidget {
  const _BarIcon({required this.glyph, required this.color});

  final _BarGlyph glyph;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _glyphExtent,
      child: CustomPaint(
        painter: _BarGlyphPainter(glyph: glyph, color: color),
        size: const Size.square(_glyphExtent),
      ),
    );
  }
}

const double _strikeLetterSize = 15;
const double _strikeLetterBaseline = 17.5;
const double _strikeLetterCentre = 12;

class _BarGlyphPainter extends CustomPainter {
  const _BarGlyphPainter({required this.glyph, required this.color});

  final _BarGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.shortestSide / FormatIconPainter.viewBox);
    if (glyph == _BarGlyph.strike) {
      _paintStrikeLetter(canvas);
    }
    canvas.drawPath(_path(), _stroke());
    final Path? dots = _dots();
    if (dots != null) {
      canvas.drawPath(dots, _fill());
    }
    canvas.restore();
  }

  void _paintStrikeLetter(Canvas canvas) {
    final TextPainter letter = TextPainter(
      text: TextSpan(
        text: 'S',
        style: TextStyle(
          fontFamily: TypographyTokens.serif,
          fontSize: _strikeLetterSize,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    letter.paint(
      canvas,
      Offset(
        _strikeLetterCentre - letter.width / 2,
        _strikeLetterBaseline -
            letter.computeDistanceToActualBaseline(TextBaseline.alphabetic),
      ),
    );
    letter.dispose();
  }

  Paint _stroke() => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = FormatIconPainter.strokeWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..isAntiAlias = true;

  Paint _fill() => Paint()
    ..color = color
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  Path? _dots() {
    if (glyph != _BarGlyph.more) {
      return null;
    }
    return Path()
      ..addOval(Rect.fromCircle(center: const Offset(6, 12), radius: 1.6))
      ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 1.6))
      ..addOval(Rect.fromCircle(center: const Offset(18, 12), radius: 1.6));
  }

  Path _path() => switch (glyph) {
    _BarGlyph.strike =>
      Path()
        ..moveTo(5.5, 12.5)
        ..lineTo(18.5, 12.5),
    _BarGlyph.highlight =>
      Path()
        ..moveTo(13.5, 5.5)
        ..lineTo(18.5, 10.5)
        ..lineTo(11, 18)
        ..lineTo(6, 18)
        ..lineTo(6, 13)
        ..close()
        ..moveTo(4.5, 20.5)
        ..lineTo(19.5, 20.5),
    _BarGlyph.code =>
      Path()
        ..moveTo(8.5, 7.5)
        ..lineTo(3.5, 12)
        ..lineTo(8.5, 16.5)
        ..moveTo(15.5, 7.5)
        ..lineTo(20.5, 12)
        ..lineTo(15.5, 16.5),
    _BarGlyph.photo =>
      Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3.5, 5, 17, 14),
            const Radius.circular(2.5),
          ),
        )
        ..addOval(Rect.fromCircle(center: const Offset(9, 10), radius: 1.6))
        ..moveTo(4, 17)
        ..lineTo(9, 12.5)
        ..lineTo(12.5, 15.5)
        ..lineTo(15.5, 13)
        ..lineTo(20, 17),
    _BarGlyph.numbered =>
      Path()
        ..moveTo(4, 5)
        ..lineTo(5, 4.5)
        ..lineTo(5, 9)
        ..moveTo(3.5, 14)
        ..quadraticBezierTo(5, 12.5, 6.2, 14)
        ..lineTo(3.5, 18)
        ..lineTo(6.5, 18)
        ..moveTo(10, 7)
        ..lineTo(20, 7)
        ..moveTo(10, 12)
        ..lineTo(20, 12)
        ..moveTo(10, 17)
        ..lineTo(20, 17),
    _BarGlyph.task =>
      Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 4, 6, 6),
            const Radius.circular(1.5),
          ),
        )
        ..moveTo(4.5, 7)
        ..lineTo(5.8, 8.3)
        ..lineTo(7.8, 5.6)
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(3, 14, 6, 6),
            const Radius.circular(1.5),
          ),
        )
        ..moveTo(12, 7)
        ..lineTo(21, 7)
        ..moveTo(12, 17)
        ..lineTo(21, 17),
    _BarGlyph.table =>
      Path()
        ..addRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTRB(3, 5, 21, 19),
            const Radius.circular(2),
          ),
        )
        ..moveTo(3, 10)
        ..lineTo(21, 10)
        ..moveTo(3, 14.5)
        ..lineTo(21, 14.5)
        ..moveTo(9, 5)
        ..lineTo(9, 19)
        ..moveTo(15, 5)
        ..lineTo(15, 19),
    _BarGlyph.redo =>
      Path()
        ..moveTo(16, 6.5)
        ..lineTo(20.2, 10.8)
        ..lineTo(16, 15)
        ..moveTo(20.2, 10.8)
        ..lineTo(9.5, 10.8)
        ..arcToPoint(
          const Offset(9.5, 19),
          radius: const Radius.circular(4.1),
          clockwise: false,
        )
        ..lineTo(14.5, 19),
    _BarGlyph.more => Path(),
  };

  @override
  bool shouldRepaint(_BarGlyphPainter oldDelegate) =>
      oldDelegate.glyph != glyph || oldDelegate.color != color;
}
