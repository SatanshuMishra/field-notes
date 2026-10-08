import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show FutureProviderFamily;

import 'package:field_notes/app/shell/bottom_bar_shell.dart'
    show phoneGestureBarInset;
import 'package:field_notes/app/shell/shell_layout.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/icons/chevron_glyph.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/design/widgets/icon_sticker_button.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/domain/services/media_store.dart';
import 'package:field_notes/features/entry_cards/cards/video_body.dart';
import 'package:field_notes/features/entry_cards/cards/video_controls_overlay.dart';
import 'package:field_notes/features/entry_cards/cards/video_scrubber.dart';
import 'package:field_notes/features/entry_cards/compact/log_actions_pill.dart'
    show logActionsDeleteKey;
import 'package:field_notes/features/entry_cards/media/media_resolver.dart';
import 'package:field_notes/features/entry_cards/playback/playback_focus.dart';
import 'package:field_notes/features/entry_cards/playback/video_playback.dart';
import 'package:field_notes/features/entry_cards/playback/video_slots.dart';
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
import 'package:field_notes/state/media_provider.dart';

const String _earlierLabel = 'Earlier';
const String _laterLabel = 'Later';
const String _playLabel = 'Play';
const String _pauseLabel = 'Pause';

const double _dockGlyphSize = 18;
const double _stepGlyphSize = 15;

const double _phoneQuietTop = 16;
const double _phoneQuietSide = 18;
const double _phonePrimary = 68;
const double _phoneScrubberHeight = 44;
const double _phoneScrubberReach = (scrubberHeight - _phoneScrubberHeight) / 2;
const double _phoneScrubberSide = 16;
const double _phoneScrubberLift = 116;
const BorderRadius _phoneScrubberRadius = BorderRadius.all(
  Radius.circular(_phoneScrubberHeight / 2),
);
const EdgeInsets _phoneScrubberPadding = EdgeInsets.symmetric(horizontal: 16);
const double _timeGap = 12;

const double _macPrimary = 48;
const double _macStepFace = 40;
const double _macStepSlot = 48;
const double _macCapsuleGap = 6;
const double _macCapsuleMaxWidth = 780;
const double _macCapsuleBottom = 24;
const double _macCapsuleSide = 24;

const Key videoScrubberBarKey = ValueKey<String>('video-scrubber-bar');

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
  });

  final LogViewerScene scene;
  final MediaResolver resolver;
  final EntryVideoPlayerFactory playerFactory;
  final VideoSlots slots;
  final PlaybackFocus? focus;

  @override
  ConsumerState<VideoViewerView> createState() => _VideoViewerViewState();
}

class _VideoViewerViewState extends ConsumerState<VideoViewerView> {
  final VideoControlsHandle _handle = VideoControlsHandle();

  @override
  void dispose() {
    _handle.dispose();
    super.dispose();
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
    final bool sidebar = resolveShellLayout(platform) == ShellLayout.sidebar;
    return ViewerKeys(
      onSpace: _toggle,
      onLeft: scene.onEarlier,
      onRight: scene.onLater,
      onEscape: scene.onBack,
      child: ViewerStage(
        ground: ViewerGround.media,
        onSwipeNext: scene.onLater,
        onSwipePrevious: scene.onEarlier,
        child: VideoBody(
          key: ValueKey<String>(scene.entry.id),
          entry: scene.entry,
          resolver: widget.resolver,
          playerFactory: widget.playerFactory,
          slots: widget.slots,
          aspectRatio: _aspectRatio(),
          handle: _handle,
          focus: widget.focus,
          controlModel: resolveVideoControlModel(platform),
          controls: sidebar ? _macControls : _phoneControls,
        ),
      ),
    );
  }

  Widget _quietLine(BuildContext context) {
    final LogViewerScene scene = widget.scene;
    return ViewerQuietLine(mood: scene.mood, text: scene.quietLine(context));
  }

  Widget _time(BuildContext context, Duration? time) {
    return Text(
      formatMediaDuration(time?.inMilliseconds),
      maxLines: 1,
      softWrap: false,
      style: context.textStyles.captionSans.copyWith(
        color: Palette.mediaInk,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
      ),
    );
  }

  Widget _scrubber(VideoControlsState state) {
    return VideoScrubber(
      position: state.position,
      total: state.total,
      onSeek: state.onSeek,
      onScrubUpdate: state.onScrubUpdate,
      onScrubEnd: state.onScrubEnd,
    );
  }

  Widget _phoneControls(BuildContext context, VideoControlsState state) {
    final MediaQueryData media = MediaQuery.of(context);
    final double statusBar = media.padding.top;
    final double gestureBar = phoneGestureBarInset(media);
    return Stack(
      children: <Widget>[
        const Positioned.fill(child: ViewerOverlayShade(top: true)),
        const Positioned.fill(child: ViewerOverlayShade(top: false)),
        Positioned(
          top: statusBar + _phoneQuietTop,
          left: _phoneQuietSide,
          right: _phoneQuietSide,
          child: Center(child: _quietLine(context)),
        ),
        Positioned(
          left: _phoneScrubberSide,
          right: _phoneScrubberSide,
          bottom: gestureBar + _phoneScrubberLift - _phoneScrubberReach,
          height: scrubberHeight,
          child: _PhoneScrubberBar(
            elapsed: _time(context, state.position),
            scrubber: NoSwipe(child: _scrubber(state)),
            total: _time(context, state.total),
          ),
        ),
        Positioned.fill(child: ViewerDock(slots: _phoneSlots(state))),
      ],
    );
  }

  List<ViewerDockSlot?> _phoneSlots(VideoControlsState state) {
    final LogViewerScene scene = widget.scene;
    final VoidCallback? onEarlier = scene.onEarlier;
    final VoidCallback? onLater = scene.onLater;
    final bool playing = state.isPlaying;
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
          onPressed: state.onToggle,
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

  Widget _macControls(BuildContext context, VideoControlsState state) {
    final LogViewerScene scene = widget.scene;
    return Stack(
      children: <Widget>[
        const Positioned.fill(child: ViewerOverlayShade(top: true)),
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
        Positioned(
          left: _macCapsuleSide,
          right: _macCapsuleSide,
          bottom: _macCapsuleBottom,
          child: Center(child: _macCapsule(context, state)),
        ),
      ],
    );
  }

  Widget _macCapsule(BuildContext context, VideoControlsState state) {
    final LogViewerScene scene = widget.scene;
    final VoidCallback? onEarlier = scene.onEarlier;
    final VoidCallback? onLater = scene.onLater;
    return ViewerCapsule(
      maxWidth: _macCapsuleMaxWidth,
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
          playing: state.isPlaying,
          diameter: _macPrimary,
          onPressed: state.onToggle,
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
        const SizedBox(width: _timeGap),
        _time(context, state.position),
        const SizedBox(width: _timeGap),
        Expanded(child: _scrubber(state)),
        const SizedBox(width: _timeGap),
        _time(context, state.total),
        const SizedBox(width: _timeGap),
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

class _PhoneScrubberBar extends StatelessWidget {
  const _PhoneScrubberBar({
    required this.elapsed,
    required this.scrubber,
    required this.total,
  });

  final Widget elapsed;
  final Widget scrubber;
  final Widget total;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        const Positioned.fill(
          top: _phoneScrubberReach,
          bottom: _phoneScrubberReach,
          child: GlassSurface(
            key: videoScrubberBarKey,
            tone: GlassTone.media,
            borderRadius: _phoneScrubberRadius,
            child: SizedBox.expand(),
          ),
        ),
        Padding(
          padding: _phoneScrubberPadding,
          child: Row(
            children: <Widget>[
              elapsed,
              const SizedBox(width: _timeGap),
              Expanded(child: scrubber),
              const SizedBox(width: _timeGap),
              total,
            ],
          ),
        ),
      ],
    );
  }
}
