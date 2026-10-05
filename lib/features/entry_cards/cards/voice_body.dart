import 'dart:async';
import 'dart:math' as math;

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../domain/models/models.dart';
import '../media/live_media.dart';
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
  });

  final Entry entry;
  final MediaResolver resolver;
  final EntryAudioPlayerFactory playerFactory;

  @override
  State<VoiceBody> createState() => _VoiceBodyState();
}

class _VoiceBodyState extends State<VoiceBody> {
  final MediaArrivalWatch _arrivals = MediaArrivalWatch();
  EntryAudioPlayer? _player;
  StreamSubscription<AudioPlaybackState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  AudioPlaybackState _state = AudioPlaybackState.idle;
  Duration _position = Duration.zero;
  bool _unavailable = false;
  bool _ready = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _startPrepare();
  }

  @override
  void didUpdateWidget(VoiceBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_needsRePrepare(oldWidget)) {
      return;
    }
    _arrivals.cancel();
    _teardownPlayer();
    _state = AudioPlaybackState.idle;
    _position = Duration.zero;
    _unavailable = false;
    _ready = false;
    _startPrepare();
  }

  void _onArrived() {
    if (!mounted || !_unavailable) {
      return;
    }
    _arrivals.cancel();
    _teardownPlayer();
    setState(() {
      _state = AudioPlaybackState.idle;
      _position = Duration.zero;
      _unavailable = false;
      _ready = false;
    });
    _startPrepare();
  }

  bool _needsRePrepare(VoiceBody oldWidget) {
    if (oldWidget.entry.mediaId != widget.entry.mediaId) {
      return true;
    }
    if (identical(oldWidget.resolver, widget.resolver)) {
      return false;
    }
    return !_ready;
  }

  void _startPrepare() {
    unawaited(
      _prepare().catchError((Object error, StackTrace stackTrace) {
        debugPrint('Voice prepare failed: $error\n$stackTrace');
      }),
    );
  }

  Future<void> _prepare() async {
    final int gen = ++_generation;
    final String? mediaId = widget.entry.mediaId;
    final ResolvedMedia media;
    try {
      media = await widget.resolver.resolve(mediaId);
    } catch (error, stackTrace) {
      debugPrint('Voice media resolve failed: $error\n$stackTrace');
      if (_isCurrent(gen)) {
        _markUnavailable();
      }
      return;
    }
    if (!_isCurrent(gen)) {
      return;
    }
    if (!media.isAvailable || media.file == null) {
      setState(() => _unavailable = true);
      _arrivals.watch(widget.resolver, mediaId, _onArrived);
      return;
    }
    final EntryAudioPlayer player = widget.playerFactory();
    _player = player;
    _stateSub = player.stateStream.listen(
      _onState,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Voice playback stream failed: $error\n$stackTrace');
        _markUnavailable();
      },
    );
    _positionSub = player.positionStream.listen(
      _onPosition,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Voice position stream failed: $error\n$stackTrace');
        _markUnavailable();
      },
    );
    try {
      await player.load(media.file!.path);
    } catch (error, stackTrace) {
      debugPrint('Voice playback load failed: $error\n$stackTrace');
      if (_isCurrent(gen)) {
        _markUnavailable();
      }
      return;
    }
    if (!_isCurrent(gen)) {
      return;
    }
    setState(() => _ready = true);
  }

  bool _isCurrent(int gen) => mounted && gen == _generation;

  void _teardownPlayer() {
    final EntryAudioPlayer? player = _player;
    _player = null;
    unawaited(_stateSub?.cancel());
    unawaited(_positionSub?.cancel());
    _stateSub = null;
    _positionSub = null;
    unawaited(player?.dispose());
  }

  void _markUnavailable() {
    if (!mounted) {
      return;
    }
    setState(() {
      _unavailable = true;
      _ready = false;
    });
  }

  void _onState(AudioPlaybackState state) {
    if (!mounted) {
      return;
    }
    setState(() => _state = state);
  }

  void _onPosition(Duration position) {
    if (!mounted) {
      return;
    }
    setState(() => _position = position);
  }

  bool get _isPlaying => _state == AudioPlaybackState.playing;

  bool get _isActive => switch (_state) {
    AudioPlaybackState.playing => true,
    AudioPlaybackState.paused ||
    AudioPlaybackState.loading => _position > Duration.zero,
    AudioPlaybackState.idle ||
    AudioPlaybackState.completed ||
    AudioPlaybackState.error => false,
  };

  Duration get _total =>
      Duration(milliseconds: math.max(0, widget.entry.durationMs ?? 0));

  double get _progress {
    final int total = _total.inMilliseconds;
    if (total <= 0) {
      return 0;
    }
    return (_position.inMilliseconds / total).clamp(0.0, 1.0);
  }

  Duration _stepped(Duration delta) {
    final Duration target = _position + delta;
    if (target <= Duration.zero) {
      return Duration.zero;
    }
    return target >= _total ? _total : target;
  }

  String _positionPhrase(Duration position) =>
      '${formatMediaDuration(position.inMilliseconds)}'
      ' of ${formatMediaDuration(_total.inMilliseconds)}';

  void _seekToFraction(double fraction) {
    final Duration target = Duration(
      milliseconds: (fraction.clamp(0.0, 1.0) * _total.inMilliseconds).round(),
    );
    unawaited(_seek(target, play: !_isActive));
  }

  void _seekBy(Duration delta) {
    unawaited(_seek(_stepped(delta), play: false));
  }

  Future<void> _seek(Duration target, {required bool play}) async {
    final EntryAudioPlayer? player = _player;
    if (player == null) {
      return;
    }
    setState(() => _position = target);
    try {
      await player.seek(target);
      if (play) {
        await player.play();
      }
    } catch (error, stackTrace) {
      debugPrint('Voice playback seek failed: $error\n$stackTrace');
      _markUnavailable();
    }
  }

  Future<void> _toggle() async {
    final EntryAudioPlayer? player = _player;
    if (player == null) {
      return;
    }
    try {
      if (_isPlaying) {
        await player.pause();
        return;
      }
      if (_state == AudioPlaybackState.completed) {
        await player.seek(Duration.zero);
      }
      await player.play();
    } catch (error, stackTrace) {
      debugPrint('Voice playback toggle failed: $error\n$stackTrace');
      _markUnavailable();
    }
  }

  @override
  void dispose() {
    _generation += 1;
    _arrivals.cancel();
    _teardownPlayer();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailable) {
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: _unavailableMinHeight),
        child: const CorruptMediaPlaceholder(
          label: "Can't play this recording",
        ),
      );
    }
    final FieldNotesColors colors = context.colors;
    return Row(
      children: <Widget>[
        _PlayToggle(isPlaying: _isPlaying, onTap: _ready ? _toggle : null),
        const SizedBox(width: _toggleSize + _toggleGap - _toggleTarget),
        Expanded(
          child: Semantics(
            container: true,
            slider: true,
            enabled: _ready,
            label: _positionLabel,
            value: _positionPhrase(_position),
            increasedValue: _positionPhrase(_stepped(_seekStep)),
            decreasedValue: _positionPhrase(_stepped(-_seekStep)),
            onIncrease: _ready ? () => _seekBy(_seekStep) : null,
            onDecrease: _ready ? () => _seekBy(-_seekStep) : null,
            child: VoiceWaveform(
              seed: voiceWaveformSeed(widget.entry.id),
              active: _isActive,
              progress: _progress,
              onSeek: _ready ? _seekToFraction : null,
            ),
          ),
        ),
        const SizedBox(width: _labelGap),
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: _labelMinWidth),
          child: Text(
            '${formatMediaDuration(_position.inMilliseconds)}'
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
                      child: CustomPaint(
                        size: const Size(_toggleGlyphSize, _toggleGlyphSize),
                        painter: _TransportGlyph(
                          isPlaying: isPlaying,
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
      ),
    );
  }
}

class _TransportGlyph extends CustomPainter {
  const _TransportGlyph({required this.isPlaying, required this.color});

  final bool isPlaying;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fill = Paint()..color = color;
    if (isPlaying) {
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
  bool shouldRepaint(_TransportGlyph oldDelegate) =>
      isPlaying != oldDelegate.isPlaying || color != oldDelegate.color;
}
