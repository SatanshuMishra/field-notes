import 'package:flutter/services.dart';
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
    this.focusNode,
    this.textInputAction,
    this.onSubmitted,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.enableIMEPersonalizedLearning = true,
  });

  final TextEditingController controller;
  final String? hintText;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;
  final bool autocorrect;
  final bool enableSuggestions;
  final bool enableIMEPersonalizedLearning;

  @override
  State<SettingsTextField> createState() => _SettingsTextFieldState();
}

class _SettingsTextFieldState extends State<SettingsTextField> {
  final GlobalKey<EditableTextState> _editableTextKey =
      GlobalKey<EditableTextState>();
  FocusNode? _ownedFocusNode;
  bool _focused = false;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownedFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _applyEnabled();
    _focusNode.addListener(_handleFocusChange);
    _focused = _focusNode.hasFocus;
  }

  @override
  void didUpdateWidget(covariant SettingsTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final bool nodeChanged = oldWidget.focusNode != widget.focusNode;
    if (nodeChanged) {
      final FocusNode previous = oldWidget.focusNode ?? _ownedFocusNode!;
      previous.removeListener(_handleFocusChange);
      _focusNode.addListener(_handleFocusChange);
      _focused = _focusNode.hasFocus;
    }
    if (nodeChanged || oldWidget.enabled != widget.enabled) {
      _applyEnabled();
    }
  }

  void _applyEnabled() {
    final FocusNode node = _focusNode;
    node.canRequestFocus = widget.enabled;
    node.skipTraversal = !widget.enabled;
    if (!widget.enabled && node.hasFocus) {
      node.unfocus();
    }
  }

  void _handleFocusChange() {
    setState(() => _focused = _focusNode.hasFocus);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _ownedFocusNode?.dispose();
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
    _editableTextKey.currentState?.renderEditable.selectPosition(
      cause: SelectionChangedCause.tap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final FieldNotesTextStyles textStyles = context.textStyles;
    final Color borderColor = _focused ? Palette.coral : colors.line;
    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.cardBright,
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
                            builder:
                                (
                                  BuildContext context,
                                  TextEditingValue value,
                                  _,
                                ) {
                                  if (value.text.isNotEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return Text(
                                    widget.hintText!,
                                    style: textStyles.bodySans.copyWith(
                                      color: colors.placeholder,
                                    ),
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
                      textInputAction: widget.textInputAction,
                      autocorrect: widget.autocorrect,
                      enableSuggestions: widget.enableSuggestions,
                      enableIMEPersonalizedLearning:
                          widget.enableIMEPersonalizedLearning,
                      style: textStyles.bodySans,
                      cursorColor: colors.accentInk,
                      backgroundCursorColor: colors.muted,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
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
