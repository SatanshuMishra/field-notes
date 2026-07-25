import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../domain/models/models.dart';
import '../media/media_image.dart';
import '../media/media_placeholders.dart';
import '../media/media_resolver.dart';
import '../playback/video_playback.dart';
import '../util/duration_format.dart';

const double _videoHeight = 200;
const double _transportSize = 56;
const double _transportGlyph = 18;
const Border _transportFocusOutline = Border.fromBorderSide(
  BorderSide(color: Palette.ink, width: 3),
);

class VideoBody extends StatefulWidget {
  const VideoBody({
    super.key,
    required this.entry,
    required this.resolver,
    required this.playerFactory,
  });

  final Entry entry;
  final MediaResolver resolver;
  final EntryVideoPlayerFactory playerFactory;

  @override
  State<VideoBody> createState() => _VideoBodyState();
}

class _VideoBodyState extends State<VideoBody> {
  EntryVideoPlayer? _player;
  StreamSubscription<VideoPlaybackState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  VideoPlaybackState _state = VideoPlaybackState.idle;
  bool _unavailable = false;
  bool _ready = false;
  bool _hasPlayed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_prepare());
  }

  Future<void> _prepare() async {
    final ResolvedMedia media;
    try {
      media = await widget.resolver.resolve(widget.entry.mediaId);
    } catch (error, stackTrace) {
      debugPrint('Video media resolve failed: $error\n$stackTrace');
      _markUnavailable();
      return;
    }
    if (!mounted) {
      return;
    }
    if (!media.isAvailable || media.file == null) {
      setState(() => _unavailable = true);
      return;
    }
    final EntryVideoPlayer player = widget.playerFactory();
    _player = player;
    _stateSub = player.stateStream.listen(
      _onState,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Video playback stream failed: $error\n$stackTrace');
        _markUnavailable();
      },
    );
    _positionSub = player.positionStream.listen(
      null,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Video position stream failed: $error\n$stackTrace');
        _markUnavailable();
      },
    );
    try {
      await player.load(media.file!.path);
      if (!mounted) {
        return;
      }
      setState(() => _ready = true);
    } catch (error, stackTrace) {
      debugPrint('Video playback load failed: $error\n$stackTrace');
      _markUnavailable();
    }
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

  void _onState(VideoPlaybackState state) {
    if (!mounted) {
      return;
    }
    if (state == VideoPlaybackState.error) {
      _markUnavailable();
      return;
    }
    setState(() {
      _state = state;
      _hasPlayed = _hasPlayed || state == VideoPlaybackState.playing;
    });
  }

  bool get _isPlaying => _state == VideoPlaybackState.playing;

  bool get _showCapturedPoster =>
      !_unavailable && !_hasPlayed && widget.entry.thumbnailMediaId != null;

  Future<void> _toggle() async {
    final EntryVideoPlayer? player = _player;
    if (player == null) {
      return;
    }
    try {
      if (_isPlaying) {
        await player.pause();
        return;
      }
      if (_state == VideoPlaybackState.completed) {
        await player.seek(Duration.zero);
      }
      await player.play();
    } catch (error, stackTrace) {
      debugPrint('Video playback toggle failed: $error\n$stackTrace');
      _markUnavailable();
    }
  }

  @override
  void dispose() {
    unawaited(_stateSub?.cancel());
    unawaited(_positionSub?.cancel());
    unawaited(_player?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _videoHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _poster(),
          ClipRRect(
            borderRadius: Shapes.cardBorderRadius,
            child: Center(
              child: _player?.buildSurface() ?? const SizedBox.shrink(),
            ),
          ),
          if (_showCapturedPoster)
            MediaImage(
              resolver: widget.resolver,
              mediaId: widget.entry.thumbnailMediaId,
              errorLabel: 'Video',
              height: _videoHeight,
            ),
          _DurationChip(durationMs: widget.entry.durationMs),
          Center(
            child: _VideoTransport(
              isPlaying: _isPlaying,
              onTap: _ready ? _toggle : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _poster() {
    if (_unavailable) {
      return const CorruptMediaPlaceholder(
        label: "Can't play this video",
        height: _videoHeight,
      );
    }
    return const NeutralMediaPlaceholder(height: _videoHeight);
  }
}

class _DurationChip extends StatelessWidget {
  const _DurationChip({required this.durationMs});

  final int? durationMs;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 8,
      bottom: 8,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Palette.ink,
          borderRadius: Shapes.buttonBorderRadius,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Text(
            formatMediaDuration(durationMs),
            style: TypographyTokens.captionSans.copyWith(
              color: Palette.cardBright,
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoTransport extends StatefulWidget {
  const _VideoTransport({required this.isPlaying, required this.onTap});

  final bool isPlaying;
  final VoidCallback? onTap;

  @override
  State<_VideoTransport> createState() => _VideoTransportState();
}

class _VideoTransportState extends State<_VideoTransport> {
  bool _focused = false;

  void _onFocusHighlight(bool focused) {
    if (!mounted || focused == _focused) {
      return;
    }
    setState(() => _focused = focused);
  }

  Object? _activate(Intent intent) {
    widget.onTap?.call();
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;
    return FocusableActionDetector(
      enabled: enabled,
      onShowFocusHighlight: _onFocusHighlight,
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: _activate),
      },
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.isPlaying ? 'Pause video' : 'Play video',
        child: GestureDetector(
          key: const ValueKey<String>('video-play-toggle'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: Opacity(
            opacity: enabled ? 1.0 : 0.5,
            child: Container(
              width: _transportSize,
              height: _transportSize,
              decoration: BoxDecoration(
                color: Palette.coral,
                shape: BoxShape.circle,
                border: _focused ? _transportFocusOutline : Shapes.outline,
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(_transportGlyph, _transportGlyph),
                  painter: _TransportGlyph(isPlaying: widget.isPlaying),
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
