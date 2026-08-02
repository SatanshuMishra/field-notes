import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_route.dart';

import 'capture_chooser_sheet.dart';
import 'capture_routes_provider.dart';

const Duration _kChooserSheetEntrance = Duration(milliseconds: 240);
const Cubic _kChooserSheetCurve = Cubic(0.2, 0.8, 0.2, 1);
const Color _kChooserSheetBarrier = Color(0x572A241D);

Future<EntryType?> showCaptureChooser(
  BuildContext context, {
  required Set<EntryType> availableTypes,
  ShellLayout? layout,
}) {
  final ShellLayout resolved =
      layout ?? resolveShellLayout(Theme.of(context).platform);
  final bool isSheet = resolved == ShellLayout.bottomBar;
  return showGeneralDialog<EntryType>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss capture chooser',
    barrierColor: isSheet
        ? _kChooserSheetBarrier
        : Palette.ink.withValues(alpha: 0.32),
    transitionDuration: isSheet ? _kChooserSheetEntrance : Motion.modalPop,
    pageBuilder: (
      BuildContext dialogContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return DialogHost(
        child: CaptureChooserSheet(
          availableTypes: availableTypes,
          onOptionSelected: (EntryType type) =>
              Navigator.of(dialogContext).pop(type),
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
            CurvedAnimation(parent: animation, curve: _kChooserSheetCurve),
          ),
          child: child,
        );
      }
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
}

Future<String?> openCapture(
  BuildContext context,
  WidgetRef ref, {
  required String date,
}) async {
  final CaptureRouteRegistry registry = ref.read(captureRoutesProvider);
  final Set<EntryType> availableTypes = <EntryType>{
    for (final CaptureRoute route in registry.routes) route.type,
  };

  final EntryType? chosen = await showCaptureChooser(
    context,
    availableTypes: availableTypes,
  );
  if (chosen == null || !context.mounted) {
    return null;
  }

  final CaptureRoute? route = registry.routeFor(chosen);
  if (route == null) {
    return null;
  }
  return route.open(context, date);
}
