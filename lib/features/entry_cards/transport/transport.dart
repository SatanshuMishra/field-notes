import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show UncontrolledProviderScope;

import '../../../data/media/video_frames.dart';
import '../../../design/interaction/min_target.dart';
import '../../../design/tokens/tokens.dart';
import '../../../domain/platform/desktop_platform.dart';
import '../cards/voice_waveform.dart';
import '../playback/video_playback.dart';
import 'transport_bar.dart';
import 'transport_keys.dart';
import 'transport_timeline.dart';

export 'transport_bar.dart' show TransportValue, transportReadoutHold;

enum TransportKind { video, voice }

enum TransportMode { card, viewer }

const String transportVideoPositionLabel = 'Video position';
const Key transportVideoTimelineKey = ValueKey<String>('video-scrub-bar');

const double _railTimelineHeight = 24;
const double _viewerVoiceHeight = 128;
const double _viewerVoiceCompactHeight = 112;
const double _timelineGap = 4;
const double _viewerVoiceGap = 16;
const double _viewerVoiceMaxWidth = 880;
const double _fadeStop = 0.62;
const Alignment _readoutAlignment = Alignment(0, -0.08);
const EdgeInsets _viewerVideoPadding = EdgeInsets.fromLTRB(24, 72, 24, 16);
const double _fitSidePadding = 24;
const double _fitNarrowSidePadding = 16;
const double _fitFixedTargets = 6;
const double _fitPlayGap = 4;
const double _fitVolumeTrack = 82;
const double _fitTimeAllowance = 100;
const EdgeInsets _viewerVideoCompactPadding = EdgeInsets.fromLTRB(
  16,
  56,
  16,
  36,
);
const EdgeInsets _viewerVoicePadding = EdgeInsets.fromLTRB(112, 96, 112, 48);
const EdgeInsets _viewerVoiceCompactPadding = EdgeInsets.fromLTRB(
  20,
  96,
  20,
  36,
);

String transportSeekReadout(Duration delta) =>
    '${delta.isNegative ? '-' : '+'}${delta.inSeconds.abs()} s';

class TransportActivityNotification extends Notification {
  const TransportActivityNotification();
}

class Transport extends StatefulWidget {
  const Transport({
    super.key,
    required this.kind,
    required this.mode,
    required this.value,
    this.peaks,
    this.mediaPath,
    this.tuning,
    this.compact,
    this.fitWidth = false,
    this.autofocus = false,
    this.playKey,
    this.onFullScreen,
    this.fullScreen = false,
    this.onBack,
    this.backLabel = 'Back',
    this.onMore,
  });

  final TransportKind kind;
  final TransportMode mode;
  final TransportValue value;
  final List<double>? peaks;
  final String? mediaPath;
  final PlaybackTuning? tuning;
  final bool? compact;
  final bool fitWidth;
  final bool autofocus;
  final Key? playKey;
  final VoidCallback? onFullScreen;
  final bool fullScreen;
  final VoidCallback? onBack;
  final String backLabel;
  final VoidCallback? onMore;

  @override
  State<Transport> createState() => _TransportState();
}

class _TransportState extends State<Transport> {
  VideoFrames? _frames;
  Timer? _readoutTimer;
  String? _readout;
  int _readoutSerial = 0;

  @override
  void dispose() {
    _readoutTimer?.cancel();
    super.dispose();
  }

  PlaybackTuning get _tuning => widget.tuning ?? playbackTuning;

  bool get _inViewer => widget.mode == TransportMode.viewer;

  bool get _isVideo => widget.kind == TransportKind.video;

  bool get _canSeek =>
      widget.value.onSeek != null &&
      (widget.value.total ?? Duration.zero) > Duration.zero;

  bool _compactIn(BuildContext context) =>
      widget.compact ?? !isDesktopPlatform(Theme.of(context).platform);

  void _flash(String text) {
    if (!_inViewer) {
      return;
    }
    _readoutTimer?.cancel();
    setState(() {
      _readout = text;
      _readoutSerial += 1;
    });
    _readoutTimer = Timer(transportReadoutHold, _clearReadout);
  }

  void _clearReadout() {
    if (mounted) {
      setState(() => _readout = null);
    }
  }

  void _announceActivity() =>
      const TransportActivityNotification().dispatch(context);

  void _seekTo(Duration target) {
    final TransportValue value = widget.value;
    final Duration? total = value.total;
    if (total != null) {
      value.onSeek?.call(clampPlaybackPosition(target, total));
    }
  }

  void _seekBy(Duration delta) {
    _seekTo(widget.value.position + delta);
    _flash(transportSeekReadout(delta));
  }

  void _seekToShare(double share) {
    final Duration? total = widget.value.total;
    if (total != null) {
      _seekTo(Duration(milliseconds: (total.inMilliseconds * share).round()));
    }
  }

  void _volumeBy(double delta) {
    final PlaybackTuning tuning = _tuning;
    tuning.setVolume(tuning.volume + delta);
    _flash(transportVolumePhrase(tuning.volume));
  }

  void _toggleMute() {
    final PlaybackTuning tuning = _tuning;
    tuning.toggleMute();
    _flash(tuning.muted ? 'Muted' : 'Sound on');
  }

  Map<LogicalKeyboardKey, VoidCallback> _bindings(BuildContext context) {
    final bool canSeek = _canSeek;
    final bool hasVolumeControls = isDesktopPlatform(
      Theme.of(context).platform,
    );
    return transportKeyBindings(
      onToggle: widget.value.onToggle,
      onSeekBy: canSeek ? _seekBy : null,
      onSeekToShare: canSeek ? _seekToShare : null,
      onVolumeBy: hasVolumeControls ? _volumeBy : null,
      onMute: hasVolumeControls ? _toggleMute : null,
      onFullScreen: widget.onFullScreen,
      onFrameStep: canSeek && _isVideo && !widget.value.isPlaying
          ? (Duration delta) => _seekTo(widget.value.position + delta)
          : null,
    );
  }

  VideoFrames? _findFrames() => context
      .findAncestorWidgetOfExactType<UncontrolledProviderScope>()
      ?.container
      .read(videoFramesProvider);

  Future<Uint8List?> _frameAt(Duration position) async {
    final String? path = widget.mediaPath;
    final VideoFrames? frames = _frames ??= _findFrames();
    if (path == null || frames == null) {
      return null;
    }
    return frames.frameAt(path, position);
  }

  double _voiceHeight(bool compact) {
    if (!_inViewer) {
      return voiceWaveformTargetHeight;
    }
    return compact ? _viewerVoiceCompactHeight : _viewerVoiceHeight;
  }

  Widget _timeline(
    BuildContext context,
    TransportPalette palette,
    bool compact,
  ) {
    final TransportValue value = widget.value;
    final Duration? total = value.total;
    if (!_isVideo) {
      final int totalMs = total?.inMilliseconds ?? 0;
      return VoiceWaveform(
        peaks: widget.peaks,
        active: value.active,
        progress: totalMs <= 0
            ? 0
            : (value.position.inMilliseconds / totalMs).clamp(0.0, 1.0),
        total: total,
        height: _voiceHeight(compact),
        barsHeight: _inViewer ? _voiceHeight(compact) : voiceWaveformBarsHeight,
        palette: palette,
        onSeek: value.onSeek,
      );
    }
    final double height = _railHeight(context);
    return TransportTimeline(
      pressKey: transportVideoTimelineKey,
      label: transportVideoPositionLabel,
      position: value.position,
      total: total,
      onSeek: value.onSeek,
      onScrubUpdate: value.onScrubUpdate,
      onScrubEnd: value.onScrubEnd,
      palette: palette,
      height: height,
      frameAt: widget.mediaPath == null ? null : _frameAt,
      frameSize: _inViewer ? transportViewerFrameSize : transportCardFrameSize,
    );
  }

  double _railHeight(BuildContext context) {
    final double target = minTargetOn(Theme.of(context).platform);
    return target > _railTimelineHeight ? target : _railTimelineHeight;
  }

  VoidCallback? get _onBack10 =>
      _canSeek ? () => _seekBy(-transportSkipStep) : null;

  VoidCallback? get _onForward10 =>
      _canSeek ? () => _seekBy(transportSkipStep) : null;

  TransportPlayFace get _playFace {
    if (!_inViewer) {
      return TransportPlayFace.accent;
    }
    return _isVideo ? TransportPlayFace.quiet : TransportPlayFace.cta;
  }

  Widget _controls(
    BuildContext context,
    TransportPalette palette,
    bool compact,
    _Fit fit,
  ) {
    final PlaybackTuning tuning = _tuning;
    if (_inViewer && compact) {
      return TransportDock(
        value: widget.value,
        tuning: tuning,
        onBack10: _onBack10,
        onForward10: _onForward10,
        playKey: widget.playKey,
        onBack: widget.onBack,
        backLabel: widget.backLabel,
        onMore: widget.onMore,
      );
    }
    return TransportBar(
      value: widget.value,
      tuning: tuning,
      face: _playFace,
      rail: palette.rail,
      volumeAlwaysOpen: _inViewer && fit.volumeOpen,
      showSpeed: fit.speed,
      onBack10: _onBack10,
      onForward10: _onForward10,
      playKey: widget.playKey,
      onFullScreen: _inViewer ? widget.onFullScreen : null,
      fullScreen: widget.fullScreen,
    );
  }

  Widget _track(BuildContext context, bool compact, _Fit fit) {
    final FieldNotesColors colors = context.colors;
    final TransportPalette palette = _inViewer
        ? TransportPalette.viewer(colors)
        : TransportPalette.card(colors);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _timeline(context, palette, compact),
        SizedBox(
          height: _inViewer && !_isVideo ? _viewerVoiceGap : _timelineGap,
        ),
        _controls(context, palette, compact, fit),
      ],
    );
  }

  _Fit _fitFor(BuildContext context, double width) {
    if (!widget.fitWidth) {
      return _Fit.roomy;
    }
    final double target = minIconTargetOn(Theme.of(context).platform);
    final double time =
        _fitTimeAllowance * MediaQuery.textScalerOf(context).scale(1);
    final double base = _fitFixedTargets * target + _fitPlayGap + time;
    final double roomy = width - 2 * _fitSidePadding;
    if (roomy >= base + _fitVolumeTrack) {
      return _Fit.roomy;
    }
    final double narrow = width - 2 * _fitNarrowSidePadding;
    if (narrow >= base) {
      return _Fit.closedVolume;
    }
    return _Fit.bare;
  }

  Widget _viewerVideo(
    BuildContext context,
    Widget track,
    bool compact,
    _Fit fit,
  ) {
    final FieldNotesColors colors = context.colors;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[colors.viewerFadeStart, colors.viewerFadeEnd],
                stops: const <double>[0, _fadeStop],
              ),
            ),
            child: Padding(
              padding: compact
                  ? _viewerVideoCompactPadding
                  : _viewerVideoPadding.copyWith(
                      left: fit.sidePadding,
                      right: fit.sidePadding,
                    ),
              child: track,
            ),
          ),
        ),
        ..._readoutLayer(),
      ],
    );
  }

  Widget _viewerVoice(Widget track, bool compact) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Padding(
          padding: compact ? _viewerVoiceCompactPadding : _viewerVoicePadding,
          child: Align(
            alignment: compact ? Alignment.bottomCenter : Alignment.center,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _viewerVoiceMaxWidth),
              child: track,
            ),
          ),
        ),
        ..._readoutLayer(),
      ],
    );
  }

  List<Widget> _readoutLayer() {
    final String? readout = _readout;
    if (readout == null) {
      return const <Widget>[];
    }
    return <Widget>[
      Positioned.fill(
        child: IgnorePointer(
          child: Align(
            alignment: _readoutAlignment,
            child: TransportReadout(
              key: ValueKey<int>(_readoutSerial),
              text: readout,
            ),
          ),
        ),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bool compact = _compactIn(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final _Fit fit = _fitFor(context, constraints.maxWidth);
        return ListenableBuilder(
          listenable: _tuning,
          builder: (BuildContext context, Widget? child) {
            final Widget track = _track(context, compact, fit);
            final Widget laidOut = switch ((widget.mode, widget.kind)) {
              (TransportMode.card, _) => track,
              (TransportMode.viewer, TransportKind.video) => _viewerVideo(
                context,
                track,
                compact,
                fit,
              ),
              (TransportMode.viewer, TransportKind.voice) => _viewerVoice(
                track,
                compact,
              ),
            };
            return TransportKeys(
              bindings: _bindings(context),
              takesFocus: _inViewer,
              autofocus: widget.autofocus,
              onHandled: _announceActivity,
              child: laidOut,
            );
          },
        );
      },
    );
  }
}

enum _Fit {
  roomy(_fitSidePadding, true, true),
  closedVolume(_fitNarrowSidePadding, false, true),
  bare(_fitNarrowSidePadding, false, false);

  const _Fit(this.sidePadding, this.volumeOpen, this.speed);

  final double sidePadding;
  final bool volumeOpen;
  final bool speed;
}
