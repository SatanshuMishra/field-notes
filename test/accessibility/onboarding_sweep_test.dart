import 'package:flutter_test/flutter_test.dart';

import 'states/onboarding_states.dart';
import 'support/a11y_state.dart';
import 'support/reading_order.dart';

void main() {
  a11ySweepArea(
    area: 'onboarding',
    groupName: 'every onboarding state loads and matches its baseline',
    states: onboardingStates,
  );

  group('every onboarding state keeps each node in reading order', () {
    for (final A11yState state in onboardingStates) {
      testWidgets(state.id, (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await state.pump(tester);
        expect(
          readingOrderOrphans(tester),
          isEmpty,
          reason:
              '${state.id}: these nodes are in the hit-test tree but no '
              'node lists them in reading order',
        );
        handle.dispose();
      });
    }
  });
}
