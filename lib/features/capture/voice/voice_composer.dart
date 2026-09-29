import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/feedback/feedback.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/capture_route.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';

import 'voice_recorder.dart';
import 'voice_recorder_provider.dart';
import 'voice_recorder_sheet.dart';

const String unexpectedVoiceSaveMessage =
    'Could not save your recording. Please try again.';

const String voiceSaveTimeoutMessage =
    'Saving took too long. Nothing was saved — please try again.';

const Duration voiceSaveTimeout = Duration(seconds: 20);

const Duration voiceElapsedTick = Duration(milliseconds: 250);

const String voiceLetGoToastMessage = 'Let go · nothing was saved';
const String voiceSavedToastMessage = 'Voice memo saved';
const String voiceRecorderBarrierLabel = 'Dismiss voice recorder';

const Key voiceDiscardConfirmKey = ValueKey<String>('voice-discard-confirm');

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
  bool _asking = false;
  String? _errorMessage;
  Duration _elapsed = Duration.zero;
  Timer? _elapsedTicker;
  Timer? _breath;
  bool _pending = false;
  bool _closing = false;

  VoiceRecorder get _recorder => ref.read(voiceRecorderProvider);

  @override
  void dispose() {
    _stopTicker();
    _cancelBreath();
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

  void _cancelBreath() {
    _breath?.cancel();
    _breath = null;
  }

  Future<void> _start() async {
    if (_closing || _asking || _pending) {
      return;
    }
    if (_phase == VoiceRecorderPhase.breathing) {
      await _record();
      return;
    }
    if (_phase != VoiceRecorderPhase.idle) {
      return;
    }
    setState(() => _errorMessage = null);
    final VoiceRecorder recorder = _recorder;
    _pending = true;
    try {
      final bool granted = await recorder.hasPermission();
      if (!mounted || _closing) {
        return;
      }
      if (!granted) {
        setState(() => _errorMessage = micPermissionMessage);
        return;
      }
      setState(() => _phase = VoiceRecorderPhase.breathing);
      _breath = Timer(stageBreathDuration, () => unawaited(_record()));
    } on VoiceRecorderException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.message);
    } finally {
      _pending = false;
    }
  }

  Future<void> _record() async {
    if (_closing || _pending || _phase != VoiceRecorderPhase.breathing) {
      return;
    }
    _cancelBreath();
    final VoiceRecorder recorder = _recorder;
    _pending = true;
    try {
      await recorder.start();
    } on VoiceRecorderException catch (error) {
      _pending = false;
      if (!mounted || _closing) {
        return;
      }
      setState(() {
        _phase = VoiceRecorderPhase.idle;
        _errorMessage = error.message;
      });
      return;
    }
    _pending = false;
    if (!mounted || _closing) {
      await recorder.cancel();
      return;
    }
    setState(() {
      _phase = VoiceRecorderPhase.recording;
      _elapsed = Duration.zero;
    });
    _startTicker();
  }

  Future<void> _pause() async {
    if (_pending || _phase != VoiceRecorderPhase.recording) {
      return;
    }
    final VoiceRecorder recorder = _recorder;
    _pending = true;
    try {
      await recorder.pause();
    } on VoiceRecorderException catch (error) {
      _pending = false;
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.message);
      return;
    }
    _pending = false;
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
    if (_pending || _closing || _phase != VoiceRecorderPhase.paused) {
      return;
    }
    final VoiceRecorder recorder = _recorder;
    _pending = true;
    try {
      await recorder.resume();
    } on VoiceRecorderException catch (error) {
      _pending = false;
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.message);
      return;
    }
    _pending = false;
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
    if (_pending || _asking || _closing || !_phase.isTaking) {
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
    _closing = true;
    showTransientToast(context, voiceSavedToastMessage);
    Navigator.of(context).pop(entryId);
  }

  Future<String> _persist() async {
    final VoiceRecorder recorder = _recorder;
    final VoiceRecording recording = await recorder.stop();
    final CaptureService service = await ref.read(
      captureServiceProvider.future,
    );
    final CaptureResult result = await service.capture(
      VoiceCaptureRequest(
        date: widget.date,
        audio: recording.media,
        durationMs: recording.durationMs,
      ),
    );
    try {
      await recorder.releaseSaved(recording);
    } catch (error, stackTrace) {
      debugPrint('Voice capture release failed: $error\n$stackTrace');
    }
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

  void _leave() {
    if (_closing || _asking || _phase == VoiceRecorderPhase.saving) {
      return;
    }
    if (_phase.isTaking) {
      unawaited(_askToLetGo());
      return;
    }
    _closing = true;
    _cancelBreath();
    _stopTicker();
    Navigator.of(context).pop();
  }

  void _escape() {
    if (_asking) {
      _keepGoing();
      return;
    }
    _leave();
  }

  Future<void> _askToLetGo() async {
    if (_closing || _asking || !_phase.isTaking) {
      return;
    }
    setState(() => _asking = true);
    if (_phase == VoiceRecorderPhase.recording) {
      await _pause();
    }
  }

  void _keepGoing() {
    if (_closing || !_asking) {
      return;
    }
    setState(() => _asking = false);
  }

  Future<void> _letGo() async {
    if (_closing) {
      return;
    }
    _closing = true;
    _cancelBreath();
    _stopTicker();
    await _recorder.cancel();
    if (!mounted) {
      return;
    }
    showTransientToast(context, voiceLetGoToastMessage);
    Navigator.of(context).pop();
  }

  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop) {
      return;
    }
    _escape();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: VoiceRecorderSheet(
        phase: _phase,
        asking: _asking,
        onStart: _start,
        onStop: _stop,
        onCancel: _leave,
        onPause: _pause,
        onResume: _resume,
        onDiscard: _askToLetGo,
        onDismiss: _escape,
        onKeepGoing: _keepGoing,
        onLetGo: _letGo,
        elapsed: _elapsed,
        errorMessage: _errorMessage,
        letGoKey: voiceDiscardConfirmKey,
      ),
    );
  }
}

Future<String?> showVoiceComposer(BuildContext context, String date) {
  return showImmersiveRecorder<String>(
    context,
    barrierLabel: voiceRecorderBarrierLabel,
    builder: (BuildContext context) => VoiceComposerConnector(date: date),
  );
}

final CaptureRoute voiceCaptureRoute = CaptureRoute(
  type: EntryType.voice,
  open: showVoiceComposer,
);
