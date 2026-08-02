import 'package:flutter/widgets.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/domain/mood/mood.dart';

import 'mood_picker_sheet.dart';

const Duration _kMoodPickerEntrance = Duration(milliseconds: 180);

Future<Mood?> showMoodPicker(
  BuildContext context, {
  Mood? selected,
}) {
  return showGeneralDialog<Mood>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss mood picker',
    barrierColor: const Color(0x472A241D),
    transitionDuration: _kMoodPickerEntrance,
    pageBuilder: (
      BuildContext dialogContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return DialogHost(
        child: MoodPickerSheet(
          selected: selected,
          onMoodSelected: (Mood mood) => Navigator.of(dialogContext).pop(mood),
        ),
      );
    },
    transitionBuilder: (
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
