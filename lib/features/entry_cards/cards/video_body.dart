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
  VideoPlaybackState _state = VideoPlaybackState.idle;
  bool _started = false;
  bool _unavailable = false;

  Future<void> _start() async {
    setState(() => _started = true);
    final ResolvedMedia media;
    try {
      media = await widget.resolver.resolve(widget.entry.mediaId);
    } catch (_) {
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
      onError: (Object _) => _markUnavailable(),
    );
    try {
      await player.load(media.file!.path);
      if (!mounted) {
        return;
      }
      await player.play();
    } catch (_) {
      _markUnavailable();
    }
  }

  void _markUnavailable() {
    if (!mounted) {
      return;
    }
    setState(() => _unavailable = true);
  }

  void _onState(VideoPlaybackState state) {
    if (!mounted) {
      return;
    }
    setState(() => _state = state);
  }

  bool get _surfaceReady =>
      _player != null &&
      _state != VideoPlaybackState.idle &&
      _state != VideoPlaybackState.loading &&
      _state != VideoPlaybackState.error;

  @override
  void dispose() {
    unawaited(_stateSub?.cancel());
    unawaited(_player?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_unavailable) {
      return const CorruptMediaPlaceholder(
        label: "Can't play this video",
        height: _videoHeight,
      );
    }
    if (_surfaceReady) {
      return ClipRRect(
        borderRadius: Shapes.cardBorderRadius,
        child: _player!.buildSurface(),
      );
    }
    return _VideoThumbnail(
      entry: widget.entry,
      resolver: widget.resolver,
      onPlay: _started ? null : _start,
    );
  }
}

class _VideoThumbnail extends StatelessWidget {
  const _VideoThumbnail({
    required this.entry,
    required this.resolver,
    required this.onPlay,
  });

  final Entry entry;
  final MediaResolver resolver;
  final VoidCallback? onPlay;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _videoHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          MediaImage(
            resolver: resolver,
            mediaId: entry.thumbnailMediaId,
            errorLabel: 'Video',
            height: _videoHeight,
          ),
          Center(
            child: Semantics(
              button: true,
              enabled: onPlay != null,
              label: 'Play video',
              child: GestureDetector(
                key: const ValueKey<String>('video-play-toggle'),
                behavior: HitTestBehavior.opaque,
                onTap: onPlay,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Palette.coral,
                    shape: BoxShape.circle,
                    border: Shapes.outline,
                  ),
                  child: const Center(
                    child: CustomPaint(
                      size: Size(18, 18),
                      painter: _PlayGlyph(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
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
                  formatMediaDuration(entry.durationMs),
                  style: TypographyTokens.captionSans.copyWith(
                    color: Palette.cardBright,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayGlyph extends CustomPainter {
  const _PlayGlyph();

  @override
  void paint(Canvas canvas, Size size) {
    final Paint fill = Paint()..color = Palette.cardBright;
    final Path triangle = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, size.height / 2)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(triangle, fill);
  }

  @override
  bool shouldRepaint(_PlayGlyph oldDelegate) => false;
}
