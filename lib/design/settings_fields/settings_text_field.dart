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
  });

  final TextEditingController controller;
  final String? hintText;
  final bool enabled;
  final bool obscureText;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;

  @override
  State<SettingsTextField> createState() => _SettingsTextFieldState();
}

class _SettingsTextFieldState extends State<SettingsTextField> {
  late final FocusNode _focusNode;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
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
          child: Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[
              if (widget.hintText != null)
                IgnorePointer(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: widget.controller,
                    builder: (BuildContext context, TextEditingValue value, _) {
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
              EditableText(
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
  });

  final TextEditingController controller;
  final String? hintText;
  final bool enabled;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingsTextField(
      controller: controller,
      hintText: hintText,
      enabled: enabled,
      obscureText: true,
      onChanged: onChanged,
    );
  }
}
