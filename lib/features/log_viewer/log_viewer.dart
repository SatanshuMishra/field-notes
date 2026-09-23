import 'package:flutter/widgets.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';

import 'log_viewer_panel.dart';

enum LogViewerExit { back, close }

enum LogViewerOutcome { returned, closedAll, deleted }

Future<LogViewerOutcome> showLogViewer(
  BuildContext context, {
  required String date,
  required String entryId,
  required LogViewerExit exit,
}) async {
  final LogViewerOutcome? outcome = await showGeneralDialog<LogViewerOutcome>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Dismiss log viewer',
    barrierColor: const Color(0x00000000),
    transitionDuration: Motion.modalPop,
    pageBuilder: (
      BuildContext dialogContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return DialogHost(
        child: ComposerShell(
          closeOnScrimTap: true,
          responsive: true,
          child: LogViewerPanel(date: date, entryId: entryId, exit: exit),
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
        curve: Motion.entranceCurve,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
  return outcome ?? LogViewerOutcome.returned;
}
