import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/interaction/hover_fill.dart';
import 'package:field_notes/design/interaction/hover_style.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:flutter/material.dart';

import '../tokens/tokens.dart';

const String settingsToggleFallbackLabel = 'Switch';

const Duration _knobTravel = Duration(milliseconds: 150);

class _ToggleMetrics {
  const _ToggleMetrics({
    required this.trackWidth,
    required this.trackHeight,
    required this.trackRadius,
    required this.inset,
    required this.knob,
    required this.knobBorder,
    required this.minTargetWidth,
    required this.minTargetHeight,
  });

  static const _ToggleMetrics phone = _ToggleMetrics(
    trackWidth: 52,
    trackHeight: 30,
    trackRadius: BorderRadius.all(Radius.circular(15)),
    inset: 3,
    knob: 22,
    knobBorder: Shapes.outlineWidth,
    minTargetWidth: 48,
    minTargetHeight: 48,
  );

  static const _ToggleMetrics sidebar = _ToggleMetrics(
    trackWidth: 36,
    trackHeight: 20,
    trackRadius: BorderRadius.all(Radius.circular(10)),
    inset: Shapes.outlineWidth + 1.5,
    knob: 14,
    knobBorder: 1.2,
    minTargetWidth: 36,
    minTargetHeight: 24,
  );

  final double trackWidth;
  final double trackHeight;
  final BorderRadius trackRadius;
  final double inset;
  final double knob;
  final double knobBorder;
  final double minTargetWidth;
  final double minTargetHeight;
}

class SettingsToggle extends StatelessWidget {
  const SettingsToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.semanticLabel = settingsToggleFallbackLabel,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final bool enabled;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final VoidCallback? toggle = enabled ? () => onChanged?.call(!value) : null;
    final FieldNotesColors colors = context.colors;
    final Border outline = context.shadows.outline;
    final _ToggleMetrics metrics = switch (resolveShellLayout(
      Theme.of(context).platform,
    )) {
      ShellLayout.sidebar => _ToggleMetrics.sidebar,
      ShellLayout.bottomBar => _ToggleMetrics.phone,
    };
    final FocusRingSurface hoverSurface = value
        ? FocusRingSurface.dark
        : FocusRingSurface.light;
    return Pressable(
      label: semanticLabel,
      toggled: value,
      onPressed: toggle,
      borderRadius: metrics.trackRadius,
      shape: HoverShape.pill,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: metrics.minTargetWidth,
            minHeight: metrics.minTargetHeight,
          ),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: SizedBox(
              width: metrics.trackWidth,
              height: metrics.trackHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: value ? Palette.coral : colors.panelTop,
                  border: outline,
                  borderRadius: metrics.trackRadius,
                ),
                child: HoverFill(
                  hovered: hovered,
                  surface: hoverSurface,
                  shape: HoverShape.pill,
                  borderRadius: metrics.trackRadius,
                  position: DecorationPosition.background,
                  child: Padding(
                    padding: EdgeInsets.all(metrics.inset),
                    child: AnimatedAlign(
                      duration: _knobTravel,
                      alignment: value
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colors.cardBright,
                          border: Border.all(
                            color: colors.line,
                            width: metrics.knobBorder,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(
                          width: metrics.knob,
                          height: metrics.knob,
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
