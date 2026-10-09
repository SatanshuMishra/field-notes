import 'package:field_notes/design/keyboard/shortcut_modifier.dart';
import 'package:field_notes/features/note_engine/input/command_registry.dart';
import 'package:field_notes/features/note_engine/input/note_shortcuts.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const List<TargetPlatform> _commandPlatforms = <TargetPlatform>[
  TargetPlatform.macOS,
  TargetPlatform.iOS,
];

const List<TargetPlatform> _controlPlatforms = <TargetPlatform>[
  TargetPlatform.windows,
  TargetPlatform.android,
];

void _expectActivator(
  SingleActivator activator, {
  required LogicalKeyboardKey key,
  required bool command,
  bool shift = false,
  required String reason,
}) {
  expect(activator.trigger, key, reason: reason);
  expect(activator.meta, command, reason: reason);
  expect(activator.control, !command, reason: reason);
  expect(activator.shift, shift, reason: reason);
  expect(activator.alt, isFalse, reason: reason);
}

SingleActivator _activatorFor(
  Map<ShortcutActivator, Intent> shortcuts,
  String commandId,
) =>
    shortcuts.entries
            .singleWhere(
              (MapEntry<ShortcutActivator, Intent> entry) =>
                  entry.value is NoteCommandIntent &&
                  (entry.value as NoteCommandIntent).commandId == commandId,
            )
            .key
        as SingleActivator;

void main() {
  test('Command on Apple platforms and Control everywhere else', () {
    for (final TargetPlatform platform in TargetPlatform.values) {
      expect(
        usesCommandKey(platform),
        _commandPlatforms.contains(platform),
        reason: platform.name,
      );
    }

    for (final TargetPlatform platform in _commandPlatforms) {
      _expectActivator(
        primaryShortcut(LogicalKeyboardKey.backslash, platform),
        key: LogicalKeyboardKey.backslash,
        command: true,
        reason: platform.name,
      );
      _expectActivator(
        primaryShortcut(LogicalKeyboardKey.keyX, platform, shift: true),
        key: LogicalKeyboardKey.keyX,
        command: true,
        shift: true,
        reason: '${platform.name} shifted',
      );
    }

    for (final TargetPlatform platform in _controlPlatforms) {
      _expectActivator(
        primaryShortcut(LogicalKeyboardKey.backslash, platform),
        key: LogicalKeyboardKey.backslash,
        command: false,
        reason: platform.name,
      );
      _expectActivator(
        primaryShortcut(LogicalKeyboardKey.keyX, platform, shift: true),
        key: LogicalKeyboardKey.keyX,
        command: false,
        shift: true,
        reason: '${platform.name} shifted',
      );
    }

    expect(primaryModifierLabel(TargetPlatform.macOS), '⌘');
    expect(primaryModifierLabel(TargetPlatform.windows), 'Ctrl+');
  });

  test('note formatting uses Control on Windows and Command on macOS', () {
    final Map<ShortcutActivator, Intent> windows = noteShortcuts(
      TargetPlatform.windows,
    );
    final Map<ShortcutActivator, Intent> mac = noteShortcuts(
      TargetPlatform.macOS,
    );

    _expectActivator(
      _activatorFor(windows, NoteCommandId.bold),
      key: LogicalKeyboardKey.keyB,
      command: false,
      reason: 'windows bold',
    );
    _expectActivator(
      _activatorFor(windows, NoteCommandId.strikethrough),
      key: LogicalKeyboardKey.keyX,
      command: false,
      shift: true,
      reason: 'windows strikethrough',
    );
    _expectActivator(
      _activatorFor(mac, NoteCommandId.bold),
      key: LogicalKeyboardKey.keyB,
      command: true,
      reason: 'mac bold',
    );
    _expectActivator(
      _activatorFor(mac, NoteCommandId.strikethrough),
      key: LogicalKeyboardKey.keyX,
      command: true,
      shift: true,
      reason: 'mac strikethrough',
    );
    expect(windows.values.whereType<RedoTextIntent>(), hasLength(1));
    expect(mac.values.whereType<RedoTextIntent>(), isEmpty);
  });
}
