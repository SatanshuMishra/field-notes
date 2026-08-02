import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/capture_route.dart';
import 'package:field_notes/features/capture/core/composer_shell.dart';
import 'package:field_notes/features/today/today_date.dart';
import 'package:field_notes/features/today/today_providers.dart';

import 'text_composer_sheet.dart';

const String unexpectedSaveMessage =
    'Could not save your note. Please try again.';

const String textSaveTimeoutMessage =
    'Saving took too long. Nothing was saved — please try again.';

const Duration textSaveTimeout = Duration(seconds: 20);

class TextComposerConnector extends ConsumerStatefulWidget {
  const TextComposerConnector({
    super.key,
    required this.date,
    this.saveTimeout = textSaveTimeout,
  });

  final String date;
  final Duration saveTimeout;

  @override
  ConsumerState<TextComposerConnector> createState() =>
      _TextComposerConnectorState();
}

class _TextComposerConnectorState extends ConsumerState<TextComposerConnector> {
  bool _isSaving = false;
  String? _errorMessage;
  late final String _metaText;

  @override
  void initState() {
    super.initState();
    _metaText = _composeMeta();
  }

  String _composeMeta() {
    final DateTime? parsed = parseDateKey(widget.date);
    final String longDate =
        parsed == null ? widget.date : headerDateLabel(parsed);
    final DateTime now = ref.read(todayClockProvider)();
    final String hour = now.hour.toString().padLeft(2, '0');
    final String minute = now.minute.toString().padLeft(2, '0');
    return '$longDate · $hour:$minute';
  }

  Future<void> _save(String text) async {
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    String? entryId;
    final Future<String> pending = _persist(text);
    try {
      entryId = await pending.timeout(widget.saveTimeout);
    } on TimeoutException {
      unawaited(pending.then((_) {}, onError: (_) {}));
      _fail(textSaveTimeoutMessage);
    } on CaptureException catch (error) {
      _fail(error.message);
    } catch (error, stackTrace) {
      debugPrint('Note save failed: $error\n$stackTrace');
      _fail(unexpectedSaveMessage);
    }
    if (entryId == null || !mounted) {
      return;
    }
    Navigator.of(context).pop(entryId);
  }

  Future<String> _persist(String text) async {
    final CaptureService service =
        await ref.read(captureServiceProvider.future);
    final CaptureResult result = await service.capture(
      TextCaptureRequest(date: widget.date, text: text),
    );
    return result.entry.id;
  }

  void _fail(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _isSaving = false;
      _errorMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return TextComposerSheet(
      onSave: _save,
      onCancel: () => Navigator.of(context).pop(),
      errorMessage: _errorMessage,
      isSaving: _isSaving,
      metaText: _metaText,
    );
  }
}

Future<String?> showTextComposer(BuildContext context, String date) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss note composer',
    barrierColor: const Color(0x00000000),
    transitionDuration: Motion.modalPop,
    pageBuilder: (
      BuildContext dialogContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return DialogHost(
        child: ComposerShell(child: TextComposerConnector(date: date)),
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

final CaptureRoute textCaptureRoute = CaptureRoute(
  type: EntryType.text,
  open: showTextComposer,
);
