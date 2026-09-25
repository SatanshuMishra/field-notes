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

const String videoDiscardConfirmTitle = 'Discard this recording?';
const String videoDiscardConfirmMessage =
    'This take will be thrown away and nothing will be saved.';
const String videoDiscardConfirmLabel = 'Discard';
const String videoDiscardConfirmCancelLabel = 'Cancel';
const String videoDiscardedToastMessage = 'Recording discarded';
const String videoSavedToastMessage = 'Video saved';

const Key videoDiscardConfirmKey = ValueKey<String>('video-discard-confirm');

const double _confirmMaxWidth = 420;
const double _confirmTitleGap = 8;
const double _confirmActionsGap = 20;
const double _confirmActionSpacing = 12;

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
  Duration _elapsed = Duration.zero;
  Timer? _elapsedTicker;
  final List<Timer> _timers = <Timer>[];
  List<VideoTimelineEvent> _pendingEvents = const <VideoTimelineEvent>[];
  late final VideoRecorder _recorder;

  void _startTicker() {
    _elapsedTicker?.cancel();
    _elapsedTicker = Timer.periodic(videoElapsedTick, (Timer _) {
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

  @override
  void initState() {
    super.initState();
    _recorder = ref.read(videoRecorderProvider);
    unawaited(_prepare());
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
      _showDenied();
      return;
    }
    ref.read(selectedCameraDeviceProvider.notifier).remember(deviceId);
    setState(() {
      _devices = List<VideoCaptureDevice>.unmodifiable(devices);
      _deviceId = deviceId;
      _preview = _recorder.openSession(deviceId);
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
        _phase != VideoRecorderPhase.idle ||
        deviceId == _deviceId) {
      return;
    }
    _switching = true;
    setState(() {
      _phase = VideoRecorderPhase.preparing;
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
    _switching = false;
    if (!mounted) {
      return;
    }
    ref.read(selectedCameraDeviceProvider.notifier).remember(deviceId);
    setState(() {
      _preview = _recorder.openSession(deviceId);
      _phase = VideoRecorderPhase.idle;
      _errorMessage = failure;
    });
  }

  Future<void> _start() async {
    if (_phase == VideoRecorderPhase.denied) {
      setState(() {
        _phase = VideoRecorderPhase.preparing;
        _errorMessage = null;
      });
      await _prepare();
      return;
    }
    if (_phase != VideoRecorderPhase.idle) {
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
    final Duration elapsed = _recorder.elapsed;
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
      await _recorder.pause();
    } on VideoRecorderException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _errorMessage = error.message);
      return;
    }
    _cancelTimers();
    _stopTicker();
    if (!mounted) {
      return;
    }
    setState(() {
      _phase = VideoRecorderPhase.paused;
      _elapsed = _recorder.elapsed;
    });
  }

  Future<void> _resume() async {
    if (_phase != VideoRecorderPhase.paused) {
      return;
    }
    try {
      await _recorder.resume();
    } on VideoRecorderException catch (error) {
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
      _preview = null;
      _elapsed = _recorder.elapsed;
      _errorMessage = null;
      _nudgeMessage = null;
    });
    String? entryId;
    final Future<String> pending = _persist();
    try {
      entryId = await pending.timeout(widget.saveTimeout);
    } on TimeoutException {
      unawaited(pending.then((_) {}, onError: (_) {}));
      _failBackTo(previous, videoSaveTimeoutMessage);
    } on VideoRecorderException catch (error) {
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
    await _release();
    if (!mounted) {
      return;
    }
    showTransientToast(context, videoSavedToastMessage);
    Navigator.of(context).pop(entryId);
  }

  Future<String> _persist() async {
    final VideoRecording recording = await _recorder.stop();
    final CaptureService service =
        await ref.read(captureServiceProvider.future);
    final CaptureResult result = await service.capture(
      VideoCaptureRequest(
        date: widget.date,
        video: recording.media,
        durationMs: recording.durationMs,
        thumbnail: recording.thumbnail,
      ),
    );
    return result.entry.id;
  }

  void _failBackTo(VideoRecorderPhase phase, String message) {
    if (!mounted) {
      return;
    }
    final String? deviceId = _deviceId;
    setState(() {
      _phase = phase;
      _errorMessage = message;
      _preview = deviceId == null ? null : _recorder.openSession(deviceId);
    });
  }

  Future<void> _cancel() async {
    _cancelTimers();
    _stopTicker();
    if (_phase == VideoRecorderPhase.recording ||
        _phase == VideoRecorderPhase.paused ||
        _phase == VideoRecorderPhase.arming) {
      try {
        await _recorder.cancel();
      } catch (error, stackTrace) {
        debugPrint('Video cancel failed: $error\n$stackTrace');
      }
    }
    await _release();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _discard() async {
    if (_phase != VideoRecorderPhase.recording &&
        _phase != VideoRecorderPhase.paused) {
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
    _cancelTimers();
    _stopTicker();
    try {
      await _recorder.cancel();
    } catch (error, stackTrace) {
      debugPrint('Video cancel failed: $error\n$stackTrace');
    }
    await _release();
    if (!mounted) {
      return;
    }
    showTransientToast(context, videoDiscardedToastMessage);
    Navigator.of(context).pop();
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
    _cancelTimers();
    _stopTicker();
    unawaited(_release());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VideoRecorderSheet(
      phase: _phase,
      preview: _preview,
      devices: _devices,
      selectedDeviceId: _deviceId,
      onDeviceChanged: _selectDevice,
      elapsed: _elapsed,
      nudgeMessage: _nudgeMessage,
      errorMessage: _errorMessage,
      deniedMessage: _deniedMessage ?? cameraPermissionMessage,
      onStart: _start,
      onStop: _stop,
      onCancel: _cancel,
      onPause: _pause,
      onResume: _resume,
      onDiscard: _discard,
      supportsPause: _recorder.supportsPause,
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
                  videoDiscardConfirmTitle,
                  style: TypographyTokens.titleSerif,
                ),
                const SizedBox(height: _confirmTitleGap),
                Text(
                  videoDiscardConfirmMessage,
                  style: TypographyTokens.bodySans,
                ),
                const SizedBox(height: _confirmActionsGap),
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: _confirmActionSpacing,
                  runSpacing: _confirmActionSpacing,
                  children: <Widget>[
                    StickerButton(
                      label: videoDiscardConfirmCancelLabel,
                      variant: StickerButtonVariant.secondary,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    StickerButton(
                      key: videoDiscardConfirmKey,
                      label: videoDiscardConfirmLabel,
                      variant: StickerButtonVariant.danger,
                      labelStyle: TypographyTokens.captureLabelSans,
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

Future<String?> showVideoComposer(BuildContext context, String date) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Dismiss video recorder',
    barrierColor: const Color(0x00000000),
    transitionDuration: Motion.modalPop,
    pageBuilder: (
      BuildContext dialogContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return DialogHost(
        child: ComposerShell(child: VideoComposerConnector(date: date)),
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

final CaptureRoute videoCaptureRoute = CaptureRoute(
  type: EntryType.video,
  open: showVideoComposer,
);
