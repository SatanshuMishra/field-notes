import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../design/motion/motion.dart';
import '../../../design/tokens/tokens.dart';
import '../../../domain/models/models.dart';
import '../media/media_placeholders.dart';
import '../media/media_resolver.dart';
import '../playback/audio_playback.dart';
import '../util/duration_format.dart';

const List<double> _entryWaveHeights = <double>[
  0.40,
  0.75,
  1.00,
  0.55,
  0.85,
  0.35,
  0.70,
  0.50,
  0.90,
  0.45,
  0.65,
  0.80,
  0.38,
  0.60,
];

const List<Duration> _entryWaveDurations = <Duration>[
  Duration(milliseconds: 700),
  Duration(milliseconds: 850),
  Duration(milliseconds: 1000),
  Duration(milliseconds: 1150),
];

const double _waveCoralThreshold = 0.62;
const double _waveMidThreshold = 0.42;
const double _waveHeight = 24;
const double _waveBarWidth = 3;
const double _waveSpacing = 2.5;
const double _waveBarRadius = 2;

const double _unavailableMinHeight = 64;

const double _toggleSize = 38;
const double _toggleGlyphSize = 15;
const double _toggleGlyphOffset = 2;

Color _entryWaveTint(double height) {
  if (height > _waveCoralThreshold) {
    return Palette.coral;
  }
  return height > _waveMidThreshold ? Palette.waveMid : Palette.waveLight;
}

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
    _teardownPlayer();
    _state = AudioPlaybackState.idle;
    _position = Duration.zero;
    _unavailable = false;
    _ready = false;
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
    return Row(
      children: <Widget>[
        _PlayToggle(isPlaying: _isPlaying, onTap: _ready ? _toggle : null),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: _waveHeight,
            child: ClipRect(
              child: OverflowBox(
                alignment: Alignment.centerLeft,
                minWidth: 0,
                maxWidth: double.infinity,
                child: WaveformBars(
                  key: ValueKey<bool>(_isPlaying),
                  animate: _isPlaying,
                  heights: _entryWaveHeights,
                  perBarDurations: _isPlaying ? _entryWaveDurations : null,
                  colorFor: _entryWaveTint,
                  barWidth: _waveBarWidth,
                  spacing: _waveSpacing,
                  maxHeight: _waveHeight,
                  barRadius: _waveBarRadius,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${formatMediaDuration(_position.inMilliseconds)}'
          ' / ${formatMediaDuration(widget.entry.durationMs)}',
          style: TypographyTokens.caption11Sans.copyWith(color: Palette.muted),
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
      button: true,
      enabled: onTap != null,
      label: isPlaying ? 'Pause' : 'Play',
      child: GestureDetector(
        key: const ValueKey<String>('voice-play-toggle'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1.0,
          child: Container(
            width: _toggleSize,
            height: _toggleSize,
            decoration: const BoxDecoration(
              color: Palette.coral,
              shape: BoxShape.circle,
              border: Shapes.outline,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(left: _toggleGlyphOffset),
                child: CustomPaint(
                  size: const Size(_toggleGlyphSize, _toggleGlyphSize),
                  painter: _TransportGlyph(isPlaying: isPlaying),
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
  const _TransportGlyph({required this.isPlaying});

  final bool isPlaying;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fill = Paint()..color = Palette.cardBright;
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
      isPlaying != oldDelegate.isPlaying;
}
