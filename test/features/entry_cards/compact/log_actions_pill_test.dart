import 'package:field_notes/features/entry_cards/compact/log_actions_pill.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _cardAKey = ValueKey<String>('card-a');
const Key _cardBKey = ValueKey<String>('card-b');
const Key _revealAKey = ValueKey<String>('reveal-a');
const Key _revealBKey = ValueKey<String>('reveal-b');
const Key _outsideKey = ValueKey<String>('outside');

const Duration _settle = Duration(milliseconds: 200);

Future<void> _settleReveal(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(_settle);
}

Widget _card(Key key) => SizedBox(
      key: key,
      width: 300,
      height: 100,
      child: const ColoredBox(color: Color(0xFFEEDDCC)),
    );

Widget _harness({
  VoidCallback? onEdit,
  required VoidCallback onDelete,
  bool second = false,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ListView(
        children: <Widget>[
          const SizedBox(key: _outsideKey, height: 60),
          Center(
            child: LogActionsReveal(
              key: _revealAKey,
              onEdit: onEdit,
              onDelete: onDelete,
              child: _card(_cardAKey),
            ),
          ),
          if (second) ...<Widget>[
            const SizedBox(height: 60),
            Center(
              child: LogActionsReveal(
                key: _revealBKey,
                onEdit: onEdit,
                onDelete: onDelete,
                child: _card(_cardBKey),
              ),
            ),
          ],
          const SizedBox(height: 400),
        ],
      ),
    ),
  );
}

Finder _pillOf(Key revealKey) => find.descendant(
      of: find.byKey(revealKey),
      matching: find.byKey(logActionsPillKey),
    );

double _opacity(WidgetTester tester, [Key revealKey = _revealAKey]) {
  final Opacity opacity = tester.widget<Opacity>(
    find
        .ancestor(of: _pillOf(revealKey), matching: find.byType(Opacity))
        .first,
  );
  return opacity.opacity;
}

void main() {
  testWidgets('the pill is hidden until the card is hovered',
      (WidgetTester tester) async {
    int deletes = 0;
    await tester.pumpWidget(_harness(onEdit: () {}, onDelete: () => deletes++));

    expect(_opacity(tester), 0);
    await tester.tapAt(tester.getCenter(find.byKey(logActionsDeleteKey)));
    await _settleReveal(tester);
    expect(deletes, 0);
    expect(_opacity(tester), 0);

    final TestGesture mouse =
        await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(tester.getCenter(find.byKey(_cardAKey)));
    await _settleReveal(tester);

    expect(_opacity(tester), 1);
  });

  testWidgets('keyboard focus inside the card reveals the pill',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness(onEdit: () {}, onDelete: () {}));
    expect(_opacity(tester), 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await _settleReveal(tester);

    expect(_opacity(tester), 1);
  });

  testWidgets('a long-press reveals the pill and a tap outside hides it',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness(onEdit: () {}, onDelete: () {}));

    await tester.longPress(find.byKey(_cardAKey));
    await _settleReveal(tester);
    expect(_opacity(tester), 1);

    await tester.tapAt(tester.getTopLeft(find.byKey(_outsideKey)) +
        const Offset(4, 4));
    await _settleReveal(tester);
    expect(_opacity(tester), 0);
  });

  testWidgets("a tap just below a button's top edge runs its action",
      (WidgetTester tester) async {
    int deletes = 0;
    await tester.pumpWidget(_harness(onEdit: () {}, onDelete: () => deletes++));

    await tester.longPress(find.byKey(_cardAKey));
    await _settleReveal(tester);

    final Offset target = tester.getTopLeft(find.byKey(logActionsDeleteKey)) +
        Offset(tester.getSize(find.byKey(logActionsDeleteKey)).width / 2, 2);
    expect(target.dy, lessThan(tester.getTopLeft(find.byKey(_cardAKey)).dy));

    await tester.tapAt(target);
    await _settleReveal(tester);

    expect(deletes, 1);
  });

  testWidgets('a card without an edit action shows Delete only',
      (WidgetTester tester) async {
    await tester.pumpWidget(_harness(onDelete: () {}));

    expect(find.byKey(logActionsEditKey), findsNothing);
    expect(find.byKey(logActionsDeleteKey), findsOneWidget);
  });

  testWidgets('choosing an action hides the pill and runs it once',
      (WidgetTester tester) async {
    int edits = 0;
    await tester.pumpWidget(_harness(onEdit: () => edits++, onDelete: () {}));

    await tester.longPress(find.byKey(_cardAKey));
    await _settleReveal(tester);
    expect(_opacity(tester), 1);

    await tester.tap(find.byKey(logActionsEditKey));
    await _settleReveal(tester);

    expect(edits, 1);
    expect(_opacity(tester), 0);
  });

  testWidgets("revealing one card's pill hides another's",
      (WidgetTester tester) async {
    await tester.pumpWidget(
      _harness(onEdit: () {}, onDelete: () {}, second: true),
    );

    await tester.longPress(find.byKey(_cardAKey));
    await _settleReveal(tester);
    expect(_opacity(tester, _revealAKey), 1);
    expect(_opacity(tester, _revealBKey), 0);

    await tester.longPress(find.byKey(_cardBKey));
    await _settleReveal(tester);
    expect(_opacity(tester, _revealAKey), 0);
    expect(_opacity(tester, _revealBKey), 1);
  });
}
