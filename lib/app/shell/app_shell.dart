import 'package:flutter/material.dart';

import 'bottom_bar_shell.dart';
import 'destination_placeholder.dart';
import 'shell_destination.dart';
import 'shell_layout.dart';
import 'sidebar_shell.dart';

void _noShellAction() {}

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.onCapturePressed, this.onSoundPressed});

  final VoidCallback? onCapturePressed;
  final VoidCallback? onSoundPressed;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  ShellDestination _selected = ShellDestination.today;

  void _select(ShellDestination destination) {
    setState(() => _selected = destination);
  }

  @override
  Widget build(BuildContext context) {
    final ShellLayout layout = resolveShellLayout(Theme.of(context).platform);
    final Widget body = DestinationPlaceholder(destination: _selected);

    switch (layout) {
      case ShellLayout.sidebar:
        return SidebarShell(
          destinations: ShellDestination.primary,
          selected: _selected,
          onSelect: _select,
          onSound: widget.onSoundPressed ?? _noShellAction,
          body: body,
        );
      case ShellLayout.bottomBar:
        return BottomBarShell(
          destinations: ShellDestination.primary,
          selected: _selected,
          onSelect: _select,
          onCapture: widget.onCapturePressed ?? _noShellAction,
          body: body,
        );
    }
  }
}
