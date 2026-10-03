import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';

import 'log_viewer_panel.dart';

enum LogViewerExit { back, close }

enum LogViewerOutcome { returned, closedAll, deleted }

const String _barrierLabel = 'Dismiss log viewer';

Future<LogViewerOutcome> showLogViewer(
  BuildContext context, {
  required String date,
  required String entryId,
  required LogViewerExit exit,
}) async {
  if (resolveShellLayout(Theme.of(context).platform) == ShellLayout.bottomBar) {
    final LogViewerOutcome? outcome = await showPhoneSheet<LogViewerOutcome>(
      context,
      barrierLabel: _barrierLabel,
      builder: (BuildContext sheetContext) {
        return LogViewerPanel(
          date: date,
          entryId: entryId,
          exit: exit,
          layout: ShellLayout.bottomBar,
        );
      },
    );
    return outcome ?? LogViewerOutcome.returned;
  }
  final LogViewerOutcome? outcome = await showGeneralDialog<LogViewerOutcome>(
    context: context,
    barrierDismissible: false,
    barrierLabel: _barrierLabel,
    barrierColor: const Color(0x00000000),
    transitionDuration: Motion.modalPop,
    pageBuilder:
        (
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
    transitionBuilder:
        (
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
