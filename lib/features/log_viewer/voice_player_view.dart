import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/entry_cards/cards/voice_body.dart'
    show voiceTransportValue;
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/audio_playback.dart';
import 'package:field_notes/features/entry_cards/playback/playback_focus.dart';
import 'package:field_notes/features/entry_cards/playback/voice_playback.dart';
import 'package:field_notes/features/entry_cards/transport/transport.dart';
import 'package:field_notes/features/entry_cards/util/duration_format.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart'
    show LogViewerPlace;
import 'package:field_notes/features/log_viewer/log_viewer_scene.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart';
import 'package:field_notes/features/log_viewer/viewer_waveform.dart';

const String _unavailableLabel = "Can't play this recording";

const Duration _seekStep = Duration(seconds: 5);

const double _totalSize = 17;
const double _totalAlpha = 0.6;

const Alignment _unavailableAlignment = Alignment(0, -0.45);
const EdgeInsets _unavailablePadding = EdgeInsets.symmetric(horizontal: 72);

const double _embeddedWaveMaxWidth = 720;
const double _embeddedWaveHeight = 140;
const double _embeddedWaveSide = 28;
const double _embeddedElapsedSize = 44;
const double _embeddedPrimary = 56;
const double _embeddedGap = 18;
const EdgeInsets _embeddedPadding = EdgeInsets.symmetric(vertical: 24);

class VoicePlayerView extends StatefulWidget {
  const VoicePlayerView({
    super.key,
    required this.scene,
    required this.resolver,
    required this.playerFactory,
    this.focus,
    this.embedded = false,
    this.autoplay = false,
    this.startAt,
    this.onPlace,
  });

  final LogViewerScene scene;
  final MediaResolver resolver;
  final EntryAudioPlayerFactory playerFactory;
  final PlaybackFocus? focus;
  final bool embedded;
  final bool autoplay;
  final Duration? startAt;
  final ValueChanged<LogViewerPlace>? onPlace;

  @override
  State<VoicePlayerView> createState() => _VoicePlayerViewState();
}

class _VoicePlayerViewState extends State<VoicePlayerView> {
  late final VoicePlayback _playback;
  bool _launchPending = false;

  @override
  void initState() {
    super.initState();
    _playback = VoicePlayback(
      entry: widget.scene.entry,
      resolver: widget.resolver,
      playerFactory: widget.playerFactory,
      focus: widget.focus,
    );
    _launchPending = widget.autoplay || widget.startAt != null;
    _playback.addListener(_onPlayback);
  }

  @override
  void didUpdateWidget(VoicePlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scene.entry.id != widget.scene.entry.id) {
      _launchPending = false;
    }
    _playback.rebind(entry: widget.scene.entry, resolver: widget.resolver);
  }

  @override
  void dispose() {
    _playback.removeListener(_onPlayback);
    _playback.dispose();
    super.dispose();
  }

  void _onPlayback() {
    if (!mounted) {
      return;
    }
    if (_launchPending && _playback.ready) {
      _launchPending = false;
      _launch();
    }
    widget.onPlace?.call((
      position: _playback.state == AudioPlaybackState.completed
          ? Duration.zero
          : _playback.position,
      playing: _playback.isPlaying,
    ));
    setState(() {});
  }

  void _launch() {
    final Duration? startAt = widget.startAt;
    if (startAt != null) {
      unawaited(_playback.seekTo(startAt, play: widget.autoplay));
      return;
    }
    if (widget.autoplay && !_playback.isPlaying) {
      unawaited(_playback.toggle());
    }
  }

  String _positionPhrase(Duration position) =>
      '${formatMediaDuration(position.inMilliseconds)}'
      ' of ${formatMediaDuration(_playback.total.inMilliseconds)}';

  @override
  Widget build(BuildContext context) {
    final LogViewerScene scene = widget.scene;
    final VoicePlayback playback = _playback;
    final VoidCallback? toggle = playback.ready ? playback.toggle : null;
    if (widget.embedded) {
      return ViewerKeys(onSpace: toggle, child: _embeddedPlayer(toggle));
    }
    return ViewerKeys(
      autofocus: false,
      onEscape: scene.onEscape,
      onPageUp: scene.onEarlier,
      onPageDown: scene.onLater,
      child: ViewerStage(
        ground: ViewerGround.voice,
        onSwipeNext: scene.onLater,
        onSwipePrevious: scene.onEarlier,
        child: _viewerPlayer(context),
      ),
    );
  }

  Widget _media(double height) {
    final VoicePlayback playback = _playback;
    if (playback.unavailable) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            _unavailableLabel,
            textAlign: TextAlign.center,
            style: context.textStyles.captionSans.copyWith(
              color: Palette.mediaInk,
            ),
          ),
        ),
      );
    }
    final bool ready = playback.ready;
    return ViewerWaveform(
      peaks: widget.scene.entry.peaks,
      progress: playback.progress,
      active: playback.isActive,
      height: height,
      onSeek: ready ? playback.seekToFraction : null,
      semanticValue: _positionPhrase(playback.position),
      increasedValue: _positionPhrase(playback.stepped(_seekStep)),
      decreasedValue: _positionPhrase(playback.stepped(-_seekStep)),
      onIncrease: ready ? () => playback.seekBy(_seekStep) : null,
      onDecrease: ready ? () => playback.seekBy(-_seekStep) : null,
    );
  }

  Widget _elapsed(double size) {
    final VoicePlayback playback = _playback;
    final TextStyle elapsed = context.textStyles.displaySerif.copyWith(
      fontSize: size,
      color: Palette.mediaInk,
      fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
    );
    return Text.rich(
      TextSpan(
        text: formatMediaDuration(playback.position.inMilliseconds),
        style: elapsed,
        children: <InlineSpan>[
          TextSpan(
            text: ' / ${formatMediaDuration(playback.total.inMilliseconds)}',
            style: elapsed.copyWith(
              fontSize: _totalSize,
              color: Palette.mediaInk.withValues(alpha: _totalAlpha),
            ),
          ),
        ],
      ),
      maxLines: 1,
      softWrap: false,
    );
  }

  Widget _viewerPlayer(BuildContext context) {
    final LogViewerScene scene = widget.scene;
    final VoicePlayback playback = _playback;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        NoSwipe(
          behavior: HitTestBehavior.deferToChild,
          child: Transport(
            kind: TransportKind.voice,
            mode: TransportMode.viewer,
            value: voiceTransportValue(playback),
            peaks: scene.entry.peaks,
            tuning: playback.tuning,
            autofocus: true,
            onBack: scene.onBack,
            backLabel: scene.exitLabel,
            onMore: () => showViewerLogSheet(context, scene),
            onFullScreen: scene.onFullScreen,
            fullScreen: scene.fullScreen,
          ),
        ),
        if (playback.unavailable)
          Align(
            alignment: _unavailableAlignment,
            child: Padding(
              padding: _unavailablePadding,
              child: Text(
                _unavailableLabel,
                textAlign: TextAlign.center,
                style: context.textStyles.captionSans.copyWith(
                  color: context.colors.ink,
                ),
              ),
            ),
          ),
        ViewerFullScreenHide(
          fullScreen: scene.fullScreen,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              ViewerLogBar(scene: scene),
              ViewerEdgeArrows(
                onPrevious: scene.onEarlier,
                onNext: scene.onLater,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _embeddedPlayer(VoidCallback? toggle) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double waveWidth = math.min(
          _embeddedWaveMaxWidth,
          math.max(0.0, constraints.maxWidth - _embeddedWaveSide * 2),
        );
        return ClipRect(
          child: OverflowBox(
            minHeight: 0,
            maxHeight: double.infinity,
            alignment: Alignment.center,
            child: Padding(
              padding: _embeddedPadding,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SizedBox(
                    width: waveWidth,
                    height: _embeddedWaveHeight,
                    child: _media(_embeddedWaveHeight),
                  ),
                  const SizedBox(height: _embeddedGap),
                  _elapsed(_embeddedElapsedSize),
                  const SizedBox(height: _embeddedGap),
                  ViewerPrimaryButton(
                    playing: _playback.isPlaying,
                    diameter: _embeddedPrimary,
                    onPressed: toggle,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
