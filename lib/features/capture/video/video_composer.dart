import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/motion/motion.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/capture_service.dart';
import 'package:field_notes/features/capture/core/capture_providers.dart';
import 'package:field_notes/features/capture/core/capture_route.dart';

import 'video_recorder.dart';
import 'video_recorder_provider.dart';
import 'video_recorder_sheet.dart';
import 'video_timeline.dart';

const String unexpectedVideoSaveMessage =
    'Could not save your video. Please try again.';

const Duration videoSaveTimeout = Duration(seconds: 20);

class VideoComposerConnector extends ConsumerStatefulWidget {
  const VideoComposerConnector({
    super.key,
    required this.date,
    this.saveTimeout = videoSaveTimeout,
  });

  final String date;
  final Duration saveTimeout;

  @override
  ConsumerState<VideoComposerConnector> createState() =>
      _VideoComposerConnectorState();
}

class _VideoComposerConnectorState
    extends ConsumerState<VideoComposerConnector> {
  VideoRecorderPhase _phase = VideoRecorderPhase.idle;
  String? _errorMessage;
  String? _nudgeMessage;
  Widget? _preview;
  final List<Timer> _timers = <Timer>[];

  VideoRecorder get _recorder => ref.read(videoRecorderProvider);

  Future<void> _start() async {
    setState(() => _errorMessage = null);
    final VideoRecorder recorder = _recorder;
    final bool granted;
    try {
      granted = await recorder.hasPermission();
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _phase = VideoRecorderPhase.denied);
      return;
    }
    if (!mounted) {
      return;
    }
    if (!granted) {
      setState(() => _phase = VideoRecorderPhase.denied);
      return;
    }
    setState(() {
      _preview = recorder.buildPreview();
      _phase = VideoRecorderPhase.arming;
      _nudgeMessage = null;
    });
    try {
      await recorder.start();
      if (!mounted) {
        return;
      }
      setState(() {
        _preview = recorder.buildPreview();
        _phase = VideoRecorderPhase.recording;
      });
      _scheduleTimeline();
    } on VideoRecorderException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _phase = VideoRecorderPhase.idle;
        _preview = null;
        _errorMessage = error.message;
      });
    }
  }

  void _scheduleTimeline() {
    for (final VideoTimelineEvent event in videoTimelineEvents()) {
      _timers.add(Timer(event.at, () => _onTimelineEvent(event)));
    }
  }

  void _onTimelineEvent(VideoTimelineEvent event) {
    if (!mounted || _phase != VideoRecorderPhase.recording) {
      return;
    }
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

  Future<void> _stop() async {
    if (_phase != VideoRecorderPhase.recording) {
      return;
    }
    _cancelTimers();
    setState(() {
      _phase = VideoRecorderPhase.saving;
      _errorMessage = null;
      _nudgeMessage = null;
    });
    String? entryId;
    final Future<String> pending = _persist();
    try {
      try {
        entryId = await pending.timeout(widget.saveTimeout);
      } on TimeoutException {
        entryId = await pending;
      }
    } on VideoRecorderException catch (error) {
      _failBackToRecording(error.message);
    } on CaptureException catch (error) {
      _failBackToRecording(error.message);
    } catch (error, stackTrace) {
      debugPrint('Video save failed: $error\n$stackTrace');
      _failBackToRecording(unexpectedVideoSaveMessage);
    }
    if (entryId == null || !mounted) {
      return;
    }
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

  void _failBackToRecording(String message) {
    if (!mounted) {
      return;
    }
    setState(() {
      _phase = VideoRecorderPhase.recording;
      _errorMessage = message;
    });
  }

  Future<void> _cancel() async {
    _cancelTimers();
    if (_phase == VideoRecorderPhase.recording ||
        _phase == VideoRecorderPhase.arming) {
      await _recorder.cancel();
    }
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _cancelTimers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VideoRecorderSheet(
      phase: _phase,
      preview: (_phase == VideoRecorderPhase.arming ||
              _phase == VideoRecorderPhase.recording)
          ? _preview
          : null,
      nudgeMessage: _nudgeMessage,
      errorMessage: _errorMessage,
      onStart: _start,
      onStop: _stop,
      onCancel: _cancel,
    );
  }
}

Future<String?> showVideoComposer(BuildContext context, String date) {
  return showGeneralDialog<String>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Dismiss video recorder',
    barrierColor: Palette.ink.withValues(alpha: 0.32),
    transitionDuration: Motion.modalPop,
    pageBuilder: (
      BuildContext dialogContext,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
    ) {
      return VideoComposerConnector(date: date);
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
