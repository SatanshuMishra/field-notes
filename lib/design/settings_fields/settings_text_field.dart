import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

class SettingsTextField extends StatefulWidget {
  const SettingsTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.enabled = true,
    this.obscureText = false,
    this.keyboardType,
    this.onChanged,
    this.semanticLabel,
  });

  final TextEditingController controller;
  final String? hintText;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final String? semanticLabel;

  @override
  State<SettingsTextField> createState() => _SettingsTextFieldState();
}

class _SettingsTextFieldState extends State<SettingsTextField> {
  final GlobalKey<EditableTextState> _editableTextKey =
      GlobalKey<EditableTextState>();
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(
      canRequestFocus: widget.enabled,
      skipTraversal: !widget.enabled,
    );
    _focusNode.addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant SettingsTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) {
      _focusNode.canRequestFocus = widget.enabled;
      _focusNode.skipTraversal = !widget.enabled;
      if (!widget.enabled && _focusNode.hasFocus) {
        _focusNode.unfocus();
      }
    }
  }

  void _handleFocusChange() {
    setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.enabled) {
      return;
    }
    _editableTextKey.currentState?.renderEditable.handleTapDown(details);
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.enabled) {
      return;
    }
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
    _editableTextKey.currentState?.renderEditable
        .selectPosition(cause: SelectionChangedCause.tap);
  }

  @override
  Widget build(BuildContext context) {
    final Color borderColor = _focused ? Palette.coral : Palette.ink;
    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Palette.cardBright,
          border: Border.all(color: borderColor, width: Shapes.outlineWidth),
          borderRadius: Shapes.buttonBorderRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: MergeSemantics(
            child: Semantics(
              label: widget.semanticLabel ?? widget.hintText,
              hint: widget.semanticLabel == null ? null : widget.hintText,
              enabled: widget.enabled ? null : false,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                excludeFromSemantics: !widget.enabled,
                onTapDown: _handleTapDown,
                onTapUp: _handleTapUp,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: <Widget>[
                    if (widget.hintText != null)
                      ExcludeSemantics(
                        child: IgnorePointer(
                          child: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: widget.controller,
                            builder: (BuildContext context,
                                TextEditingValue value, _) {
                              if (value.text.isNotEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Text(
                                widget.hintText!,
                                style: TypographyTokens.bodySans
                                    .copyWith(color: Palette.placeholder),
                              );
                            },
                          ),
                        ),
                      ),
                    EditableText(
                      key: _editableTextKey,
                      controller: widget.controller,
                      focusNode: _focusNode,
                      readOnly: !widget.enabled,
                      obscureText: widget.obscureText,
                      keyboardType: widget.keyboardType ?? TextInputType.text,
                      style: TypographyTokens.bodySans,
                      cursorColor: Palette.coral,
                      backgroundCursorColor: Palette.muted,
                      onChanged: widget.onChanged,
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

class SettingsSecretField extends StatelessWidget {
  const SettingsSecretField({
    super.key,
    required this.controller,
    this.hintText,
    this.enabled = true,
    this.onChanged,
    this.semanticLabel,
  });

  final TextEditingController controller;
  final String? hintText;
  final bool enabled;
  final ValueChanged<String>? onChanged;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return SettingsTextField(
      controller: controller,
      hintText: hintText,
      enabled: enabled,
      obscureText: true,
      onChanged: onChanged,
      semanticLabel: semanticLabel,
    );
  }
}
