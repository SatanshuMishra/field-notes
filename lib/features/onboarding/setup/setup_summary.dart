import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:flutter/material.dart';

import '../onboarding_surface.dart';
import 'setup_reminder_step.dart';

const Key setupSummaryChangeReminderKey = ValueKey<String>(
  'setup-summary-change-reminder',
);
const Key setupSummaryChangeWeekKey = ValueKey<String>(
  'setup-summary-change-week',
);
const Key setupSummaryChangeStorageKey = ValueKey<String>(
  'setup-summary-change-storage',
);

const String _changeLabel = 'Change';

const double _rowHeight = 56;
const double _iconSize = 18;

const TextStyle _rowLabelStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 9.5,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.86,
  color: Palette.muted,
);

const TextStyle _rowValueStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 14,
  fontWeight: FontWeight.w600,
  color: Palette.ink,
);

const TextStyle _changeStyle = TextStyle(
  fontFamily: TypographyTokens.sans,
  fontSize: 12,
  fontWeight: FontWeight.w600,
  color: Palette.coral,
);

class SetupSummary extends StatelessWidget {
  const SetupSummary({
    super.key,
    required this.layout,
    required this.reminderEnabled,
    required this.time,
    required this.weekStart,
    required this.onChangeReminder,
    required this.onChangeWeek,
    required this.onChangeStorage,
  });

  final ShellLayout layout;
  final bool reminderEnabled;
  final ReminderTime time;
  final WeekStart weekStart;
  final VoidCallback onChangeReminder;
  final VoidCallback onChangeWeek;
  final VoidCallback onChangeStorage;

  @override
  Widget build(BuildContext context) {
    final bool compact = layout == ShellLayout.bottomBar;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Palette.cardWarm,
        border: Shapes.outline,
        borderRadius: BorderRadius.all(Radius.circular(Shapes.radiusMd)),
        boxShadow: Shadows.cardDefault,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _SummaryRow(
            icon: Icons.notifications_none_rounded,
            label: 'Reminder',
            value: reminderEnabled
                ? 'Daily at ${formatSetupTime(time)}'
                : 'Off',
            changeKey: setupSummaryChangeReminderKey,
            changeName: 'Change reminder',
            compact: compact,
            onChange: onChangeReminder,
          ),
          const DashedDivider(thickness: 1, color: Palette.ink20),
          _SummaryRow(
            icon: Icons.calendar_today_outlined,
            label: 'Week starts on',
            value: weekStart.label,
            changeKey: setupSummaryChangeWeekKey,
            changeName: 'Change week start',
            compact: compact,
            onChange: onChangeWeek,
          ),
          const DashedDivider(thickness: 1, color: Palette.ink20),
          _SummaryRow(
            icon: Icons.lock_outline_rounded,
            label: 'Entries live',
            value: 'On this device',
            changeKey: setupSummaryChangeStorageKey,
            changeName: 'Change where entries live',
            compact: compact,
            onChange: onChangeStorage,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.changeKey,
    required this.changeName,
    required this.compact,
    required this.onChange,
  });

  final IconData icon;
  final String label;
  final String value;
  final Key changeKey;
  final String changeName;
  final bool compact;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: _rowHeight),
      child: Padding(
        padding: const EdgeInsets.only(left: 14, right: 6),
        child: Row(
          children: <Widget>[
            ExcludeSemantics(
              child: Icon(icon, size: _iconSize, color: Palette.ink),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Semantics(
                container: true,
                label: '$label: $value',
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(label.toUpperCase(), style: _rowLabelStyle),
                      const SizedBox(height: 1),
                      Text(
                        value,
                        style: compact
                            ? _rowValueStyle.copyWith(fontSize: 13.5)
                            : _rowValueStyle,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            OnboardingTextButton(
              key: changeKey,
              label: _changeLabel,
              semanticLabel: changeName,
              onPressed: onChange,
              style: _changeStyle,
            ),
          ],
        ),
      ),
    );
  }
}
