import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/features/capture/core/capture.dart';
import 'package:field_notes/features/settings/settings_controller.dart';
import 'package:field_notes/features/settings/settings_providers.dart';
import 'package:field_notes/features/sound/sound_providers.dart';
import 'package:field_notes/features/streak/streak.dart';
import 'package:field_notes/features/today/today.dart';

import 'bottom_bar_shell.dart';
import 'shell_content.dart';
import 'shell_destination.dart';
import 'shell_layout.dart';
import 'sidebar_shell.dart';

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key, this.onCapturePressed, this.onSoundPressed});

  final VoidCallback? onCapturePressed;
  final VoidCallback? onSoundPressed;

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  ShellDestination _selected = ShellDestination.today;

  void _select(ShellDestination destination) {
    setState(() => _selected = destination);
  }

  Future<void> _openCapture() async {
    await openCapture(context, ref, date: ref.read(todayDateProvider));
  }

  Future<void> _toggleSound() async {
    final bool next = !ref.read(soundEnabledProvider);
    final SettingsWriteResult result =
        await ref.read(settingsControllerProvider).setSoundEnabled(next);
    if (result is SettingsWriteFailed) {
      debugPrint('Sound toggle failed: ${result.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ShellLayout layout = resolveShellLayout(Theme.of(context).platform);
    final Widget body = ShellContent(destination: _selected);
    final VoidCallback onCapture = widget.onCapturePressed ?? _openCapture;
    final VoidCallback onSound = widget.onSoundPressed ?? _toggleSound;

    switch (layout) {
      case ShellLayout.sidebar:
        return SidebarShell(
          destinations: ShellDestination.primary,
          selected: _selected,
          onSelect: _select,
          onSound: onSound,
          soundOn: ref.watch(soundEnabledProvider),
          streak: const StreakCard(),
          body: body,
        );
      case ShellLayout.bottomBar:
        return BottomBarShell(
          destinations: ShellDestination.primary,
          selected: _selected,
          onSelect: _select,
          onCapture: onCapture,
          body: body,
        );
    }
  }
}
