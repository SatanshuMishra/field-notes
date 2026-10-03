import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:flutter/material.dart';

const String reminderTimeSheetTitle = 'Reminder time';
const String reminderTimeSheetDoneLabel = 'Done';
const String reminderTimeHourUpLabel = 'Hour up';
const String reminderTimeHourDownLabel = 'Hour down';
const String reminderTimeMinuteUpLabel = 'Minute up';
const String reminderTimeMinuteDownLabel = 'Minute down';

const Key reminderTimeSheetDoneKey = ValueKey<String>('reminder-time-done');

const int reminderTimeMinuteStep = 5;

const double reminderTimeStepperWidth = 64;
const double reminderTimeStepperHeight = 44;
const double reminderTimeDigitSize = 40;
const double reminderTimeDigitWidth = 72;

const EdgeInsets _bodyPadding = EdgeInsets.only(top: 16, bottom: 6);
const double _columnGap = 8;
const double _stepGap = 5;
const double _separatorSize = 26;
const double _caretSize = 13;
const double _stepperBorderWidth = 1.5;
const BorderRadius _stepperRadius = BorderRadius.all(Radius.circular(8));

Future<TimeOfDay?> showReminderTimeSheet(
  BuildContext context,
  TimeOfDay initial,
) {
  return showPhoneSheet<TimeOfDay>(
    context,
    builder: (BuildContext sheetContext) => ReminderTimeSheet(
      initial: initial,
      onDone: (TimeOfDay time) => Navigator.of(sheetContext).pop(time),
    ),
  );
}

TimeOfDay stepReminderHour(TimeOfDay time, int direction) => TimeOfDay(
  hour: (time.hour + direction) % TimeOfDay.hoursPerDay,
  minute: time.minute,
);

TimeOfDay stepReminderMinute(TimeOfDay time, int direction) => TimeOfDay(
  hour: time.hour,
  minute:
      (time.minute + direction * reminderTimeMinuteStep) %
      TimeOfDay.minutesPerHour,
);

String _twoDigits(int value) => value.toString().padLeft(2, '0');

class ReminderTimeSheet extends StatefulWidget {
  const ReminderTimeSheet({
    super.key,
    required this.initial,
    required this.onDone,
  });

  final TimeOfDay initial;
  final ValueChanged<TimeOfDay> onDone;

  @override
  State<ReminderTimeSheet> createState() => _ReminderTimeSheetState();
}

class _ReminderTimeSheetState extends State<ReminderTimeSheet> {
  late TimeOfDay _time = widget.initial;

  void _step(TimeOfDay Function(TimeOfDay time, int direction) step, int by) {
    setState(() => _time = step(_time, by));
  }

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return PhoneSheet(
      title: reminderTimeSheetTitle,
      footerDirection: Axis.vertical,
      actions: <Widget>[
        PhoneSheetButton(
          key: reminderTimeSheetDoneKey,
          label: reminderTimeSheetDoneLabel,
          background: Palette.coral,
          foreground: Palette.onAccent,
          shadows: context.shadows.emphasis,
          onPressed: () => widget.onDone(_time),
        ),
      ],
      child: Padding(
        padding: _bodyPadding,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _StepperColumn(
              name: 'Hour',
              value: _time.hour,
              upLabel: reminderTimeHourUpLabel,
              downLabel: reminderTimeHourDownLabel,
              onUp: () => _step(stepReminderHour, 1),
              onDown: () => _step(stepReminderHour, -1),
            ),
            const SizedBox(width: _columnGap),
            ExcludeSemantics(
              child: Text(
                ':',
                style: TextStyle(
                  fontFamily: TypographyTokens.serif,
                  fontSize: _separatorSize,
                  fontWeight: FontWeight.w500,
                  color: colors.ink,
                ),
              ),
            ),
            const SizedBox(width: _columnGap),
            _StepperColumn(
              name: 'Minute',
              value: _time.minute,
              upLabel: reminderTimeMinuteUpLabel,
              downLabel: reminderTimeMinuteDownLabel,
              onUp: () => _step(stepReminderMinute, 1),
              onDown: () => _step(stepReminderMinute, -1),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperColumn extends StatelessWidget {
  const _StepperColumn({
    required this.name,
    required this.value,
    required this.upLabel,
    required this.downLabel,
    required this.onUp,
    required this.onDown,
  });

  final String name;
  final int value;
  final String upLabel;
  final String downLabel;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    final String digits = _twoDigits(value);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        _StepperButton(label: upLabel, up: true, onPressed: onUp),
        const SizedBox(height: _stepGap),
        Semantics(
          label: name,
          value: digits,
          liveRegion: true,
          child: ExcludeSemantics(
            child: SizedBox(
              width: reminderTimeDigitWidth,
              child: Text(
                digits,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: TypographyTokens.serif,
                  fontSize: reminderTimeDigitSize,
                  fontWeight: FontWeight.w500,
                  height: 1,
                  color: context.colors.ink,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: _stepGap),
        _StepperButton(label: downLabel, up: false, onPressed: onDown),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({
    required this.label,
    required this.up,
    required this.onPressed,
  });

  final String label;
  final bool up;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final FieldNotesColors colors = context.colors;
    return Semantics(
      button: true,
      label: label,
      onTap: onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onPressed,
        child: FocusRing(
          onPressed: onPressed,
          includeFocusSemantics: false,
          borderRadius: _stepperRadius,
          child: SizedBox(
            width: reminderTimeStepperWidth,
            height: reminderTimeStepperHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: colors.cardLight,
                border: Border.all(
                  color: colors.line,
                  width: _stepperBorderWidth,
                ),
                borderRadius: _stepperRadius,
              ),
              child: Center(
                child: Icon(
                  up ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                  size: _caretSize,
                  color: colors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
