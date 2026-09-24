import 'package:field_notes/features/note_engine/input/command_registry.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

final class NoteCommandIntent extends Intent {
  const NoteCommandIntent(this.commandId);

  final String commandId;
}

final class NoteEscapeIntent extends Intent {
  const NoteEscapeIntent();
}

Map<ShortcutActivator, Intent> noteShortcuts(TargetPlatform platform) {
  final bool apple =
      platform == TargetPlatform.macOS || platform == TargetPlatform.iOS;

  SingleActivator command(LogicalKeyboardKey key, {bool shift = false}) =>
      SingleActivator(key, meta: apple, control: !apple, shift: shift);

  return <ShortcutActivator, Intent>{
    command(LogicalKeyboardKey.keyB): const NoteCommandIntent(
      NoteCommandId.bold,
    ),
    command(LogicalKeyboardKey.keyI): const NoteCommandIntent(
      NoteCommandId.italic,
    ),
    command(LogicalKeyboardKey.keyK): const NoteCommandIntent(
      NoteCommandId.link,
    ),
    command(LogicalKeyboardKey.keyX, shift: true): const NoteCommandIntent(
      NoteCommandId.strikethrough,
    ),
    command(LogicalKeyboardKey.keyH, shift: true): const NoteCommandIntent(
      NoteCommandId.highlight,
    ),
    command(LogicalKeyboardKey.keyE): const NoteCommandIntent(
      NoteCommandId.inlineCode,
    ),
    command(LogicalKeyboardKey.digit7, shift: true): const NoteCommandIntent(
      NoteCommandId.numberedList,
    ),
    command(LogicalKeyboardKey.digit8, shift: true): const NoteCommandIntent(
      NoteCommandId.bulletList,
    ),
    command(LogicalKeyboardKey.digit9, shift: true): const NoteCommandIntent(
      NoteCommandId.taskList,
    ),
    command(LogicalKeyboardKey.keyL): const NoteCommandIntent(
      NoteCommandId.toggleTask,
    ),
    const SingleActivator(LogicalKeyboardKey.enter, shift: true):
        const NoteCommandIntent(NoteCommandId.lineBreak),
    const SingleActivator(LogicalKeyboardKey.numpadEnter, shift: true):
        const NoteCommandIntent(NoteCommandId.lineBreak),
    const SingleActivator(LogicalKeyboardKey.escape): const NoteEscapeIntent(),
    if (!apple)
      const SingleActivator(LogicalKeyboardKey.keyY, control: true):
          const RedoTextIntent(SelectionChangedCause.keyboard),
  };
}
