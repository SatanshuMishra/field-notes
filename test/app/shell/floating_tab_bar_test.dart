import 'package:field_notes/app/shell/app_shell.dart';
import 'package:field_notes/app/shell/phone_bottom_bar.dart';
import 'package:field_notes/app/shell/shell_content.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/today/today.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/app_shell_harness.dart';

const Size _surface = Size(384, 832);
const double _statusBar = 34;
const double _gestureBar = 24;

Future<void> _pumpPhone(WidgetTester tester) async {
  tester.view.physicalSize = _surface;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  tester.view.viewPadding = const FakeViewPadding(
    top: _statusBar,
    bottom: _gestureBar,
  );
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: shellOverrides(),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(platform: TargetPlatform.android),
        home: const AppShell(),
      ),
    ),
  );
  await tester.pump();
}

final Finder _bar = find.byType(PhoneBottomBar);

final Finder _capture = find.byKey(const ValueKey<String>('capture-button'));

Finder _tab(ShellDestination d) =>
    find.byKey(ValueKey<String>('tab-${d.name}'));

Rect _captureCircle(WidgetTester tester) {
  final Finder circle = find.descendant(
    of: _capture,
    matching: find.byWidgetPredicate(
      (Widget widget) =>
          widget is DecoratedBox &&
          widget.decoration is BoxDecoration &&
          (widget.decoration as BoxDecoration).shape == BoxShape.circle,
    ),
  );
  expect(circle, findsOneWidget);
  return tester.getRect(circle);
}

List<Color> _fills(WidgetTester tester, Finder owner) => tester
    .widgetList<DecoratedBox>(
      find.descendant(of: owner, matching: find.byType(DecoratedBox)),
    )
    .map((DecoratedBox box) => box.decoration)
    .whereType<BoxDecoration>()
    .map((BoxDecoration decoration) => decoration.color)
    .whereType<Color>()
    .toList();

bool _paintsPill(WidgetTester tester, ShellDestination d, Color pill) => _fills(
  tester,
  _tab(d),
).any((Color color) => color.toARGB32() == pill.toARGB32());

Rect _semanticRect(WidgetTester tester, Finder finder) {
  final SemanticsNode node = tester.getSemantics(finder);
  Rect rect = node.rect;
  for (
    SemanticsNode? current = node;
    current != null;
    current = current.parent
  ) {
    final Matrix4? transform = current.transform;
    if (transform != null) {
      rect = MatrixUtils.transformRect(transform, rect);
    }
  }
  return rect;
}

void main() {
  testWidgets(
    'the tab bar floats 12 in from each side and 8 above the gesture inset, '
    '64 tall',
    (WidgetTester tester) async {
      await _pumpPhone(tester);

      expect(_bar, findsOneWidget);
      final Rect bar = tester.getRect(_bar);
      expect(bar.left, 12);
      expect(bar.right, 372);
      expect(bar.bottom, 800);
      expect(bar.height, 64);

      final Finder glass = find.descendant(
        of: _bar,
        matching: find.byType(GlassSurface),
      );
      expect(glass, findsOneWidget);
      expect(tester.getRect(glass), bar);
      expect(
        tester.widget<GlassSurface>(glass).borderRadius,
        const BorderRadius.all(Radius.circular(32)),
      );
      expect(
        find.descendant(of: _bar, matching: find.byType(BackdropFilter)),
        findsOneWidget,
      );
    },
  );

  testWidgets('the plus sits inside the bar and the active tab gets a pill', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await _pumpPhone(tester);

    final Rect bar = tester.getRect(_bar);
    final Rect circle = _captureCircle(tester);
    expect(circle.size, const Size.square(46));
    expect(circle.top, greaterThanOrEqualTo(bar.top));
    expect(circle.bottom, lessThanOrEqualTo(bar.bottom));
    expect(circle.left, greaterThanOrEqualTo(bar.left));
    expect(circle.right, lessThanOrEqualTo(bar.right));
    expect(circle.center.dx, moreOrLessEquals(bar.center.dx, epsilon: 0.01));
    expect(circle.center.dy, moreOrLessEquals(bar.center.dy, epsilon: 0.01));

    final List<Finder> cells = <Finder>[
      _tab(ShellDestination.today),
      _tab(ShellDestination.calendar),
      _capture,
      _tab(ShellDestination.garden),
      _tab(ShellDestination.search),
    ];
    final List<double> centres = <double>[
      for (final Finder cell in cells) tester.getCenter(cell).dx,
    ];
    for (int index = 1; index < centres.length; index++) {
      expect(centres[index], greaterThan(centres[index - 1]));
    }
    for (final Finder cell in cells) {
      final Rect area = _semanticRect(tester, cell);
      expect(area.height, greaterThanOrEqualTo(48), reason: '$cell');
      expect(area.width, greaterThanOrEqualTo(44), reason: '$cell');
      expect(area.top, greaterThanOrEqualTo(bar.top - 0.01));
      expect(area.bottom, lessThanOrEqualTo(bar.bottom + 0.01));
    }

    final Color paperPill = GlassTone.paper.pillFor(Brightness.light);
    for (final ShellDestination d in ShellDestination.primary) {
      expect(
        _paintsPill(tester, d, paperPill),
        d == ShellDestination.today,
        reason: '${d.name} with Today selected',
      );
    }
    expect(
      _fills(tester, _capture).map((Color color) => color.toARGB32()),
      contains(Palette.coral.toARGB32()),
    );

    await tester.tap(_tab(ShellDestination.calendar));
    await tester.pump();
    for (final ShellDestination d in ShellDestination.primary) {
      expect(
        _paintsPill(tester, d, paperPill),
        d == ShellDestination.calendar,
        reason: '${d.name} with Calendar selected',
      );
    }

    await tester.tap(_tab(ShellDestination.garden));
    await tester.pump();
    final Color scenePill = GlassTone.scene.pillFor(Brightness.light);
    for (final ShellDestination d in ShellDestination.primary) {
      expect(
        _paintsPill(tester, d, scenePill),
        d == ShellDestination.garden,
        reason: '${d.name} with the Meadow selected',
      );
    }
    final Finder sceneGlass = find.descendant(
      of: _bar,
      matching: find.byType(GlassSurface),
    );
    expect(tester.widget<GlassSurface>(sceneGlass).tone, GlassTone.scene);
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: _tab(ShellDestination.today),
              matching: find.text('Today'),
            ),
          )
          .style!
          .color!
          .toARGB32(),
      const Color.fromRGBO(251, 243, 228, 0.82).toARGB32(),
    );
    handle.dispose();
  });

  testWidgets('page content scrolls beneath the floating tab bar', (
    WidgetTester tester,
  ) async {
    await _pumpPhone(tester);

    final Rect body = tester.getRect(find.byType(ShellContent));
    final Rect bar = tester.getRect(_bar);
    expect(body.top, 0);
    expect(body.bottom, _surface.height);
    expect(body.left, 0);
    expect(body.right, _surface.width);
    expect(body.contains(bar.topLeft), isTrue);
    expect(body.contains(bar.bottomRight - const Offset(0.5, 0.5)), isTrue);

    final Rect page = tester.getRect(find.byType(TodayScreen));
    expect(page.bottom, _surface.height);
    final EdgeInsets inset = MediaQuery.paddingOf(
      tester.element(find.byType(TodayScreen)),
    );
    expect(inset.top, _statusBar + 44);
    expect(inset.bottom, _gestureBar + 80);
    expect(_surface.height - inset.bottom, lessThanOrEqualTo(bar.top));
  });
}
