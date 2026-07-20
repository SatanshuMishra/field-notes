import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/capture_route.dart';

import 'text_composer_sheet.dart';

const String unexpectedSaveMessage =
    'Could not save your note. Please try again.';

class TextComposerConnector extends ConsumerStatefulWidget {
  const TextComposerConnector({super.key, required this.date});

  final String date;

  @override
  ConsumerState<TextComposerConnector> createState() =>
      _TextComposerConnectorState();
}

class _TextComposerConnectorState extends ConsumerState<TextComposerConnector> {
  bool _isSaving = false;
  String? _errorMessage;

  Future<void> _save(String text) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final CaptureService service =
          await ref.read(captureServiceProvider.future);
      final CaptureResult result = await service.capture(
        TextCaptureRequest(date: widget.date, text: text),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(result.entry.id);
    } on CaptureException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isSaving = false;
        _errorMessage = unexpectedSaveMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextComposerSheet(
      onSave: _save,
      onCancel: () => Navigator.of(context).pop(),
      errorMessage: _errorMessage,
      isSaving: _isSaving,
    );
  }
}

Future<String?> showTextComposer(BuildContext context, String date) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss note composer',
    barrierColor: Palette.ink.withValues(alpha: 0.32),
    transitionDuration: Motion.modalPop,
    pageBuilder: (
      BuildContext dialogContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return TextComposerConnector(date: date);
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

final CaptureRoute textCaptureRoute = CaptureRoute(
  type: EntryType.text,
  open: showTextComposer,
);
