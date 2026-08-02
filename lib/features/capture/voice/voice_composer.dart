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

import 'voice_recorder.dart';
import 'voice_recorder_provider.dart';
import 'voice_recorder_sheet.dart';

const String unexpectedVoiceSaveMessage =
    'Could not save your recording. Please try again.';

const String voiceSaveTimeoutMessage =
    'Saving took too long. Nothing was saved — please try again.';

const Duration voiceSaveTimeout = Duration(seconds: 20);

class VoiceComposerConnector extends ConsumerStatefulWidget {
  const VoiceComposerConnector({
    super.key,
    required this.date,
    this.saveTimeout = voiceSaveTimeout,
  });

  final String date;
  final Duration saveTimeout;

  @override
  ConsumerState<VoiceComposerConnector> createState() =>
      _VoiceComposerConnectorState();
}

class _VoiceComposerConnectorState
    extends ConsumerState<VoiceComposerConnector> {
  VoiceRecorderPhase _phase = VoiceRecorderPhase.idle;
  String? _errorMessage;

  VoiceRecorder get _recorder => ref.read(voiceRecorderProvider);

  Future<void> _start() async {
    setState(() => _errorMessage = null);
    final VoiceRecorder recorder = _recorder;
    try {
      final bool granted = await recorder.hasPermission();
      if (!mounted) {
        return;
      }
      if (!granted) {
        setState(() => _errorMessage = micPermissionMessage);
        return;
      }
      await recorder.start();
      if (!mounted) {
        return;
      }
      setState(() => _phase = VoiceRecorderPhase.recording);
    } on VoiceRecorderException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.message);
    }
  }

  Future<void> _stop() async {
    setState(() {
      _phase = VoiceRecorderPhase.saving;
      _errorMessage = null;
    });
    String? entryId;
    final Future<String> pending = _persist();
    try {
      entryId = await pending.timeout(widget.saveTimeout);
    } on TimeoutException {
      unawaited(pending.then((_) {}, onError: (_) {}));
      _failBackToRecording(voiceSaveTimeoutMessage);
    } on VoiceRecorderException catch (error) {
      _failBackToRecording(error.message);
    } on CaptureException catch (error) {
      _failBackToRecording(error.message);
    } catch (error, stackTrace) {
      debugPrint('Voice save failed: $error\n$stackTrace');
      _failBackToRecording(unexpectedVoiceSaveMessage);
    }
    if (entryId == null || !mounted) {
      return;
    }
    Navigator.of(context).pop(entryId);
  }

  Future<String> _persist() async {
    final VoiceRecording recording = await _recorder.stop();
    final CaptureService service =
        await ref.read(captureServiceProvider.future);
    final CaptureResult result = await service.capture(
      VoiceCaptureRequest(
        date: widget.date,
        audio: recording.media,
        durationMs: recording.durationMs,
      ),
    );
    return result.entry.id;
  }

  void _failBackToRecording(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _phase = VoiceRecorderPhase.recording;
      _errorMessage = message;
    });
  }

  Future<void> _cancel() async {
    if (_phase == VoiceRecorderPhase.recording) {
      await _recorder.cancel();
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return VoiceRecorderSheet(
      phase: _phase,
      onStart: _start,
      onStop: _stop,
      onCancel: _cancel,
      errorMessage: _errorMessage,
    );
  }
}

Future<String?> showVoiceComposer(BuildContext context, String date) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Dismiss voice recorder',
    barrierColor: const Color(0x00000000),
    transitionDuration: Motion.modalPop,
    pageBuilder: (
      BuildContext dialogContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return DialogHost(
        child: ComposerShell(child: VoiceComposerConnector(date: date)),
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

final CaptureRoute voiceCaptureRoute = CaptureRoute(
  type: EntryType.voice,
  open: showVoiceComposer,
);
