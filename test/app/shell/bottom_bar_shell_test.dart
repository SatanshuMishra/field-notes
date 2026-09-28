import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/shell_destination.dart';

import '../app_harness.dart';

BottomBarShell _shell({
  ShellDestination selected = ShellDestination.today,
  ValueChanged<ShellDestination>? onSelect,
  VoidCallback? onCapture,
}) {
  return BottomBarShell(
    destinations: ShellDestination.primary,
    selected: selected,
    onSelect: onSelect ?? (_) {},
    onCapture: onCapture ?? () {},
    body: const SizedBox.shrink(),
  );
}

void main() {
  group('BottomBarShell', () {
    testWidgets('renders four tabs and the center capture',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        appHarness(_shell(), platform: TargetPlatform.android),
      );

      for (final ShellDestination d in ShellDestination.primary) {
        expect(find.byKey(ValueKey<String>('tab-${d.name}')), findsOneWidget);
      }
      expect(find.byKey(const ValueKey<String>('capture-button')),
          findsOneWidget);
    });

    testWidgets('a tab reports its destination on tap',
        (WidgetTester tester) async {
      ShellDestination? picked;
      await tester.pumpWidget(
        appHarness(
          _shell(onSelect: (ShellDestination d) => picked = d),
          platform: TargetPlatform.android,
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('tab-search')));
      expect(picked, ShellDestination.search);
    });

    testWidgets('the center capture invokes onCapture',
        (WidgetTester tester) async {
      int captures = 0;
      await tester.pumpWidget(
        appHarness(
          _shell(onCapture: () => captures++),
          platform: TargetPlatform.android,
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('capture-button')));
      expect(captures, 1);
    });

    testWidgets('the gear selects the settings destination',
        (WidgetTester tester) async {
      ShellDestination? picked;
      await tester.pumpWidget(
        appHarness(
          _shell(onSelect: (ShellDestination d) => picked = d),
          platform: TargetPlatform.android,
        ),
      );

      await tester.tap(find.byKey(const ValueKey<String>('gear-button')));
      expect(picked, ShellDestination.settings);
    });

    testWidgets(
      'the tabs keep their pre-209 painted spacing with 48 dp tap areas',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1233, 2673);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);
        final SemanticsHandle handle = tester.ensureSemantics();
        ShellDestination? picked;
        await tester.pumpWidget(
          appHarness(
            _shell(onSelect: (ShellDestination d) => picked = d),
            platform: TargetPlatform.android,
          ),
        );

        final Finder capture = find.byKey(
          const ValueKey<String>('capture-button'),
        );
        final List<Rect> painted = <Rect>[
          _tabContent(tester, ShellDestination.today),
          _tabContent(tester, ShellDestination.calendar),
          tester.getRect(capture),
          _tabContent(tester, ShellDestination.garden),
          _tabContent(tester, ShellDestination.search),
        ];
        final Rect row = tester.getRect(
          find.ancestor(of: capture, matching: find.byType(Row)).first,
        );
        final List<double> gaps = <double>[
          for (int i = 1; i < painted.length; i++)
            painted[i].left - painted[i - 1].right,
        ];
        for (final double gap in gaps) {
          expect(gap, moreOrLessEquals(gaps.first, epsilon: 0.01));
        }
        expect(
          painted.first.left - row.left,
          moreOrLessEquals(gaps.first / 2, epsilon: 0.01),
        );
        expect(
          row.right - painted.last.right,
          moreOrLessEquals(gaps.first / 2, epsilon: 0.01),
        );

        for (final ShellDestination d in ShellDestination.primary) {
          final Rect area = _semanticRect(
            tester,
            find.byKey(ValueKey<String>('tab-${d.name}')),
          );
          expect(area.width, greaterThanOrEqualTo(47.99), reason: d.name);
          expect(area.height, greaterThanOrEqualTo(47.99), reason: d.name);
          picked = null;
          await tester.tapAt(area.centerLeft + const Offset(1, 0));
          expect(picked, d);
          picked = null;
          await tester.tapAt(area.centerRight - const Offset(1, 0));
          expect(picked, d);
        }
        handle.dispose();
      },
    );
  });
}

Rect _tabContent(WidgetTester tester, ShellDestination d) => tester.getRect(
  find
      .descendant(
        of: find.byKey(ValueKey<String>('tab-${d.name}')),
        matching: find.byType(Padding),
      )
      .first,
);

Rect _semanticRect(WidgetTester tester, Finder finder) {
  final SemanticsNode node = tester.getSemantics(finder);
  final Rect physical =
      <SemanticsNode>[
        for (
          SemanticsNode? current = node;
          current != null;
          current = current.parent
        )
          current,
      ].fold(
        node.rect,
        (Rect rect, SemanticsNode current) => switch (current.transform) {
          final Matrix4 transform => MatrixUtils.transformRect(transform, rect),
          null => rect,
        },
      );
  final double ratio = tester.view.devicePixelRatio;
  return Rect.fromLTRB(
    physical.left / ratio,
    physical.top / ratio,
    physical.right / ratio,
    physical.bottom / ratio,
  );
}
