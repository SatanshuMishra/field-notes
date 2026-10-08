import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/widgets.dart';

enum SettingsTab {
  journal(label: 'Journal', sublabel: 'theme, calendar, text size'),
  syncStorage(label: 'Sync & storage', sublabel: 'where entries live'),
  remindersSound(label: 'Reminders & sound', sublabel: 'nudges, prompts'),
  data(label: 'Data', sublabel: 'export, delete');

  const SettingsTab({required this.label, required this.sublabel});

  final String label;
  final String sublabel;
}

const Key settingsTabRailKey = ValueKey<String>('settings-tab-rail');

ValueKey<String> settingsTabKey(SettingsTab tab) =>
    ValueKey<String>('settings-tab-${tab.name}');

const double settingsTabRailWidth = 196;

const double _railGap = 6;
const double _sublabelGap = 1;

const EdgeInsets _railItemPadding = EdgeInsets.symmetric(
  horizontal: 13,
  vertical: 10,
);

const BorderRadius _railItemRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusControl),
);

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
              child: _RailFace(tab: tab, selected: tab == selected),
            ),
          ],
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
    required this.child,
  });

  final SettingsTab tab;
  final bool selected;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: settingsTabKey(tab),
      button: true,
      selected: selected,
      label: tab.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: FocusRing(
          onPressed: onPressed,
          borderRadius: _railItemRadius,
          child: ExcludeSemantics(child: child),
        ),
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
