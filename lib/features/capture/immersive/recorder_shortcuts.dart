import 'package:field_notes/design/keyboard/shortcut_modifier.dart';
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
  required TargetPlatform platform,
  RecorderPrimaryVerb? primary,
  bool keep = false,
  RecorderLeaveVerb? leave,
}) {
  return <String>[
    if (primary != null) 'space ${primary.word}',
    if (keep) usesCommandKey(platform) ? '⌘↩ keep' : 'ctrl+enter keep',
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
    final TargetPlatform platform = Theme.of(context).platform;
    return CallbackShortcuts(
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.space): ?onPrimary,
        primaryShortcut(LogicalKeyboardKey.enter, platform): ?onKeep,
        primaryShortcut(LogicalKeyboardKey.numpadEnter, platform): ?onKeep,
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
