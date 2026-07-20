import 'package:flutter/widgets.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';

class TextComposerSheet extends StatefulWidget {
  const TextComposerSheet({
    super.key,
    required this.onSave,
    required this.onCancel,
    this.initialText = '',
    this.errorMessage,
    this.isSaving = false,
    this.title = 'Write a note',
    this.hintText = 'What happened today?',
    this.saveLabel = 'Save note',
    this.savingLabel = 'Saving...',
    this.cancelLabel = 'Cancel',
    this.maxWidth = 420,
  });

  final ValueChanged<String> onSave;
  final VoidCallback onCancel;
  final String initialText;
  final String? errorMessage;
  final bool isSaving;
  final String title;
  final String hintText;
  final String saveLabel;
  final String savingLabel;
  final String cancelLabel;
  final double maxWidth;

  @override
  State<TextComposerSheet> createState() => _TextComposerSheetState();
}

class _TextComposerSheetState extends State<TextComposerSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focusNode = FocusNode();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String? errorMessage = widget.errorMessage;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: widget.maxWidth),
        child: StickerCard(
          surface: Palette.cardBright,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(widget.title, style: TypographyTokens.titleSerif),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Palette.cardWarm,
                  border: Shapes.outline,
                  borderRadius: Shapes.buttonBorderRadius,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  child: Stack(
                    children: <Widget>[
                      IgnorePointer(
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _controller,
                          builder: (
                            BuildContext context,
                            TextEditingValue value,
                            Widget? child,
                          ) {
                            if (value.text.isNotEmpty) {
                              return const SizedBox.shrink();
                            }
                            return Text(
                              widget.hintText,
                              style: TypographyTokens.bodySans
                                  .copyWith(color: Palette.placeholder),
                            );
                          },
                        ),
                      ),
                      EditableText(
                        controller: _controller,
                        focusNode: _focusNode,
                        style: TypographyTokens.bodySerif,
                        cursorColor: Palette.coral,
                        backgroundCursorColor: Palette.muted,
                        keyboardType: TextInputType.multiline,
                        minLines: 4,
                        maxLines: 8,
                      ),
                    ],
                  ),
                ),
              ),
              if (errorMessage != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  errorMessage,
                  style: TypographyTokens.captionSans
                      .copyWith(color: Palette.danger),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  StickerButton(
                    label: widget.cancelLabel,
                    variant: StickerButtonVariant.secondary,
                    onPressed: widget.isSaving ? null : widget.onCancel,
                  ),
                  const SizedBox(width: 12),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _controller,
                    builder: (
                      BuildContext context,
                      TextEditingValue value,
                      Widget? child,
                    ) {
                      final bool canSave =
                          value.text.trim().isNotEmpty && !widget.isSaving;
                      return StickerButton(
                        label: widget.isSaving
                            ? widget.savingLabel
                            : widget.saveLabel,
                        onPressed:
                            canSave ? () => widget.onSave(value.text) : null,
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
