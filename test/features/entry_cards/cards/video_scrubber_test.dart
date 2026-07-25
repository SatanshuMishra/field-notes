import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/features/entry_cards/cards/video_scrubber.dart';

import '../support/entry_cards_harness.dart';

const ValueKey<String> _scrubBar = ValueKey<String>('video-scrub-bar');
const Duration _minute = Duration(minutes: 1);
const Duration _realPosition = Duration(seconds: 5);

Widget _scrubber({required Duration position, required Duration? total}) {
  return cardHarness(
    VideoScrubber(
      position: position,
      total: total,
      onSeek: (Duration _) {},
      onScrubUpdate: null,
      onScrubEnd: null,
    ),
  );
}

String _spokenPosition(WidgetTester tester) =>
    tester.getSemantics(find.byKey(_scrubBar)).value;

void main() {
  group('VideoScrubber', () {
    testWidgets(
      'drops the drag preview when the duration goes unknown mid-drag',
      (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        try {
          await tester.pumpWidget(
            _scrubber(position: _realPosition, total: _minute),
          );

          final Rect bar = tester.getRect(find.byKey(_scrubBar));
          final TestGesture gesture = await tester.startGesture(
            Offset(bar.left + 1, bar.center.dy),
          );
          await gesture.moveTo(bar.center);
          await tester.pump();

          expect(_spokenPosition(tester), '0:30 of 1:00');

          await tester.pumpWidget(
            _scrubber(position: _realPosition, total: null),
          );
          await tester.pumpWidget(
            _scrubber(position: _realPosition, total: _minute),
          );

          expect(_spokenPosition(tester), '0:05 of 1:00');

          await gesture.up();
        } finally {
          handle.dispose();
        }
      },
    );
  });
}
