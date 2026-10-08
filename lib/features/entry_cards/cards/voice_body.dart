import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/features/entry_cards/playback/playback_focus.dart';
import 'package:field_notes/features/entry_cards/playback/voice_playback.dart';
import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../domain/models/models.dart';
import '../media/media_placeholders.dart';
import '../media/media_resolver.dart';
import '../playback/audio_playback.dart';
import '../util/duration_format.dart';
import 'voice_waveform.dart';

const double _unavailableMinHeight = 64;

const double _toggleSize = 38;
const double _toggleTarget = 48;
const double _toggleGap = 12;
const double _toggleGlyphSize = 15;
const double _toggleGlyphOffset = 2;
const BorderRadius _toggleRadius = BorderRadius.all(
  Radius.circular(_toggleSize / 2),
);

const double _labelGap = 12;
const double _labelMinWidth = 62;
const Duration _seekStep = Duration(seconds: 5);
const String _positionLabel = 'Playback position';

class VoiceBody extends StatefulWidget {
  const VoiceBody({
    super.key,
    required this.entry,
    required this.resolver,
    required this.playerFactory,
    this.focus,
  });

  final Entry entry;
  final MediaResolver resolver;
  final EntryAudioPlayerFactory playerFactory;
  final PlaybackFocus? focus;

  @override
  State<VoiceBody> createState() => _VoiceBodyState();
}

class _VoiceBodyState extends State<VoiceBody> {
  late final VoicePlayback _playback;

  @override
  void initState() {
    super.initState();
    _playback = VoicePlayback(
      entry: widget.entry,
      resolver: widget.resolver,
      playerFactory: widget.playerFactory,
      focus: widget.focus,
    );
    _playback.addListener(_onPlayback);
  }

  @override
  void didUpdateWidget(VoiceBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    _playback.rebind(entry: widget.entry, resolver: widget.resolver);
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
  void dispose() {
    _playback.removeListener(_onPlayback);
    _playback.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final VoicePlayback playback = _playback;
    if (playback.unavailable) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _unavailableMinHeight),
        child: const CorruptMediaPlaceholder(
          label: "Can't play this recording",
        ),
      );
    }
    final FieldNotesColors colors = context.colors;
    final bool ready = playback.ready;
    return Row(
      children: <Widget>[
        _PlayToggle(
          isPlaying: playback.isPlaying,
          onTap: ready ? playback.toggle : null,
        ),
        const SizedBox(width: _toggleSize + _toggleGap - _toggleTarget),
        Expanded(
          child: Semantics(
            container: true,
            slider: true,
            enabled: ready,
            label: _positionLabel,
            value: _positionPhrase(playback.position),
            increasedValue: _positionPhrase(playback.stepped(_seekStep)),
            decreasedValue: _positionPhrase(playback.stepped(-_seekStep)),
            onIncrease: ready ? () => playback.seekBy(_seekStep) : null,
            onDecrease: ready ? () => playback.seekBy(-_seekStep) : null,
            child: VoiceWaveform(
              seed: voiceWaveformSeed(widget.entry.id),
              active: playback.isActive,
              progress: playback.progress,
              onSeek: ready ? playback.seekToFraction : null,
            ),
          ),
        ),
        const SizedBox(width: _labelGap),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: _labelMinWidth),
          child: Text(
            '${formatMediaDuration(playback.position.inMilliseconds)}'
            ' / ${formatMediaDuration(widget.entry.durationMs)}',
            textAlign: TextAlign.right,
            style: context.textStyles.caption11Sans.copyWith(
              color: colors.muted,
              fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _PlayToggle extends StatelessWidget {
  const _PlayToggle({required this.isPlaying, required this.onTap});

  final bool isPlaying;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      enabled: onTap != null,
      label: isPlaying ? 'Pause' : 'Play',
      child: GestureDetector(
        key: const ValueKey<String>('voice-play-toggle'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: _toggleTarget,
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Opacity(
              opacity: onTap == null ? 0.5 : 1.0,
              child: FocusRing(
                enabled: onTap != null,
                onPressed: onTap,
                borderRadius: _toggleRadius,
                child: Container(
                  width: _toggleSize,
                  height: _toggleSize,
                  decoration: BoxDecoration(
                    color: Palette.coral,
                    shape: BoxShape.circle,
                    border: context.shadows.outline,
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.only(left: _toggleGlyphOffset),
                      child: PlayPauseGlyph(
                        playing: isPlaying,
                        color: FieldNotesColors.light.cardBright,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PlayPauseGlyph extends StatelessWidget {
  const PlayPauseGlyph({
    super.key,
    required this.playing,
    required this.color,
    this.size = _toggleGlyphSize,
  });

  final bool playing;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: _PlayPauseGlyphPainter(playing: playing, color: color),
    );
  }
}

class _PlayPauseGlyphPainter extends CustomPainter {
  const _PlayPauseGlyphPainter({required this.playing, required this.color});

  final bool playing;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fill = Paint()..color = color;
    if (playing) {
      final double barWidth = size.width * 0.3;
      canvas.drawRect(Rect.fromLTWH(0, 0, barWidth, size.height), fill);
      canvas.drawRect(
        Rect.fromLTWH(size.width - barWidth, 0, barWidth, size.height),
        fill,
      );
      return;
    }
    final Path triangle = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(triangle, fill);
  }

  @override
  bool shouldRepaint(_PlayPauseGlyphPainter oldDelegate) =>
      playing != oldDelegate.playing || color != oldDelegate.color;
}
