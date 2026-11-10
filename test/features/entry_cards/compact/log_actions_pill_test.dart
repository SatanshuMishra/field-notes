import 'package:field_notes/design/widgets/widgets.dart';
import 'package:field_notes/features/entry_cards/compact/log_actions_pill.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _cardKey = ValueKey<String>('card');
const Key _menuItemKey = ValueKey<String>('menu-item');

final class _Taps {
  int opens = 0;
  int chosen = 0;
}

Future<_Taps> _pumpActions(
  WidgetTester tester, {
  Alignment alignment = Alignment.topRight,
}) async {
  final _Taps taps = _Taps();
  final GlobalKey anchor = GlobalKey();
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: alignment,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: LogCardActions(
              onOpen: () => taps.opens++,
              moreAnchorKey: anchor,
              onMore: () => showLogActionsMenu(
                anchor.currentContext!,
                items: <LogMenuItem>[
                  LogMenuItem(
                    key: _menuItemKey,
                    label: 'Rename',
                    glyph: LogMenuGlyph.title,
                    onSelected: () => taps.chosen++,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return taps;
}

Color? _pillFill(WidgetTester tester, Key button) {
  final Iterable<DecoratedBox> faces = tester.widgetList<DecoratedBox>(
    find.descendant(
      of: find.byKey(button),
      matching: find.byType(DecoratedBox),
    ),
  );
  return <Color?>[
    for (final DecoratedBox face in faces)
      if (face.decoration case BoxDecoration(:final Color color)) color,
  ].firstOrNull;
}

Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(find.byKey(logActionsMoreKey));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a desktop menu sits straight under More at its right edge', (
    WidgetTester tester,
  ) async {
    await _pumpActions(tester);

    await _openMenu(tester);

    final Rect more = tester.getRect(find.byKey(logActionsMoreKey));
    final Rect menu = tester.getRect(find.byKey(logActionsMenuKey));
    expect(menu.right, moreOrLessEquals(more.right, epsilon: 0.01));
    expect(menu.top, greaterThanOrEqualTo(more.bottom));
    expect(find.byType(PhoneSheet), findsNothing);
    final Iterable<Transform> transforms = tester.widgetList<Transform>(
      find.ancestor(
        of: find.byKey(logActionsMenuKey),
        matching: find.byType(Transform),
      ),
    );
    for (final Transform transform in transforms) {
      expect(transform.transform.entry(0, 1), 0);
      expect(transform.transform.entry(1, 0), 0);
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a desktop menu with no room below opens above More', (
    WidgetTester tester,
  ) async {
    await _pumpActions(tester, alignment: Alignment.bottomRight);

    await _openMenu(tester);

    final Rect more = tester.getRect(find.byKey(logActionsMoreKey));
    final Rect menu = tester.getRect(find.byKey(logActionsMenuKey));
    expect(menu.bottom, lessThanOrEqualTo(more.top));
  }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

  testWidgets('choosing a menu row closes it and runs the action once', (
    WidgetTester tester,
  ) async {
    final _Taps taps = await _pumpActions(tester);

    await _openMenu(tester);
    await tester.tap(find.byKey(_menuItemKey));
    await tester.pumpAndSettle();

    expect(taps.chosen, 1);
    expect(taps.opens, 0);
    expect(find.byKey(logActionsMenuKey), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('a click outside closes the menu and runs nothing', (
    WidgetTester tester,
  ) async {
    final _Taps taps = await _pumpActions(tester);

    await _openMenu(tester);
    await tester.tapAt(const Offset(4, 400));
    await tester.pumpAndSettle();

    expect(taps.chosen, 0);
    expect(find.byKey(logActionsMenuKey), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('on a phone the menu is a bottom sheet with full size rows', (
    WidgetTester tester,
  ) async {
    await _pumpActions(tester);

    await _openMenu(tester);

    expect(find.byType(PhoneSheet), findsOneWidget);
    expect(
      tester.getSize(find.byKey(_menuItemKey)).height,
      greaterThanOrEqualTo(48),
    );
  });

  testWidgets('Open fires only Open and lights up with the card highlight', (
    WidgetTester tester,
  ) async {
    int opens = 0;
    Widget actions(bool highlighted) => MaterialApp(
      home: Scaffold(
        body: Center(
          child: LogCardHighlight(
            active: highlighted,
            child: LogCardActions(onOpen: () => opens++, onMore: () {}),
          ),
        ),
      ),
    );
    Color openFill() =>
        (tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: find.byKey(logActionsOpenKey),
                            matching: find.byType(DecoratedBox),
                          )
                          .last,
                    )
                    .decoration
                as BoxDecoration)
            .color ??
        const Color(0x00000000);

    await tester.pumpWidget(actions(false));
    expect(openFill(), const Color(0x00000000));

    await tester.pumpWidget(actions(true));
    expect(openFill(), isNot(const Color(0x00000000)));

    await tester.tap(find.byKey(logActionsOpenKey));
    await tester.pump();
    expect(opens, 1);
  });

  testWidgets('a pill button fills after Tab and never after a mouse click', (
    WidgetTester tester,
  ) async {
    int deletes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LogActionsPill(onEdit: () {}, onDelete: () => deletes++),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(FocusManager.instance.highlightMode, FocusHighlightMode.traditional);

    final TestGesture mouse = await tester.createGesture(
      kind: PointerDeviceKind.mouse,
    );
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byKey(logActionsDeleteKey)));
    await tester.pump();
    await mouse.down(tester.getCenter(find.byKey(logActionsDeleteKey)));
    await mouse.up();
    await mouse.moveTo(Offset.zero);
    await tester.pump();

    expect(deletes, 1);
    expect(_pillFill(tester, logActionsDeleteKey), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    expect(_pillFill(tester, logActionsEditKey), isNull);
    expect(_pillFill(tester, logActionsDeleteKey), isNotNull);

    await mouse.down(tester.getCenter(find.byKey(logActionsDeleteKey)));
    await mouse.up();
    await mouse.moveTo(Offset.zero);
    await tester.pump();

    expect(deletes, 2);
    expect(_pillFill(tester, logActionsDeleteKey), isNull);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('the card frame opens on tap and long-presses on hold', (
    WidgetTester tester,
  ) async {
    int opens = 0;
    int holds = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LogCardFrame(
              onOpen: () => opens++,
              onLongPress: () => holds++,
              builder: (BuildContext context, bool hovered) => const ColoredBox(
                key: _cardKey,
                color: Color(0xFFEEDDCC),
                child: SizedBox(width: 300, height: 100),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(_cardKey));
    await tester.pump(const Duration(milliseconds: 400));
    expect(opens, 1);
    expect(holds, 0);

    await tester.longPress(find.byKey(_cardKey));
    await tester.pump(const Duration(milliseconds: 400));
    expect(opens, 1);
    expect(holds, 1);
  });

  testWidgets('the card frame keeps its place in the list for screen readers', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LogCardFrame(
              onOpen: () {},
              onLongPress: () {},
              semanticIndex: 3,
              builder: (BuildContext context, bool hovered) =>
                  const SizedBox(width: 300, height: 100),
            ),
          ),
        ),
      ),
    );

    expect(
      tester.widget<IndexedSemantics>(find.byType(IndexedSemantics)).index,
      3,
    );
  });
}
