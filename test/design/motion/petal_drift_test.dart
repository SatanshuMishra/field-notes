import 'package:field_notes/design/motion/motion.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _beneathKey = ValueKey<String>('beneath-the-petals');
const String _beneathLabel = 'Beneath the petals';

typedef _Area = ({String name, TargetPlatform platform, Size size, int petals});

const List<_Area> _areas = <_Area>[
  (
    name: 'macOS page body',
    platform: TargetPlatform.macOS,
    size: Size(1063, 758),
    petals: 6,
  ),
  (
    name: 'phone page body',
    platform: TargetPlatform.android,
    size: Size(360, 640),
    petals: 3,
  ),
];

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

Future<void> _pumpLayer(
  WidgetTester tester, {
  required Size size,
  required bool petals,
  required bool still,
  required VoidCallback onTap,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size, disableAnimations: still),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            Semantics(
              button: true,
              label: _beneathLabel,
              child: GestureDetector(
                key: _beneathKey,
                behavior: HitTestBehavior.opaque,
                onTap: onTap,
                child: const SizedBox.expand(),
              ),
            ),
            if (petals) const PetalDrift(),
          ],
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 2));
}

int _nodesUnder(SemanticsNode node) {
  final List<SemanticsNode> children = <SemanticsNode>[];
  node.visitChildren((SemanticsNode child) {
    children.add(child);
    return true;
  });
  return children.fold<int>(
    1,
    (int count, SemanticsNode child) => count + _nodesUnder(child),
  );
}

int _semanticsNodes(WidgetTester tester) => <int>[
  for (final RenderView view in tester.binding.renderViews)
    if (view.owner?.semanticsOwner?.rootSemanticsNode
        case final SemanticsNode root)
      _nodesUnder(root),
].fold<int>(0, (int total, int count) => total + count);

Future<void> _tapThrough(WidgetTester tester) async {
  final Finder layer = find.byType(PetalDrift);
  expect(tester.getRect(layer), Offset.zero & tester.view.physicalSize);
  await tester.tapAt(tester.getCenter(layer));
  await tester.pump();
}

void main() {
  testWidgets('petals never take input and vanish with reduce motion', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    for (final _Area area in _areas) {
      await _onPlatform(area.platform, () async {
        int taps = 0;
        void onTap() => taps++;

        await _pumpLayer(
          tester,
          size: area.size,
          petals: false,
          still: false,
          onTap: onTap,
        );
        final int bare = _semanticsNodes(tester);
        expect(bare, greaterThan(0), reason: area.name);

        await _pumpLayer(
          tester,
          size: area.size,
          petals: true,
          still: false,
          onTap: onTap,
        );
        expect(find.byType(PetalDrift), findsOneWidget, reason: area.name);
        expect(
          find.byType(PetalDrift),
          paintsExactlyCountTimes(#drawRRect, area.petals * 2),
          reason: area.name,
        );
        expect(tester.hasRunningAnimations, isTrue, reason: area.name);
        expect(_semanticsNodes(tester), bare, reason: area.name);
        expect(
          tester.getSemantics(find.byKey(_beneathKey)),
          isSemantics(label: _beneathLabel, isButton: true, hasTapAction: true),
          reason: area.name,
        );
        await _tapThrough(tester);
        expect(taps, 1, reason: area.name);

        await _pumpLayer(
          tester,
          size: area.size,
          petals: true,
          still: true,
          onTap: onTap,
        );
        expect(find.byType(PetalDrift), findsOneWidget, reason: area.name);
        expect(find.byType(PetalDrift), paintsNothing, reason: area.name);
        expect(tester.hasRunningAnimations, isFalse, reason: area.name);
        expect(_semanticsNodes(tester), bare, reason: area.name);
        await _tapThrough(tester);
        expect(taps, 2, reason: area.name);
      });
    }
    handle.dispose();
  });
}
