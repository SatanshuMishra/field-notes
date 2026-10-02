import 'package:flutter/material.dart';

import 'package:field_notes/design/focus/focus_ring.dart';

import '../../design/tokens/tokens.dart';
import 'keep_focus_in_view.dart';
import 'phone_bottom_bar.dart';
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
                child: PhoneBottomBar(
                  destinations: destinations,
                  selected: selected,
                  onSelect: onSelect,
                  onCapture: onCapture,
                ),
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
}

const BorderRadius _gearRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusControl),
);
