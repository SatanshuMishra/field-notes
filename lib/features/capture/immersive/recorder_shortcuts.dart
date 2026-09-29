import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RecorderShortcuts extends StatelessWidget {
  const RecorderShortcuts({
    super.key,
    required this.child,
    this.onPrimary,
    this.onKeep,
    this.onLeave,
  });

  final Widget child;
  final VoidCallback? onPrimary;
  final VoidCallback? onKeep;
  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final bool apple = switch (Theme.of(context).platform) {
      TargetPlatform.macOS || TargetPlatform.iOS => true,
      _ => false,
    };
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.space): ?onPrimary,
        SingleActivator(LogicalKeyboardKey.enter, meta: apple, control: !apple):
            ?onKeep,
        SingleActivator(
          LogicalKeyboardKey.numpadEnter,
          meta: apple,
          control: !apple,
        ): ?onKeep,
        const SingleActivator(LogicalKeyboardKey.escape): ?onLeave,
      },
      child: Focus(
        autofocus: true,
        skipTraversal: true,
        includeSemantics: false,
        child: child,
      ),
    );
  }
}
