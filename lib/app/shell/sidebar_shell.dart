import 'package:flutter/material.dart';

import '../../design/tokens/tokens.dart';
import '../../design/widgets/widgets.dart';
import 'shell_destination.dart';

class SidebarShell extends StatelessWidget {
  const SidebarShell({
    super.key,
    required this.destinations,
    required this.selected,
    required this.onSelect,
    required this.onSound,
    required this.streak,
    required this.body,
  });

  final List<ShellDestination> destinations;
  final ShellDestination selected;
  final ValueChanged<ShellDestination> onSelect;
  final VoidCallback onSound;
  final Widget streak;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Palette.page,
      body: Column(
        children: <Widget>[
          _titleBar(),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _rail(),
                const DashedDivider(axis: Axis.vertical),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _titleBar() {
    return Container(
      height: 36,
      color: Palette.titleBar,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Row(
        key: const ValueKey<String>('traffic-lights'),
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _dot(Palette.trafficRed),
          const SizedBox(width: 8),
          _dot(Palette.trafficAmber),
          const SizedBox(width: 8),
          _dot(Palette.trafficGreen),
        ],
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _rail() {
    return SizedBox(
      width: 248,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('field notes', style: TypographyTokens.wordmarkAccent),
            const SizedBox(height: 20),
            for (final ShellDestination d in destinations) _railItem(d),
            const Spacer(),
            streak,
            const SizedBox(height: 12),
            StickerButton(
              key: const ValueKey<String>('settings-button'),
              label: 'Settings',
              variant: StickerButtonVariant.secondary,
              icon: const Icon(
                Icons.settings_outlined,
                size: 16,
                color: Palette.ink,
              ),
              onPressed: () => onSelect(ShellDestination.settings),
            ),
            const SizedBox(height: 8),
            StickerButton(
              key: const ValueKey<String>('sound-button'),
              label: 'Sound',
              variant: StickerButtonVariant.secondary,
              icon: const Icon(
                Icons.volume_up_outlined,
                size: 16,
                color: Palette.ink,
              ),
              onPressed: onSound,
            ),
            const SizedBox(height: 12),
            const Text(
              'On this device only',
              style: TypographyTokens.captionSans,
            ),
          ],
        ),
      ),
    );
  }

  Widget _railItem(ShellDestination d) {
    final bool isSelected = d == selected;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        key: ValueKey<String>('rail-${d.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(d),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isSelected ? Palette.cardBright : null,
            border: isSelected ? Shapes.outline : null,
            borderRadius: Shapes.buttonBorderRadius,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: <Widget>[
                Icon(d.icon, size: 18, color: Palette.ink),
                const SizedBox(width: 10),
                Text(d.label, style: TypographyTokens.labelSans),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
