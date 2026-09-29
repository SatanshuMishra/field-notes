import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:flutter/material.dart';

import 'setup_week_step.dart';

const Key setupStorageDeviceKey = ValueKey<String>('setup-storage-device');
const Key setupStorageServerKey = ValueKey<String>('setup-storage-server');

const double _optionHeight = 60;
const double _optionGap = 10;
const double _iconBox = 36;
const double _iconSize = 18;
const double _optionBorderWidth = 2;
const double _disabledOpacity = 0.5;

const BorderRadius _optionRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusMd),
);

TextStyle _titleStyle(FieldNotesColors colors) => TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 14,
  fontWeight: FontWeight.w600,
  color: colors.ink,
);

TextStyle _subtitleStyle(FieldNotesColors colors) => TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 11.5,
  fontWeight: FontWeight.w400,
  color: colors.muted,
);

class SetupStorageStep extends StatelessWidget {
  const SetupStorageStep({super.key, required this.layout});

  final ShellLayout layout;

  static void _keepOnDevice() {}

  @override
  Widget build(BuildContext context) {
    final bool sidebar = layout == ShellLayout.sidebar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _StorageOption(
          key: setupStorageDeviceKey,
          icon: Icons.lock_outline_rounded,
          title: 'This device',
          subtitle: 'Private · no account needed',
          selected: true,
          compact: !sidebar,
          onPressed: _keepOnDevice,
        ),
        const SizedBox(height: _optionGap),
        _StorageOption(
          key: setupStorageServerKey,
          icon: Icons.sync_rounded,
          title: 'My own server',
          subtitle: 'Arrives in a future update',
          selected: false,
          compact: !sidebar,
          onPressed: null,
        ),
      ],
    );
  }
}

class _StorageOption extends StatelessWidget {
  const _StorageOption({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.compact,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final bool compact;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    final bool enabled = onPressed != null;
    return Semantics(
      checked: selected,
      inMutuallyExclusiveGroup: true,
      enabled: enabled,
      label: '$title, $subtitle',
      child: Opacity(
        opacity: enabled ? 1 : _disabledOpacity,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: FocusRing(
            enabled: enabled,
            onPressed: onPressed,
            borderRadius: _optionRadius,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: _optionHeight),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: selected ? colors.cardLight : colors.cardWarm,
                  border: Border.all(
                    color: selected ? Palette.coral : colors.ink22,
                    width: _optionBorderWidth,
                  ),
                  borderRadius: _optionRadius,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: ExcludeSemantics(
                    child: Row(
                      children: <Widget>[
                        SizedBox.square(
                          dimension: _iconBox,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: selected
                                  ? Palette.coral
                                  : colors.cardBright,
                              border: context.shadows.outline,
                              borderRadius: const BorderRadius.all(
                                Radius.circular(Shapes.radiusCell),
                              ),
                            ),
                            child: Icon(
                              icon,
                              size: _iconSize,
                              color: selected ? Palette.onAccent : colors.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(title, style: _titleStyle(colors)),
                              Text(
                                subtitle,
                                style: compact
                                    ? _subtitleStyle(
                                        colors,
                                      ).copyWith(fontSize: 11)
                                    : _subtitleStyle(colors),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SetupRadioDot(selected: selected),
                      ],
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
