import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

bool usesCommandKey(TargetPlatform platform) =>
    platform == TargetPlatform.macOS || platform == TargetPlatform.iOS;

SingleActivator primaryShortcut(
  LogicalKeyboardKey key,
  TargetPlatform platform, {
  bool shift = false,
}) {
  final bool command = usesCommandKey(platform);
  return SingleActivator(key, meta: command, control: !command, shift: shift);
}

String primaryModifierLabel(TargetPlatform platform) =>
    usesCommandKey(platform) ? '⌘' : 'Ctrl+';
