import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'states/settings_states.dart';
import 'support/a11y_state.dart';
import 'support/reading_order.dart';

void main() {
  testWidgets(
    'MB1: Settings keeps every node in reading order at desktop window '
    'heights and scroll offsets',
    (WidgetTester tester) async {
      final A11yState settings = settingsStates.firstWhere(
        (A11yState state) => state.id == 'b1-settings',
      );
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<String> failures = <String>[];
      for (double height = 640; height <= 1100; height += 20) {
        await settings.pump(tester);
        tester.view.physicalSize = Size(1280, height);
        tester.view.devicePixelRatio = 1;
        await tester.pumpAndSettle();
        final ScrollableState scrollable = tester.state<ScrollableState>(
          find
              .descendant(
                of: find.byType(SettingsScreen),
                matching: find.byType(Scrollable),
              )
              .first,
        );
        final double extent = scrollable.position.maxScrollExtent;
        for (double offset = 0; offset <= extent; offset += 40) {
          scrollable.position.jumpTo(offset);
          await tester.pump();
          final List<String> orphans = readingOrderOrphans(tester);
          if (orphans.isNotEmpty) {
            failures.add('height $height offset $offset: $orphans');
          }
        }
      }
      await settings.pump(tester);
      expect(find.text('Text size'), findsOneWidget);
      expect(failures, isEmpty);
      handle.dispose();
    },
  );
}
