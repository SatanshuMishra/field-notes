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
      backgroundColor: Palette.panelTop,
      body: Column(
        children: <Widget>[
          _titleBar(),
          Expanded(
            child: DecoratedBox(
              decoration: _panelWash,
              child: DecoratedBox(
                decoration: _panelGlow,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _rail(),
                    const DashedDivider(axis: Axis.vertical),
                    Expanded(child: body),
                  ],
                ),
              ),
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

const double _panelGlowBaseRadius = 0.5;
const double _panelGlowExtentX = 1.2;
const double _panelGlowExtentY = 0.6;
const double _panelGlowCentreX = 0.15;
const double _panelGlowFadeStop = 0.55;

const Color _panelCoralTintFade = Color(0x00C76A54);

const BoxDecoration _panelWash = BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[Palette.panelTop, Palette.panelBottom],
  ),
);

const BoxDecoration _panelGlow = BoxDecoration(
  gradient: RadialGradient(
    center: Alignment(2 * _panelGlowCentreX - 1, -1),
    radius: _panelGlowBaseRadius,
    colors: <Color>[Palette.panelCoralTint, _panelCoralTintFade],
    stops: <double>[0, _panelGlowFadeStop],
    transform: _PanelGlowScale(),
  ),
);

class _PanelGlowScale extends GradientTransform {
  const _PanelGlowScale();

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    final double base = _panelGlowBaseRadius * bounds.shortestSide;
    if (base <= 0) {
      return Matrix4.identity();
    }
    final double scaleX = _panelGlowExtentX * bounds.width / base;
    final double scaleY = _panelGlowExtentY * bounds.height / base;
    final double centreX = bounds.left + _panelGlowCentreX * bounds.width;
    final double centreY = bounds.top;
    return Matrix4.identity()
      ..setEntry(0, 0, scaleX)
      ..setEntry(1, 1, scaleY)
      ..setEntry(0, 3, centreX * (1 - scaleX))
      ..setEntry(1, 3, centreY * (1 - scaleY));
  }
}
