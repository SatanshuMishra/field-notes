import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/domain/services/reminder_service.dart';
import 'package:field_notes/domain/settings/settings.dart';
import 'package:field_notes/features/settings/widgets/reminder_schedule_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const double _width = 600;
const double _markerOuterRadius = 10;
const double _noonFraction = 6 / 22;
const double _lastCallFraction = 16.5 / 22;

typedef _Circle = ({Offset centre, double radius});

Future<List<_Circle>> _markersFor(
  WidgetTester tester,
  ReminderTime customTime,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: fieldNotesTheme(platform: TargetPlatform.macOS),
      home: Material(
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: _width,
            child: ReminderTimeline(
              slots: const ReminderService().slotsFor(
                ReminderSchedule.custom,
                customTime,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  final RenderObject timeline = tester.renderObject(
    find.descendant(
      of: find.byType(ReminderTimeline),
      matching: find.byType(CustomPaint),
    ),
  );
  final List<_Circle> circles = <_Circle>[];
  expect(
    timeline,
    paints..everything((Symbol method, List<dynamic> arguments) {
      if (method == #drawCircle) {
        circles.add((
          centre: arguments[0] as Offset,
          radius: arguments[1] as double,
        ));
      }
      return true;
    }),
  );
  return <_Circle>[
    for (final _Circle circle in circles)
      if (circle.radius == _markerOuterRadius) circle,
  ];
}

void _expectInside(_Circle marker, String reason) {
  expect(
    marker.centre.dx - marker.radius,
    greaterThanOrEqualTo(0),
    reason: reason,
  );
  expect(
    marker.centre.dx + marker.radius,
    lessThanOrEqualTo(_width),
    reason: reason,
  );
}

void main() {
  testWidgets('an early-morning custom time sits inside the timeline at the '
      'morning end', (WidgetTester tester) async {
    for (final ReminderTime time in const <ReminderTime>[
      ReminderTime(hour: 4, minute: 0),
      ReminderTime(hour: 5, minute: 30),
      ReminderTime(hour: 5, minute: 59),
      ReminderTime(hour: 6, minute: 0),
    ]) {
      final List<_Circle> markers = await _markersFor(tester, time);
      final _Circle custom = markers.first;

      expect(markers, hasLength(2), reason: '$time');
      _expectInside(custom, '$time');
      expect(
        custom.centre.dx,
        lessThan(_width * _noonFraction),
        reason: '$time',
      );
    }
  });

  testWidgets('a 1:15 AM custom time is the last call at the night end, '
      'after 10:30 PM', (WidgetTester tester) async {
    final List<_Circle> markers = await _markersFor(
      tester,
      const ReminderTime(hour: 1, minute: 15),
    );

    expect(markers, hasLength(1));
    _expectInside(markers.single, '1:15');
    expect(markers.single.centre.dx, greaterThan(_width * _lastCallFraction));
  });
}
