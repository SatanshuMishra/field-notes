import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/widgets.dart';
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

const Duration voiceElapsedTick = Duration(milliseconds: 250);

const String voiceDiscardConfirmTitle = 'Discard this recording?';
const String voiceDiscardConfirmMessage =
    'This take will be thrown away and nothing will be saved.';
const String voiceDiscardConfirmLabel = 'Discard';
const String voiceDiscardConfirmCancelLabel = 'Cancel';
const String voiceDiscardedToastMessage = 'Recording discarded';
const String voiceSavedToastMessage = 'Voice memo saved';

const Key voiceDiscardConfirmKey = ValueKey<String>('voice-discard-confirm');

const double _confirmMaxWidth = 420;
const double _confirmTitleGap = 8;
const double _confirmActionsGap = 20;
const double _confirmActionSpacing = 12;

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
  Duration _elapsed = Duration.zero;
  Timer? _elapsedTicker;

  VoiceRecorder get _recorder => ref.read(voiceRecorderProvider);

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }

  void _startTicker() {
    _elapsedTicker?.cancel();
    _elapsedTicker = Timer.periodic(voiceElapsedTick, (Timer _) {
      if (!mounted) {
        return;
      }
      setState(() => _elapsed = _recorder.elapsed);
    });
  }

  void _stopTicker() {
    _elapsedTicker?.cancel();
    _elapsedTicker = null;
  }

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
      setState(() {
        _phase = VoiceRecorderPhase.recording;
        _elapsed = Duration.zero;
      });
      _startTicker();
    } on VoiceRecorderException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.message);
    }
  }

  Future<void> _pause() async {
    final VoiceRecorder recorder = _recorder;
    try {
      await recorder.pause();
    } on VoiceRecorderException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.message);
      return;
    }
    _stopTicker();
    if (!mounted) {
      return;
    }
    setState(() {
      _phase = VoiceRecorderPhase.paused;
      _elapsed = recorder.elapsed;
    });
  }

  Future<void> _resume() async {
    final VoiceRecorder recorder = _recorder;
    try {
      await recorder.resume();
    } on VoiceRecorderException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.message);
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _phase = VoiceRecorderPhase.recording;
      _errorMessage = null;
    });
    _startTicker();
  }

  Future<void> _stop() async {
    if (_phase != VoiceRecorderPhase.recording &&
        _phase != VoiceRecorderPhase.paused) {
      return;
    }
    final VoiceRecorderPhase previous = _phase;
    _stopTicker();
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
      _failBackTo(previous, voiceSaveTimeoutMessage);
    } on VoiceRecorderException catch (error) {
      _failBackTo(previous, error.message);
    } on CaptureException catch (error) {
      _failBackTo(previous, error.message);
    } catch (error, stackTrace) {
      debugPrint('Voice save failed: $error\n$stackTrace');
      _failBackTo(previous, unexpectedVoiceSaveMessage);
    }
    if (entryId == null || !mounted) {
      return;
    }
    showTransientToast(context, voiceSavedToastMessage);
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

  void _failBackTo(VoiceRecorderPhase phase, String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _phase = phase;
      _errorMessage = message;
    });
  }

  Future<void> _cancel() async {
    _stopTicker();
    if (_phase == VoiceRecorderPhase.recording ||
        _phase == VoiceRecorderPhase.paused) {
      await _recorder.cancel();
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _discard() async {
    if (_phase != VoiceRecorderPhase.recording &&
        _phase != VoiceRecorderPhase.paused) {
      await _cancel();
      return;
    }
    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => const _DiscardConfirmDialog(),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    _stopTicker();
    await _recorder.cancel();
    if (!mounted) {
      return;
    }
    showTransientToast(context, voiceDiscardedToastMessage);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return VoiceRecorderSheet(
      phase: _phase,
      onStart: _start,
      onStop: _stop,
      onCancel: _cancel,
      onPause: _pause,
      onResume: _resume,
      onDiscard: _discard,
      elapsed: _elapsed,
      errorMessage: _errorMessage,
    );
  }
}

class _DiscardConfirmDialog extends StatelessWidget {
  const _DiscardConfirmDialog();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _confirmMaxWidth),
          child: StickerCard(
            surface: Palette.cardBright,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  voiceDiscardConfirmTitle,
                  style: TypographyTokens.titleSerif,
                ),
                const SizedBox(height: _confirmTitleGap),
                Text(
                  voiceDiscardConfirmMessage,
                  style: TypographyTokens.bodySans,
                ),
                const SizedBox(height: _confirmActionsGap),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: _confirmActionSpacing,
                  runSpacing: _confirmActionSpacing,
                  children: <Widget>[
                    StickerButton(
                      label: voiceDiscardConfirmCancelLabel,
                      variant: StickerButtonVariant.secondary,
                      padTapTarget: true,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    StickerButton(
                      key: voiceDiscardConfirmKey,
                      label: voiceDiscardConfirmLabel,
                      variant: StickerButtonVariant.danger,
                      labelStyle: TypographyTokens.captureLabelSans,
                      padTapTarget: true,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
