import 'dart:async';

import 'package:field_notes/features/entry_cards/playback/playback_focus.dart';
import 'package:field_notes/features/entry_cards/playback/video_playback.dart'
    show PlaybackTuning;
import 'package:field_notes/features/entry_cards/playback/voice_playback.dart';
import 'package:flutter/widgets.dart';

import '../../../domain/models/models.dart';
import '../media/media_placeholders.dart';
import '../media/media_resolver.dart';
import '../playback/audio_playback.dart';
import '../transport/transport.dart';

export '../transport/transport_bar.dart' show PlayPauseGlyph;

const double _unavailableMinHeight = 64;
const Key voicePlayToggleKey = ValueKey<String>('voice-play-toggle');

TransportValue voiceTransportValue(VoicePlayback playback) {
  final bool ready = playback.ready;
  return TransportValue(
    position: playback.position,
    total: playback.total,
    isPlaying: playback.isPlaying,
    active:
        playback.isActive ||
        (playback.state == AudioPlaybackState.idle &&
            playback.position > Duration.zero),
    onToggle: ready ? playback.toggle : null,
    onSeek: ready
        ? (Duration target) => unawaited(playback.seekTo(target, play: false))
        : null,
  );
}

class VoiceBody extends StatefulWidget {
  const VoiceBody({
    super.key,
    required this.entry,
    required this.resolver,
    required this.playerFactory,
    this.focus,
    this.tuning,
  });

  final Entry entry;
  final MediaResolver resolver;
  final EntryAudioPlayerFactory playerFactory;
  final PlaybackFocus? focus;
  final PlaybackTuning? tuning;

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
      tuning: widget.tuning,
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
    return Transport(
      kind: TransportKind.voice,
      mode: TransportMode.card,
      value: voiceTransportValue(playback),
      peaks: widget.entry.peaks,
      tuning: playback.tuning,
      playKey: voicePlayToggleKey,
    );
  }
}
