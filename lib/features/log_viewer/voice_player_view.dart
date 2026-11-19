import 'dart:async';

import 'package:flutter/material.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/entry_cards/cards/voice_body.dart'
    show voiceTransportValue;
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/audio_playback.dart';
import 'package:field_notes/features/entry_cards/playback/playback_focus.dart';
import 'package:field_notes/features/entry_cards/playback/voice_playback.dart';
import 'package:field_notes/features/entry_cards/transport/transport.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart'
    show LogViewerPlace;
import 'package:field_notes/features/log_viewer/log_viewer_scene.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart';

const String _unavailableLabel = "Can't play this recording";

const Alignment _unavailableAlignment = Alignment(0, -0.45);
const EdgeInsets _unavailablePadding = EdgeInsets.symmetric(horizontal: 72);

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

  @override
  Widget build(BuildContext context) {
    final LogViewerScene scene = widget.scene;
    if (widget.embedded) {
      return _transportOnly(context);
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
        if (playback.unavailable) _unavailableNotice(context),
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

  Widget _transportOnly(BuildContext context) {
    final VoicePlayback playback = _playback;
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Transport(
          kind: TransportKind.voice,
          mode: TransportMode.viewer,
          value: voiceTransportValue(playback),
          peaks: widget.scene.entry.peaks,
          tuning: playback.tuning,
          autofocus: true,
        ),
        if (playback.unavailable) _unavailableNotice(context),
      ],
    );
  }

  Widget _unavailableNotice(BuildContext context) {
    return Align(
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
    );
  }
}
