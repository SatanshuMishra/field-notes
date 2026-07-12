import 'package:flutter/material.dart';

import '../../design/tokens/tokens.dart';
import 'shell_destination.dart';

class BottomBarShell extends StatelessWidget {
  const BottomBarShell({
    super.key,
    required this.destinations,
    required this.selected,
    required this.onSelect,
    required this.onCapture,
    required this.body,
  }) : assert(destinations.length == 4, 'BottomBarShell requires four destinations');

  final List<ShellDestination> destinations;
  final ShellDestination selected;
  final ValueChanged<ShellDestination> onSelect;
  final VoidCallback onCapture;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.page,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            _topBar(),
            Expanded(child: body),
          ],
        ),
      ),
      bottomNavigationBar: _bottomBar(),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      child: Row(
        children: <Widget>[
          const Text('field notes', style: TypographyTokens.wordmarkAccent),
          const Spacer(),
          GestureDetector(
            key: const ValueKey<String>('gear-button'),
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(ShellDestination.settings),
            child: const Padding(
              padding: EdgeInsets.all(8),
              child: Icon(Icons.settings_outlined, color: Palette.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Palette.panelTop,
        border: Border(
          top: BorderSide(color: Palette.ink, width: Shapes.outlineWidth),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              _tab(destinations[0]),
              _tab(destinations[1]),
              _captureButton(),
              _tab(destinations[2]),
              _tab(destinations[3]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(ShellDestination d) {
    final bool isSelected = d == selected;
    final Color color = isSelected ? Palette.coral : Palette.mutedDeep;
    return GestureDetector(
      key: ValueKey<String>('tab-${d.name}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelect(d),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(d.icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(
              d.label,
              style: TypographyTokens.captionSans.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _captureButton() {
    return GestureDetector(
      key: const ValueKey<String>('capture-button'),
      behavior: HitTestBehavior.opaque,
      onTap: onCapture,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: Palette.coral,
          shape: BoxShape.circle,
          border: Border.all(color: Palette.ink, width: Shapes.outlineWidth),
          boxShadow: Shadows.button,
        ),
        child: const Icon(Icons.add, color: Palette.cardBright, size: 28),
      ),
    );
  }
}
