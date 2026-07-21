import 'package:field_notes/features/calendar/widgets/calendar_chevron_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('exposes its semantic label and fires onPressed when tapped',
      (WidgetTester tester) async {
    int taps = 0;
    await tester.pumpWidget(
      _host(
        CalendarChevronButton(
          direction: ChevronDirection.previous,
          semanticLabel: 'Previous month',
          onPressed: () => taps++,
        ),
      ),
    );

    expect(find.bySemanticsLabel('Previous month'), findsOneWidget);

    await tester.tap(find.byType(CalendarChevronButton));
    expect(taps, 1);
  });
}
