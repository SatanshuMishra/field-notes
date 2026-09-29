import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/features/onboarding/tour_anchor.dart';
import 'package:field_notes/features/today/today.dart';

import '../../app/support/app_shell_harness.dart';

const Size _sidebarSurface = Size(1280, 800);
const Size _bottomBarSurface = Size(360, 740);
const double _epsilon = 1.0;

RenderBox _windowBox(WidgetTester tester) =>
    tester.renderObject<RenderBox>(find.byType(AppShell));

Rect _rectOfKey(WidgetTester tester, Key key, RenderBox ancestor) {
  final RenderBox box = tester.renderObject<RenderBox>(find.byKey(key));
  return box.localToGlobal(Offset.zero, ancestor: ancestor) & box.size;
}

Rect _rectOfType(WidgetTester tester, Type type, RenderBox ancestor) {
  final RenderBox box = tester.renderObject<RenderBox>(find.byType(type));
  return box.localToGlobal(Offset.zero, ancestor: ancestor) & box.size;
}

bool _containsRect(Rect outer, Rect inner) {
  return inner.left >= outer.left - _epsilon &&
      inner.top >= outer.top - _epsilon &&
      inner.right <= outer.right + _epsilon &&
      inner.bottom <= outer.bottom + _epsilon;
}

void _expectRectEquals(Rect a, Rect b) {
  expect(a.left, closeTo(b.left, _epsilon));
  expect(a.top, closeTo(b.top, _epsilon));
  expect(a.right, closeTo(b.right, _epsilon));
  expect(a.bottom, closeTo(b.bottom, _epsilon));
}

Future<void> _onPlatform(
  TargetPlatform platform,
  Future<void> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

Map<TourTarget, Rect> _readAllRects(WidgetTester tester, RenderBox ancestor) {
  final TourAnchors anchors = ProviderScope.containerOf(
    tester.element(find.byType(AppShell)),
  ).read(tourAnchorsProvider);

  final Map<TourTarget, Rect> rects = <TourTarget, Rect>{};
  for (final TourTarget target in TourTarget.values) {
    final Rect? rect = anchors.rectOf(target, ancestor);
    expect(rect, isNotNull, reason: '${target.name} has no rect');
    rects[target] = rect!;
  }
  return rects;
}

void main() {
  testWidgets(
    'the sidebar layout exposes nav, calendar, mood, capture and settings tour targets',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.macOS, () async {
        await pumpShell(
          tester,
          const AppShell(),
          platform: TargetPlatform.macOS,
          surface: _sidebarSurface,
        );

        final RenderBox windowBox = _windowBox(tester);
        final Rect windowRect = Offset.zero & windowBox.size;
        final Map<TourTarget, Rect> rects = _readAllRects(tester, windowBox);

        for (final TourTarget target in TourTarget.values) {
          expect(
            _containsRect(windowRect, rects[target]!),
            isTrue,
            reason: '${target.name} rect is outside the window',
          );
        }

        expect(
          _containsRect(rects[TourTarget.nav]!, rects[TourTarget.calendar]!),
          isTrue,
        );

        final Rect railRect = _rectOfType(tester, TodayRightRail, windowBox);
        expect(_containsRect(railRect, rects[TourTarget.capture]!), isTrue);
      });
    },
  );

  testWidgets(
    'the bottom-bar layout exposes nav, calendar, mood, capture and settings tour targets',
    (WidgetTester tester) async {
      await _onPlatform(TargetPlatform.android, () async {
        await pumpShell(
          tester,
          const AppShell(),
          platform: TargetPlatform.android,
          surface: _bottomBarSurface,
        );

        final RenderBox windowBox = _windowBox(tester);
        final Rect windowRect = Offset.zero & windowBox.size;
        final Map<TourTarget, Rect> rects = _readAllRects(tester, windowBox);

        for (final TourTarget target in TourTarget.values) {
          expect(
            _containsRect(windowRect, rects[target]!),
            isTrue,
            reason: '${target.name} rect is outside the window',
          );
        }

        expect(
          _containsRect(rects[TourTarget.nav]!, rects[TourTarget.calendar]!),
          isTrue,
        );

        final Rect captureButtonRect = _rectOfKey(
          tester,
          const ValueKey<String>('capture-button'),
          windowBox,
        );
        _expectRectEquals(rects[TourTarget.capture]!, captureButtonRect);

        final Rect gearButtonRect = _rectOfKey(
          tester,
          const ValueKey<String>('gear-button'),
          windowBox,
        );
        _expectRectEquals(rects[TourTarget.settings]!, gearButtonRect);
      });
    },
  );
}
