import 'package:field_notes/features/entry_cards/compact/log_actions_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Key _cardKey = ValueKey<String>('card');

Future<List<String>> _pumpCards(WidgetTester tester) async {
  final List<String> taps = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: <Widget>[
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => taps.add('above'),
                child: const SizedBox(width: 371, height: 120),
              ),
              const SizedBox(height: 12),
              LogActionsReveal(
                onEdit: () => taps.add('edit'),
                onDelete: () => taps.add('delete'),
                child: GestureDetector(
                  key: _cardKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: () => taps.add('card'),
                  child: const SizedBox(width: 371, height: 139),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return taps;
}

void main() {
  testWidgets('a hidden pill does not swallow taps on the card', (
    WidgetTester tester,
  ) async {
    final List<String> taps = await _pumpCards(tester);
    final Rect card = tester.getRect(find.byKey(_cardKey));
    for (final Offset point in <Offset>[
      card.topRight + const Offset(-85, 10),
      card.topRight + const Offset(-20, 5),
      card.topRight + const Offset(-60, 30),
    ]) {
      await tester.tapAt(point);
      await tester.pump(const Duration(milliseconds: 400));
    }
    expect(taps, <String>['card', 'card', 'card']);
  });

  testWidgets('a shown pill reaches no higher than its painted top', (
    WidgetTester tester,
  ) async {
    await _pumpCards(tester);
    await tester.longPress(find.byKey(_cardKey));
    await tester.pumpAndSettle();
    final Rect pill = tester.getRect(find.byKey(logActionsPillKey));
    final Rect painted = tester.getRect(
      find
          .descendant(
            of: find.byKey(logActionsPillKey),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(pill.top, moreOrLessEquals(painted.top, epsilon: 0.01));
  });
}
