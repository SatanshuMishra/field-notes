import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/icons/chevron_glyph.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/features/entry_cards/cards/voice_waveform.dart'
    show voiceWaveformSeed;
import 'package:field_notes/features/entry_cards/compact/log_actions_pill.dart'
    show logActionsDeleteKey;
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/audio_playback.dart';
import 'package:field_notes/features/entry_cards/playback/playback_focus.dart';
import 'package:field_notes/features/entry_cards/playback/voice_playback.dart';
import 'package:field_notes/features/entry_cards/util/duration_format.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart'
    show LogViewerExit;
import 'package:field_notes/features/log_viewer/log_viewer_panel.dart'
    show
        logViewerBackKey,
        logViewerDeleteLabel,
        logViewerEarlierKey,
        logViewerEarlierLabel,
        logViewerLaterKey,
        logViewerLaterLabel;
import 'package:field_notes/features/log_viewer/log_viewer_scene.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart';
import 'package:field_notes/features/log_viewer/viewer_waveform.dart';

const String _unavailableLabel = "Can't play this recording";
const String _earlierLabel = 'Earlier';
const String _laterLabel = 'Later';
const String _playLabel = 'Play';
const String _pauseLabel = 'Pause';

const Duration _seekStep = Duration(seconds: 5);

const double _dockGlyphSize = 18;
const double _stepGlyphSize = 15;

const double _totalSize = 17;
const double _totalAlpha = 0.6;
const double _elapsedGap = 18;

const double _phoneQuietTop = 16;
const double _phoneQuietSide = 18;
const double _phoneWaveHeight = 176;
const double _phoneWaveSide = 22;
const double _phoneElapsedSize = 48;
const double _phonePrimary = 68;

const double _macWaveMaxWidth = 960;
const double _macWaveHeight = 200;
const double _macWaveSide = 40;
const double _macElapsedSize = 56;
const double _macPrimary = 56;
const double _macStepFace = 40;
const double _macStepSlot = 48;
const double _macCapsuleGap = 6;
const double _macCapsuleBottom = 30;

class VoicePlayerView extends StatefulWidget {
  const VoicePlayerView({
    super.key,
    required this.scene,
    required this.resolver,
    required this.playerFactory,
    this.focus,
  });

  final LogViewerScene scene;
  final MediaResolver resolver;
  final EntryAudioPlayerFactory playerFactory;
  final PlaybackFocus? focus;

  @override
  State<VoicePlayerView> createState() => _VoicePlayerViewState();
}

class _VoicePlayerViewState extends State<VoicePlayerView> {
  late final VoicePlayback _playback;

  @override
  void initState() {
    super.initState();
    _playback = VoicePlayback(
      entry: widget.scene.entry,
      resolver: widget.resolver,
      playerFactory: widget.playerFactory,
      focus: widget.focus,
    );
    _playback.addListener(_onPlayback);
  }

  @override
  void didUpdateWidget(VoicePlayerView oldWidget) {
    super.didUpdateWidget(oldWidget);
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
    setState(() {});
  }

  String _positionPhrase(Duration position) =>
      '${formatMediaDuration(position.inMilliseconds)}'
      ' of ${formatMediaDuration(_playback.total.inMilliseconds)}';

  @override
  Widget build(BuildContext context) {
    final LogViewerScene scene = widget.scene;
    final VoicePlayback playback = _playback;
    final VoidCallback? toggle = playback.ready ? playback.toggle : null;
    final bool sidebar =
        resolveShellLayout(Theme.of(context).platform) == ShellLayout.sidebar;
    return ViewerKeys(
      onSpace: toggle,
      onLeft: scene.onEarlier,
      onRight: scene.onLater,
      onEscape: scene.onBack,
      child: ViewerStage(
        ground: ViewerGround.voice,
        onSwipeNext: scene.onLater,
        onSwipePrevious: scene.onEarlier,
        child: sidebar ? _macPlayer(toggle) : _phonePlayer(toggle),
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
      seed: voiceWaveformSeed(widget.scene.entry.id),
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

  Widget _quietLine(BuildContext context) {
    final LogViewerScene scene = widget.scene;
    return ViewerQuietLine(mood: scene.mood, text: scene.quietLine(context));
  }

  Widget _phonePlayer(VoidCallback? toggle) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double statusBar = MediaQuery.paddingOf(context).top;
        final double waveTop = (constraints.maxHeight - _phoneWaveHeight) / 2;
        return Stack(
          children: <Widget>[
            Positioned(
              top: statusBar + _phoneQuietTop,
              left: _phoneQuietSide,
              right: _phoneQuietSide,
              child: Center(child: _quietLine(context)),
            ),
            Positioned(
              top: waveTop,
              left: _phoneWaveSide,
              right: _phoneWaveSide,
              height: _phoneWaveHeight,
              child: _media(_phoneWaveHeight),
            ),
            Positioned(
              top: waveTop + _phoneWaveHeight + _elapsedGap,
              left: _phoneWaveSide,
              right: _phoneWaveSide,
              child: Center(child: _elapsed(_phoneElapsedSize)),
            ),
            Positioned.fill(child: ViewerDock(slots: _phoneSlots(toggle))),
          ],
        );
      },
    );
  }

  List<ViewerDockSlot?> _phoneSlots(VoidCallback? toggle) {
    final LogViewerScene scene = widget.scene;
    final VoidCallback? onEarlier = scene.onEarlier;
    final VoidCallback? onLater = scene.onLater;
    final bool playing = _playback.isPlaying;
    return <ViewerDockSlot?>[
      ViewerDockSlot(
        label: scene.exitLabel,
        control: ViewerGlassCircle(
          grouped: true,
          key: logViewerBackKey,
          label: scene.exitLabel,
          glyph: _exitGlyph(scene.exit),
          onPressed: scene.onBack,
        ),
      ),
      if (onEarlier == null)
        null
      else
        ViewerDockSlot(
          label: _earlierLabel,
          control: ViewerGlassCircle(
            grouped: true,
            key: logViewerEarlierKey,
            label: logViewerEarlierLabel,
            glyph: const ChevronGlyph(
              pointsBack: true,
              color: Palette.mediaInk,
            ),
            onPressed: onEarlier,
          ),
        ),
      ViewerDockSlot(
        label: playing ? _pauseLabel : _playLabel,
        control: ViewerPrimaryButton(
          playing: playing,
          diameter: _phonePrimary,
          onPressed: toggle,
        ),
      ),
      if (onLater == null)
        null
      else
        ViewerDockSlot(
          label: _laterLabel,
          control: ViewerGlassCircle(
            grouped: true,
            key: logViewerLaterKey,
            label: logViewerLaterLabel,
            glyph: const ChevronGlyph(
              pointsBack: false,
              color: Palette.mediaInk,
            ),
            onPressed: onLater,
          ),
        ),
      ViewerDockSlot(
        label: logViewerDeleteLabel,
        control: ViewerGlassCircle(
          grouped: true,
          key: logActionsDeleteKey,
          label: logViewerDeleteLabel,
          glyph: const IconStickerGlyphIcon(
            glyph: IconStickerGlyph.trash,
            color: Palette.mediaInk,
            size: _dockGlyphSize,
          ),
          onPressed: scene.onDelete,
        ),
      ),
    ];
  }

  Widget _exitGlyph(LogViewerExit exit) {
    return switch (exit) {
      LogViewerExit.back => const ChevronGlyph(
        pointsBack: true,
        color: Palette.mediaInk,
      ),
      LogViewerExit.close => const IconStickerGlyphIcon(
        glyph: IconStickerGlyph.close,
        color: Palette.mediaInk,
        size: _dockGlyphSize,
      ),
    };
  }

  Widget _macPlayer(VoidCallback? toggle) {
    final LogViewerScene scene = widget.scene;
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double waveWidth = math.min(
          _macWaveMaxWidth,
          math.max(0.0, constraints.maxWidth - _macWaveSide * 2),
        );
        final double waveTop = (constraints.maxHeight - _macWaveHeight) / 2;
        return Stack(
          children: <Widget>[
            Positioned(
              top: waveTop,
              left: (constraints.maxWidth - waveWidth) / 2,
              width: waveWidth,
              height: _macWaveHeight,
              child: _media(_macWaveHeight),
            ),
            Positioned(
              top: waveTop + _macWaveHeight + _elapsedGap,
              left: _macWaveSide,
              right: _macWaveSide,
              child: Center(child: _elapsed(_macElapsedSize)),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: _macCapsuleBottom,
              child: Center(child: _macCapsule(toggle)),
            ),
            Positioned.fill(
              child: ViewerTopBar(
                exitLabel: scene.exitLabel,
                onExit: scene.onBack,
                centre: _quietLine(context),
                onDelete: scene.onDelete,
                exitKey: logViewerBackKey,
                deleteKey: logActionsDeleteKey,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _macCapsule(VoidCallback? toggle) {
    final LogViewerScene scene = widget.scene;
    final VoidCallback? onEarlier = scene.onEarlier;
    final VoidCallback? onLater = scene.onLater;
    return ViewerCapsule(
      children: <Widget>[
        _macStep(
          onEarlier == null
              ? null
              : ViewerGlassCircle(
                  key: logViewerEarlierKey,
                  label: logViewerEarlierLabel,
                  face: _macStepFace,
                  glyph: const ChevronGlyph(
                    pointsBack: true,
                    color: Palette.mediaInk,
                    size: _stepGlyphSize,
                  ),
                  onPressed: onEarlier,
                ),
        ),
        const SizedBox(width: _macCapsuleGap),
        ViewerPrimaryButton(
          playing: _playback.isPlaying,
          diameter: _macPrimary,
          onPressed: toggle,
        ),
        const SizedBox(width: _macCapsuleGap),
        _macStep(
          onLater == null
              ? null
              : ViewerGlassCircle(
                  key: logViewerLaterKey,
                  label: logViewerLaterLabel,
                  face: _macStepFace,
                  glyph: const ChevronGlyph(
                    pointsBack: false,
                    color: Palette.mediaInk,
                    size: _stepGlyphSize,
                  ),
                  onPressed: onLater,
                ),
        ),
      ],
    );
  }

  Widget _macStep(Widget? control) {
    return SizedBox.square(
      dimension: _macStepSlot,
      child: Center(
        child: control ?? const SizedBox.square(dimension: _macStepFace),
      ),
    );
  }
}
