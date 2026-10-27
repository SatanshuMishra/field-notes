import 'package:flutter/widgets.dart';

class KeyboardFocusBuilder extends StatefulWidget {
  const KeyboardFocusBuilder({
    super.key,
    required this.focusNode,
    required this.builder,
  });

  final FocusNode focusNode;
  final Widget Function(BuildContext context, bool keyboardFocused) builder;

  @override
  State<KeyboardFocusBuilder> createState() => _KeyboardFocusBuilderState();
}

class _KeyboardFocusBuilderState extends State<KeyboardFocusBuilder> {
  late bool _keyboardFocused = _isKeyboardFocused();

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_sync);
    FocusManager.instance.addHighlightModeListener(_onHighlightMode);
  }

  @override
  void didUpdateWidget(KeyboardFocusBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.focusNode, widget.focusNode)) {
      oldWidget.focusNode.removeListener(_sync);
      widget.focusNode.addListener(_sync);
      _sync();
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_sync);
    FocusManager.instance.removeHighlightModeListener(_onHighlightMode);
    super.dispose();
  }

  bool _isKeyboardFocused() =>
      widget.focusNode.hasPrimaryFocus &&
      FocusManager.instance.highlightMode == FocusHighlightMode.traditional;

  void _onHighlightMode(FocusHighlightMode _) => _sync();

  void _sync() {
    final bool keyboardFocused = _isKeyboardFocused();
    if (mounted && keyboardFocused != _keyboardFocused) {
      setState(() => _keyboardFocused = keyboardFocused);
    }
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _keyboardFocused);
}
