import 'dart:async';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:flutter/material.dart';

import '../../design/flowers/flowers.dart';
import '../../design/icons/nav_icons.dart';
import '../../design/tokens/tokens.dart';
import '../../design/widgets/icon_sticker_button.dart';
import '../../design/widgets/widgets.dart';
import '../../domain/mood/flower_kind.dart';
import '../../features/onboarding/tour_anchor.dart';
import 'keep_focus_in_view.dart';
import 'shell_destination.dart';
import 'window_chrome.dart';

const double shellSidebarWidth = 216;

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
    final FieldNotesColors colors = context.colors;
    return KeepFocusInView(
      child: Scaffold(
        backgroundColor: colors.panelTop,
        body: Column(
          children: <Widget>[
            _titleBar(context),
            Expanded(
              child: DecoratedBox(
                decoration: _panelWash(colors),
                child: DecoratedBox(
                  decoration: _panelGlow,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      FocusTraversalGroup(child: _rail(context)),
                      DashedDivider(
                        axis: Axis.vertical,
                        thickness: 1.0,
                        color: colors.ink22,
                      ),
                      Expanded(child: FocusTraversalGroup(child: body)),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _titleBar(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return GestureDetector(
      key: windowTitleBarKey,
      behavior: HitTestBehavior.opaque,
      onPanStart: (DragStartDetails _) => unawaited(startWindowDrag()),
      onDoubleTap: () => unawaited(runTitlebarDoubleClick()),
      child: Container(
        height: shellTitleBarHeight,
        padding: const EdgeInsets.symmetric(horizontal: shellTitleBarPadding),
        decoration: BoxDecoration(
          color: colors.titleBar,
          border: Border(bottom: BorderSide(color: colors.ink16, width: 1)),
        ),
        child: Row(
          children: <Widget>[
            const SizedBox(
              key: ValueKey<String>('traffic-lights'),
              width: windowButtonsSlotWidth,
            ),
            Expanded(
              child: Text(
                'field notes — a journal of days',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.textStyles.windowTitleAccent,
              ),
            ),
            const SizedBox(width: windowButtonsSlotWidth),
          ],
        ),
      ),
    );
  }

  Widget _rail(BuildContext context) {
    return SizedBox(
      width: shellSidebarWidth,
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
                Text('field\nnotes', style: context.textStyles.wordmarkAccent),
              ],
            ),
            const SizedBox(height: 24),
            TourAnchor(
              target: TourTarget.nav,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final ShellDestination d in destinations)
                    if (d == ShellDestination.calendar)
                      TourAnchor(
                        target: TourTarget.calendar,
                        child: _railItem(context, d),
                      )
                    else
                      _railItem(context, d),
                ],
              ),
            ),
            const Spacer(),
            streak,
            const SizedBox(height: 14),
            _footer(context),
          ],
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final bool settingsSelected = selected == ShellDestination.settings;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        TourAnchor(
          target: TourTarget.settings,
          child: IconStickerButton(
            key: const ValueKey<String>('settings-button'),
            glyph: IconStickerGlyph.gear,
            glyphColor: settingsSelected ? Palette.onAccent : colors.ink,
            background: settingsSelected ? Palette.coral : colors.cardLight,
            semanticLabel: ShellDestination.settings.label,
            selected: settingsSelected,
            onPressed: () => onSelect(ShellDestination.settings),
          ),
        ),
        const SizedBox(width: _footerGap),
        IconStickerButton(
          key: const ValueKey<String>('sound-button'),
          glyph: soundOn ? IconStickerGlyph.soundOn : IconStickerGlyph.soundOff,
          glyphColor: colors.ink,
          background: soundOn ? colors.cardLight : colors.cardWarm,
          semanticLabel: soundOn ? _soundOnLabel : _soundOffLabel,
          onPressed: onSound,
        ),
        const SizedBox(width: _footerGap),
        Flexible(child: _syncCaption(context)),
      ],
    );
  }

  Widget _syncCaption(BuildContext context) {
    final FieldNotesTextStyles textStyles = context.textStyles;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          _syncPrimaryCopy,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyles.syncPrimarySans.copyWith(height: _syncLineHeight),
        ),
        Text(
          _syncSecondaryCopy,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textStyles.syncSecondarySans.copyWith(height: _syncLineHeight),
        ),
      ],
    );
  }

  Widget _railItem(BuildContext context, ShellDestination d) {
    final FieldNotesShadows shadows = context.shadows;
    final bool isSelected = d == selected;
    final Color foreground = isSelected
        ? Palette.onAccent
        : context.colors.inkSoft;
    final NavGlyph? glyph = d.glyph;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        button: true,
        selected: isSelected,
        label: d.label,
        child: GestureDetector(
          key: ValueKey<String>('rail-${d.name}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(d),
          child: FocusRing(
            onPressed: () => onSelect(d),
            borderRadius: _navItemRadius,
            child: ExcludeSemantics(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: isSelected ? Palette.coral : null,
                  border: isSelected ? shadows.outline : null,
                  borderRadius: _navItemRadius,
                  boxShadow: isSelected ? shadows.emphasis : null,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  child: Row(
                    children: <Widget>[
                      if (glyph == null)
                        Icon(d.icon, size: 18, color: foreground)
                      else
                        NavIcon(glyph: glyph, color: foreground, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        d.label,
                        style: context.textStyles.navLabelSans.copyWith(
                          color: foreground,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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

const double _panelGlowBaseRadius = 0.5;
const double _panelGlowExtentX = 1.2;
const double _panelGlowExtentY = 0.6;
const double _panelGlowCentreX = 0.15;
const double _panelGlowFadeStop = 0.55;

const Color _panelCoralTintFade = Color(0x00C76A54);

BoxDecoration _panelWash(FieldNotesColors colors) => BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: <Color>[colors.panelTop, colors.panelBottom],
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
