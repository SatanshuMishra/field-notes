import 'dart:math' as math;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/widgets.dart';

import 'package:field_notes/design/icons/format_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';
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

const double formatBarHeight = 36;

const double _buttonExtent = 30;
const double _glyphExtent = 17;
const double _horizontalPadding = 12;
const double _disabledOpacity = 0.35;
const double _menuGap = 4;
const double _menuPadding = 5;
const double _menuItemHeight = 36;
const double _menuItemPadding = 14;
const double _menuMinWidth = 160;

typedef _Command = Transaction? Function(EditorState state);

enum _BarGlyph { numbered, task, table, more, redo }

class FormatBar extends StatelessWidget {
  const FormatBar({
    super.key,
    required this.controller,
    required this.undoController,
    this.trailing,
    this.tablesAvailable = tablesEnabled,
  });

  final TextEditingController controller;
  final UndoHistoryController undoController;
  final Widget? trailing;
  final bool tablesAvailable;

  @override
  Widget build(BuildContext context) {
    return TextFieldTapRegion(
      child: SizedBox(
        height: formatBarHeight,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: _horizontalPadding,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  dragStartBehavior: DragStartBehavior.down,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _action(
                        formatBoldKey,
                        const FormatIcon(
                          glyph: FormatGlyph.bold,
                          color: Palette.ink,
                          size: _glyphExtent,
                        ),
                        'Bold',
                        (EditorState s) =>
                            toggleInlineFormat(s, InlineFormat.bold),
                      ),
                      _action(
                        formatItalicKey,
                        const FormatIcon(
                          glyph: FormatGlyph.italic,
                          color: Palette.ink,
                          size: _glyphExtent,
                        ),
                        'Italic',
                        (EditorState s) =>
                            toggleInlineFormat(s, InlineFormat.italic),
                      ),
                      _action(
                        formatHeadingKey,
                        const FormatIcon(
                          glyph: FormatGlyph.heading,
                          color: Palette.ink,
                          size: _glyphExtent,
                        ),
                        'Heading',
                        cycleHeading,
                      ),
                      _action(
                        formatListKey,
                        const FormatIcon(
                          glyph: FormatGlyph.list,
                          color: Palette.ink,
                          size: _glyphExtent,
                        ),
                        'Bullet list',
                        (EditorState s) => toggleList(s, NoteListKind.bullet),
                      ),
                      _action(
                        formatNumberedKey,
                        const _BarIcon(glyph: _BarGlyph.numbered),
                        'Numbered list',
                        (EditorState s) =>
                            toggleList(s, NoteListKind.numbered),
                      ),
                      _action(
                        formatTaskKey,
                        const _BarIcon(glyph: _BarGlyph.task),
                        'Task list',
                        (EditorState s) => toggleList(s, NoteListKind.task),
                      ),
                      _action(
                        formatQuoteKey,
                        const FormatIcon(
                          glyph: FormatGlyph.quote,
                          color: Palette.ink,
                          size: _glyphExtent,
                        ),
                        'Quote',
                        toggleQuote,
                      ),
                      _action(
                        formatLinkKey,
                        const FormatIcon(
                          glyph: FormatGlyph.link,
                          color: Palette.ink,
                          size: _glyphExtent,
                        ),
                        'Link',
                        (EditorState s) =>
                            toggleInlineFormat(s, InlineFormat.link),
                      ),
                      if (tablesAvailable)
                        _action(
                          formatTableKey,
                          const _BarIcon(glyph: _BarGlyph.table),
                          'Table',
                          insertTable,
                        ),
                      _MoreFormats(
                        key: formatMoreKey,
                        onChosen: _runner(),
                      ),
                    ],
                  ),
                ),
              ),
              ?trailing,
              _historyButton(
                formatUndoKey,
                const FormatIcon(
                  glyph: FormatGlyph.undo,
                  color: Palette.ink,
                  size: _glyphExtent,
                ),
                'Undo',
                (UndoHistoryValue history) => history.canUndo,
                undoController.undo,
              ),
              _historyButton(
                formatRedoKey,
                const _BarIcon(glyph: _BarGlyph.redo),
                'Redo',
                (UndoHistoryValue history) => history.canRedo,
                undoController.redo,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void Function(_Command command)? _runner() {
    final TextEditingController current = controller;
    if (current is! NoteEditorController) {
      return null;
    }
    return current.applyCommand;
  }

  Widget _action(Key key, Widget icon, String label, _Command command) {
    final void Function(_Command command)? run = _runner();
    return _FormatButton(
      key: key,
      icon: icon,
      label: label,
      onTap: run == null ? null : () => run(command),
    );
  }

  Widget _historyButton(
    Key key,
    Widget icon,
    String label,
    bool Function(UndoHistoryValue history) available,
    VoidCallback onTap,
  ) {
    return ValueListenableBuilder<UndoHistoryValue>(
      valueListenable: undoController,
      builder: (
        BuildContext context,
        UndoHistoryValue history,
        Widget? child,
      ) {
        return _FormatButton(
          key: key,
          icon: icon,
          label: label,
          onTap: available(history) ? onTap : null,
        );
      },
    );
  }
}

class _FormatButton extends StatelessWidget {
  const _FormatButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final Widget icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: _buttonExtent,
          child: Center(
            child: Opacity(
              opacity: enabled ? 1 : _disabledOpacity,
              child: icon,
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreItem {
  const _MoreItem(this.key, this.label, this.format);

  final Key key;
  final String label;
  final InlineFormat format;
}

const List<_MoreItem> _moreItems = <_MoreItem>[
  _MoreItem(formatStrikethroughKey, 'Strikethrough', InlineFormat.strikethrough),
  _MoreItem(formatHighlightKey, 'Highlight', InlineFormat.highlight),
  _MoreItem(formatCodeKey, 'Inline code', InlineFormat.code),
];

class _MoreFormats extends StatefulWidget {
  const _MoreFormats({super.key, required this.onChosen});

  final void Function(_Command command)? onChosen;

  @override
  State<_MoreFormats> createState() => _MoreFormatsState();
}

class _MoreFormatsState extends State<_MoreFormats> {
  final OverlayPortalController _menu = OverlayPortalController();
  final Object _group = Object();

  @override
  void didUpdateWidget(_MoreFormats oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onChosen == null && _menu.isShowing) {
      _menu.hide();
    }
  }

  void _toggle() {
    setState(() {
      if (_menu.isShowing) {
        _menu.hide();
      } else {
        _menu.show();
      }
    });
  }

  void _close() {
    if (!_menu.isShowing) {
      return;
    }
    setState(_menu.hide);
  }

  void _choose(InlineFormat format) {
    final void Function(_Command command)? run = widget.onChosen;
    _close();
    if (run != null) {
      run((EditorState s) => toggleInlineFormat(s, format));
    }
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      groupId: _group,
      child: OverlayPortal(
        controller: _menu,
        overlayChildBuilder: _panel,
        child: _FormatButton(
          icon: const _BarIcon(glyph: _BarGlyph.more),
          label: 'More formats',
          onTap: widget.onChosen == null ? null : _toggle,
        ),
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
    return CustomSingleChildLayout(
      delegate: _MenuLayout(
        anchor: anchor,
        keyboardInset: MediaQuery.viewInsetsOf(overlayContext).bottom,
      ),
      child: TextFieldTapRegion(
        child: TapRegion(
          groupId: _group,
          onTapOutside: (PointerDownEvent _) => _close(),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: Palette.toolbarInk,
              borderRadius: BorderRadius.all(Radius.circular(Shapes.radiusSm)),
              boxShadow: Shadows.toastLift,
            ),
            child: Padding(
              padding: const EdgeInsets.all(_menuPadding),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: _menuMinWidth),
                child: IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (final _MoreItem item in _moreItems)
                        Semantics(
                          button: true,
                          label: item.label,
                          excludeSemantics: true,
                          child: GestureDetector(
                            key: item.key,
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _choose(item.format),
                            child: SizedBox(
                              height: _menuItemHeight,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: _menuItemPadding,
                                ),
                                child: Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: Text(
                                    item.label,
                                    style: TypographyTokens.toolbarSans,
                                  ),
                                ),
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
      ),
    );
  }
}

class _MenuLayout extends SingleChildLayoutDelegate {
  const _MenuLayout({required this.anchor, required this.keyboardInset});

  final Rect anchor;
  final double keyboardInset;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

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
  const _BarIcon({required this.glyph});

  final _BarGlyph glyph;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: _glyphExtent,
      child: CustomPaint(
        painter: _BarGlyphPainter(glyph: glyph, color: Palette.ink),
        size: const Size.square(_glyphExtent),
      ),
    );
  }
}

class _BarGlyphPainter extends CustomPainter {
  const _BarGlyphPainter({required this.glyph, required this.color});

  final _BarGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.shortestSide / FormatIconPainter.viewBox);
    canvas.drawPath(_path(), _stroke());
    final Path? dots = _dots();
    if (dots != null) {
      canvas.drawPath(dots, _fill());
    }
    canvas.restore();
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
      ..addOval(Rect.fromCircle(center: const Offset(5, 12), radius: 1.6))
      ..addOval(Rect.fromCircle(center: const Offset(12, 12), radius: 1.6))
      ..addOval(Rect.fromCircle(center: const Offset(19, 12), radius: 1.6));
  }

  Path _path() => switch (glyph) {
    _BarGlyph.numbered => Path()
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
    _BarGlyph.task => Path()
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
    _BarGlyph.table => Path()
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
    _BarGlyph.redo => Path()
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
