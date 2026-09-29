import 'package:field_notes/features/settings/settings_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'states/settings_states.dart';
import 'support/a11y_state.dart';
import 'support/reading_order.dart';

const Map<String, String> _tabStates = <String, String>{
  'b1-settings': 'Storage mode',
  'b6-settings-reminders': 'Daily reminder',
  'b7-settings-journal': 'Text size',
  'b8-settings-data': 'Delete all',
};

const List<TargetPlatform> _platforms = <TargetPlatform>[
  TargetPlatform.android,
  TargetPlatform.macOS,
];

Future<void> _sweep(
  WidgetTester tester,
  TargetPlatform platform,
  List<String> failures,
) async {
  for (final MapEntry<String, String> tab in _tabStates.entries) {
    final A11yState settings = settingsStates.firstWhere(
      (A11yState state) => state.id == tab.key,
    );
    for (double height = 640; height <= 1100; height += 20) {
      await settings.pump(tester);
      tester.view.physicalSize = Size(1280, height);
      tester.view.devicePixelRatio = 1;
      await tester.pumpAndSettle();
      final ScrollableState scrollable = tester.state<ScrollableState>(
        find
            .ancestor(
              of: find.byKey(settingsTabContentKey),
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
          failures.add(
            '${platform.name} ${tab.key} height $height offset $offset: '
            '$orphans',
          );
        }
      }
    }
    await settings.pump(tester);
    expect(
      find.text(tab.value),
      findsOneWidget,
      reason: '${platform.name} ${tab.key}',
    );
  }
}

void main() {
  testWidgets(
    'MB1: Settings keeps every node in reading order at desktop window '
    'heights and scroll offsets',
    (WidgetTester tester) async {
      final SemanticsHandle handle = tester.ensureSemantics();
      final List<String> failures = <String>[];
      for (final TargetPlatform platform in _platforms) {
        debugDefaultTargetPlatformOverride = platform;
        try {
          await _sweep(tester, platform, failures);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      }
      expect(failures, isEmpty);
      handle.dispose();
    },
  );
}
