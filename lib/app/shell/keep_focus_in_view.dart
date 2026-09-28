import 'package:flutter/widgets.dart';

class KeepFocusInView extends StatefulWidget {
  const KeepFocusInView({super.key, required this.child});

  final Widget child;

  @override
  State<KeepFocusInView> createState() => _KeepFocusInViewState();
}

class _KeepFocusInViewState extends State<KeepFocusInView> {
  FocusNode? _lastFocus;

  @override
  void initState() {
    super.initState();
    FocusManager.instance.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    FocusManager.instance.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    final FocusNode? focus = FocusManager.instance.primaryFocus;
    if (identical(focus, _lastFocus)) {
      return;
    }
    _lastFocus = focus;
    if (focus == null ||
        FocusManager.instance.highlightMode != FocusHighlightMode.traditional ||
        !identical(
          focus.context?.findAncestorStateOfType<_KeepFocusInViewState>(),
          this,
        )) {
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((Duration _) {
      if (!mounted || !focus.hasPrimaryFocus) {
        return;
      }
      final RenderObject? target = focus.context?.findRenderObject();
      if (target != null && target.attached) {
        target.showOnScreen();
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
