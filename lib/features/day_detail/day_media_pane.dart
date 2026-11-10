import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart'
    show MediaResolver, logOwnTitle, videoSlotsProvider;
import 'package:field_notes/features/entry_cards/playback/playback_focus.dart';
import 'package:field_notes/features/log_viewer/log_viewer.dart';
import 'package:field_notes/features/log_viewer/log_viewer_scene.dart';
import 'package:field_notes/features/log_viewer/video_viewer_view.dart';
import 'package:field_notes/features/log_viewer/voice_player_view.dart';
import 'package:field_notes/features/today/today_providers.dart';

import 'day_note_pane.dart';

const Key dayMediaPaneKey = ValueKey<String>('day-media-pane');

const EdgeInsets _stagePadding = EdgeInsets.fromLTRB(28, 18, 28, 24);
const BorderRadius _stageRadius = BorderRadius.all(
  Radius.circular(Shapes.radiusMd),
);

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
        title: logOwnTitle(entry),
        onOpenFull: _openFullScreen,
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
