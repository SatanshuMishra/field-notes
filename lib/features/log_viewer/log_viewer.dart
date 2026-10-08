import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/entry_cards/playback/playback_focus.dart';

import 'log_viewer_panel.dart';

enum LogViewerExit { back, close }

enum LogViewerOutcome { returned, closedAll, deleted }

const String _barrierLabel = 'Dismiss log viewer';

final Animatable<double> _fade = CurveTween(curve: Motion.entranceCurve);

Future<LogViewerOutcome> showLogViewer(
  BuildContext context, {
  required String date,
  required String entryId,
  required LogViewerExit exit,
  ValueChanged<String>? onReadNote,
}) async {
  playbackFocus.silence();
  final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  final bool phone =
      resolveShellLayout(Theme.of(context).platform) == ShellLayout.bottomBar;
  final Duration entrance = phone ? phoneSheetEntrance : Motion.modalPop;
  final LogViewerOutcome? outcome = await showGeneralDialog<LogViewerOutcome>(
    context: context,
    barrierDismissible: false,
    barrierLabel: _barrierLabel,
    barrierColor: const Color(0x00000000),
    transitionDuration: still ? Duration.zero : entrance,
    pageBuilder:
        (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          return DialogHost(
            child: LogViewerPanel(
              date: date,
              entryId: entryId,
              exit: exit,
              onReadNote: onReadNote,
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
          return FadeTransition(opacity: animation.drive(_fade), child: child);
        },
  );
  return outcome ?? LogViewerOutcome.returned;
}
