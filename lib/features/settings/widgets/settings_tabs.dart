import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/icons/settings_icons.dart';
import 'package:field_notes/design/interaction/hover_style.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/widgets.dart';

enum SettingsTab {
  journal(
    label: 'Journal',
    sublabel: 'theme, calendar, text size',
    glyph: SettingsGlyph.book,
  ),
  syncStorage(
    label: 'Sync & storage',
    sublabel: 'where entries live',
    glyph: SettingsGlyph.flip,
  ),
  remindersSound(
    label: 'Reminders & sound',
    sublabel: 'nudges, prompts',
    glyph: SettingsGlyph.bell,
  ),
  voice(
    label: 'Voice',
    sublabel: 'microphone, noise',
    glyph: SettingsGlyph.microphone,
  ),
  data(label: 'Data', sublabel: 'export, delete', glyph: SettingsGlyph.archive),
  about(
    label: 'About',
    sublabel: 'version, updates',
    glyph: SettingsGlyph.info,
  );

  const SettingsTab({
    required this.label,
    required this.sublabel,
    required this.glyph,
  });

  final String label;
  final String sublabel;
  final SettingsGlyph glyph;
}

List<SettingsTab> settingsTabsFor({required bool syncAvailable}) =>
    <SettingsTab>[
      for (final SettingsTab tab in SettingsTab.values)
        if (syncAvailable || tab != SettingsTab.syncStorage) tab,
    ];

const Key settingsTabRailKey = ValueKey<String>('settings-tab-rail');
const Key settingsTabSeparatorKey = ValueKey<String>('settings-tab-separator');

ValueKey<String> settingsTabKey(SettingsTab tab) =>
    ValueKey<String>('settings-tab-${tab.name}');

ValueKey<String> settingsTabFaceKey(SettingsTab tab) =>
    ValueKey<String>('settings-tab-face-${tab.name}');

ValueKey<String> settingsTabMarkKey(SettingsTab tab) =>
    ValueKey<String>('settings-tab-mark-${tab.name}');

const double settingsTabRailWidth = 190;
const double settingsTabEntryMinHeight = 44;
const double settingsTabEntryGap = 6;
const double settingsTabIconSize = 18;
const double settingsTabSelectedOpacity = 0.11;
const double settingsTabSeparatorOpacity = 0.14;
const double settingsTabMarkSize = 8;
const double settingsTabMarkRing = 3;
const double settingsTabMarkRingOpacity = 0.18;

const double _hitInset = 2;
const double _iconGap = 10;
const double _labelSize = 14;
const double _separatorMargin = 10;
const double _separatorInset = 12;
const double _separatorThickness = 1;

const EdgeInsets _entryPadding = EdgeInsets.symmetric(
  vertical: 11,
  horizontal: 10,
);

const BorderRadius _entryRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusControl),
);

class SettingsTabRail extends StatelessWidget {
  const SettingsTabRail({
    super.key,
    required this.selected,
    required this.onSelected,
    this.marked = const <SettingsTab>{},
  });

  final SettingsTab selected;
  final ValueChanged<SettingsTab> onSelected;
  final Set<SettingsTab> marked;

  @override
  Widget build(BuildContext context) {
    const double boxGap = settingsTabEntryGap - 2 * _hitInset;
    return SizedBox(
      width: settingsTabRailWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final SettingsTab tab in SettingsTab.values) ...<Widget>[
            if (tab != SettingsTab.values.first) const SizedBox(height: boxGap),
            if (tab == SettingsTab.about) ...<Widget>[
              const _Separator(),
              const SizedBox(height: boxGap),
            ],
            _TabEntry(
              tab: tab,
              selected: tab == selected,
              marked: marked.contains(tab),
              onPressed: () => onSelected(tab),
            ),
          ],
        ],
      ),
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: _separatorInset,
        vertical: _separatorMargin + _hitInset,
      ),
      child: SizedBox(
        key: settingsTabSeparatorKey,
        height: _separatorThickness,
        child: ColoredBox(
          color: context.colors.ink.withValues(
            alpha: settingsTabSeparatorOpacity,
          ),
        ),
      ),
    );
  }
}

class _TabEntry extends StatelessWidget {
  const _TabEntry({
    required this.tab,
    required this.selected,
    required this.marked,
    required this.onPressed,
  });

  final SettingsTab tab;
  final bool selected;
  final bool marked;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Pressable(
      key: settingsTabKey(tab),
      label: tab.label,
      selected: selected,
      onPressed: onPressed,
      borderRadius: _entryRadius,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => Padding(
        padding: const EdgeInsets.symmetric(vertical: _hitInset),
        child: Container(
          key: settingsTabFaceKey(tab),
          constraints: const BoxConstraints(
            minHeight: settingsTabEntryMinHeight,
          ),
          padding: _entryPadding,
          decoration: HoverStyle.decoration(
            color: selected
                ? Palette.coral.withValues(alpha: settingsTabSelectedOpacity)
                : hovered
                ? HoverStyle.of(
                    context,
                    FocusRingSurface.light,
                    HoverShape.rounded,
                  )
                : null,
            shape: HoverShape.rounded,
            borderRadius: _entryRadius,
          ),
          child: Row(
            children: <Widget>[
              SettingsIcon(
                tab.glyph,
                size: settingsTabIconSize,
                color: selected ? colors.accentInk : colors.ink,
              ),
              const SizedBox(width: _iconGap),
              Expanded(
                child: Text(
                  tab.label,
                  style: context.textStyles.labelSans.copyWith(
                    fontSize: _labelSize,
                    fontWeight: FontWeight.w600,
                    color: colors.ink,
                  ),
                ),
              ),
              if (marked) ...<Widget>[
                const SizedBox(width: _iconGap),
                Container(
                  key: settingsTabMarkKey(tab),
                  width: settingsTabMarkSize,
                  height: settingsTabMarkSize,
                  decoration: BoxDecoration(
                    color: Palette.coral,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Palette.coral.withValues(
                          alpha: settingsTabMarkRingOpacity,
                        ),
                        spreadRadius: settingsTabMarkRing,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
