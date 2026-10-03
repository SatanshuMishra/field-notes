import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:field_notes/app/shell/bottom_bar_shell.dart';
import 'package:field_notes/app/shell/phone_bottom_bar.dart';
import 'package:field_notes/app/shell/shell_destination.dart';
import 'package:field_notes/app/theme/app_theme.dart';
import 'package:field_notes/design/focus/focus_ring.dart';
import 'package:field_notes/design/glass/glass.dart';
import 'package:field_notes/design/icons/nav_icons.dart';
import 'package:field_notes/design/tokens/tokens.dart';
import 'package:field_notes/features/streak/streak.dart';

const Key _pageKey = ValueKey<String>('page');

const double _barHeight = 64;
const double _captureExtent = 46;
const double _iconSize = 22;
const double _labelGap = 2;
const double _plusStroke = 2.6;

const Color _sceneInk = Color.fromRGBO(251, 243, 228, 0.82);
const Color _sceneSelectedInk = Color(0xFFFFD9C9);

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

Widget _app(Widget child, {Brightness brightness = Brightness.light}) =>
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        streakSummaryProvider.overrideWithValue(
          const StreakSummary(current: 3, longest: 3),
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: fieldNotesTheme(
          platform: TargetPlatform.android,
          brightness: brightness,
        ),
        home: child,
      ),
    );

void _phone(WidgetTester tester, {double bottomInset = 0}) {
  tester.view.physicalSize = const Size(1080, 2220);
  tester.view.devicePixelRatio = 3;
  tester.view.padding = FakeViewPadding(bottom: bottomInset * 3);
  tester.view.viewPadding = FakeViewPadding(bottom: bottomInset * 3);
  addTearDown(tester.view.reset);
}

final Finder _bar = find.byType(PhoneBottomBar);

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

Finder get _circle => find.descendant(
  of: _capture,
  matching: find.byWidgetPredicate(
    (Widget widget) =>
        widget is DecoratedBox &&
        widget.decoration is BoxDecoration &&
        (widget.decoration as BoxDecoration).shape == BoxShape.circle,
  ),
);

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

Color _expectedInk(
  FieldNotesColors colors, {
  required ShellDestination selected,
  required ShellDestination d,
}) {
  final bool overScene = selected == ShellDestination.garden;
  final bool on = d == selected;
  return switch ((overScene, on)) {
    (true, true) => _sceneSelectedInk,
    (true, false) => _sceneInk,
    (false, true) => colors.accentInkStrong,
    (false, false) => colors.mutedInkStrong,
  };
}

void main() {
  group('BottomBarShell', () {
    testWidgets('renders four tabs and the center capture', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app(_shell()));

      for (final ShellDestination d in ShellDestination.primary) {
        expect(find.byKey(ValueKey<String>('tab-${d.name}')), findsOneWidget);
      }
      expect(_capture, findsOneWidget);
    });

    testWidgets('a tab reports its destination on tap', (
      WidgetTester tester,
    ) async {
      ShellDestination? picked;
      await tester.pumpWidget(
        _app(_shell(onSelect: (ShellDestination d) => picked = d)),
      );

      await tester.tap(find.byKey(const ValueKey<String>('tab-search')));
      expect(picked, ShellDestination.search);
    });

    testWidgets('the center capture invokes onCapture', (
      WidgetTester tester,
    ) async {
      int captures = 0;
      await tester.pumpWidget(_app(_shell(onCapture: () => captures++)));

      await tester.tap(_capture);
      expect(captures, 1);
    });

    testWidgets('the gear selects the settings destination', (
      WidgetTester tester,
    ) async {
      ShellDestination? picked;
      await tester.pumpWidget(
        _app(_shell(onSelect: (ShellDestination d) => picked = d)),
      );

      await tester.tap(find.byKey(const ValueKey<String>('gear-button')));
      expect(picked, ShellDestination.settings);
    });

    testWidgets(
      'the capture circle sits inside the bar and its whole cell takes the tap',
      (WidgetTester tester) async {
        _phone(tester);
        int captures = 0;
        int pageTaps = 0;
        await tester.pumpWidget(
          _app(
            _shell(
              onCapture: () => captures++,
              body: GestureDetector(
                key: _pageKey,
                behavior: HitTestBehavior.opaque,
                onTap: () => pageTaps++,
                child: const SizedBox.expand(),
              ),
            ),
          ),
        );

        final Rect bar = tester.getRect(_bar);
        final Rect circle = tester.getRect(_circle);
        expect(circle.size, const Size.square(_captureExtent));
        expect(
          circle.center.dx,
          moreOrLessEquals(bar.center.dx, epsilon: 0.01),
        );
        expect(
          circle.center.dy,
          moreOrLessEquals(bar.center.dy, epsilon: 0.01),
        );
        expect(circle.top, greaterThan(bar.top));
        expect(circle.bottom, lessThan(bar.bottom));
        expect(tester.getRect(find.byKey(_pageKey)).bottom, 740);

        final Rect cell = tester.getRect(_capture);
        expect(cell.top, bar.top);
        expect(cell.bottom, bar.bottom);
        for (final Offset point in <Offset>[
          circle.center,
          Offset(cell.left + 2, bar.top + 2),
          Offset(cell.right - 2, bar.bottom - 2),
        ]) {
          await tester.tapAt(point);
        }
        expect(captures, 3);
        expect(pageTaps, 0);

        await tester.tapAt(Offset(circle.center.dx, bar.top - 2));
        expect(pageTaps, 1);
        expect(captures, 3);
      },
    );

    testWidgets('the capture button shows the thin drawn plus', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      await tester.pumpWidget(_app(_shell()));

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
        (tester.getCenter(plus) - tester.getCenter(_circle)).distance,
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
              _app(_shell(selected: selected), brightness: brightness),
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
              final Rect iconRect = tester.getRect(icon);
              final Rect label = tester.getRect(_labelOf(d));
              expect(
                iconRect.top - bar.top,
                moreOrLessEquals(bar.bottom - label.bottom, epsilon: 0.5),
                reason: reason,
              );
              expect(
                drawn.color.toARGB32(),
                _expectedInk(colors, selected: selected, d: d).toARGB32(),
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

    testWidgets('tab labels are eleven-point semibold on one line', (
      WidgetTester tester,
    ) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpWidget(
        _app(_shell(selected: ShellDestination.calendar)),
      );

      final Rect bar = tester.getRect(_bar);
      expect(bar.width, 360 - 24);
      expect(bar.height, _barHeight);
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
        expect(style.fontSize, 11, reason: d.name);
        expect(style.fontWeight, FontWeight.w600, reason: d.name);
        expect(paragraph.didExceedMaxLines, isFalse, reason: d.name);
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
        expect(
          tester.getRect(label).bottom,
          lessThanOrEqualTo(bar.bottom),
          reason: d.name,
        );
        expect(
          tester.getRect(label).width,
          lessThanOrEqualTo(column + 0.01),
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
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: fieldNotesTheme(platform: TargetPlatform.android),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: PhoneBottomBar(
                destinations: ShellDestination.primary,
                selected: ShellDestination.calendar,
              ),
            ),
          ),
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
      expect(find.bySemanticsLabel('New entry'), findsNothing);
      handle.dispose();
    });

    testWidgets('the five cells sit centred in five equal columns', (
      WidgetTester tester,
    ) async {
      const double inset = 24;
      _phone(tester, bottomInset: inset);
      final SemanticsHandle handle = tester.ensureSemantics();
      ShellDestination? picked;
      await tester.pumpWidget(
        _app(_shell(onSelect: (ShellDestination d) => picked = d)),
      );

      final Rect bar = tester.getRect(_bar);
      expect(bar.left, 12);
      expect(bar.right, 348);
      expect(bar.bottom, 740 - inset - 8);
      expect(bar.height, _barHeight);

      final double column = bar.width / 5;
      for (final (int index, Finder item) in _items.indexed) {
        final double centre = bar.left + column * (index + 0.5);
        expect(
          tester.getCenter(item).dx,
          moreOrLessEquals(centre, epsilon: 0.01),
          reason: 'item ${index + 1}',
        );
        final Rect area = _semanticRect(tester, item);
        expect(area.height, greaterThanOrEqualTo(48), reason: 'item $index');
        expect(area.width, greaterThanOrEqualTo(44), reason: 'item $index');
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
        for (final double x in <double>[left + 1, left + column - 1]) {
          picked = null;
          await tester.tapAt(Offset(x, bar.top + _barHeight / 2));
          expect(picked, d, reason: '${d.name} at $x');
        }
      }
      handle.dispose();
    });

    testWidgets('the selected tab sits on the soft glass pill', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      for (final Brightness brightness in Brightness.values) {
        for (final ShellDestination selected in ShellDestination.primary) {
          await tester.pumpWidget(
            _app(_shell(selected: selected), brightness: brightness),
          );
          final GlassTone tone = selected == ShellDestination.garden
              ? GlassTone.scene
              : GlassTone.paper;
          final GlassSurface glass = tester.widget<GlassSurface>(
            find.descendant(of: _bar, matching: find.byType(GlassSurface)),
          );
          expect(glass.tone, tone, reason: selected.name);
          final Color pill = tone.pillFor(brightness);
          for (final ShellDestination d in ShellDestination.primary) {
            final Iterable<BoxDecoration> fills = tester
                .widgetList<DecoratedBox>(
                  find.descendant(
                    of: _tab(d),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .map((DecoratedBox box) => box.decoration)
                .whereType<BoxDecoration>()
                .where((BoxDecoration decoration) => decoration.color != null);
            expect(
              fills.map((BoxDecoration fill) => fill.color!.toARGB32()),
              d == selected ? <int>[pill.toARGB32()] : isEmpty,
              reason: '${brightness.name} ${selected.name}: ${d.name}',
            );
            if (d == selected) {
              expect(
                fills.single.borderRadius,
                const BorderRadius.all(Radius.circular(26)),
              );
            }
          }
        }
      }
    });

    testWidgets('the capture button casts the soft terracotta shadow', (
      WidgetTester tester,
    ) async {
      _phone(tester);
      for (final Brightness brightness in Brightness.values) {
        await tester.pumpWidget(_app(_shell(), brightness: brightness));

        final FieldNotesColors colors = _colors(tester);
        final BoxDecoration circle =
            tester.widget<DecoratedBox>(_circle).decoration as BoxDecoration;
        expect(circle.color!.toARGB32(), Palette.coral.toARGB32());
        final BorderSide outline = (circle.border! as Border).top;
        expect(outline.width, Shapes.outlineWidth);
        expect(outline.color.toARGB32(), colors.line.toARGB32());

        final BoxShadow shadow = circle.boxShadow!.single;
        expect(shadow.offset, const Offset(0, 4), reason: brightness.name);
        expect(shadow.blurRadius, 12, reason: brightness.name);
        expect(shadow.spreadRadius, -4, reason: brightness.name);
        expect(
          shadow.color.toARGB32(),
          const Color.fromRGBO(120, 50, 30, 0.55).toARGB32(),
          reason: brightness.name,
        );
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
