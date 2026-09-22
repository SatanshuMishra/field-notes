import 'package:flutter/widgets.dart';

import 'package:field_notes/design/icons/format_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';

import 'format_actions.dart';

const Key formatBoldKey = ValueKey<String>('format-bold');
const Key formatItalicKey = ValueKey<String>('format-italic');
const Key formatHeadingKey = ValueKey<String>('format-heading');
const Key formatListKey = ValueKey<String>('format-list');
const Key formatQuoteKey = ValueKey<String>('format-quote');
const Key formatLinkKey = ValueKey<String>('format-link');
const Key formatUndoKey = ValueKey<String>('format-undo');

const double formatBarHeight = 36;

const double _buttonExtent = 30;
const double _glyphExtent = 17;
const double _horizontalPadding = 12;
const double _disabledOpacity = 0.35;

class FormatBar extends StatelessWidget {
  const FormatBar({
    super.key,
    required this.controller,
    required this.undoController,
    this.trailing,
  });

  final TextEditingController controller;
  final UndoHistoryController undoController;
  final Widget? trailing;

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
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _action(
                        formatBoldKey,
                        FormatGlyph.bold,
                        'Bold',
                        toggleBold,
                      ),
                      _action(
                        formatItalicKey,
                        FormatGlyph.italic,
                        'Italic',
                        toggleItalic,
                      ),
                      _action(
                        formatHeadingKey,
                        FormatGlyph.heading,
                        'Heading',
                        toggleHeading,
                      ),
                      _action(
                        formatListKey,
                        FormatGlyph.list,
                        'Bullet list',
                        toggleBullet,
                      ),
                      _action(
                        formatQuoteKey,
                        FormatGlyph.quote,
                        'Quote',
                        toggleQuote,
                      ),
                      _action(
                        formatLinkKey,
                        FormatGlyph.link,
                        'Link',
                        toggleLink,
                      ),
                    ],
                  ),
                ),
              ),
              ?trailing,
              _undo(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _action(
    Key key,
    FormatGlyph glyph,
    String label,
    TextEditingValue Function(TextEditingValue value) action,
  ) {
    return _FormatButton(
      key: key,
      glyph: glyph,
      label: label,
      onTap: () => _apply(action),
    );
  }

  Widget _undo() {
    return ValueListenableBuilder<UndoHistoryValue>(
      valueListenable: undoController,
      builder: (
        BuildContext context,
        UndoHistoryValue history,
        Widget? child,
      ) {
        return _FormatButton(
          key: formatUndoKey,
          glyph: FormatGlyph.undo,
          label: 'Undo',
          onTap: history.canUndo ? undoController.undo : null,
        );
      },
    );
  }

  void _apply(TextEditingValue Function(TextEditingValue value) action) {
    final TextEditingValue current = controller.value;
    final TextEditingValue next = action(current);
    if (next == current) {
      return;
    }
    controller.value = next;
  }
}

class _FormatButton extends StatelessWidget {
  const _FormatButton({
    super.key,
    required this.glyph,
    required this.label,
    required this.onTap,
  });

  final FormatGlyph glyph;
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
              child: FormatIcon(
                glyph: glyph,
                color: Palette.ink,
                size: _glyphExtent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
