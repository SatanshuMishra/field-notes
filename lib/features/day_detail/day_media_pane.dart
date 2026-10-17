import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/domain/models/models.dart';
import 'package:field_notes/features/entry_cards/entry_cards.dart'
    show MediaResolver, logPreviewOf, videoSlotsProvider;
import 'package:field_notes/features/log_viewer/log_viewer.dart'
    show LogViewerExit;
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

class DayMediaPane extends ConsumerWidget {
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
    this.onFullScreen,
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
  final VoidCallback? onFullScreen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Entry entry = selected;
    return KeyedSubtree(
      key: dayMediaPaneKey,
      child: DayPaneFrame(
        entries: entries,
        entry: entry,
        title: logPreviewOf(entry).heading,
        actions: <Widget>[_FullScreenButton(onPressed: onFullScreen)],
        onDelete: () => onDelete(entry),
        onStep: onStep,
        body: Padding(
          padding: _stagePadding,
          child: ClipRRect(
            borderRadius: _stageRadius,
            child: ColoredBox(
              color: entry.type == EntryType.video
                  ? Palette.mediaBlack
                  : Palette.mediaGround,
              child: SizedBox.expand(child: _view(ref, _sceneOf(entry))),
            ),
          ),
        ),
      ),
    );
  }

  Widget _view(WidgetRef ref, LogViewerScene scene) {
    if (scene.entry.type == EntryType.video) {
      return VideoViewerView(
        scene: scene,
        resolver: resolver,
        playerFactory: ref.watch(todayVideoPlayerFactoryProvider),
        slots: ref.watch(videoSlotsProvider),
        embedded: true,
        autoplay: autoplay,
      );
    }
    return VoicePlayerView(
      scene: scene,
      resolver: resolver,
      playerFactory: ref.watch(todayAudioPlayerFactoryProvider),
      embedded: true,
      autoplay: autoplay,
    );
  }

  LogViewerScene _sceneOf(Entry entry) {
    final int index = entries.indexWhere(
      (Entry candidate) => candidate.id == entry.id,
    );
    final Entry? earlier = index > 0 ? entries[index - 1] : null;
    final Entry? later = index >= 0 && index + 1 < entries.length
        ? entries[index + 1]
        : null;
    return LogViewerScene(
      entry: entry,
      date: date,
      dayTitle: dayTitle,
      mood: mood,
      index: index,
      count: entries.length,
      earlier: earlier,
      later: later,
      exit: LogViewerExit.back,
      onBack: onClose,
      onEarlier: earlier == null ? null : () => onStep(earlier),
      onLater: later == null ? null : () => onStep(later),
      onDelete: () => onDelete(entry),
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
    return Tooltip(
      message: dayMediaPaneFullScreenLabel,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        label: dayMediaPaneFullScreenLabel,
        child: GestureDetector(
          key: dayMediaPaneFullScreenKey,
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: _press,
          child: SizedBox.square(
            dimension: _fullScreenTarget,
            child: Center(
              child: FocusRing(
                onPressed: _press,
                borderRadius: _fullScreenRadius,
                child: Container(
                  width: _fullScreenFace,
                  height: _fullScreenFace,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Palette.toolbarInk,
                    borderRadius: _fullScreenRadius,
                    boxShadow: Shadows.toastLift,
                  ),
                  child: const CustomPaint(
                    size: Size.square(_fullScreenGlyph),
                    painter: _FullScreenGlyphPainter(color: Palette.onAccent),
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
