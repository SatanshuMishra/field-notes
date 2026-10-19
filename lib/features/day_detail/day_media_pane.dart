import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/interaction/hover_style.dart';
import 'package:field_notes/design/interaction/pressable.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart'
    show MediaResolver, logPreviewOf, videoSlotsProvider;
import 'package:field_notes/features/entry_cards/playback/playback_focus.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_scene.dart';
import 'package:field_notes/features/log_viewer/video_viewer_view.dart';
import 'package:field_notes/features/log_viewer/voice_player_view.dart';
import 'package:field_notes/features/today/today_providers.dart';

import 'day_note_pane.dart';

const String dayMediaPaneFullScreenLabel = 'Full screen';

const Key dayMediaPaneKey = ValueKey<String>('day-media-pane');
const Key dayMediaPaneFullScreenKey = ValueKey<String>(
  'day-media-pane-full-screen',
);

const EdgeInsets _stagePadding = EdgeInsets.fromLTRB(28, 18, 28, 24);
const BorderRadius _stageRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusMd),
);

const double _fullScreenTarget = 48;
const double _fullScreenFace = 38;
const double _fullScreenGlyph = 14;
const double _fullScreenStroke = 1.8;
const double _fullScreenCorner = 0.36;
const BorderRadius _fullScreenRadius = BorderRadius.all(Radius.circular(10));

typedef DayMediaFullScreenClosed = void Function(
  Entry entry,
  LogViewerOutcome outcome,
  Duration? endedAt,
);

class DayMediaPane extends ConsumerStatefulWidget {
  const DayMediaPane({
    super.key,
    required this.entries,
    required this.selected,
    required this.date,
    required this.dayTitle,
    required this.mood,
    required this.resolver,
    required this.onDelete,
    required this.onStep,
    required this.onClose,
    this.autoplay = false,
    this.startAt,
    this.onPlace,
    this.onCoveredChanged,
    this.onFullScreenClosed,
  });

  final List<Entry> entries;
  final Entry selected;
  final String date;
  final String dayTitle;
  final Mood? mood;
  final MediaResolver resolver;
  final ValueChanged<Entry> onDelete;
  final ValueChanged<Entry> onStep;
  final VoidCallback onClose;
  final bool autoplay;
  final Duration? startAt;
  final ValueChanged<LogViewerPlace>? onPlace;
  final ValueChanged<bool>? onCoveredChanged;
  final DayMediaFullScreenClosed? onFullScreenClosed;

  @override
  ConsumerState<DayMediaPane> createState() => _DayMediaPaneState();
}

class _DayMediaPaneState extends ConsumerState<DayMediaPane> {
  LogViewerPlace _place = (position: Duration.zero, playing: false);
  bool _fullScreen = false;

  @override
  void initState() {
    super.initState();
    _place = (position: widget.startAt ?? Duration.zero, playing: false);
  }

  void _onPlace(LogViewerPlace place) {
    _place = place;
    widget.onPlace?.call(place);
  }

  void _openFullScreen() => unawaited(_showFullScreen());

  Future<void> _showFullScreen() async {
    if (_fullScreen) {
      return;
    }
    _fullScreen = true;
    final Entry entry = widget.selected;
    final LogViewerPlace from = _place;
    final ValueChanged<bool>? onCoveredChanged = widget.onCoveredChanged;
    playbackFocus.silence();
    Duration? endedAt;
    onCoveredChanged?.call(true);
    final LogViewerOutcome outcome;
    try {
      outcome = await showLogViewer(
        context,
        date: widget.date,
        entryId: entry.id,
        exit: LogViewerExit.back,
        startAt: from.position,
        autoplay: from.playing,
        onPosition: (String entryId, Duration position) {
          if (entryId == entry.id) {
            endedAt = position;
          }
        },
      );
    } finally {
      _fullScreen = false;
      onCoveredChanged?.call(false);
    }
    widget.onFullScreenClosed?.call(entry, outcome, endedAt);
  }

  @override
  Widget build(BuildContext context) {
    final Entry entry = widget.selected;
    return KeyedSubtree(
      key: dayMediaPaneKey,
      child: DayPaneFrame(
        entries: widget.entries,
        entry: entry,
        title: logPreviewOf(entry).heading,
        actions: <Widget>[_FullScreenButton(onPressed: _openFullScreen)],
        onDelete: () => widget.onDelete(entry),
        onStep: widget.onStep,
        body: Padding(
          padding: _stagePadding,
          child: ClipRRect(
            borderRadius: _stageRadius,
            child: ColoredBox(
              color: entry.type == EntryType.video
                  ? Palette.mediaBlack
                  : Palette.mediaGround,
              child: SizedBox.expand(child: _view(_sceneOf(entry))),
            ),
          ),
        ),
      ),
    );
  }

  Widget _view(LogViewerScene scene) {
    if (scene.entry.type == EntryType.video) {
      return VideoViewerView(
        scene: scene,
        resolver: widget.resolver,
        playerFactory: ref.watch(todayVideoPlayerFactoryProvider),
        slots: ref.watch(videoSlotsProvider),
        embedded: true,
        autoplay: widget.autoplay,
        startAt: widget.startAt,
        onPlace: _onPlace,
      );
    }
    return VoicePlayerView(
      scene: scene,
      resolver: widget.resolver,
      playerFactory: ref.watch(todayAudioPlayerFactoryProvider),
      embedded: true,
      autoplay: widget.autoplay,
      startAt: widget.startAt,
      onPlace: _onPlace,
    );
  }

  LogViewerScene _sceneOf(Entry entry) {
    final List<Entry> entries = widget.entries;
    final int index = entries.indexWhere(
      (Entry candidate) => candidate.id == entry.id,
    );
    final Entry? earlier = index > 0 ? entries[index - 1] : null;
    final Entry? later = index >= 0 && index + 1 < entries.length
        ? entries[index + 1]
        : null;
    return LogViewerScene(
      entry: entry,
      date: widget.date,
      dayTitle: widget.dayTitle,
      mood: widget.mood,
      index: index,
      count: entries.length,
      earlier: earlier,
      later: later,
      exit: LogViewerExit.back,
      onBack: widget.onClose,
      onEarlier: earlier == null ? null : () => widget.onStep(earlier),
      onLater: later == null ? null : () => widget.onStep(later),
      onDelete: () => widget.onDelete(entry),
      onEdit: null,
    );
  }
}

class _FullScreenButton extends StatelessWidget {
  const _FullScreenButton({required this.onPressed});

  final VoidCallback? onPressed;

  void _press() => onPressed?.call();

  @override
  Widget build(BuildContext context) {
    return Pressable(
      key: dayMediaPaneFullScreenKey,
      label: dayMediaPaneFullScreenLabel,
      tooltip: dayMediaPaneFullScreenLabel,
      onPressed: _press,
      borderRadius: _fullScreenRadius,
      paintsHover: false,
      builder: (BuildContext context, bool hovered) => SizedBox.square(
        dimension: _fullScreenTarget,
        child: Center(
          child: Container(
            width: _fullScreenFace,
            height: _fullScreenFace,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Palette.toolbarInk,
              borderRadius: _fullScreenRadius,
              boxShadow: Shadows.toastLift,
            ),
            foregroundDecoration: HoverStyle.decoration(
              color: hovered
                  ? HoverStyle.of(
                      context,
                      FocusRingSurface.dark,
                      HoverShape.rounded,
                    )
                  : null,
              shape: HoverShape.rounded,
              borderRadius: _fullScreenRadius,
            ),
            child: const CustomPaint(
              size: Size.square(_fullScreenGlyph),
              painter: _FullScreenGlyphPainter(color: Palette.onAccent),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullScreenGlyphPainter extends CustomPainter {
  const _FullScreenGlyphPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double arm = size.shortestSide * _fullScreenCorner;
    final double right = size.width;
    final double bottom = size.height;
    final Path corners = Path()
      ..moveTo(0, arm)
      ..lineTo(0, 0)
      ..lineTo(arm, 0)
      ..moveTo(right - arm, 0)
      ..lineTo(right, 0)
      ..lineTo(right, arm)
      ..moveTo(right, bottom - arm)
      ..lineTo(right, bottom)
      ..lineTo(right - arm, bottom)
      ..moveTo(arm, bottom)
      ..lineTo(0, bottom)
      ..lineTo(0, bottom - arm);
    canvas.drawPath(
      corners,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = _fullScreenStroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_FullScreenGlyphPainter oldDelegate) =>
      color != oldDelegate.color;
}
