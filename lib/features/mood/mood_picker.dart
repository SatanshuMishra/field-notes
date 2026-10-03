import 'package:flutter/material.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/mood/mood.dart';

import 'mood_picker_sheet.dart';

const Duration _kMoodPickerEntrance = Duration(milliseconds: 180);
const String _kMoodPickerBarrierLabel = 'Dismiss mood picker';

Future<Mood?> showMoodPicker(
  BuildContext context, {
  Mood? selected,
  ShellLayout? layout,
}) {
  final ShellLayout resolved =
      layout ?? resolveShellLayout(Theme.of(context).platform);
  if (resolved == ShellLayout.bottomBar) {
    return showPhoneSheet<Mood>(
      context,
      barrierLabel: _kMoodPickerBarrierLabel,
      builder: (BuildContext sheetContext) {
        return MoodPickerSheet(
          selected: selected,
          onMoodSelected: (Mood mood) => Navigator.of(sheetContext).pop(mood),
          layout: resolved,
        );
      },
    );
  }
  return showGeneralDialog<Mood>(
    context: context,
    barrierDismissible: true,
    barrierLabel: _kMoodPickerBarrierLabel,
    barrierColor: const Color(0x472A241D),
    transitionDuration: _kMoodPickerEntrance,
    pageBuilder:
        (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          return DialogHost(
            child: MoodPickerSheet(
              selected: selected,
              onMoodSelected: (Mood mood) =>
                  Navigator.of(dialogContext).pop(mood),
              layout: resolved,
            ),
          );
        },
    transitionBuilder:
        (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          final Animation<double> curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOut,
          );
          return FadeTransition(
            opacity: curved,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(curved),
              child: child,
            ),
          );
        },
  );
}
