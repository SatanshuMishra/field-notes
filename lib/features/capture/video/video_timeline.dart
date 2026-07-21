const Duration videoHardCap = Duration(minutes: 30);

const String videoNudge5Message = '5 minutes in — looking good.';
const String videoNudge10Message = '10 minutes recorded.';
const String videoNudge20Message = '20 minutes in — 10 minutes left.';

enum VideoTimelineEventKind { nudge, cap }

class VideoTimelineEvent {
  const VideoTimelineEvent({
    required this.at,
    required this.kind,
    this.message,
  });

  final Duration at;
  final VideoTimelineEventKind kind;
  final String? message;
}

List<VideoTimelineEvent> videoTimelineEvents() => const <VideoTimelineEvent>[
      VideoTimelineEvent(
        at: Duration(minutes: 5),
        kind: VideoTimelineEventKind.nudge,
        message: videoNudge5Message,
      ),
      VideoTimelineEvent(
        at: Duration(minutes: 10),
        kind: VideoTimelineEventKind.nudge,
        message: videoNudge10Message,
      ),
      VideoTimelineEvent(
        at: Duration(minutes: 20),
        kind: VideoTimelineEventKind.nudge,
        message: videoNudge20Message,
      ),
      VideoTimelineEvent(
        at: videoHardCap,
        kind: VideoTimelineEventKind.cap,
      ),
    ];
