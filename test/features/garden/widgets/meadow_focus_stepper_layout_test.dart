import 'package:field_notes/features/garden/model/meadow_focus.dart';
import 'package:field_notes/features/garden/scene/meadow_view.dart';
import 'package:field_notes/features/garden/widgets/meadow_focus_stepper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const MeadowFocus _january = MeadowFocus(
  kind: MeadowFocusKind.month,
  index: 0,
  count: 12,
  range: MeadowRange(first: 0, last: 30, key: 'month-0'),
  title: 'January',
);
const String _counts = '0 blooms';

Future<void> _pumpStepper(WidgetTester tester, {required bool compact}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: meadowDeskStepperWidth,
            child: MeadowFocusStepper(
              focus: _january,
              counts: _counts,
              compact: compact,
              onStep: (int step) {},
              onClose: () {},
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final bool compact in <bool>[true, false]) {
    testWidgets('the month and its count sit in the middle of the '
        '${compact ? 'phone' : 'desktop'} stepper', (
      WidgetTester tester,
    ) async {
      await _pumpStepper(tester, compact: compact);
      final Rect stepper = tester.getRect(find.byKey(meadowFocusStepperKey));
      final Rect title = tester.getRect(find.byKey(meadowFocusTitleKey));
      final Rect counts = tester.getRect(find.text(_counts));
      expect(
        (title.top + counts.bottom) / 2,
        moreOrLessEquals(stepper.center.dy, epsilon: 0.5),
      );
    });
  }
}
