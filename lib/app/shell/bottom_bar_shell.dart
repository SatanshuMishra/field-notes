import 'package:flutter/material.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/features/calendar/widgets/calendar_chevron_button.dart';

import '../../design/tokens/tokens.dart';
import 'keep_focus_in_view.dart';
import 'shell_destination.dart';

class BottomBarShell extends StatelessWidget {
  const BottomBarShell({
    super.key,
    required this.destinations,
    required this.selected,
    required this.onSelect,
    required this.onCapture,
    required this.body,
    this.obscured = false,
    this.appearanceToggle,
  }) : assert(
         destinations.length == 4,
         'BottomBarShell requires four destinations',
       );

  final List<ShellDestination> destinations;
  final ShellDestination selected;
  final ValueChanged<ShellDestination> onSelect;
  final VoidCallback onCapture;
  final Widget body;
  final bool obscured;
  final Widget? appearanceToggle;

  @override
  Widget build(BuildContext context) {
    return KeepFocusInView(
      child: ExcludeSemantics(
        excluding: obscured,
        child: ExcludeFocus(
          excluding: obscured,
          child: AbsorbPointer(
            absorbing: obscured,
            child: Scaffold(
              backgroundColor: context.colors.panelTop,
              body: SafeArea(
                bottom: false,
                child: Column(
                  children: <Widget>[
                    FocusTraversalGroup(child: _topBar(context)),
                    Expanded(child: FocusTraversalGroup(child: body)),
                  ],
                ),
              ),
              bottomNavigationBar: FocusTraversalGroup(
                child: _bottomBar(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      child: Row(
        children: <Widget>[
          Text('field notes', style: context.textStyles.wordmarkAccent),
          const Spacer(),
          ?appearanceToggle,
          Semantics(
            button: true,
            label: 'Settings',
            child: GestureDetector(
              key: const ValueKey<String>('gear-button'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(ShellDestination.settings),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minWidth: kMinInteractiveDimension,
                  minHeight: kMinInteractiveDimension,
                ),
                child: Center(
                  widthFactor: 1,
                  heightFactor: 1,
                  child: FocusRing(
                    onPressed: () => onSelect(ShellDestination.settings),
                    borderRadius: _gearRadius,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: ExcludeSemantics(
                        child: Icon(
                          Icons.settings_outlined,
                          color: context.colors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.panelTop,
        border: Border(
          top: BorderSide(color: colors.line, width: Shapes.outlineWidth),
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
              _tab(context, destinations[0]),
              _tab(context, destinations[1]),
              _captureButton(context),
              _tab(context, destinations[2]),
              _tab(context, destinations[3]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tab(BuildContext context, ShellDestination d) {
    final FieldNotesColors colors = context.colors;
    final bool isSelected = d == selected;
    final Color color = isSelected ? colors.accentInk : colors.mutedDeep;
    return CalendarTapArea(
      reach: const EdgeInsets.symmetric(
        horizontal: kMinInteractiveDimension / 2,
      ),
      child: Semantics(
        button: true,
        selected: isSelected,
        label: d.label,
        child: GestureDetector(
          key: ValueKey<String>('tab-${d.name}'),
          behavior: HitTestBehavior.opaque,
          onTap: () => onSelect(d),
          child: FocusRing(
            onPressed: () => onSelect(d),
            borderRadius: _tabRadius,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
              child: ExcludeSemantics(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(d.icon, size: 22, color: color),
                    const SizedBox(height: 2),
                    Text(
                      d.label,
                      style: context.textStyles.captionSans.copyWith(
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _captureButton(BuildContext context) {
    return Semantics(
      button: true,
      label: 'New entry',
      child: GestureDetector(
        key: const ValueKey<String>('capture-button'),
        behavior: HitTestBehavior.opaque,
        onTap: onCapture,
        child: FocusRing(
          onPressed: onCapture,
          borderRadius: _captureRadius,
          child: Container(
            width: _captureExtent,
            height: _captureExtent,
            decoration: BoxDecoration(
              color: Palette.coral,
              shape: BoxShape.circle,
              border: Border.all(
                color: context.colors.line,
                width: Shapes.outlineWidth,
              ),
              boxShadow: context.shadows.button,
            ),
            child: ExcludeSemantics(
              child: Icon(
                Icons.add,
                color: FieldNotesColors.light.cardBright,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const double _captureExtent = 52;

const BorderRadius _captureRadius = BorderRadius.all(
  Radius.circular(_captureExtent / 2),
);

const BorderRadius _gearRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusControl),
);

const BorderRadius _tabRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusControl),
);
