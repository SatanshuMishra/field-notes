import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum RecorderPrimaryVerb {
  start('start'),
  pause('pause'),
  resume('resume'),
  keep('keep');

  const RecorderPrimaryVerb(this.word);

  final String word;
}

enum RecorderLeaveVerb {
  leave('leave'),
  keepGoing('keep going');

  const RecorderLeaveVerb(this.word);

  final String word;
}

String recorderKeyHint({
  RecorderPrimaryVerb? primary,
  bool keep = false,
  RecorderLeaveVerb? leave,
}) {
  return <String>[
    if (primary != null) 'space ${primary.word}',
    if (keep) '⌘↩ keep',
    if (leave != null) 'esc ${leave.word}',
  ].join(' · ');
}

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
