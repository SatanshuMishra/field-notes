import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/notes/notes.dart';

const Key photoCaptionFieldEditorKey =
    ValueKey<String>('photo-caption-editor');

const String photoCaptionFieldHint = 'Caption';

final RegExp _forbidden = RegExp(r'[\]\r\n]');

double photoCaptionLineHeight(TextScaler scaler) {
  final TextPainter painter = TextPainter(
    text: const TextSpan(text: 'Ag', style: notePhotoCaptionStyle),
    textAlign: notePhotoCaptionAlign,
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout();
  final double height = painter.height;
  painter.dispose();
  return height;
}

class PhotoCaptionField extends StatefulWidget {
  const PhotoCaptionField({
    super.key,
    required this.caption,
    required this.width,
    required this.height,
    required this.onCommit,
    required this.onCancel,
  });

  final String caption;
  final double width;
  final double height;
  final ValueChanged<String> onCommit;
  final VoidCallback onCancel;

  @override
  State<PhotoCaptionField> createState() => _PhotoCaptionFieldState();
}

class _PhotoCaptionFieldState extends State<PhotoCaptionField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.caption,
  )..selection = TextSelection(
      baseOffset: 0,
      extentOffset: widget.caption.length,
    );
  final FocusNode _focus = FocusNode(debugLabel: photoCaptionFieldHint);
  bool _settled = false;

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit() {
    if (_settled) {
      return;
    }
    _settled = true;
    widget.onCommit(_controller.text);
  }

  void _cancel() {
    if (_settled) {
      return;
    }
    _settled = true;
    widget.onCancel();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) {
      return KeyEventResult.ignored;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _cancel();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _commit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      child: TapRegion(
        onTapOutside: (PointerDownEvent event) => _commit(),
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: _onKey,
          child: SizedBox(
            width: widget.width,
            height: widget.height,
            child: Material(
              type: MaterialType.transparency,
              child: TextField(
                key: photoCaptionFieldEditorKey,
                controller: _controller,
                focusNode: _focus,
                autofocus: true,
                maxLines: 1,
                style: notePhotoCaptionStyle,
                textAlign: notePhotoCaptionAlign,
                cursorColor: Palette.coral,
                keyboardType: TextInputType.text,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.sentences,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.deny(_forbidden),
                ],
                onSubmitted: (String _) => _commit(),
                decoration: InputDecoration.collapsed(
                  hintText: photoCaptionFieldHint,
                  hintStyle: notePhotoCaptionStyle.copyWith(
                    color: Palette.placeholder,
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
