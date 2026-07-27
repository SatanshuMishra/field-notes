import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/capture/core/capture_route.dart';

import 'capture_chooser_sheet.dart';
import 'capture_routes_provider.dart';

Future<EntryType?> showCaptureChooser(
  BuildContext context, {
  required Set<EntryType> availableTypes,
}) {
  return showGeneralDialog<EntryType>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss capture chooser',
    barrierColor: Palette.ink.withValues(alpha: 0.32),
    transitionDuration: Motion.modalPop,
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
