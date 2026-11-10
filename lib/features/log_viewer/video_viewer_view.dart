import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/platform/desktop_platform.dart';
import 'package:field_notes/domain/services/media_store.dart';
import 'package:field_notes/features/entry_cards/cards/video_body.dart';
import 'package:field_notes/features/entry_cards/cards/video_controls_overlay.dart';
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/playback_focus.dart';
import 'package:field_notes/features/entry_cards/playback/video_playback.dart';
import 'package:field_notes/features/entry_cards/playback/video_slots.dart';
import 'package:field_notes/features/entry_cards/transport/transport.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart'
    show LogViewerPlace;
import 'package:field_notes/features/log_viewer/log_viewer_scene.dart';
import 'package:field_notes/features/log_viewer/viewer_chrome.dart';
import 'package:field_notes/state/media_provider.dart';

final FutureProviderFamily<double?, String> videoAspectProvider = FutureProvider
    .autoDispose
    .family<double?, String>((Ref ref, String mediaId) async {
      final MediaStore store = await ref.watch(mediaStoreProvider.future);
      final MediaBlob? blob = await blobForMediaReference(store, mediaId);
      final int? width = blob?.width;
      final int? height = blob?.height;
      if (width == null || height == null || width <= 0 || height <= 0) {
        return null;
      }
      return width / height;
    });

class VideoViewerView extends ConsumerStatefulWidget {
  const VideoViewerView({
    super.key,
    required this.scene,
    required this.resolver,
    required this.playerFactory,
    required this.slots,
    this.focus,
    this.embedded = false,
    this.autoplay = false,
    this.startAt,
    this.onPlace,
  });

  final LogViewerScene scene;
  final MediaResolver resolver;
  final EntryVideoPlayerFactory playerFactory;
  final VideoSlots slots;
  final PlaybackFocus? focus;
  final bool embedded;
  final bool autoplay;
  final Duration? startAt;
  final ValueChanged<LogViewerPlace>? onPlace;

  @override
  ConsumerState<VideoViewerView> createState() => _VideoViewerViewState();
}

class _VideoViewerViewState extends ConsumerState<VideoViewerView> {
  final VideoControlsHandle _handle = VideoControlsHandle();
  bool _autoplayPending = false;
  Duration? _startPending;

  @override
  void initState() {
    super.initState();
    _autoplayPending = widget.autoplay;
    _startPending = widget.startAt;
    _handle.addListener(_onControls);
  }

  @override
  void didUpdateWidget(VideoViewerView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scene.entry.id != widget.scene.entry.id) {
      _autoplayPending = false;
      _startPending = null;
    }
  }

  @override
  void dispose() {
    _handle.removeListener(_onControls);
    _handle.dispose();
    super.dispose();
  }

  void _onControls() {
    final VideoControlsState? state = _handle.state;
    if (state == null) {
      return;
    }
    _seekToStart(state);
    _startIfAsked(state);
    widget.onPlace?.call((
      position: state.completed ? Duration.zero : state.position,
      playing: state.isPlaying,
    ));
  }

  void _seekToStart(VideoControlsState state) {
    final Duration? startAt = _startPending;
    final ValueChanged<Duration>? seek = state.onSeek;
    if (startAt == null || !state.ready || seek == null) {
      return;
    }
    _startPending = null;
    seek(startAt);
  }

  void _startIfAsked(VideoControlsState state) {
    final VoidCallback? start = state.onToggle;
    if (!_autoplayPending || start == null) {
      return;
    }
    _autoplayPending = false;
    if (!state.isPlaying) {
      start();
    }
  }

  void _toggle() {
    _handle.state?.onToggle?.call();
  }

  double? _aspectRatio() {
    final String? mediaId = widget.scene.entry.mediaId;
    if (mediaId == null || mediaId.isEmpty) {
      return null;
    }
    return ref.watch(videoAspectProvider(mediaId)).value;
  }

  @override
  Widget build(BuildContext context) {
    final LogViewerScene scene = widget.scene;
    final TargetPlatform platform = Theme.of(context).platform;
    if (widget.embedded) {
      return ViewerKeys(
        onSpace: _toggle,
        child: _body(platform, _embeddedControls),
      );
    }
    return ViewerKeys(
      autofocus: false,
      onEscape: scene.onEscape,
      onPageUp: scene.onEarlier,
      onPageDown: scene.onLater,
      child: ViewerStage(
        ground: ViewerGround.media,
        onSwipeNext: scene.onLater,
        onSwipePrevious: scene.onEarlier,
        child: _body(platform, _viewerControls),
      ),
    );
  }

  Widget _body(TargetPlatform platform, VideoControlsBuilder controls) {
    final LogViewerScene scene = widget.scene;
    return VideoBody(
      key: ValueKey<String>(scene.entry.id),
      entry: scene.entry,
      resolver: widget.resolver,
      playerFactory: widget.playerFactory,
      slots: widget.slots,
      aspectRatio: _aspectRatio(),
      handle: _handle,
      focus: widget.focus,
      controlModel: resolveVideoControlModel(platform),
      onFullScreen: scene.onFullScreen,
      controls: controls,
    );
  }

  Widget _embeddedControls(BuildContext context, VideoControlsState state) {
    return Transport(
      kind: TransportKind.video,
      mode: TransportMode.viewer,
      compact: false,
      value: state.transport,
      mediaPath: state.mediaPath,
      tuning: state.tuning,
      onFullScreen: widget.scene.onFullScreen,
    );
  }

  Widget _viewerControls(BuildContext context, VideoControlsState state) {
    final LogViewerScene scene = widget.scene;
    return ViewerControlsFade(
      ready: state.ready,
      playing: state.isPlaying,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          if (!isDesktopPlatform(Theme.of(context).platform))
            const ViewerDockBacking(),
          Transport(
            kind: TransportKind.video,
            mode: TransportMode.viewer,
            value: state.transport,
            mediaPath: state.mediaPath,
            tuning: state.tuning,
            autofocus: true,
            onBack: scene.onBack,
            backLabel: scene.exitLabel,
            onMore: () => showViewerLogSheet(context, scene),
            onFullScreen: scene.onFullScreen,
            fullScreen: scene.fullScreen,
          ),
          ViewerFullScreenHide(
            fullScreen: scene.fullScreen,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                ViewerLogBar(scene: scene, fades: true),
                ViewerEdgeArrows(
                  onPrevious: scene.onEarlier,
                  onNext: scene.onLater,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
