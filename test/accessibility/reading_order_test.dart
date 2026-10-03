import 'package:flutter_test/flutter_test.dart';

import 'states/capture_states.dart';
import 'states/immersive_states.dart';
import 'states/settings_states.dart';
import 'states/shell_states.dart';
import 'states/viewer_states.dart';
import 'support/a11y_state.dart';
import 'support/reading_order.dart';

void _sweepReadingOrder(String area, List<A11yState> states) {
  group('$area: every sent semantics node is reachable in reading order', () {
    for (final A11yState state in states) {
      testWidgets(state.id, (WidgetTester tester) async {
        final SemanticsHandle handle = tester.ensureSemantics();
        await state.pump(tester);
        await tester.pump();
        expect(
          readingOrderOrphans(tester),
          isEmpty,
          reason:
              '${state.id}: these nodes are in the hit-test tree but no '
              'node lists them in reading order, so macOS rejects the '
              'whole semantics update and Android drops them',
        );
        handle.dispose();
      });
    }
  });
}

void main() {
  testWidgets(
    'H1: the open month picker is readable and the calendar behind it is not',
    (WidgetTester tester) async {
      final A11yState picker = shellStates.firstWhere(
        (A11yState state) => state.id == 'a5-calendar-picker',
      );
      final SemanticsHandle handle = tester.ensureSemantics();
      await picker.pump(tester);
      await tester.pump();
      final List<String> labels = labelsInReadingOrder(tester);
      expect(labels, contains('Dismiss month picker'));
      expect(labels, contains('Back to this month'));
      expect(labels, contains('January 2026'));
      expect(labels, contains('Previous year'));
      expect(
        labels.where((String label) => label.startsWith('Day 10')),
        isEmpty,
      );
      expect(readingOrderOrphans(tester), isEmpty);
      handle.dispose();
    },
  );

  _sweepReadingOrder('shell', shellStates);
  _sweepReadingOrder('settings', settingsStates);
  _sweepReadingOrder('capture', captureStates);
  _sweepReadingOrder('immersive', immersiveStates);
  _sweepReadingOrder('viewer', viewerStates);
}
