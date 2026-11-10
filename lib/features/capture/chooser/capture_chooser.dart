import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_route.dart';

import 'capture_chooser_sheet.dart';
import 'capture_routes_provider.dart';

const String _kChooserBarrierLabel = 'Dismiss capture chooser';
const double _kPageEntryDrop = 12;
const double _kPageEntryTurnDegrees = -1.4;

Future<EntryType?> showCaptureChooser(
  BuildContext context, {
  required Set<EntryType> availableTypes,
  ShellLayout? layout,
}) {
  final ShellLayout resolved =
      layout ?? resolveShellLayout(Theme.of(context).platform);
  if (resolved == ShellLayout.bottomBar) {
    return showPhoneSheet<EntryType>(
      context,
      barrierLabel: _kChooserBarrierLabel,
      builder: (BuildContext sheetContext) {
        return CaptureChooserSheet(
          availableTypes: availableTypes,
          onOptionSelected: (EntryType type) =>
              Navigator.of(sheetContext).pop(type),
          layout: resolved,
        );
      },
    );
  }
  final bool still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  return showGeneralDialog<EntryType>(
    context: context,
    barrierDismissible: true,
    barrierLabel: _kChooserBarrierLabel,
    barrierColor: FieldNotesColors.light.ink.withValues(alpha: 0.32),
    transitionDuration: still ? Duration.zero : Motion.modalPop,
    pageBuilder:
        (
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
            child: AnimatedBuilder(
              animation: curved,
              child: child,
              builder: (BuildContext _, Widget? page) {
                final double left = 1 - curved.value;
                return Transform.translate(
                  offset: Offset(0, _kPageEntryDrop * left),
                  child: Transform.rotate(
                    angle: _kPageEntryTurnDegrees * math.pi / 180 * left,
                    child: page,
                  ),
                );
              },
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
