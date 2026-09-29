import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:flutter/widgets.dart';

import '../tokens/tokens.dart';

const double _minTapTarget = 48;

const BorderRadius _trackRadius = BorderRadius.all(Radius.circular(15));

class SettingsToggle extends StatelessWidget {
  const SettingsToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? toggle = enabled ? () => onChanged?.call(!value) : null;
    final FieldNotesColors colors = context.colors;
    final Border outline = context.shadows.outline;
    return Semantics(
      container: true,
      excludeSemantics: true,
      label: semanticLabel,
      toggled: value,
      enabled: enabled,
      onTap: toggle,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: toggle,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minWidth: _minTapTarget,
              minHeight: _minTapTarget,
            ),
            child: Center(
              widthFactor: 1,
              heightFactor: 1,
              child: FocusRing(
                enabled: toggle != null,
                onPressed: toggle,
                borderRadius: _trackRadius,
                child: SizedBox(
                  width: 52,
                  height: 30,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: value ? Palette.coral : colors.panelTop,
                      border: outline,
                      borderRadius: _trackRadius,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(3),
                      child: AnimatedAlign(
                        duration: const Duration(milliseconds: 150),
                        alignment: value
                            ? Alignment.centerRight
                            : Alignment.centerLeft,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: colors.cardBright,
                            border: outline,
                            shape: BoxShape.circle,
                          ),
                          child: const SizedBox(width: 22, height: 22),
                        ),
                      ),
                    ),
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
