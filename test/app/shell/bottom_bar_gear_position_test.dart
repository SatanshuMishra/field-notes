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
    expect(gear.size, const Size.square(22));
    expect(gear.center.dy, moreOrLessEquals(22, epsilon: 0.01));
    expect(width - gear.right, moreOrLessEquals(19, epsilon: 0.01));
    final Rect wordmark = tester.getRect(find.text('field notes'));
    expect(wordmark.left, 18);
    expect(wordmark.center.dy, moreOrLessEquals(22, epsilon: 0.01));
  });
}
