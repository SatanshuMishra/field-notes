import 'package:flutter/widgets.dart';

class SettingsConditional extends StatelessWidget {
  const SettingsConditional({
    super.key,
    required this.visible,
    required this.child,
  });

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!visible) {
      return const SizedBox.shrink();
    }
    return child;
  }
}
