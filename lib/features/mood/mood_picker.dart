import 'package:flutter/material.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/domain/mood/mood.dart';

import 'mood_picker_sheet.dart';

const Duration _kMoodPickerEntrance = Duration(milliseconds: 180);
const Duration _kMoodSheetEntrance = Duration(milliseconds: 240);
const Cubic _kMoodSheetCurve = Cubic(0.2, 0.8, 0.2, 1);

Future<Mood?> showMoodPicker(
  BuildContext context, {
  Mood? selected,
  ShellLayout? layout,
}) {
  final ShellLayout resolved =
      layout ?? resolveShellLayout(Theme.of(context).platform);
  final bool isSheet = resolved == ShellLayout.bottomBar;
  return showGeneralDialog<Mood>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss mood picker',
    barrierColor: isSheet ? const Color(0x572A241D) : const Color(0x472A241D),
    transitionDuration: isSheet ? _kMoodSheetEntrance : _kMoodPickerEntrance,
    pageBuilder: (
      BuildContext dialogContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return DialogHost(
        child: MoodPickerSheet(
          selected: selected,
          onMoodSelected: (Mood mood) => Navigator.of(dialogContext).pop(mood),
          layout: resolved,
        ),
      );
    },
    transitionBuilder: (
      BuildContext dialogContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,
    ) {
      if (isSheet) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: _kMoodSheetCurve),
          ),
          child: child,
        );
      }
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
