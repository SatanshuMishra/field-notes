import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/widgets.dart';

enum SettingsTab {
  syncStorage(
    label: 'Sync & storage',
    sublabel: 'where entries live',
    chipLabel: 'Sync',
  ),
  remindersSound(
    label: 'Reminders & sound',
    sublabel: 'nudges, prompts',
    chipLabel: 'Reminders',
  ),
  journal(
    label: 'Journal',
    sublabel: 'theme, calendar, text size',
    chipLabel: 'Journal',
  ),
  data(label: 'Data', sublabel: 'export, delete', chipLabel: 'Data');

  const SettingsTab({
    required this.label,
    required this.sublabel,
    required this.chipLabel,
  });

  final String label;
  final String sublabel;
  final String chipLabel;
}

const Key settingsTabRailKey = ValueKey<String>('settings-tab-rail');
const Key settingsTabChipsKey = ValueKey<String>('settings-tab-chips');

ValueKey<String> settingsTabKey(SettingsTab tab) =>
    ValueKey<String>('settings-tab-${tab.name}');

const double settingsTabRailWidth = 176;

const double settingsTabChipsOverhang = _segmentGlassInset;

const double _railGap = 6;
const double _sublabelGap = 1;
const double _minTapTarget = 48;

const double _segmentHeight = 40;
const double _segmentGap = 2;
const double _segmentBarPadding = 3;
const double _segmentFontSize = 12.5;
const double _segmentGlassInset =
    (_minTapTarget - _segmentHeight) / 2 - _segmentBarPadding;

const Duration _segmentFade = Duration(milliseconds: 200);

const EdgeInsets _railItemPadding = EdgeInsets.symmetric(
  horizontal: 13,
  vertical: 10,
);
const EdgeInsets _segmentPadding = EdgeInsets.symmetric(horizontal: 15);

const BorderRadius _railItemRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusControl),
);
const BorderRadius _segmentBarRadius = BorderRadius.all(Radius.circular(22));
const BorderRadius _segmentRadius = BorderRadius.all(Radius.circular(19));

const Color _clear = Color(0x00000000);

const Border _clearOutline = Border.fromBorderSide(
  BorderSide(color: _clear, width: Shapes.outlineWidth),
);

const TextStyle _sublabelStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 10.5,
  fontWeight: FontWeight.w400,
);

class SettingsTabRail extends StatelessWidget {
  const SettingsTabRail({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final SettingsTab selected;
  final ValueChanged<SettingsTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: settingsTabRailWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final SettingsTab tab in SettingsTab.values) ...<Widget>[
            if (tab != SettingsTab.values.first)
              const SizedBox(height: _railGap),
            _TabButton(
              tab: tab,
              selected: tab == selected,
              onPressed: () => onSelected(tab),
              borderRadius: _railItemRadius,
              child: _RailFace(tab: tab, selected: tab == selected),
            ),
          ],
        ],
      ),
    );
  }
}

class SettingsTabChips extends StatelessWidget {
  const SettingsTabChips({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final SettingsTab selected;
  final ValueChanged<SettingsTab> onSelected;

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: Stack(
        children: <Widget>[
          const Positioned.fill(
            top: _segmentGlassInset,
            bottom: _segmentGlassInset,
            child: GlassSurface(
              tone: GlassTone.paper,
              borderRadius: _segmentBarRadius,
              child: SizedBox.expand(),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: _segmentBarPadding),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                for (final SettingsTab tab in SettingsTab.values) ...<Widget>[
                  if (tab != SettingsTab.values.first)
                    const SizedBox(width: _segmentGap),
                  _TabButton(
                    tab: tab,
                    selected: tab == selected,
                    onPressed: () => onSelected(tab),
                    borderRadius: _segmentRadius,
                    padTapTarget: true,
                    child: _SegmentFace(tab: tab, selected: tab == selected),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.tab,
    required this.selected,
    required this.onPressed,
    required this.borderRadius,
    required this.child,
    this.padTapTarget = false,
  });

  final SettingsTab tab;
  final bool selected;
  final VoidCallback onPressed;
  final BorderRadius borderRadius;
  final Widget child;
  final bool padTapTarget;

  @override
  Widget build(BuildContext context) {
    final Widget ringed = FocusRing(
      onPressed: onPressed,
      borderRadius: borderRadius,
      child: ExcludeSemantics(child: child),
    );
    return Semantics(
      key: settingsTabKey(tab),
      button: true,
      selected: selected,
      label: tab.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: padTapTarget
            ? ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: _minTapTarget,
                  minHeight: _minTapTarget,
                ),
                child: Center(widthFactor: 1, heightFactor: 1, child: ringed),
              )
            : ringed,
      ),
    );
  }
}

class _RailFace extends StatelessWidget {
  const _RailFace({required this.tab, required this.selected});

  final SettingsTab tab;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final FieldNotesShadows shadows = context.shadows;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? Palette.coral : _clear,
        border: selected ? shadows.outline : _clearOutline,
        borderRadius: _railItemRadius,
        boxShadow: selected ? shadows.emphasis : null,
      ),
      child: Padding(
        padding: _railItemPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              tab.label,
              style: context.textStyles.toastSans.copyWith(
                color: selected ? Palette.onAccent : colors.ink,
              ),
            ),
            const SizedBox(height: _sublabelGap),
            Text(
              tab.sublabel,
              style: _sublabelStyle.copyWith(
                color: selected ? Palette.onDark85 : colors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SegmentFace extends StatelessWidget {
  const _SegmentFace({required this.tab, required this.selected});

  final SettingsTab tab;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : _segmentFade,
      height: _segmentHeight,
      padding: _segmentPadding,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? Palette.coral : _clear,
        border: selected ? context.shadows.outline : _clearOutline,
        borderRadius: _segmentRadius,
      ),
      child: Text(
        tab.chipLabel,
        maxLines: 1,
        softWrap: false,
        style: context.textStyles.toastSans.copyWith(
          fontSize: _segmentFontSize,
          color: selected ? Palette.onAccent : colors.ink,
        ),
      ),
    );
  }
}
