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
import 'video_transport.dart';

const Duration _defaultLoadTimeout = Duration(seconds: 8);
const List<Duration> _defaultRetryBackoff = <Duration>[
  Duration(milliseconds: 400),
  Duration(milliseconds: 1200),
];
const double _videoHeight = 200;
const double _controlInset = 8;
const double _fullVolume = 1.0;

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
  final Iterable<Duration> retryBackoff;

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
  int _generation = 0;
  Duration _resumeFrom = Duration.zero;
  bool _listeningForSlots = false;
  bool _scrubbing = false;
  bool _playWhenReady = false;

  @override
  void initState() {
    super.initState();
    _startPrepare(VideoSlotEvictionRights.none);
  }

  @override
  void didUpdateWidget(VideoBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.resolver, widget.resolver)) {
      return;
    }
    _mediaFile = null;
    _restart(VideoSlotEvictionRights.none);
  }

  void _startPrepare(VideoSlotEvictionRights rights) =>
      _guard(_prepare(rights), 'Video prepare failed');

  void _guard(Future<void> work, String label) {
    unawaited(
      work.catchError((Object error, StackTrace stackTrace) {
        debugPrint('$label: $error\n$stackTrace');
      }),
    );
  }

  Future<void> _prepare(VideoSlotEvictionRights rights) async {
    final int gen = _generation;
    final ResolvedMedia media;
    try {
      media = await widget.resolver.resolve(widget.entry.mediaId);
    } catch (error, stackTrace) {
      debugPrint('Video media resolve failed: $error\n$stackTrace');
      if (_isCurrentGeneration(gen)) {
        _markUnavailable();
      }
      return;
    }
    if (!_isCurrentGeneration(gen)) {
      return;
    }
    if (!media.isAvailable || media.file == null) {
      _markUnavailable();
      return;
    }
    _mediaFile = media.file;
    await _attemptLoad(rights);
  }

  Future<void> _attemptLoad(VideoSlotEvictionRights rights) async {
    final File? file = _mediaFile;
    if (!mounted || file == null) {
      return;
    }
    final VideoSlotToken? token = widget.slots.acquire(
      onEvicted: _onSlotEvicted,
      evictionRights: rights,
    );
    if (token == null) {
      _enterWaiting();
      return;
    }
    final int gen = ++_generation;
    _token = token;
    setState(() => _enterPhase(_VideoPhase.preparing));
    final EntryVideoPlayer player = widget.playerFactory();
    _player = player;
    _subscribe(player);
    try {
      await player.load(file.path).timeout(widget.loadTimeout);
    } catch (error, stackTrace) {
      debugPrint('Video playback load failed: $error\n$stackTrace');
      if (!_isCurrentAttempt(gen, token)) {
        return;
      }
      _releasePlayerAndSlot();
      _failAttempt(file, rights);
      return;
    }
    if (!_isCurrentAttempt(gen, token)) {
      return;
    }
    setState(() {
      _enterPhase(_VideoPhase.ready);
      _attempt = 0;
    });
    await _restoreVolume(player);
    if (!_isCurrentAttempt(gen, token)) {
      return;
    }
    await _resumeIfInterrupted();
    if (!_isCurrentAttempt(gen, token)) {
      return;
    }
    await _playIfRequested();
  }

  bool _isCurrentGeneration(int gen) => mounted && gen == _generation;

  bool _isCurrentAttempt(int gen, VideoSlotToken token) =>
      _isCurrentGeneration(gen) &&
      identical(token, _token) &&
      widget.slots.holds(token);

  void _subscribe(EntryVideoPlayer player) {
    _stateSub = player.stateStream.listen(
      _onState,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Video playback stream failed: $error\n$stackTrace');
        _onPlaybackFailure();
      },
    );
    _positionSub = player.positionStream.listen(
      _onPosition,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Video position stream failed: $error\n$stackTrace');
        _onPlaybackFailure();
      },
    );
  }

  Future<void> _restoreVolume(EntryVideoPlayer player) async {
    if (_volume == _fullVolume) {
      return;
    }
    try {
      await player.setVolume(_volume);
    } catch (error, stackTrace) {
      debugPrint('Video volume restore failed: $error\n$stackTrace');
    }
  }

  Future<void> _resumeIfInterrupted() async {
    final Duration resume = _resumeFrom;
    if (resume <= Duration.zero) {
      return;
    }
    _resumeFrom = Duration.zero;
    await _seek(resume);
  }

  Future<void> _playIfRequested() async {
    if (!_playWhenReady) {
      return;
    }
    _playWhenReady = false;
    await _play();
  }

  void _failAttempt(File file, VideoSlotEvictionRights rights) {
    if (!mounted) {
      return;
    }
    if (_isStructurallyUnplayable(file) ||
        _attempt >= widget.retryBackoff.length) {
      _markUnavailable();
      return;
    }
    _scheduleRetry(rights);
  }

  bool _isStructurallyUnplayable(File file) {
    try {
      return !file.existsSync() || file.lengthSync() == 0;
    } catch (error, stackTrace) {
      debugPrint('Video media probe failed: $error\n$stackTrace');
      return false;
    }
  }

  void _scheduleRetry(VideoSlotEvictionRights rights) {
    final Duration delay = widget.retryBackoff.elementAt(_attempt);
    _retryTimer?.cancel();
    setState(() {
      _attempt += 1;
      _enterPhase(_VideoPhase.retrying);
    });
    _retryTimer = Timer(
      delay,
      () => _guard(_attemptLoad(rights), 'Video retry failed'),
    );
  }

  void _enterPhase(_VideoPhase phase) {
    if (phase != _VideoPhase.waiting) {
      _stopListeningForSlots();
    }
    if (phase != _VideoPhase.ready) {
      _scrubbing = false;
    }
    _phase = phase;
  }

  void _enterWaiting() {
    if (!mounted) {
      return;
    }
    _playWhenReady = false;
    _phase = _VideoPhase.waiting;
    _scrubbing = false;
    _listenForSlots();
    scheduleMicrotask(_rebuild);
  }

  void _rebuild() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _listenForSlots() {
    if (_listeningForSlots) {
      return;
    }
    _listeningForSlots = widget.slots.addSlotFreedListener(_onSlotFreed);
  }

  void _stopListeningForSlots() {
    if (!_listeningForSlots) {
      return;
    }
    _listeningForSlots = false;
    widget.slots.removeSlotFreedListener(_onSlotFreed);
  }

  void _onSlotFreed() {
    if (!mounted || _phase != _VideoPhase.waiting) {
      return;
    }
    scheduleMicrotask(_wakeFromWaiting);
  }

  void _wakeFromWaiting() {
    if (!mounted || _phase != _VideoPhase.waiting) {
      return;
    }
    _guard(
      _attemptLoad(VideoSlotEvictionRights.none),
      'Video slot wake-up failed',
    );
  }

  void _onSlotEvicted() {
    _generation += 1;
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
    _scrubbing = false;
    unawaited(_stateSub?.cancel());
    unawaited(_positionSub?.cancel());
    _stateSub = null;
    _positionSub = null;
    unawaited(player?.dispose());
  }

  void _releasePlayerAndSlot() {
    _generation += 1;
    _teardownPlayer();
    final VideoSlotToken? token = _token;
    _token = null;
    widget.slots.release(token);
  }

  void _markUnavailable() {
    if (!mounted) {
      return;
    }
    _playWhenReady = false;
    setState(() => _enterPhase(_VideoPhase.unavailable));
  }

  void _onRetryPressed() => _restart(VideoSlotEvictionRights.evictUnpinned);

  void _restart(VideoSlotEvictionRights rights) {
    if (!mounted) {
      return;
    }
    _retryTimer?.cancel();
    _retryTimer = null;
    _releasePlayerAndSlot();
    setState(() {
      _attempt = 0;
      _enterPhase(_VideoPhase.preparing);
    });
    _startPrepare(rights);
  }

  void _onState(VideoPlaybackState state) {
    if (!mounted) {
      return;
    }
    if (state == VideoPlaybackState.error) {
      _onPlaybackFailure();
      return;
    }
    setState(() => _state = state);
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

  void _onPlaybackFailure() => _scheduleRecovery(_generation, _token);

  void _scheduleRecovery(int gen, VideoSlotToken? token) => scheduleMicrotask(
        () => _guard(
          _recoverFromPlaybackError(gen, token),
          'Video playback recovery failed',
        ),
      );

  Future<void> _recoverFromPlaybackError(
    int gen,
    VideoSlotToken? token,
  ) async {
    if (token == null || !_isCurrentAttempt(gen, token)) {
      debugPrint('Video playback error arrived from a stale attempt');
      return;
    }
    if (_phase != _VideoPhase.ready && _phase != _VideoPhase.preparing) {
      debugPrint('Video playback error arrived with no live attempt: $_phase');
      return;
    }
    _resumeFrom = _position;
    _releasePlayerAndSlot();
    final File? file = _mediaFile;
    if (file == null) {
      _markUnavailable();
      return;
    }
    _failAttempt(file, VideoSlotEvictionRights.evictUnpinned);
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

  bool get _canClaimSlot => _phase == _VideoPhase.waiting;

  bool get _muted => _volume <= 0;

  bool get _isRenderingVideo =>
      _player != null &&
      (_state == VideoPlaybackState.playing ||
          _state == VideoPlaybackState.paused ||
          _state == VideoPlaybackState.completed);

  bool get _showCapturedPoster =>
      widget.entry.thumbnailMediaId != null && !_isRenderingVideo;

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
    final VideoSlotToken? token = _token;
    if (player == null || token == null) {
      return;
    }
    final int gen = _generation;
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
    if (!_isCurrentAttempt(gen, token)) {
      return;
    }
    setState(() {
      if (target <= 0) {
        _volumeBeforeMute = previous;
      }
      _volume = target;
    });
  }

  void _onTransportTap() {
    if (_canClaimSlot) {
      _playWhenReady = true;
      _guard(
        _attemptLoad(VideoSlotEvictionRights.evictUnpinned),
        'Video slot claim failed',
      );
      return;
    }
    _guard(_toggle(), 'Video playback toggle failed');
  }

  Future<void> _toggle() async {
    final EntryVideoPlayer? player = _player;
    final VideoSlotToken? token = _token;
    if (player == null) {
      return;
    }
    if (!_isPlaying) {
      await _play();
      return;
    }
    final int gen = _generation;
    try {
      await player.pause();
      widget.slots.unpin(token);
    } catch (error, stackTrace) {
      debugPrint('Video playback pause failed: $error\n$stackTrace');
      widget.slots.unpin(token);
      _scheduleRecovery(gen, token);
    }
  }

  Future<void> _play() async {
    final EntryVideoPlayer? player = _player;
    final VideoSlotToken? token = _token;
    if (player == null) {
      return;
    }
    final int gen = _generation;
    try {
      if (_state == VideoPlaybackState.completed) {
        await player.seek(Duration.zero);
      }
      widget.slots.pin(token);
      await player.play();
    } catch (error, stackTrace) {
      debugPrint('Video playback start failed: $error\n$stackTrace');
      widget.slots.unpin(token);
      _scheduleRecovery(gen, token);
    }
  }

  @override
  void dispose() {
    _generation += 1;
    _retryTimer?.cancel();
    _retryTimer = null;
    _stopListeningForSlots();
    _teardownPlayer();
    final VideoSlotToken? token = _token;
    _token = null;
    widget.slots.release(token);
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
      child: Stack(fit: StackFit.expand, children: _layers()),
    );
  }

  List<Widget> _layers() {
    return <Widget>[
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
        child: VideoTransport(
          isPlaying: _isPlaying,
          onTap: _ready || _canClaimSlot ? _onTransportTap : null,
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
    ];
  }
}
