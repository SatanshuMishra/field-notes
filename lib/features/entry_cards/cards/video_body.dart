import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';

import '../../../design/tokens/tokens.dart';
import '../../../domain/models/models.dart';
import '../media/media_image.dart';
import '../media/media_placeholders.dart';
import '../media/media_resolver.dart';
import '../playback/video_playback.dart';
import '../playback/video_slots.dart';
import 'video_control_bar.dart';
import 'video_scrubber.dart';

const Duration _defaultLoadTimeout = Duration(seconds: 8);
const List<Duration> _defaultRetryBackoff = <Duration>[
  Duration(milliseconds: 400),
  Duration(milliseconds: 1200),
];
const double _videoHeight = 200;
const double _transportSize = 56;
const double _transportGlyph = 18;
const double _controlInset = 8;
const double _fullVolume = 1.0;
const Border _transportFocusOutline = Border.fromBorderSide(
  BorderSide(color: Palette.ink, width: 3),
);

enum _VideoPhase { waiting, preparing, ready, retrying, unavailable }

class VideoBody extends StatefulWidget {
  const VideoBody({
    super.key,
    required this.entry,
    required this.resolver,
    required this.playerFactory,
    required this.slots,
    this.loadTimeout = _defaultLoadTimeout,
    this.retryBackoff = _defaultRetryBackoff,
  });

  final Entry entry;
  final MediaResolver resolver;
  final EntryVideoPlayerFactory playerFactory;
  final VideoSlots slots;
  final Duration loadTimeout;
  final List<Duration> retryBackoff;

  @override
  State<VideoBody> createState() => _VideoBodyState();
}

class _VideoBodyState extends State<VideoBody> {
  EntryVideoPlayer? _player;
  StreamSubscription<VideoPlaybackState>? _stateSub;
  StreamSubscription<Duration>? _positionSub;
  VideoPlaybackState _state = VideoPlaybackState.idle;
  Duration _position = Duration.zero;
  double _volume = _fullVolume;
  double _volumeBeforeMute = _fullVolume;
  _VideoPhase _phase = _VideoPhase.preparing;
  File? _mediaFile;
  VideoSlotToken? _token;
  Timer? _retryTimer;
  int _attempt = 0;
  Duration _resumeFrom = Duration.zero;
  bool _listeningForSlots = false;
  bool _hasPlayed = false;
  bool _scrubbing = false;

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
      _markUnavailable();
      return;
    }
    _mediaFile = media.file;
    await _attemptLoad();
  }

  Future<void> _attemptLoad() async {
    final File? file = _mediaFile;
    if (!mounted || file == null) {
      return;
    }
    final VideoSlotToken? token =
        widget.slots.acquire(onEvicted: _onSlotEvicted);
    if (token == null) {
      _enterWaiting();
      return;
    }
    _token = token;
    setState(() => _phase = _VideoPhase.preparing);
    final EntryVideoPlayer player = widget.playerFactory();
    _player = player;
    _subscribe(player);
    try {
      await player.load(file.path).timeout(widget.loadTimeout);
    } catch (error, stackTrace) {
      debugPrint('Video playback load failed: $error\n$stackTrace');
      _releasePlayerAndSlot();
      _failAttempt(file);
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _phase = _VideoPhase.ready;
      _attempt = 0;
    });
    await _resumeIfInterrupted();
  }

  void _subscribe(EntryVideoPlayer player) {
    _stateSub = player.stateStream.listen(
      _onState,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Video playback stream failed: $error\n$stackTrace');
        _markUnavailable();
      },
    );
    _positionSub = player.positionStream.listen(
      _onPosition,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Video position stream failed: $error\n$stackTrace');
        _markUnavailable();
      },
    );
  }

  Future<void> _resumeIfInterrupted() async {
    final Duration resume = _resumeFrom;
    if (resume <= Duration.zero) {
      return;
    }
    _resumeFrom = Duration.zero;
    await _seek(resume);
  }

  void _failAttempt(File file) {
    if (!mounted) {
      return;
    }
    if (_isStructurallyUnplayable(file) ||
        _attempt >= widget.retryBackoff.length) {
      _markUnavailable();
      return;
    }
    _scheduleRetry();
  }

  bool _isStructurallyUnplayable(File file) {
    try {
      return !file.existsSync() || file.lengthSync() == 0;
    } catch (error, stackTrace) {
      debugPrint('Video media probe failed: $error\n$stackTrace');
      return true;
    }
  }

  void _scheduleRetry() {
    final Duration delay = widget.retryBackoff[_attempt];
    _retryTimer?.cancel();
    setState(() {
      _attempt += 1;
      _phase = _VideoPhase.retrying;
    });
    _retryTimer = Timer(delay, () => unawaited(_attemptLoad()));
  }

  void _enterWaiting() {
    if (!mounted) {
      return;
    }
    _listenForSlots();
    setState(() => _phase = _VideoPhase.waiting);
  }

  void _listenForSlots() {
    if (_listeningForSlots) {
      return;
    }
    _listeningForSlots = true;
    widget.slots.addSlotFreedListener(_onSlotFreed);
  }

  void _onSlotFreed() {
    if (!mounted || _phase != _VideoPhase.waiting) {
      return;
    }
    unawaited(_attemptLoad());
  }

  void _onSlotEvicted() {
    _token = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _resumeFrom = _position;
    _teardownPlayer();
    _enterWaiting();
  }

  void _teardownPlayer() {
    final EntryVideoPlayer? player = _player;
    _player = null;
    _state = VideoPlaybackState.idle;
    unawaited(_stateSub?.cancel());
    unawaited(_positionSub?.cancel());
    _stateSub = null;
    _positionSub = null;
    unawaited(player?.dispose());
  }

  void _releasePlayerAndSlot() {
    _teardownPlayer();
    widget.slots.release(_token);
    _token = null;
  }

  void _markUnavailable() {
    if (!mounted) {
      return;
    }
    setState(() => _phase = _VideoPhase.unavailable);
  }

  void _onRetryPressed() => unawaited(_retry());

  Future<void> _retry() async {
    if (!mounted) {
      return;
    }
    _retryTimer?.cancel();
    _retryTimer = null;
    _releasePlayerAndSlot();
    setState(() {
      _attempt = 0;
      _phase = _VideoPhase.preparing;
    });
    await _prepare();
  }

  void _onState(VideoPlaybackState state) {
    if (!mounted) {
      return;
    }
    if (state == VideoPlaybackState.error) {
      scheduleMicrotask(() => unawaited(_recoverFromPlaybackError()));
      return;
    }
    setState(() {
      _state = state;
      _hasPlayed = _hasPlayed || state == VideoPlaybackState.playing;
    });
    _syncPin(state);
  }

  void _syncPin(VideoPlaybackState state) {
    if (state == VideoPlaybackState.playing) {
      widget.slots.pin(_token);
      return;
    }
    if (state == VideoPlaybackState.paused ||
        state == VideoPlaybackState.completed) {
      widget.slots.unpin(_token);
    }
  }

  Future<void> _recoverFromPlaybackError() async {
    if (!mounted || _phase != _VideoPhase.ready) {
      return;
    }
    _resumeFrom = _position;
    _releasePlayerAndSlot();
    final File? file = _mediaFile;
    if (file == null) {
      _markUnavailable();
      return;
    }
    _failAttempt(file);
  }

  void _onPosition(Duration position) {
    if (!mounted || _scrubbing) {
      return;
    }
    setState(() => _position = position);
  }

  void _onScrubUpdate(Duration position) {
    final Duration? total = _total;
    if (!mounted || total == null) {
      return;
    }
    setState(() {
      _scrubbing = true;
      _position = clampPlaybackPosition(position, total);
    });
  }

  void _onScrubEnd() {
    if (!mounted) {
      return;
    }
    _scrubbing = false;
  }

  bool get _isPlaying => _state == VideoPlaybackState.playing;

  bool get _ready => _phase == _VideoPhase.ready;

  bool get _muted => _volume <= 0;

  bool get _showCapturedPoster =>
      !_hasPlayed && widget.entry.thumbnailMediaId != null;

  Duration? get _total {
    final Duration? reported = _player?.duration;
    if (reported != null && reported > Duration.zero) {
      return reported;
    }
    final int? declared = widget.entry.durationMs;
    if (declared == null || declared <= 0) {
      return null;
    }
    return Duration(milliseconds: declared);
  }

  Future<void> _seek(Duration position) async {
    final EntryVideoPlayer? player = _player;
    final Duration? total = _total;
    if (player == null || total == null) {
      return;
    }
    final Duration target = clampPlaybackPosition(position, total);
    final Duration previous = _position;
    setState(() => _position = target);
    try {
      await player.seek(target);
    } catch (error, stackTrace) {
      debugPrint('Video seek failed: $error\n$stackTrace');
      if (!mounted) {
        return;
      }
      setState(() => _position = previous);
    }
  }

  Future<void> _toggleMute() async {
    final EntryVideoPlayer? player = _player;
    if (player == null) {
      return;
    }
    final double restored =
        _volumeBeforeMute > 0 ? _volumeBeforeMute : _fullVolume;
    final double target = _muted ? restored : 0.0;
    final double previous = _volume;
    try {
      await player.setVolume(target);
    } catch (error, stackTrace) {
      debugPrint('Video volume change failed: $error\n$stackTrace');
      return;
    }
    if (!mounted) {
      return;
    }
    setState(() {
      if (target <= 0) {
        _volumeBeforeMute = previous;
      }
      _volume = target;
    });
  }

  Future<void> _toggle() async {
    final EntryVideoPlayer? player = _player;
    if (player == null) {
      return;
    }
    try {
      if (_isPlaying) {
        await player.pause();
        widget.slots.unpin(_token);
        return;
      }
      if (_state == VideoPlaybackState.completed) {
        await player.seek(Duration.zero);
      }
      widget.slots.pin(_token);
      await player.play();
    } catch (error, stackTrace) {
      debugPrint('Video playback toggle failed: $error\n$stackTrace');
      widget.slots.unpin(_token);
      unawaited(_recoverFromPlaybackError());
    }
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    widget.slots.removeSlotFreedListener(_onSlotFreed);
    unawaited(_stateSub?.cancel());
    unawaited(_positionSub?.cancel());
    unawaited(_player?.dispose());
    widget.slots.release(_token);
    _token = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == _VideoPhase.unavailable) {
      return CorruptMediaPlaceholder(
        label: "Can't play this video",
        height: _videoHeight,
        onRetry: _onRetryPressed,
      );
    }
    return SizedBox(
      height: _videoHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const NeutralMediaPlaceholder(height: _videoHeight),
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
          Center(
            child: _VideoTransport(
              isPlaying: _isPlaying,
              onTap: _ready ? _toggle : null,
            ),
          ),
          Positioned(
            left: _controlInset,
            right: _controlInset,
            bottom: _controlInset,
            child: VideoControlBar(
              position: _position,
              total: _total,
              muted: _muted,
              onSeek: _ready ? _seek : null,
              onScrubUpdate: _ready ? _onScrubUpdate : null,
              onScrubEnd: _ready ? _onScrubEnd : null,
              onToggleMute: _ready ? _toggleMute : null,
            ),
          ),
        ],
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
