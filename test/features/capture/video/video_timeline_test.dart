import 'package:field_notes/features/capture/video/video_timeline.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('videoHardCap', () {
    test('is exactly 30 minutes', () {
      expect(videoHardCap, const Duration(minutes: 30));
    });
  });

  group('videoTimelineEvents', () {
    test('schedules nudges at 5, 10, and 20 minutes then the 30-minute cap', () {
      final List<VideoTimelineEvent> events = videoTimelineEvents();

      expect(events, hasLength(4));

      expect(events[0].at, const Duration(minutes: 5));
      expect(events[0].kind, VideoTimelineEventKind.nudge);
      expect(events[0].message, videoNudge5Message);

      expect(events[1].at, const Duration(minutes: 10));
      expect(events[1].kind, VideoTimelineEventKind.nudge);
      expect(events[1].message, videoNudge10Message);

      expect(events[2].at, const Duration(minutes: 20));
      expect(events[2].kind, VideoTimelineEventKind.nudge);
      expect(events[2].message, videoNudge20Message);

      expect(events[3].at, videoHardCap);
      expect(events[3].kind, VideoTimelineEventKind.cap);
      expect(events[3].message, isNull);
    });

    test('is strictly increasing in time with the cap last', () {
      final List<VideoTimelineEvent> events = videoTimelineEvents();
      for (var i = 1; i < events.length; i++) {
        expect(events[i].at > events[i - 1].at, isTrue);
      }
      expect(events.last.kind, VideoTimelineEventKind.cap);
    });

    test('every nudge fires strictly before the hard cap', () {
      final List<VideoTimelineEvent> events = videoTimelineEvents();
      for (final VideoTimelineEvent event in events) {
        if (event.kind == VideoTimelineEventKind.nudge) {
          expect(event.at < videoHardCap, isTrue);
          expect(event.message, isNotNull);
        }
      }
    });
  });
}
