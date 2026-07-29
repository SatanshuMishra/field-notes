import 'package:flutter/material.dart';

import '../../design/flowers/flowers.dart';
import '../../design/icons/nav_icons.dart';
import '../../design/tokens/tokens.dart';
import '../../design/widgets/icon_sticker_button.dart';
import '../../design/widgets/widgets.dart';
import '../../domain/mood/flower_kind.dart';
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
    this.soundOn = true,
  });

  final List<ShellDestination> destinations;
  final ShellDestination selected;
  final ValueChanged<ShellDestination> onSelect;
  final VoidCallback onSound;
  final Widget streak;
  final Widget body;
  final bool soundOn;

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
                    const DashedDivider(
                      axis: Axis.vertical,
                      thickness: 1.0,
                      color: Palette.ink22,
                    ),
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
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: Palette.titleBar,
        border: Border(bottom: BorderSide(color: Palette.ink16, width: 1)),
      ),
      child: Row(
        children: <Widget>[
          Row(
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
          const Expanded(
            child: Text(
              'field notes — a journal of days',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TypographyTokens.windowTitleAccent,
            ),
          ),
          const SizedBox(width: 56),
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
      width: 216,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                const FlowerBloom(kind: FlowerKind.peony, size: 32),
                const SizedBox(width: 9),
                const Text(
                  'field\nnotes',
                  style: TypographyTokens.wordmarkAccent,
                ),
              ],
            ),
            const SizedBox(height: 24),
            for (final ShellDestination d in destinations) _railItem(d),
            const Spacer(),
            streak,
            const SizedBox(height: 12),
            _footer(),
          ],
        ),
      ),
    );
  }

  Widget _footer() {
    final bool settingsSelected = selected == ShellDestination.settings;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        IconStickerButton(
          key: const ValueKey<String>('settings-button'),
          glyph: IconStickerGlyph.gear,
          glyphColor: settingsSelected ? Palette.onAccent : Palette.ink,
          background: settingsSelected ? Palette.coral : Palette.cardLight,
          semanticLabel: ShellDestination.settings.label,
          onPressed: () => onSelect(ShellDestination.settings),
        ),
        const SizedBox(width: _footerGap),
        IconStickerButton(
          key: const ValueKey<String>('sound-button'),
          glyph: soundOn ? IconStickerGlyph.soundOn : IconStickerGlyph.soundOff,
          glyphColor: Palette.ink,
          background: soundOn ? Palette.cardLight : Palette.cardWarm,
          semanticLabel: soundOn ? _soundOnLabel : _soundOffLabel,
          onPressed: onSound,
        ),
        const SizedBox(width: _footerGap),
        Flexible(child: _syncCaption()),
      ],
    );
  }

  Widget _syncCaption() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _syncPrimaryCopy,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _syncPrimaryStyle,
        ),
        Text(
          _syncSecondaryCopy,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _syncSecondaryStyle,
        ),
      ],
    );
  }

  Widget _railItem(ShellDestination d) {
    final bool isSelected = d == selected;
    final Color foreground = isSelected ? Palette.onAccent : Palette.inkSoft;
    final NavGlyph? glyph = d.glyph;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GestureDetector(
        key: ValueKey<String>('rail-${d.name}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => onSelect(d),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: isSelected ? Palette.coral : null,
            border: isSelected ? Shapes.outline : null,
            borderRadius: _navItemRadius,
            boxShadow: isSelected ? Shadows.emphasis : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              children: <Widget>[
                if (glyph == null)
                  Icon(d.icon, size: 18, color: foreground)
                else
                  NavIcon(glyph: glyph, color: foreground, size: 18),
                const SizedBox(width: 10),
                Text(
                  d.label,
                  style: TypographyTokens.navLabelSans.copyWith(
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

const BorderRadius _navItemRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusControl),
);

const double _footerGap = 9;
const double _syncLineHeight = 1.15;
const String _syncPrimaryCopy = 'Stored locally';
const String _syncSecondaryCopy = 'on this device only';
const String _soundOnLabel = 'Sound effects on';
const String _soundOffLabel = 'Sound effects off';

final TextStyle _syncPrimaryStyle =
    TypographyTokens.syncPrimarySans.copyWith(height: _syncLineHeight);

final TextStyle _syncSecondaryStyle =
    TypographyTokens.syncSecondarySans.copyWith(height: _syncLineHeight);

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
