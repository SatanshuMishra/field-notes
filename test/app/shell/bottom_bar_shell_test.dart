import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/phone_bottom_bar.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/icons/nav_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';

import '../app_harness.dart';

const Key _pageKey = ValueKey<String>('page');

const double _barHeight = 64;
const double _captureExtent = 52;
const double _captureRise = 4.25;
const double _captureCentreDrop = 21.75;
const double _iconSize = 22;
const double _iconTop = 13;
const double _labelGap = 3;
const double _plusStroke = 2.6;

BottomBarShell _shell({
  ShellDestination selected = ShellDestination.today,
  ValueChanged<ShellDestination>? onSelect,
  VoidCallback? onCapture,
  Widget body = const SizedBox.shrink(),
}) {
  return BottomBarShell(
    destinations: ShellDestination.primary,
    selected: selected,
    onSelect: onSelect ?? (_) {},
    onCapture: onCapture ?? () {},
    body: body,
  );
}

Widget _themed(Widget child, Brightness brightness) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: fieldNotesTheme(
    platform: TargetPlatform.android,
    brightness: brightness,
  ),
  home: child,
);

void _phone(WidgetTester tester, {double bottomInset = 0}) {
  tester.view.physicalSize = const Size(1080, 2220);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = FakeViewPadding(bottom: bottomInset * 3);
  addTearDown(tester.view.reset);
}

bool _isBar(Widget widget) => switch (widget) {
  DecoratedBox(
    decoration: BoxDecoration(
      border: Border(:final BorderSide top, :final BorderSide bottom),
    ),
  ) =>
    top.width == Shapes.outlineWidth && bottom == BorderSide.none,
  _ => false,
};

final Finder _bar = find.byWidgetPredicate(_isBar);

final Finder _capture = find.byKey(const ValueKey<String>('capture-button'));

Finder _tab(ShellDestination d) =>
    find.byKey(ValueKey<String>('tab-${d.name}'));

List<Finder> get _items => <Finder>[
  _tab(ShellDestination.today),
  _tab(ShellDestination.calendar),
  _capture,
  _tab(ShellDestination.garden),
  _tab(ShellDestination.search),
];

FieldNotesColors _colors(WidgetTester tester) =>
    FieldNotesColors.of(tester.element(find.byType(BottomBarShell)));

Finder _iconOf(ShellDestination d) =>
    find.descendant(of: _tab(d), matching: find.byType(NavIcon));

Finder _labelOf(ShellDestination d) =>
    find.descendant(of: _tab(d), matching: find.text(d.label));

bool _near(Offset a, Offset b) => (a - b).distance < 0.01;

bool _drawsThePlus(Symbol method, List<dynamic> arguments) {
  if (method != #drawPath) {
    return false;
  }
  final Path path = arguments[0] as Path;
  final Paint paint = arguments[1] as Paint;
  final List<(Offset, Offset)> strokes = <(Offset, Offset)>[
    for (final PathMetric metric in path.computeMetrics())
      (
        metric.getTangentForOffset(0)!.position,
        metric.getTangentForOffset(metric.length)!.position,
      ),
  ];
  const List<(Offset, Offset)> plus = <(Offset, Offset)>[
    (Offset(12, 5), Offset(12, 19)),
    (Offset(5, 12), Offset(19, 12)),
  ];
  if (strokes.length != plus.length ||
      !<int>[for (int i = 0; i < plus.length; i++) i].every(
        (int i) =>
            _near(strokes[i].$1, plus[i].$1) &&
            _near(strokes[i].$2, plus[i].$2),
      )) {
    throw 'drew the strokes $strokes, not the plus $plus';
  }
  if (paint.style != PaintingStyle.stroke ||
      (paint.strokeWidth - _plusStroke).abs() > 0.001 ||
      paint.strokeCap != StrokeCap.round ||
      paint.color.toARGB32() != Palette.onAccent.toARGB32()) {
    throw 'drew the plus with $paint, not a round-capped white '
        '$_plusStroke stroke';
  }
  return true;
}

void main() {
  group('BottomBarShell', () {
    testWidgets('renders four tabs and the center capture', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        appHarness(_shell(), platform: TargetPlatform.android),
      );

      for (final ShellDestination d in ShellDestination.primary) {
        expect(find.byKey(ValueKey<String>('tab-${d.name}')), findsOneWidget);
      }
      expect(
        find.byKey(const ValueKey<String>('capture-button')),
        findsOneWidget,
      );
    });

    testWidgets('a tab reports its destination on tap', (
      WidgetTester tester,
    ) async {
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

    testWidgets('the center capture invokes onCapture', (
      WidgetTester tester,
    ) async {
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

    testWidgets('the gear selects the settings destination', (
      WidgetTester tester,
    ) async {
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
      'the capture button sits 4.25 points above the bar and is tappable '
      'across its whole circle',
      (WidgetTester tester) async {
        _phone(tester);
        int captures = 0;
        int pageTaps = 0;
        await tester.pumpWidget(
          appHarness(
            _shell(
              onCapture: () => captures++,
              body: GestureDetector(
                key: _pageKey,
                behavior: HitTestBehavior.opaque,
                onTap: () => pageTaps++,
                child: const SizedBox.expand(),
              ),
            ),
            platform: TargetPlatform.android,
          ),
        );

        final Rect bar = tester.getRect(_bar);
        final Rect capture = tester.getRect(_capture);
        expect(capture.size, const Size.square(_captureExtent));
        expect(
          capture.top,
          moreOrLessEquals(bar.top - _captureRise, epsilon: 0.01),
        );
        expect(
          capture.center.dy,
          moreOrLessEquals(bar.top + _captureCentreDrop, epsilon: 0.01),
        );
        expect(
          capture.center.dx,
          moreOrLessEquals(bar.left + bar.width / 2, epsilon: 0.01),
        );
        expect(
          tester.getRect(find.byKey(_pageKey)).bottom,
          moreOrLessEquals(bar.top, epsilon: 0.01),
        );

        final double reach = _captureExtent / 2 - 2;
        final List<Offset> onCircle = <Offset>[
          capture.center + Offset(0, -reach),
          capture.center + Offset(-reach, 0),
          capture.center + Offset(reach, 0),
          capture.center + Offset(0, reach),
        ];
        expect(onCircle.first.dy, lessThan(bar.top));
        for (final Offset point in onCircle) {
          await tester.tapAt(point);
        }
        expect(captures, onCircle.length);
        expect(pageTaps, 0);

        await tester.tapAt(Offset(capture.center.dx - 40, bar.top - 2));
        expect(pageTaps, 1);
        expect(captures, onCircle.length);

        final Offset besideTheCircle = Offset(
          capture.center.dx - 20,
          bar.top - 1,
        );
        expect(
          (besideTheCircle - capture.center).distance,
          greaterThan(_captureExtent / 2),
        );
        await tester.tapAt(besideTheCircle);
        expect(pageTaps, 2);
        expect(captures, onCircle.length);
      },
    );

    testWidgets('the capture button shows the thin drawn plus', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(
        appHarness(_shell(), platform: TargetPlatform.android),
      );

      final Finder plus = find.descendant(
        of: _capture,
        matching: find.byType(NavIcon),
      );
      expect(plus, findsOneWidget);
      final NavIcon icon = tester.widget<NavIcon>(plus);
      expect(icon.size, _iconSize);
      expect(icon.color.toARGB32(), Palette.onAccent.toARGB32());
      expect(tester.getSize(plus), const Size.square(_iconSize));
      expect(
        (tester.getCenter(plus) - tester.getCenter(_capture)).distance,
        lessThan(0.01),
      );
      expect(plus, paints..something(_drawsThePlus));
      expect(
        find.descendant(of: _capture, matching: find.byType(Icon)),
        findsNothing,
      );
      expect(find.byIcon(Icons.add), findsNothing);
    });

    testWidgets(
      'the tabs use the drawn house, calendar, flower and magnifier icons',
      (WidgetTester tester) async {
        _phone(tester);
        for (final Brightness brightness in Brightness.values) {
          for (final ShellDestination selected in ShellDestination.primary) {
            await tester.pumpWidget(
              _themed(_shell(selected: selected), brightness),
            );
            final FieldNotesColors colors = _colors(tester);
            final Rect bar = tester.getRect(_bar);
            for (final ShellDestination d in ShellDestination.primary) {
              final String reason =
                  '${brightness.name} ${selected.name} '
                  'selected, ${d.name}';
              final Finder icon = _iconOf(d);
              expect(icon, findsOneWidget, reason: reason);
              final NavIcon drawn = tester.widget<NavIcon>(icon);
              expect(drawn.glyph, d.glyph, reason: reason);
              expect(drawn.size, _iconSize, reason: reason);
              expect(
                tester.getSize(icon),
                const Size.square(_iconSize),
                reason: reason,
              );
              expect(
                tester.getRect(icon).top,
                moreOrLessEquals(bar.top + _iconTop, epsilon: 0.01),
                reason: reason,
              );
              expect(
                drawn.color.toARGB32(),
                (d == selected ? colors.accentInk : colors.mutedDeep)
                    .toARGB32(),
                reason: reason,
              );
            }
            expect(
              tester
                  .widgetList<Icon>(
                    find.descendant(
                      of: find.byType(BottomBarShell),
                      matching: find.byType(Icon),
                    ),
                  )
                  .map((Icon icon) => icon.icon),
              <IconData>[Icons.settings_outlined],
            );
          }
        }
      },
    );

    testWidgets('tab labels are twelve-point medium on one line', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        appHarness(
          _shell(selected: ShellDestination.calendar),
          platform: TargetPlatform.android,
        ),
      );

      final Rect bar = tester.getRect(_bar);
      expect(bar.width, 360);
      expect(bar.height, moreOrLessEquals(_barHeight, epsilon: 0.01));
      final double column = bar.width / 5;
      for (final ShellDestination d in ShellDestination.primary) {
        final Finder label = _labelOf(d);
        expect(label, findsOneWidget, reason: d.name);
        final Text text = tester.widget<Text>(label);
        expect(text.maxLines, 1, reason: d.name);
        expect(text.softWrap, isFalse, reason: d.name);
        final RenderParagraph paragraph = tester.renderObject<RenderParagraph>(
          label,
        );
        final TextStyle style = paragraph.text.style!;
        expect(style.fontFamily, TypographyTokens.sans, reason: d.name);
        expect(style.fontSize, 12, reason: d.name);
        expect(style.fontWeight, FontWeight.w500, reason: d.name);
        expect(style.height, isNull, reason: d.name);
        final Rect ring = tester.getRect(
          find.descendant(of: _tab(d), matching: find.byType(FocusRing)),
        );
        expect(
          ring.width,
          greaterThanOrEqualTo(tester.getRect(label).width + 8 - 0.01),
          reason: d.name,
        );
        expect(ring.right - ring.left, lessThanOrEqualTo(column + 0.01));
        expect(
          style.color!.toARGB32(),
          tester.widget<NavIcon>(_iconOf(d)).color.toARGB32(),
          reason: d.name,
        );
        expect(
          tester.getRect(label).top,
          moreOrLessEquals(
            tester.getRect(_iconOf(d)).bottom + _labelGap,
            epsilon: 0.01,
          ),
          reason: d.name,
        );

        final TextPainter oneLine = TextPainter(
          text: TextSpan(text: d.label, style: style),
          textScaler: paragraph.textScaler,
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        addTearDown(oneLine.dispose);
        expect(paragraph.textScaler.scale(12), moreOrLessEquals(15.6));
        expect(paragraph.didExceedMaxLines, isFalse, reason: d.name);
        expect(
          tester.getSize(label).height,
          moreOrLessEquals(oneLine.height, epsilon: 0.01),
          reason: d.name,
        );
        expect(
          tester.getSize(label).width,
          moreOrLessEquals(oneLine.width, epsilon: 0.01),
          reason: d.name,
        );
        expect(
          tester.getRect(label).width,
          lessThanOrEqualTo(column - 8 + 0.01),
          reason: d.name,
        );
        final int index = ShellDestination.primary.indexOf(d);
        final double centre =
            bar.left + column * (index < 2 ? index + 0.5 : index + 1.5);
        expect(
          tester.getCenter(label).dx,
          moreOrLessEquals(centre, epsilon: 0.01),
          reason: d.name,
        );
      }
    });

    testWidgets('an inert bar takes no taps, focus or screen reader nodes', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      final SemanticsHandle handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _themed(
          Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: PhoneBottomBar(
                destinations: ShellDestination.primary,
                selected: ShellDestination.calendar,
              ),
            ),
          ),
          Brightness.light,
        ),
      );

      final Finder inert = find.byType(PhoneBottomBar);
      expect(
        find.descendant(of: inert, matching: find.byType(GestureDetector)),
        findsNothing,
      );
      expect(
        find.descendant(of: inert, matching: find.byType(FocusRing)),
        findsNothing,
      );
      for (final ShellDestination d in ShellDestination.primary) {
        expect(
          find.descendant(of: inert, matching: find.text(d.label)),
          findsOneWidget,
          reason: d.name,
        );
        expect(find.bySemanticsLabel(d.label), findsNothing, reason: d.name);
      }
      handle.dispose();
    });

    testWidgets('the five items sit centred in five equal columns', (
      WidgetTester tester,
    ) async {
      const double inset = 24;
      _phone(tester, bottomInset: inset);
      final SemanticsHandle handle = tester.ensureSemantics();
      ShellDestination? picked;
      await tester.pumpWidget(
        appHarness(
          _shell(onSelect: (ShellDestination d) => picked = d),
          platform: TargetPlatform.android,
        ),
      );

      final FieldNotesColors colors = _colors(tester);
      final Rect bar = tester.getRect(_bar);
      expect(bar.left, 0);
      expect(bar.width, 360);
      expect(bar.bottom, 740);
      expect(bar.height, moreOrLessEquals(_barHeight + inset, epsilon: 0.01));
      final BoxDecoration decoration =
          tester.widget<DecoratedBox>(_bar).decoration as BoxDecoration;
      expect(decoration.color!.toARGB32(), colors.panelTop.toARGB32());
      final BorderSide top = (decoration.border! as Border).top;
      expect(top.width, Shapes.outlineWidth);
      expect(top.color.toARGB32(), colors.line.toARGB32());

      final double column = bar.width / 5;
      for (final (int index, Finder item) in _items.indexed) {
        final double centre = bar.left + column * (index + 0.5);
        expect(
          tester.getCenter(item).dx,
          moreOrLessEquals(centre, epsilon: 0.01),
          reason: 'item ${index + 1}',
        );
      }
      for (final (int index, ShellDestination d)
          in ShellDestination.primary.indexed) {
        final int slot = index < 2 ? index : index + 1;
        final double left = bar.left + column * slot;
        expect(
          tester.getCenter(_iconOf(d)).dx,
          moreOrLessEquals(left + column / 2, epsilon: 0.01),
          reason: d.name,
        );
        final Rect area = _semanticRect(tester, _tab(d));
        expect(area.width, greaterThanOrEqualTo(47.99), reason: d.name);
        expect(area.height, greaterThanOrEqualTo(47.99), reason: d.name);
        for (final double x in <double>[left + 1, left + column - 1]) {
          picked = null;
          await tester.tapAt(Offset(x, bar.top + _barHeight / 2));
          expect(picked, d, reason: '${d.name} at $x');
        }
      }
      handle.dispose();
    });

    testWidgets('the capture button casts the two-point hard shadow', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      for (final Brightness brightness in Brightness.values) {
        await tester.pumpWidget(_themed(_shell(), brightness));

        final FieldNotesColors colors = _colors(tester);
        final BoxDecoration circle = tester
            .widgetList<DecoratedBox>(
              find.descendant(
                of: _capture,
                matching: find.byType(DecoratedBox),
              ),
            )
            .map((DecoratedBox box) => box.decoration)
            .whereType<BoxDecoration>()
            .singleWhere(
              (BoxDecoration decoration) => decoration.shape == BoxShape.circle,
            );
        expect(circle.color!.toARGB32(), Palette.coral.toARGB32());
        final BorderSide outline = (circle.border! as Border).top;
        expect(outline.width, Shapes.outlineWidth);
        expect(outline.color.toARGB32(), colors.line.toARGB32());

        final List<BoxShadow> emphasis = tester
            .element(_capture)
            .shadows
            .emphasis;
        final BoxShadow shadow = circle.boxShadow!.single;
        expect(shadow.offset, const Offset(2, 2), reason: brightness.name);
        expect(shadow.blurRadius, 0, reason: brightness.name);
        expect(shadow.spreadRadius, 0, reason: brightness.name);
        expect(
          shadow.color.toARGB32(),
          colors.shadow.toARGB32(),
          reason: brightness.name,
        );
        expect(shadow.offset, emphasis.single.offset);
        expect(shadow.color.toARGB32(), emphasis.single.color.toARGB32());
      }
    });
  });
}

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
