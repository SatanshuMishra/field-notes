import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/domain/settings/app_settings.dart';
import 'package:field_notes/features/capture/audio/take_cleanup.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/capture_route.dart';
import 'package:field_notes/features/capture/core/recording_wake_hold.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/state/settings_section_request.dart';
import 'package:field_notes/state/shell_navigation.dart';

import 'voice_peak_sampler.dart';
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

typedef _KeptVoice = ({
  VoiceRecording recording,
  CaptureMedia audio,
  List<double> peaks,
});

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
  String _savingText = voiceSavingStatus;
  VoicePeakSampler? _sampler;
  StreamSubscription<double>? _levelFeed;
  late final RecordingWakeHold _wakeHold;

  VoiceRecorder get _recorder => ref.read(voiceRecorderProvider);

  @override
  void initState() {
    super.initState();
    _wakeHold = RecordingWakeHold(ref.read(stayAwakeProvider));
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _wakeHold.update(live: !_closing && _phase.stage.holdsDeviceAwake);
  }

  @override
  void dispose() {
    _stopTicker();
    _cancelBreath();
    _stopFeedingSampler();
    _wakeHold.dispose();
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

  void _feedSampler(VoiceRecorder recorder) {
    _stopFeedingSampler();
    final VoicePeakSampler? sampler = _sampler;
    if (sampler == null) {
      return;
    }
    _levelFeed = recorder.level.listen(
      (double level) => sampler.hear(level, recorder.elapsed),
    );
  }

  void _stopFeedingSampler() {
    unawaited(_levelFeed?.cancel());
    _levelFeed = null;
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
    _sampler = VoicePeakSampler();
    _feedSampler(recorder);
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
    _stopFeedingSampler();
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
    _feedSampler(recorder);
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
    _stopFeedingSampler();
    setState(() {
      _phase = VoiceRecorderPhase.saving;
      _savingText = voiceSavingStatus;
      _errorMessage = null;
    });
    final VoiceRecorder recorder = _recorder;
    final TakeCleanup cleanup = ref.read(takeCleanupProvider);
    final AppSettings settings = takeCleanupSettings(ref);
    final Future<VoiceRecording> stopping = recorder.stop();
    final Future<_KeptVoice> cleaning = stopping.then(
      (VoiceRecording recording) =>
          _clean(recorder, recording, cleanup, settings),
    );
    final Future<String> saving = cleaning.then(
      (_KeptVoice kept) => _capture(recorder, kept, cleanup),
    );
    saving.ignore();
    String? entryId;
    try {
      await stopping.timeout(widget.saveTimeout);
      await cleaning;
      entryId = await saving.timeout(widget.saveTimeout);
    } on TimeoutException {
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
    _wakeHold.update(live: false);
    closeImmersiveRecorder<String>(
      context,
      result: entryId,
      toast: voiceSavedToastMessage,
    );
  }

  Future<_KeptVoice> _clean(
    VoiceRecorder recorder,
    VoiceRecording recording,
    TakeCleanup cleanup,
    AppSettings settings,
  ) async {
    final List<double> peaks =
        _sampler?.finish(recorder.elapsed) ?? const <double>[];
    final String? status = takeCleanupStatus(settings);
    if (status != null && mounted) {
      setState(() => _savingText = status);
    }
    final CaptureMedia audio = await cleanTakeMedia(
      cleanup,
      recording.media,
      kind: TakeKind.voice,
      settings: settings,
      durationMs: recording.durationMs,
    );
    if (mounted) {
      setState(() => _savingText = voiceSavingStatus);
    }
    return (
      recording: recording,
      audio: audio,
      peaks: identical(audio, recording.media) ? peaks : const <double>[],
    );
  }

  Future<String> _capture(
    VoiceRecorder recorder,
    _KeptVoice kept,
    TakeCleanup cleanup,
  ) async {
    try {
      final CaptureService service = await ref.read(
        captureServiceProvider.future,
      );
      final CaptureResult result = await service.capture(
        VoiceCaptureRequest(
          date: widget.date,
          audio: kept.audio,
          durationMs: kept.recording.durationMs,
          peaks: kept.peaks,
        ),
      );
      try {
        await recorder.releaseSaved(kept.recording);
      } catch (error, stackTrace) {
        debugPrint('Voice capture release failed: $error\n$stackTrace');
      }
      return result.entry.id;
    } finally {
      await releaseCleanedMedia(cleanup, kept.recording.media, kept.audio);
    }
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
    _wakeHold.update(live: false);
    _cancelBreath();
    _stopTicker();
    Navigator.of(context).pop();
  }

  void _openVoiceSettings() {
    if (_closing || _asking || _phase != VoiceRecorderPhase.idle) {
      return;
    }
    final SettingsSectionRequest request = ref.read(
      settingsSectionRequestProvider.notifier,
    );
    final ShellNavigation navigation = ref.read(
      shellNavigationProvider.notifier,
    );
    _leave();
    request.request(SettingsTab.voice);
    navigation.select(ShellDestination.settings);
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
    _wakeHold.update(live: false);
    _cancelBreath();
    _stopTicker();
    _stopFeedingSampler();
    await _recorder.cancel();
    if (!mounted) {
      return;
    }
    closeImmersiveRecorder<String>(context, toast: voiceLetGoToastMessage);
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
        levels: _recorder.level,
        savingText: _savingText,
        onVoiceSettings: _openVoiceSettings,
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
