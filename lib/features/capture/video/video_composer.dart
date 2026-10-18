import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/data/media/media_work_budget.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/domain/settings/app_settings.dart';
import 'package:field_notes/features/capture/audio/audio_inputs.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/capture_route.dart';
import 'package:field_notes/features/capture/core/recording_wake_hold.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';
import 'package:field_notes/features/capture/voice/voice_composer.dart'
    show voiceSavedToastMessage;
import 'package:field_notes/features/capture/voice/voice_recorder.dart';
import 'package:field_notes/features/capture/voice/voice_recorder_provider.dart';
import 'package:field_notes/features/settings/widgets/settings_tabs.dart';
import 'package:field_notes/state/settings_providers.dart';
import 'package:field_notes/state/settings_section_request.dart';
import 'package:field_notes/state/shell_navigation.dart';

import 'audio_input_selectable.dart';
import 'camera_selection.dart';
import 'video_recorder.dart';
import 'video_recorder_provider.dart';
import 'video_recorder_sheet.dart';
import 'video_timeline.dart';

const String unexpectedVideoSaveMessage =
    'Could not save your video. Please try again.';

const String videoSaveTimeoutMessage =
    'Saving took too long. Nothing was saved — please try again.';

const Duration videoSaveTimeout = Duration(seconds: 20);

const Duration cameraReleaseTimeout = Duration(seconds: 6);

const Duration videoElapsedTick = Duration(milliseconds: 250);

const String videoDiscardedToastMessage = 'Let go · nothing was saved';
const String videoSavedToastMessage = 'Video saved';

const Key videoDiscardConfirmKey = ValueKey<String>('video-discard-confirm');

class VideoComposerConnector extends ConsumerStatefulWidget {
  const VideoComposerConnector({
    super.key,
    required this.date,
    this.saveTimeout = videoSaveTimeout,
    this.releaseTimeout = cameraReleaseTimeout,
  });

  final String date;
  final Duration saveTimeout;
  final Duration releaseTimeout;

  @override
  ConsumerState<VideoComposerConnector> createState() =>
      _VideoComposerConnectorState();
}

class _VideoComposerConnectorState
    extends ConsumerState<VideoComposerConnector> {
  VideoRecorderPhase _phase = VideoRecorderPhase.preparing;
  String? _errorMessage;
  String? _deniedMessage;
  String? _nudgeMessage;
  Widget? _preview;
  List<VideoCaptureDevice> _devices = const <VideoCaptureDevice>[];
  String? _deviceId;
  bool _released = false;
  bool _switching = false;
  bool _closing = false;
  bool _asking = false;
  bool _cameraOn = true;
  Future<void>? _cameraChange;
  VoiceRecorder? _voiceRecorder;
  Duration _elapsed = Duration.zero;
  Timer? _elapsedTicker;
  Timer? _breathTimer;
  final List<Timer> _timers = <Timer>[];
  List<VideoTimelineEvent> _pendingEvents = const <VideoTimelineEvent>[];
  late final VideoRecorder _recorder;
  late final RecordingWakeHold _wakeHold;

  VoiceRecorder get _voice {
    final VoiceRecorder voice =
        _voiceRecorder ?? ref.read(voiceRecorderProvider);
    _voiceRecorder = voice;
    return voice;
  }

  Duration get _takeElapsed => _cameraOn ? _recorder.elapsed : _voice.elapsed;

  bool get _takeSupportsPause => !_cameraOn || _recorder.supportsPause;

  void _startTicker() {
    _elapsedTicker?.cancel();
    _elapsedTicker = Timer.periodic(videoElapsedTick, (Timer _) {
      if (!mounted) {
        return;
      }
      setState(() => _elapsed = _takeElapsed);
    });
  }

  void _stopTicker() {
    _elapsedTicker?.cancel();
    _elapsedTicker = null;
  }

  @override
  void initState() {
    super.initState();
    _recorder = ref.read(videoRecorderProvider);
    _wakeHold = RecordingWakeHold(ref.read(stayAwakeProvider));
    if (_recorder is AudioInputSelectable) {
      ref.listenManual<AsyncValue<AppSettings>>(
        appSettingsProvider,
        _onSettingsChanged,
      );
    }
    unawaited(_prepare());
  }

  void _onSettingsChanged(
    AsyncValue<AppSettings>? previous,
    AsyncValue<AppSettings> next,
  ) {
    final AppSettings? before = previous?.value;
    final AppSettings? after = next.value;
    if (before == null ||
        after == null ||
        before.audioInputId == after.audioInputId) {
      return;
    }
    unawaited(_useChangedInput());
  }

  Future<void> _useChangedInput() async {
    final String? deviceId = _deviceId;
    if (_closing ||
        !_cameraOn ||
        _switching ||
        _cameraChange != null ||
        _phase != VideoRecorderPhase.idle ||
        deviceId == null) {
      return;
    }
    await _reopenCamera(deviceId);
  }

  Future<void> _useSelectedInput() async {
    final AudioInputSelectable? recorder = switch (_recorder) {
      final AudioInputSelectable selectable => selectable,
      _ => null,
    };
    if (recorder == null) {
      return;
    }
    String? inputId;
    try {
      inputId = (await ref.read(selectedAudioInputProvider.future)).id;
    } catch (error, stackTrace) {
      debugPrint('Audio input lookup failed: $error\n$stackTrace');
    }
    recorder.useAudioInput(inputId);
  }

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _wakeHold.update(live: !_closing && _phase.stage.holdsDeviceAwake);
  }

  Future<void> _prepare() async {
    final List<VideoCaptureDevice> devices;
    try {
      devices = await _recorder.listDevices();
    } on VideoRecorderException catch (error) {
      _showDenied(message: error.message);
      return;
    } catch (error, stackTrace) {
      debugPrint('Camera enumeration failed: $error\n$stackTrace');
      _showDenied(message: videoDeviceListMessage);
      return;
    }
    if (!mounted) {
      return;
    }
    final String? deviceId = resolveCameraDeviceId(
      devices: devices,
      rememberedId: ref.read(selectedCameraDeviceProvider),
    );
    if (deviceId == null) {
      _showDenied(message: videoDeviceListMessage);
      return;
    }
    if (_recorder is AudioInputSelectable) {
      await _useSelectedInput();
      if (!mounted) {
        return;
      }
    }
    ref.read(selectedCameraDeviceProvider.notifier).remember(deviceId);
    setState(() {
      _devices = List<VideoCaptureDevice>.unmodifiable(devices);
      _deviceId = deviceId;
      _preview = _cameraOn ? _recorder.openSession(deviceId) : null;
      _phase = VideoRecorderPhase.idle;
      _errorMessage = null;
      _deniedMessage = null;
    });
  }

  void _showDenied({String? message}) {
    if (!mounted) {
      return;
    }
    setState(() {
      _phase = VideoRecorderPhase.denied;
      _preview = null;
      _devices = const <VideoCaptureDevice>[];
      _deviceId = null;
      _errorMessage = null;
      _deniedMessage = message;
    });
  }

  Future<void> _selectDevice(String deviceId) async {
    if (_switching ||
        _cameraChange != null ||
        _phase != VideoRecorderPhase.idle ||
        deviceId == _deviceId) {
      return;
    }
    if (!_cameraOn) {
      ref.read(selectedCameraDeviceProvider.notifier).remember(deviceId);
      setState(() => _deviceId = deviceId);
      return;
    }
    await _reopenCamera(deviceId, rememberCamera: true, preparing: true);
  }

  Future<void> _reopenCamera(
    String deviceId, {
    bool rememberCamera = false,
    bool preparing = false,
  }) async {
    _switching = true;
    setState(() {
      if (preparing) {
        _phase = VideoRecorderPhase.preparing;
      }
      _preview = null;
      _errorMessage = null;
      _deviceId = deviceId;
    });
    String? failure;
    try {
      await _recorder.release().timeout(widget.releaseTimeout);
    } on TimeoutException {
      failure = videoDeviceSwitchMessage;
    } on VideoRecorderException catch (error) {
      failure = error.message;
    } catch (error, stackTrace) {
      debugPrint('Camera release failed: $error\n$stackTrace');
      failure = videoDeviceSwitchMessage;
    }
    if (mounted && _recorder is AudioInputSelectable) {
      await _useSelectedInput();
    }
    _switching = false;
    if (!mounted) {
      return;
    }
    if (rememberCamera) {
      ref.read(selectedCameraDeviceProvider.notifier).remember(deviceId);
    }
    if (_closing) {
      return;
    }
    setState(() {
      _preview = _recorder.openSession(deviceId);
      _phase = VideoRecorderPhase.idle;
      _errorMessage = failure;
    });
  }

  Future<void> _setCamera(bool on) async {
    if (_closing ||
        _switching ||
        _cameraChange != null ||
        _phase != VideoRecorderPhase.idle ||
        on == _cameraOn) {
      return;
    }
    if (on) {
      final Future<void> opening = _openCamera();
      _cameraChange = opening;
      await opening;
      _cameraChange = null;
      return;
    }
    setState(() {
      _cameraOn = false;
      _errorMessage = null;
      _preview = null;
    });
    final Future<void> change = _releaseCamera();
    _cameraChange = change;
    await change;
    _cameraChange = null;
  }

  Future<void> _openCamera() async {
    if (_recorder is AudioInputSelectable) {
      await _useSelectedInput();
      if (!mounted || _closing) {
        return;
      }
    }
    final String? deviceId = _deviceId;
    setState(() {
      _cameraOn = true;
      _errorMessage = null;
      _preview = deviceId == null ? null : _recorder.openSession(deviceId);
    });
  }

  Future<void> _releaseCamera() async {
    try {
      await _recorder.release().timeout(widget.releaseTimeout);
    } on TimeoutException {
      debugPrint('Camera release timed out');
    } catch (error, stackTrace) {
      debugPrint('Camera release failed: $error\n$stackTrace');
    }
  }

  Future<void> _start() async {
    if (_cameraChange != null || _switching) {
      return;
    }
    switch (_phase) {
      case VideoRecorderPhase.denied:
        await _prepare();
      case VideoRecorderPhase.idle:
        _breathe();
      case VideoRecorderPhase.breathing:
        _cancelBreath();
        await _arm();
      case _:
        return;
    }
  }

  void _breathe() {
    if (_deviceId == null) {
      _showDenied();
      return;
    }
    setState(() {
      _phase = VideoRecorderPhase.breathing;
      _errorMessage = null;
      _nudgeMessage = null;
    });
    _breathTimer = Timer(stageBreathDuration, () {
      _breathTimer = null;
      unawaited(_arm());
    });
  }

  void _cancelBreath() {
    _breathTimer?.cancel();
    _breathTimer = null;
  }

  Future<void> _arm() async {
    if (!mounted || _closing || _phase != VideoRecorderPhase.breathing) {
      return;
    }
    if (!_cameraOn) {
      await _armVoice();
      return;
    }
    final String? deviceId = _deviceId;
    if (deviceId == null) {
      _showDenied();
      return;
    }
    setState(() {
      _phase = VideoRecorderPhase.arming;
      _errorMessage = null;
      _nudgeMessage = null;
    });
    try {
      await _recorder.start();
      if (!mounted) {
        return;
      }
      setState(() {
        _preview = _recorder.openSession(deviceId);
        _phase = VideoRecorderPhase.recording;
        _elapsed = Duration.zero;
      });
      _pendingEvents = videoTimelineEvents();
      _armTimeline();
      _startTicker();
    } on VideoRecorderException catch (error) {
      _failBackToIdle(error.message);
    } catch (error, stackTrace) {
      debugPrint('Video start failed: $error\n$stackTrace');
      _failBackToIdle(videoStartMessage);
    }
  }

  Future<void> _armVoice() async {
    final VoiceRecorder voice = _voice;
    setState(() {
      _phase = VideoRecorderPhase.arming;
      _errorMessage = null;
      _nudgeMessage = null;
    });
    final Future<void>? cameraChange = _cameraChange;
    if (cameraChange != null) {
      await cameraChange;
    }
    bool granted;
    try {
      granted = await voice.hasPermission();
    } catch (error, stackTrace) {
      debugPrint('Microphone permission check failed: $error\n$stackTrace');
      granted = false;
    }
    if (!mounted || _closing || _phase != VideoRecorderPhase.arming) {
      return;
    }
    if (!granted) {
      _failBackToIdle(micPermissionMessage);
      return;
    }
    try {
      await voice.start();
    } on VoiceRecorderException catch (error) {
      _failBackToIdle(error.message);
      return;
    } catch (error, stackTrace) {
      debugPrint('Voice start failed: $error\n$stackTrace');
      _failBackToIdle(recordStartMessage);
      return;
    }
    if (!mounted || _closing) {
      unawaited(_cancelVoice(voice));
      return;
    }
    setState(() {
      _phase = VideoRecorderPhase.recording;
      _elapsed = Duration.zero;
    });
    _pendingEvents = videoTimelineEvents();
    _armTimeline();
    _startTicker();
  }

  void _failBackToIdle(String message) {
    _stopTicker();
    if (!mounted) {
      return;
    }
    setState(() {
      _phase = VideoRecorderPhase.idle;
      _errorMessage = message;
    });
  }

  void _armTimeline() {
    _cancelTimers();
    final Duration elapsed = _takeElapsed;
    for (final VideoTimelineEvent event in _pendingEvents) {
      final Duration remaining = event.at - elapsed;
      _timers.add(
        Timer(
          remaining.isNegative ? Duration.zero : remaining,
          () => _onTimelineEvent(event),
        ),
      );
    }
  }

  void _onTimelineEvent(VideoTimelineEvent event) {
    if (!mounted || _phase != VideoRecorderPhase.recording) {
      return;
    }
    _pendingEvents = <VideoTimelineEvent>[
      for (final VideoTimelineEvent pending in _pendingEvents)
        if (!identical(pending, event)) pending,
    ];
    switch (event.kind) {
      case VideoTimelineEventKind.nudge:
        setState(() => _nudgeMessage = event.message);
      case VideoTimelineEventKind.cap:
        _stop();
    }
  }

  void _cancelTimers() {
    for (final Timer timer in _timers) {
      timer.cancel();
    }
    _timers.clear();
  }

  Future<void> _pause() async {
    if (_phase != VideoRecorderPhase.recording) {
      return;
    }
    try {
      await (_cameraOn ? _recorder.pause() : _voice.pause());
    } on VideoRecorderException catch (error) {
      _showTakeError(error.message);
      return;
    } on VoiceRecorderException catch (error) {
      _showTakeError(error.message);
      return;
    }
    _cancelTimers();
    _stopTicker();
    if (!mounted) {
      return;
    }
    setState(() {
      _phase = VideoRecorderPhase.paused;
      _elapsed = _takeElapsed;
    });
  }

  void _showTakeError(String message) {
    if (!mounted) {
      return;
    }
    setState(() => _errorMessage = message);
  }

  Future<void> _resume() async {
    if (_phase != VideoRecorderPhase.paused) {
      return;
    }
    try {
      await (_cameraOn ? _recorder.resume() : _voice.resume());
    } on VideoRecorderException catch (error) {
      _showTakeError(error.message);
      return;
    } on VoiceRecorderException catch (error) {
      _showTakeError(error.message);
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _phase = VideoRecorderPhase.recording;
      _errorMessage = null;
    });
    _armTimeline();
    _startTicker();
  }

  Future<void> _stop() async {
    if (_phase != VideoRecorderPhase.recording &&
        _phase != VideoRecorderPhase.paused) {
      return;
    }
    final VideoRecorderPhase previous = _phase;
    _cancelTimers();
    _stopTicker();
    setState(() {
      _phase = VideoRecorderPhase.saving;
      _asking = false;
      _preview = null;
      _elapsed = _takeElapsed;
      _errorMessage = null;
      _nudgeMessage = null;
    });
    String? entryId;
    final bool voiceTake = !_cameraOn;
    final Duration stopTimeout =
        widget.saveTimeout + mediaWorkBudget(_elapsed) * 2;
    final Future<void> stopping;
    final Future<String> saving;
    if (voiceTake) {
      final VoiceRecorder voice = _voice;
      final Future<VoiceRecording> voiceStop = voice.stop();
      stopping = voiceStop;
      saving = voiceStop.then(
        (VoiceRecording recording) => _captureVoice(voice, recording),
      );
    } else {
      final Future<VideoRecording> videoStop = _recorder.stop();
      stopping = videoStop;
      saving = videoStop.then(_capture);
    }
    saving.ignore();
    try {
      await stopping.timeout(stopTimeout);
      entryId = await saving.timeout(widget.saveTimeout);
    } on TimeoutException {
      _failBackTo(previous, videoSaveTimeoutMessage);
    } on VideoSegmentsKeptException catch (error) {
      _failBackTo(VideoRecorderPhase.paused, error.message);
    } on VideoRecorderException catch (error) {
      _failBackTo(previous, error.message);
    } on VoiceRecorderException catch (error) {
      _failBackTo(previous, error.message);
    } on CaptureException catch (error) {
      _failBackTo(previous, error.message);
    } catch (error, stackTrace) {
      debugPrint('Video save failed: $error\n$stackTrace');
      _failBackTo(previous, unexpectedVideoSaveMessage);
    }
    if (entryId == null || !mounted) {
      return;
    }
    _closing = true;
    _wakeHold.update(live: false);
    await _release();
    if (!mounted) {
      return;
    }
    closeImmersiveRecorder<String>(
      context,
      result: entryId,
      toast: voiceTake ? voiceSavedToastMessage : videoSavedToastMessage,
    );
  }

  Future<String> _captureVoice(
    VoiceRecorder voice,
    VoiceRecording recording,
  ) async {
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
      await voice.releaseSaved(recording);
    } catch (error, stackTrace) {
      debugPrint('Voice capture release failed: $error\n$stackTrace');
    }
    return result.entry.id;
  }

  Future<String> _capture(VideoRecording recording) async {
    final CaptureService service = await ref.read(
      captureServiceProvider.future,
    );
    final CaptureResult result = await service.capture(
      VideoCaptureRequest(
        date: widget.date,
        video: recording.media,
        durationMs: recording.durationMs,
        thumbnail: recording.thumbnail,
      ),
    );
    try {
      await _recorder.releaseSaved(recording);
    } catch (error, stackTrace) {
      debugPrint('Video capture release failed: $error\n$stackTrace');
    }
    return result.entry.id;
  }

  void _failBackTo(VideoRecorderPhase phase, String message) {
    if (!mounted) {
      return;
    }
    final String? deviceId = _cameraOn ? _deviceId : null;
    setState(() {
      _phase = phase;
      _errorMessage = message;
      _preview = deviceId == null ? null : _recorder.openSession(deviceId);
      if (phase == VideoRecorderPhase.paused) {
        _elapsed = _takeElapsed;
      }
    });
  }

  Future<void> _cancelTake() async {
    if (!_cameraOn) {
      await _cancelVoice(_voice);
      return;
    }
    try {
      await _recorder.cancel();
    } catch (error, stackTrace) {
      debugPrint('Video cancel failed: $error\n$stackTrace');
    }
  }

  Future<void> _cancelVoice(VoiceRecorder voice) async {
    try {
      await voice.cancel();
    } catch (error, stackTrace) {
      debugPrint('Voice cancel failed: $error\n$stackTrace');
    }
  }

  Future<void> _cancel() async {
    if (_closing) {
      return;
    }
    _closing = true;
    _wakeHold.update(live: false);
    _cancelBreath();
    _cancelTimers();
    _stopTicker();
    if (_phase == VideoRecorderPhase.recording ||
        _phase == VideoRecorderPhase.paused ||
        _phase == VideoRecorderPhase.arming) {
      await _cancelTake();
    }
    await _release();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _leave() async {
    if (_closing || _asking) {
      return;
    }
    switch (_phase) {
      case VideoRecorderPhase.saving:
        return;
      case VideoRecorderPhase.recording || VideoRecorderPhase.paused:
        final bool pauseFirst =
            _phase == VideoRecorderPhase.recording && _takeSupportsPause;
        setState(() => _asking = true);
        if (pauseFirst) {
          await _pause();
        }
      case _:
        await _cancel();
    }
  }

  Future<void> _openVoiceSettings() async {
    if (_closing || _asking || _phase != VideoRecorderPhase.idle) {
      return;
    }
    final SettingsSectionRequest request = ref.read(
      settingsSectionRequestProvider.notifier,
    );
    final ShellNavigation navigation = ref.read(
      shellNavigationProvider.notifier,
    );
    await _cancel();
    request.request(SettingsTab.voice);
    navigation.select(ShellDestination.settings);
  }

  void _keepGoing() {
    if (!_asking || _closing) {
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
    _cancelTimers();
    _stopTicker();
    await _cancelTake();
    await _release();
    if (!mounted) {
      return;
    }
    closeImmersiveRecorder<String>(context, toast: videoDiscardedToastMessage);
  }

  void _onPopInvoked(bool didPop, Object? result) {
    if (didPop) {
      return;
    }
    if (_asking) {
      _keepGoing();
      return;
    }
    unawaited(_leave());
  }

  Future<void> _release() async {
    if (_released) {
      return;
    }
    _released = true;
    try {
      await _recorder.release().timeout(widget.releaseTimeout);
    } on TimeoutException {
      debugPrint('Camera release timed out');
    } catch (error, stackTrace) {
      debugPrint('Camera release failed: $error\n$stackTrace');
    }
  }

  @override
  void dispose() {
    _cancelBreath();
    _cancelTimers();
    _stopTicker();
    final VoiceRecorder? voice = _voiceRecorder;
    if (voice != null &&
        !_closing &&
        !_cameraOn &&
        (_phase == VideoRecorderPhase.recording ||
            _phase == VideoRecorderPhase.paused)) {
      unawaited(_cancelVoice(voice));
    }
    _wakeHold.dispose();
    unawaited(_release());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: VideoRecorderSheet(
        phase: _phase,
        preview: _preview,
        devices: _devices,
        selectedDeviceId: _deviceId,
        onDeviceChanged: _selectDevice,
        cameraOn: _cameraOn,
        onCameraChanged: _setCamera,
        controls: switch (_recorder) {
          final CameraControls controls => controls,
          _ => null,
        },
        elapsed: _elapsed,
        nudgeMessage: _nudgeMessage,
        errorMessage: _errorMessage,
        deniedMessage: _deniedMessage ?? cameraPermissionMessage,
        onStart: _start,
        onStop: _stop,
        onLeave: _leave,
        onPause: _pause,
        onResume: _resume,
        onKeepGoing: _keepGoing,
        onLetGo: _letGo,
        asking: _asking,
        letGoKey: videoDiscardConfirmKey,
        supportsPause: _takeSupportsPause,
        savingHint: videoSavingHint,
        onVoiceSettings: _openVoiceSettings,
        levels: _cameraOn ? _recorder.level : _voice.level,
      ),
    );
  }
}

Future<String?> showVideoComposer(BuildContext context, String date) {
  return showImmersiveRecorder<String>(
    context,
    barrierLabel: 'Dismiss video recorder',
    builder: (BuildContext context) => VideoComposerConnector(date: date),
  );
}

final CaptureRoute videoCaptureRoute = CaptureRoute(
  type: EntryType.video,
  open: showVideoComposer,
);
