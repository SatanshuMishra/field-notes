import 'package:field_notes/features/entry_cards/compact/log_actions_pill.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a pill that grows down reaches no higher than its painted top', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: LogActionsPill(
              key: logActionsPillKey,
              onEdit: () {},
              onDelete: () {},
              growDown: true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

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
