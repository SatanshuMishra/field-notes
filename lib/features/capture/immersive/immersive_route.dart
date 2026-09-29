import 'package:flutter/material.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/dialog_host.dart';
import 'package:field_notes/design/feedback/toast.dart';

import 'stage_phase.dart';

const Duration immersiveSidebarFade = Duration(milliseconds: 600);
const Duration immersiveBottomBarFade = Duration(milliseconds: 500);

const Color _clearBarrier = Color(0x00000000);

Duration immersiveFadeFor(ShellLayout layout) => layout == ShellLayout.sidebar
    ? immersiveSidebarFade
    : immersiveBottomBarFade;

Future<T?> showImmersiveRecorder<T>(
  BuildContext context, {
  required String barrierLabel,
  required WidgetBuilder builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: false,
    barrierLabel: barrierLabel,
    barrierColor: _clearBarrier,
    transitionDuration: immersiveFadeFor(stageLayoutOf(context)),
    pageBuilder:
        (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
        ) {
          return DialogHost(
            child: SizedBox.expand(child: Builder(builder: builder)),
          );
        },
    transitionBuilder:
        (
          BuildContext dialogContext,
          Animation<double> animation,
          Animation<double> secondaryAnimation,
          Widget child,
        ) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.ease),
            child: child,
          );
        },
  );
}

void closeImmersiveRecorder<T extends Object?>(
  BuildContext context, {
  T? result,
  String? toast,
}) {
  if (toast != null) {
    showTransientToast(
      context,
      toast,
      after: ModalRoute.of(context)?.completed,
    );
  }
  Navigator.of(context).pop<T>(result);
}
