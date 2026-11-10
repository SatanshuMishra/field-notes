import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:field_notes/design/focus/focus_ring.dart';

import '../transport/transport.dart';
import '../transport/transport_timeline.dart';

export '../transport/transport_timeline.dart' show clampPlaybackPosition;

const double scrubberHeight = 48;
const double scrubberTrackHeight = transportRailHeight;
const double scrubberHandleRadius = transportThumbRadius;
const Duration scrubberKeyboardStep = transportSeekStep;
const String videoScrubberLabel = transportVideoPositionLabel;

class _SeekStepIntent extends Intent {
  const _SeekStepIntent(this.steps);

  final int steps;
}

class _SeekEdgeIntent extends Intent {
  const _SeekEdgeIntent(this.toEnd);

  final bool toEnd;
}

const Map<ShortcutActivator, Intent> _scrubberShortcuts =
    <ShortcutActivator, Intent>{
      SingleActivator(LogicalKeyboardKey.arrowRight): _SeekStepIntent(1),
      SingleActivator(LogicalKeyboardKey.arrowLeft): _SeekStepIntent(-1),
      SingleActivator(LogicalKeyboardKey.arrowUp): _SeekStepIntent(1),
      SingleActivator(LogicalKeyboardKey.arrowDown): _SeekStepIntent(-1),
      SingleActivator(LogicalKeyboardKey.home): _SeekEdgeIntent(false),
      SingleActivator(LogicalKeyboardKey.end): _SeekEdgeIntent(true),
    };

class VideoScrubber extends StatelessWidget {
  const VideoScrubber({
    super.key,
    required this.position,
    required this.total,
    required this.onSeek,
    required this.onScrubUpdate,
    required this.onScrubEnd,
  });

  final Duration position;
  final Duration? total;
  final ValueChanged<Duration>? onSeek;
  final ValueChanged<Duration>? onScrubUpdate;
  final VoidCallback? onScrubEnd;

  void _emit(Duration target) {
    final Duration? known = total;
    if (known != null && known > Duration.zero) {
      onSeek?.call(clampPlaybackPosition(target, known));
    }
  }

  Object? _onStep(_SeekStepIntent intent) {
    _emit(position + scrubberKeyboardStep * intent.steps);
    return null;
  }

  Object? _onEdge(_SeekEdgeIntent intent) {
    _emit(intent.toEnd ? (total ?? Duration.zero) : Duration.zero);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: _scrubberShortcuts,
      child: Actions(
        actions: <Type, Action<Intent>>{
          _SeekStepIntent: CallbackAction<_SeekStepIntent>(onInvoke: _onStep),
          _SeekEdgeIntent: CallbackAction<_SeekEdgeIntent>(onInvoke: _onEdge),
        },
        child: TransportTimeline(
          pressKey: transportVideoTimelineKey,
          label: videoScrubberLabel,
          position: position,
          total: total,
          onSeek: onSeek,
          onScrubUpdate: onScrubUpdate,
          onScrubEnd: onScrubEnd,
          palette: TransportPalette.stage(),
          height: scrubberHeight,
          surface: FocusRingSurface.dark,
          alwaysShowThumb: true,
        ),
      ),
    );
  }
}
