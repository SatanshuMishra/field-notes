import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';

Future<List<String>> _pumpShortcuts(
  WidgetTester tester,
  TargetPlatform platform,
) async {
  debugDefaultTargetPlatformOverride = platform;
  tester.view.physicalSize = platform == TargetPlatform.macOS
      ? const Size(1280, 800)
      : const Size(360, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final List<String> calls = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform),
      home: Scaffold(
        body: RecorderShortcuts(
          onPrimary: () => calls.add('primary'),
          onKeep: () => calls.add('keep'),
          onLeave: () => calls.add('leave'),
          child: const SizedBox.expand(),
        ),
      ),
    ),
  );
  await tester.pump();
  return calls;
}

Future<void> _chord(
  WidgetTester tester,
  LogicalKeyboardKey modifier,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(modifier);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(modifier);
  await tester.pump();
}

void main() {
  testWidgets(
    'Space, the keep chord and Esc call the matching stage callbacks',
    (WidgetTester tester) async {
      final List<String> mac = await _pumpShortcuts(
        tester,
        TargetPlatform.macOS,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(mac, <String>['primary']);
      await _chord(
        tester,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.enter,
      );
      expect(mac, <String>['primary']);
      await _chord(
        tester,
        LogicalKeyboardKey.metaLeft,
        LogicalKeyboardKey.enter,
      );
      expect(mac, <String>['primary', 'keep']);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(mac, <String>['primary', 'keep', 'leave']);

      final List<String> android = await _pumpShortcuts(
        tester,
        TargetPlatform.android,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(android, <String>['primary']);
      await _chord(
        tester,
        LogicalKeyboardKey.metaLeft,
        LogicalKeyboardKey.enter,
      );
      expect(android, <String>['primary']);
      await _chord(
        tester,
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.enter,
      );
      expect(android, <String>['primary', 'keep']);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(android, <String>['primary', 'keep', 'leave']);

      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('a missing callback leaves its key unbound', (
    WidgetTester tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final List<String> calls = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.android),
        home: Scaffold(
          body: RecorderShortcuts(
            onLeave: () => calls.add('leave'),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await _chord(
      tester,
      LogicalKeyboardKey.controlLeft,
      LogicalKeyboardKey.enter,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(calls, <String>['leave']);
    debugDefaultTargetPlatformOverride = null;
  });
}
