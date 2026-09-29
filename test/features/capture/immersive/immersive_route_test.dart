import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/features/capture/immersive/immersive.dart';

const Key _behindButtonKey = ValueKey<String>('behind-button');
const Key _openKey = ValueKey<String>('open-recorder');

Future<void> _openOver(
  WidgetTester tester, {
  required TargetPlatform platform,
  required Size window,
  required ValueChanged<int> onBehindTap,
}) async {
  debugDefaultTargetPlatformOverride = platform;
  tester.view.physicalSize = window;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  int taps = 0;
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: fieldNotesTheme(platform: platform),
      home: Scaffold(
        body: Builder(
          builder: (BuildContext context) {
            return Stack(
              children: <Widget>[
                Center(
                  child: TextButton(
                    key: _behindButtonKey,
                    onPressed: () => onBehindTap(++taps),
                    child: const Text('Behind'),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: TextButton(
                    key: _openKey,
                    onPressed: () => showImmersiveRecorder<void>(
                      context,
                      barrierLabel: 'Dismiss recorder',
                      builder: (BuildContext context) => RecorderSurface(
                        privacyLine: 'Private · only you will hear this',
                        onLeave: () => Navigator.of(context).pop(),
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    ),
  );
}

Future<void> _expectCoversWindow(
  WidgetTester tester, {
  required Size window,
  required Duration fade,
}) async {
  final Offset behind = tester.getCenter(find.byKey(_behindButtonKey));
  await tester.tap(find.byKey(_openKey));
  await tester.pump();
  await tester.pump(fade);

  expect(find.byType(RecorderSurface), findsOneWidget);
  expect(tester.getSize(find.byType(RecorderSurface)), window);
  expect(tester.getTopLeft(find.byType(RecorderSurface)), Offset.zero);

  await tester.tapAt(behind);
  await tester.pump();
}

void main() {
  testWidgets(
    'showImmersiveRecorder covers the whole window in the sidebar layout',
    (WidgetTester tester) async {
      const Size window = Size(1280, 800);
      final List<int> behindTaps = <int>[];
      await _openOver(
        tester,
        platform: TargetPlatform.macOS,
        window: window,
        onBehindTap: behindTaps.add,
      );

      await _expectCoversWindow(
        tester,
        window: window,
        fade: const Duration(milliseconds: 600),
      );

      expect(behindTaps, isEmpty);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets(
    'showImmersiveRecorder covers the whole window in the bottom-bar layout',
    (WidgetTester tester) async {
      const Size window = Size(360, 740);
      final List<int> behindTaps = <int>[];
      await _openOver(
        tester,
        platform: TargetPlatform.android,
        window: window,
        onBehindTap: behindTaps.add,
      );

      await _expectCoversWindow(
        tester,
        window: window,
        fade: const Duration(milliseconds: 500),
      );

      expect(behindTaps, isEmpty);
      debugDefaultTargetPlatformOverride = null;
    },
  );

  testWidgets('the recorder fades in over 600 ms in the sidebar layout', (
    WidgetTester tester,
  ) async {
    await _openOver(
      tester,
      platform: TargetPlatform.macOS,
      window: const Size(1280, 800),
      onBehindTap: (int _) {},
    );

    await tester.tap(find.byKey(_openKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final FadeTransition midway = tester.widget<FadeTransition>(
      find
          .ancestor(
            of: find.byType(RecorderSurface),
            matching: find.byType(FadeTransition),
          )
          .first,
    );
    expect(midway.opacity.value, greaterThan(0));
    expect(midway.opacity.value, lessThan(1));
    expect(
      find.ancestor(
        of: find.byType(RecorderSurface),
        matching: find.byType(ScaleTransition),
      ),
      findsNothing,
    );

    await tester.pump(const Duration(milliseconds: 300));
    expect(midway.opacity.value, 1);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('Leave closes the full-window recorder', (
    WidgetTester tester,
  ) async {
    await _openOver(
      tester,
      platform: TargetPlatform.android,
      window: const Size(360, 740),
      onBehindTap: (int _) {},
    );
    await tester.tap(find.byKey(_openKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(recorderLeaveKey));
    await tester.pumpAndSettle();

    expect(find.byType(RecorderSurface), findsNothing);
    debugDefaultTargetPlatformOverride = null;
  });
}
