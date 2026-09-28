import 'package:field_notes/features/day_detail/day_detail_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('the back chip keeps its painted position', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    const Key header = ValueKey<String>('header');
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 371,
              child: DayDetailHeader(
                key: header,
                date: '2026-09-17',
                today: DateTime(2026, 9, 18),
                onClose: () {},
              ),
            ),
          ),
        ),
      ),
    );
    final Rect bounds = tester.getRect(find.byKey(header));
    final Rect chip = tester.getRect(
      find
          .descendant(
            of: find.byKey(header),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    expect(bounds.height, 73.5);
    expect(chip.topLeft - bounds.topLeft, const Offset(18, 19));
    expect(chip.size, const Size(34, 34));
    final SemanticsNode close = find.semantics
        .byLabel(dayDetailCloseLabel)
        .evaluate()
        .single;
    expect(close.rect.width, greaterThanOrEqualTo(48));
    expect(close.rect.height, greaterThanOrEqualTo(48));
    handle.dispose();
  });
}
