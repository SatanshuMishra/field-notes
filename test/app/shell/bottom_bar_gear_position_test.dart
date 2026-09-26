import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../accessibility/states/shell_states.dart';
import '../../accessibility/support/a11y_state.dart';

void main() {
  testWidgets('the gear keeps its painted position', (
    WidgetTester tester,
  ) async {
    await runA11yState(
      tester,
      shellStates.singleWhere(
        (A11yState state) => state.id == 'a1-today-empty',
      ),
    );
    final double width =
        tester.view.physicalSize.width / tester.view.devicePixelRatio;
    final Rect gear = tester.getRect(find.byIcon(Icons.settings_outlined));
    expect(gear.top, 16);
    expect(width - gear.right, moreOrLessEquals(16, epsilon: 0.01));
    expect(tester.getRect(find.text('field notes')).top, 18);
  });
}
